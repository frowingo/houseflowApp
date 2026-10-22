import Foundation
import FausCrewCore
import os

/// The iOS host of FausCrewCore's `AppEventsChannel`: one `/api/v1/events` socket while
/// the app is in the foreground and signed in. It performs the channel's effects and
/// asks the app to refresh over HTTP; the signals themselves carry no data.
@MainActor
final class AppEventsService {
    /// Forced refresh of the profile/house list and/or the given selected house.
    var onRefresh: ((_ profile: Bool, _ houseID: String?) async -> Void)?
    var onSignedOut: (() -> Void)?

    private let baseURL: URL
    private let keychain: any KeychainStoring
    private let makeTransport: @MainActor (URLSession) -> any GameRealtimeTransporting
    private let clock: GameRealtimeClock
    private let channel: AppEventsChannel
    private let socketSession = URLSession(configuration: .ephemeral)
    private static let log = Logger(subsystem: "com.fauscrew", category: "AppEvents")

    private var isForeground = true
    private var isAuthenticated = false
    private var transport: (any GameRealtimeTransporting)?
    private var socketConnection = -1
    private var receiveTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var queuedRefresh: (profile: Bool, houseID: String?)?

    init(baseURL: URL, keychain: any KeychainStoring,
         makeTransport: @escaping @MainActor (URLSession) -> any GameRealtimeTransporting = {
             GameRealtimeTransport(session: $0)
         },
         clock: GameRealtimeClock = .live, channel: AppEventsChannel = AppEventsChannel()) {
        self.baseURL = baseURL
        self.keychain = keychain
        self.makeTransport = makeTransport
        self.clock = clock
        self.channel = channel
    }

    func setForeground(_ active: Bool) {
        isForeground = active
        apply()
    }

    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
        apply()
    }

    func setSelectedHouse(_ houseID: String?) {
        channel.setSelectedHouse(houseID)
    }

    private func apply() {
        channel.setActive(foreground: isForeground, authenticated: isAuthenticated, now: clock.uptime())
        perform()
        if isForeground, isAuthenticated { startTicking() } else { tickTask?.cancel(); tickTask = nil }
    }

    private func startTicking() {
        guard tickTask == nil else { return }
        let clock = self.clock
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await clock.sleep(0.25) } catch { return }
                guard let self else { return }
                self.channel.tick(now: clock.uptime())
                self.perform()
            }
        }
    }

    private func perform() {
        for effect in channel.drainEffects() {
            switch effect {
            case .openSocket(let connection): open(connection)
            case .closeSocket: closeSocket()
            case .refresh(let profile, let houseID): refresh(profile: profile, houseID: houseID)
            case .signedOut: onSignedOut?()
            }
        }
    }

    private func open(_ connection: Int) {
        closeSocket()
        socketConnection = connection
        guard let token = keychain.authToken, var values = URLComponents(
            url: baseURL.appendingPathComponent(AppEventsWire.path), resolvingAgainstBaseURL: false) else {
            channel.connectionFailed(status: 401, connection: connection, now: clock.uptime())
            perform()
            return
        }
        values.scheme = values.scheme?.lowercased() == "https" ? "wss" : "ws"
        guard let url = values.url else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let transport = makeTransport(socketSession)
        self.transport = transport
        receiveTask = Task { [weak self] in
            do {
                try await transport.connect(request: request)
                guard let self, self.socketConnection == connection else { return }
                self.channel.socketOpened(connection: connection, now: self.clock.uptime())
                while !Task.isCancelled {
                    let data = try await transport.receive()
                    guard self.socketConnection == connection else { return }
                    self.channel.received(text: String(decoding: data, as: UTF8.self), connection: connection,
                                          now: self.clock.uptime())
                    self.perform()
                }
            } catch {
                guard let self, !Task.isCancelled, self.socketConnection == connection else { return }
                let status = (error as? NetworkHTTPFailure)?.statusCode
                Self.log.notice("App events socket closed: \(status.map(String.init) ?? "transport", privacy: .public)")
                self.channel.connectionFailed(status: status, connection: connection, now: self.clock.uptime())
                self.perform()
            }
        }
    }

    private func closeSocket() {
        receiveTask?.cancel(); receiveTask = nil
        transport?.disconnect()
        transport = nil
        socketConnection = -1
    }

    /// Refreshes run one at a time; one arriving meanwhile is merged and run next.
    private func refresh(profile: Bool, houseID: String?) {
        guard refreshTask == nil else {
            queuedRefresh = (profile || (queuedRefresh?.profile ?? false), houseID ?? queuedRefresh?.houseID)
            return
        }
        refreshTask = Task { [weak self] in
            await self?.onRefresh?(profile, houseID)
            guard let self else { return }
            self.refreshTask = nil
            if let next = self.queuedRefresh {
                self.queuedRefresh = nil
                self.refresh(profile: next.profile, houseID: next.houseID)
            }
        }
    }
}
