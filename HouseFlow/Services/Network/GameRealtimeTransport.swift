import Foundation

/// Single receive consumer; decoding, lobbies and application heartbeat live above transport.
@MainActor
protocol GameRealtimeTransporting: AnyObject {
    func connect(request: URLRequest) async throws
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func ping() async throws
    func disconnect()
}

/// Injectable socket seam for deterministic cancellation and upgrade-error tests.
@MainActor
protocol GameWebSocketConnecting: AnyObject {
    func resume()
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func ping() async throws
    func cancel()
}

@MainActor
final class GameRealtimeTransport: GameRealtimeTransporting {
    typealias SocketFactory = @MainActor (URLRequest) -> any GameWebSocketConnecting
    private let makeSocket: SocketFactory
    private let maximumIncomingBytes: Int
    private var socket: (any GameWebSocketConnecting)?
    private var generation = UUID()

    init(session: URLSession? = nil, maximumIncomingBytes: Int = 1_048_576,
         socketFactory: SocketFactory? = nil) {
        self.maximumIncomingBytes = maximumIncomingBytes
        if let socketFactory {
            makeSocket = socketFactory
        } else {
            let resolvedSession = session ?? URLSession(configuration: .ephemeral)
            makeSocket = { request in
                let task = resolvedSession.webSocketTask(with: request)
                task.maximumMessageSize = maximumIncomingBytes
                return URLSessionGameWebSocket(task: task)
            }
        }
    }

    func connect(request: URLRequest) async throws {
        try Task.checkCancellation()
        guard let url = request.url, ["ws", "wss"].contains(url.scheme?.lowercased() ?? ""),
              request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true else {
            throw GameRealtimeError.invalidContext
        }
        disconnect()
        socket = makeSocket(request)
        socket?.resume()
    }

    func send(_ data: Data) async throws {
        guard data.count <= GameRealtimeCodec.maximumClientMessageBytes else { throw GameRealtimeError.messageTooLarge }
        try await perform { try await $0.send(data) }
    }

    func receive() async throws -> Data {
        let data = try await perform { try await $0.receive() }
        guard data.count <= maximumIncomingBytes else {
            disconnect()
            throw GameRealtimeError.messageTooLarge
        }
        return data
    }

    func ping() async throws {
        try await perform { try await $0.ping() }
    }

    func disconnect() {
        generation = UUID()
        socket?.cancel()
        socket = nil
    }

    /// The game gateway accepts JSON in WebSocket text frames only.
    static func textMessage(from data: Data) throws -> URLSessionWebSocketTask.Message {
        guard let text = String(data: data, encoding: .utf8) else {
            throw GameRealtimeError.invalidResponse
        }
        return .string(text)
    }

    private func currentSocket() throws -> (any GameWebSocketConnecting, UUID) {
        try Task.checkCancellation()
        guard let socket else { throw GameRealtimeError.notConnected }
        return (socket, generation)
    }

    private func requireCurrent(_ expected: UUID) throws {
        try Task.checkCancellation()
        guard generation == expected else { throw CancellationError() }
    }

    private func perform<Value: Sendable>(
        _ action: @MainActor (any GameWebSocketConnecting) async throws -> Value
    ) async throws -> Value {
        let (socket, expected) = try currentSocket()
        return try await withTaskCancellationHandler {
            do {
                let value = try await action(socket)
                try requireCurrent(expected)
                return value
            } catch {
                try requireCurrent(expected)
                throw error
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == expected else { return }
                self.disconnect()
            }
        }
    }
}

@MainActor
private final class URLSessionGameWebSocket: GameWebSocketConnecting {
    private let task: URLSessionWebSocketTask
    init(task: URLSessionWebSocketTask) { self.task = task }
    deinit { task.cancel(with: .goingAway, reason: nil) }
    func resume() { task.resume() }
    func cancel() { task.cancel(with: .goingAway, reason: nil) }

    func send(_ data: Data) async throws {
        do {
            try await task.send(GameRealtimeTransport.textMessage(from: data))
        } catch { throw upgradeFailure(or: error) }
    }

    func receive() async throws -> Data {
        do {
            switch try await task.receive() {
            case .data(let data): return data
            case .string(let text): return Data(text.utf8)
            @unknown default: throw GameRealtimeError.invalidResponse
            }
        } catch { throw upgradeFailure(or: error) }
    }

    func ping() async throws {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                task.sendPing { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        } catch { throw upgradeFailure(or: error) }
    }

    private func upgradeFailure(or error: Error) -> Error {
        guard let response = task.response as? HTTPURLResponse, response.statusCode >= 400 else { return error }
        return NetworkHTTPFailure(response: .init(data: Data(), response: response))
    }
}
