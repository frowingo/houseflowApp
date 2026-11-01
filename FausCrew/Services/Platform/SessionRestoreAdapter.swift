import Foundation
import FausCrewCore

/// Maps Core restore outcomes back to the iOS error types already shown by the UI.
@MainActor
final class SessionRestoreAdapter: SessionRestoring {
    private let useCase: RestoreSessionUseCase

    init(useCase: RestoreSessionUseCase) {
        self.useCase = useCase
    }

    func restoreProfile(invalidMessage: String) async throws -> IsAuthUserData {
        do {
            return try await useCase.restore()
        } catch SessionRestoreError.missingToken {
            throw NetworkError.serverError("No token stored.")
        } catch SessionRestoreError.invalidProfile {
            throw NetworkError.serverError(invalidMessage)
        } catch let failure as HTTPStatusFailure {
            if let message = failure.message {
                throw NetworkError.serverError(message)
            }
            throw NetworkError.unknown(failure.statusCode)
        } catch HTTPClientError.invalidURL {
            throw NetworkError.invalidURL
        } catch HTTPClientError.invalidResponse {
            throw NetworkError.unknown(-1)
        } catch let error as DecodingError {
            throw NetworkError.decodingError(error)
        }
    }
}
