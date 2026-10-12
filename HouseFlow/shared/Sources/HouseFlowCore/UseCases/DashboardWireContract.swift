import Foundation

/// Chore and announcement wire rules shared by the two clients. The Android
/// bridge crosses once per request/response, never once per rendered row.
public enum DashboardWireContract {
    public static func choreBody(
        assignedTo: String, description: String, dueDate: String, houseId: String,
        isRecurring: Bool, level: Int, recurringInterval: Int, title: String
    ) throws -> Data {
        try JSONEncoder().encode(CreateChoreRequest(
            assignedTo: assignedTo, description: description, dueDate: dueDate,
            houseId: houseId, isRecurring: isRecurring, level: level,
            recurringInterval: recurringInterval, title: title
        ))
    }

    public static func updateChoreBody(
        assignedTo: String, description: String, dueDate: String, houseId: String,
        isRecurring: Bool, level: Int, recurringInterval: Int, title: String
    ) throws -> Data {
        try JSONEncoder().encode(UpdateChoreRequest(
            assignedTo: assignedTo, description: description, dueDate: dueDate,
            houseId: houseId, isRecurring: isRecurring, level: level,
            recurringInterval: recurringInterval, title: title
        ))
    }

    public static func statusBody(choreId: String, houseId: String, status: Int) throws -> Data {
        try JSONEncoder().encode(UpdateChoreStatusRequest(
            chores: [ChoreStatusUpdateItem(choreId: choreId, status: status)], houseId: houseId
        ))
    }

    public static func reviewBody(choreId: String, isApproved: Bool) throws -> Data {
        try JSONEncoder().encode(ReviewChoreRequest(choreId: choreId, isApproved: isApproved))
    }

    public static func announcementBody(title: String, description: String, houseId: String) throws -> Data {
        try JSONEncoder().encode(CreateAnnouncementRequest(
            description: description, houseId: houseId, title: title
        ))
    }

    public static func validate(action: String, response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws {
        guard (200...399).contains(response.statusCode) else {
            throw HTTPStatusFailure(response: response, decoder: decoder)
        }
        switch action {
        case "create", "update", "review":
            _ = try decoder.decode(ChoreResponse.self, from: response.body)
        case "status":
            let chores = try decoder.decode([ChoreResponse].self, from: response.body)
            guard !chores.isEmpty else { throw DashboardWireError.emptyStatusResult }
        case "announcement":
            let result = try decoder.decode(HouseAPIResponse<HouseAnnouncementDTO>.self, from: response.body)
            guard result.success, result.data != nil else { throw DashboardWireError.rejected(result.error) }
        default:
            throw DashboardWireError.unsupportedAction
        }
    }
}

public enum DashboardWireError: Error, Equatable {
    case emptyStatusResult
    case rejected(String?)
    case unsupportedAction
}
