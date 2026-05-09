import Foundation

struct Chore: Identifiable, Codable {
    let id = UUID()
    /// Server-assigned chore ID (nil for local/sample chores).
    let choreApiId: String?
    let houseId: String?
    /// Server-assigned user ID of the assignee.
    let assignedToId: String?
    let title: String
    let description: String
    let assignedTo: User
    let dueLabel: String
    /// Raw ISO-8601 date string from the API (nil for local/sample chores).
    let dueDate: String?
    let isDone: Bool
    /// Raw value of `ChoreStatus` (0=Draft, 1=Progress, 2=InTest, 3=Completed).
    let status: Int
    /// Raw value of `ChoreLevel` (10=Easy, 20=Medium, 30=Hard).
    let level: Int

    init(
        choreApiId: String? = nil,
        houseId: String? = nil,
        assignedToId: String? = nil,
        title: String,
        description: String = "",
        assignedTo: User,
        dueLabel: String,
        dueDate: String? = nil,
        isDone: Bool = false,
        status: Int = 0,
        level: Int = 10
    ) {
        self.choreApiId = choreApiId
        self.houseId = houseId
        self.assignedToId = assignedToId
        self.title = title
        self.description = description
        self.assignedTo = assignedTo
        self.dueLabel = dueLabel
        self.dueDate = dueDate
        self.isDone = isDone
        self.status = status
        self.level = level
    }
}