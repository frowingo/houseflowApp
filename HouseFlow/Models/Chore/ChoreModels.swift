import Foundation
import HouseFlowCore

// MARK: - iOS presentation

extension ChoreLevel {
    var localizationKey: String {
        switch self {
        case .easy: return "chore_level_easy"
        case .medium: return "chore_level_medium"
        case .hard: return "chore_level_hard"
        }
    }
}

extension ChoreStatus {
    var localizationKey: String {
        switch self {
        case .draft: return "chore_status_draft"
        case .progress: return "chore_status_in_progress"
        case .inTest: return "chore_status_in_review"
        case .completed: return "chore_status_completed"
        }
    }
}

// MARK: - App adapters

extension ChoreResponse {
    var houseChoreDTO: HouseChoreDTO {
        HouseChoreDTO(
            id: id,
            title: title,
            description: description,
            houseId: houseId,
            houseOwnerId: houseOwnerId,
            assignedTo: assignedTo,
            dueDate: dueDate,
            isCompleted: isCompleted,
            isRecurring: isRecurring,
            level: level,
            recurringInterval: recurringInterval,
            status: status,
            createdOn: createdOn,
            completedAt: completedAt,
            completedBy: completedBy,
            statusHistories: statusHistories.map(\.houseStatusHistory),
            reviewRound: reviewRound,
            reviewVotes: reviewVotes
        )
    }
}

private extension ChoreStatusHistoryResponse {
    var houseStatusHistory: ChoreStatusHistory {
        ChoreStatusHistory(
            id: id,
            choreId: choreId,
            status: status,
            updater: updater,
            dateTime: dateTime
        )
    }
}

extension HouseChoreDTO {
    var dueLabelString: String {
        HouseFlowDateFormatter.dueLabel(from: dueDate)
    }
}
