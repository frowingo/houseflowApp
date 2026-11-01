import Foundation
import FausCrewCore

final class ChoreService {
    typealias PhotoExecutor = URLSessionHTTPClient.RequestExecutor

    private let network: any NetworkServicing
    private let keychain: any KeychainStoring
    private let photoExecutor: PhotoExecutor

    init(
        network: any NetworkServicing,
        keychain: any KeychainStoring,
        photoExecutor: PhotoExecutor? = nil
    ) {
        self.network = network
        self.keychain = keychain
        if let photoExecutor {
            self.photoExecutor = photoExecutor
        } else {
            let session = Self.makeReviewPhotoSession()
            self.photoExecutor = { request in try await session.data(for: request) }
        }
    }

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
    func updateChoreStatus(houseId: String, chores: [ChoreStatusUpdateItem]) async throws -> [ChoreResponse] {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = UpdateChoreStatusRequest(chores: chores, houseId: houseId)
        return try await network.authenticatedRequest(
            path: "chore/status",
            method: "PUT",
            body: body,
            successType: [ChoreResponse].self,
            token: token
        )
    }

    // MARK: - Update Chore Status With Review Photo

    /// PUT /chore/status as multipart — exactly one chore moving to InTest.
    /// Fields: `houseId`, `chores` (JSON string) and `file`.
    func updateChoreStatusWithReviewPhoto(
        houseId: String,
        choreId: String,
        photo: ChoreReviewPhotoUpload
    ) async throws -> [ChoreResponse] {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        var form = MultipartFormData()
        form.append(name: "houseId", value: houseId)
        form.append(name: "chores", value: try DashboardWireContract.reviewPhotoChoresField(choreId: choreId))
        form.append(name: "file", fileName: photo.fileName, mimeType: photo.mimeType, data: photo.data)
        return try await network.authenticatedMultipartRequest(
            path: "chore/status",
            method: "PUT",
            form: form,
            successType: [ChoreResponse].self,
            token: token
        )
    }

    // MARK: - Review Photo

    /// GET /chore/{id}/review-photo/{round} — requires Bearer token.
    /// The signed URL lives ~5 minutes; callers must not persist or log it.
    func fetchReviewPhotoURL(choreId: String, round: Int) async throws -> ChoreReviewPhotoURLResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        return try await network.get(
            path: "chore/\(choreId)/review-photo/\(round)",
            queryItems: [],
            successType: ChoreReviewPhotoURLResponse.self,
            token: token
        )
    }

    /// Fetches the signed storage URL without a Bearer token or any cache.
    /// A 403 surfaces as `NetworkError.unknown(403)` so the caller can refresh once.
    func downloadReviewPhoto(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await photoExecutor(request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.unknown(-1) }
        guard (200..<300).contains(http.statusCode) else { throw NetworkError.unknown(http.statusCode) }
        return data
    }

    private static func makeReviewPhotoSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }

    // MARK: - Review Chore

    /// PUT /chore/review — requires Bearer token
    func reviewChore(choreId: String, isApproved: Bool) async throws -> ChoreResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = ReviewChoreRequest(choreId: choreId, isApproved: isApproved)
        return try await network.authenticatedRequest(
            path: "chore/review",
            method: "PUT",
            body: body,
            successType: ChoreResponse.self,
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
