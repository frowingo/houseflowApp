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

        let response = try await httpClient.send(HTTPRequest(
            path: "auth/isAuth",
            method: "GET",
            headers: ["Authorization": "Bearer \(token)"]
        ))
        try Task.checkCancellation()

        guard (200...399).contains(response.statusCode) else {
            throw HTTPStatusFailure(response: response, decoder: decoder)
        }

        let payload = try decoder.decode(IsAuthResponse.self, from: response.body)
        guard payload.success, let profile = payload.data else {
            throw SessionRestoreError.invalidProfile
        }
        return profile
    }
}
