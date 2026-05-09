import Foundation

final class ChoreService {
    static let shared = ChoreService()

    private let network = NetworkService.shared
    private let keychain = KeychainService.shared

    private init() {}

    // MARK: - Create Chore

    /// POST /chore/  — requires Bearer token
    func createChore(
        assignedTo: String,
        description: String,
        dueDate: String,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String
    ) async throws -> ChoreResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = CreateChoreRequest(
            assignedTo: assignedTo,
            description: description,
            dueDate: dueDate,
            houseId: houseId,
            isRecurring: isRecurring,
            level: level.rawValue,
            recurringInterval: recurringInterval,
            title: title
        )
        return try await network.authenticatedRequest(
            path: "chore",
            method: "POST",
            body: body,
            successType: ChoreResponse.self,
            token: token
        )
    }

    // MARK: - Update Chore Status

    /// PUT /chore/status  — requires Bearer token
    /// A 200 response indicates success; the response body is not used.
    func updateChoreStatus(houseId: String, chores: [ChoreStatusUpdateItem]) async throws {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = UpdateChoreStatusRequest(chores: chores, houseId: houseId)
        // We only care about 200; decode into an empty placeholder.
        _ = try await network.authenticatedRequest(
            path: "chore/status",
            method: "PUT",
            body: body,
            successType: EmptyResponse.self,
            token: token
        )
    }

    // MARK: - Update Chore

    /// PUT /chore/{id}  — requires Bearer token
    func updateChore(
        choreId: String,
        assignedTo: String,
        description: String,
        dueDate: String,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String
    ) async throws -> ChoreResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = UpdateChoreRequest(
            assignedTo: assignedTo,
            description: description,
            dueDate: dueDate,
            houseId: houseId,
            isRecurring: isRecurring,
            level: level.rawValue,
            recurringInterval: recurringInterval,
            title: title
        )
        return try await network.authenticatedRequest(
            path: "chore/\(choreId)",
            method: "PUT",
            body: body,
            successType: ChoreResponse.self,
            token: token
        )
    }
}

// MARK: - Private helpers

/// Used to satisfy the generic decode constraint when the response body is irrelevant.
private struct EmptyResponse: Decodable {}
