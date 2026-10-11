import Foundation

public enum SessionRestoreError: Error, Equatable, Sendable {
    case missingToken
    case invalidProfile
}

/// The startup/foreground session check. Routing and visible error presentation
/// remain with the platform host.
@MainActor
public struct RestoreSessionUseCase {
    private let httpClient: any HTTPClient
    private let secureStore: any SecureSessionStore
    private let decoder: JSONDecoder

    public init(
        httpClient: any HTTPClient,
        secureStore: any SecureSessionStore,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.httpClient = httpClient
        self.secureStore = secureStore
        self.decoder = decoder
    }

    public func restore() async throws -> IsAuthUserData {
        try Task.checkCancellation()
        guard let token = secureStore.authToken else {
            throw SessionRestoreError.missingToken
        }

        let response = try await httpClient.send(AuthWireContract.profileRequest(token: token))
        try Task.checkCancellation()
        return try AuthWireContract.profile(from: response, decoder: decoder)
    }
}
