import Foundation

/// Whether the backend would accept `POST chore/{id}/remind` from the current user. It checks, in
/// this order: the chore is assigned, not to the sender, still open, and due within the window.
/// (A second reminder from the same sender is answered with 409; the server alone knows that.)
public enum ChoreReminderRules {
    /// A reminder is allowed this long before the due date.
    public static let window: TimeInterval = 12 * 60 * 60

    /// `status` is a `ChoreStatus` raw value; `dueDate` the wire string.
    public static func canRemind(
        assignedToID: String?, currentUserID: String?, status: Int, dueDate: String?, now: Date
    ) -> Bool {
        guard let assignee = nonBlank(assignedToID), let user = nonBlank(currentUserID), assignee != user,
              status == ChoreStatus.draft.rawValue || status == ChoreStatus.progress.rawValue,
              let due = dueDate.flatMap(APIDate.parse) else { return false }
        return now >= due.addingTimeInterval(-window) && now < due
    }

    private static func nonBlank(_ value: String?) -> String? {
        value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
}
