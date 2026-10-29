import Foundation
import FausCrewCore

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
            reviewVotes: reviewVotes,
            reviewPhotoRounds: reviewPhotoRounds
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

extension ChoreReviewPhotoError {
    var localizationKey: String {
        switch self {
        case .missing: return "chore_review_photo_missing"
        case .unsupportedFormat: return "chore_review_photo_unsupported"
        case .tooLarge: return "chore_review_photo_too_large"
        }
    }

    var fallbackMessage: String {
        switch self {
        case .missing: return "Add a photo before sending the chore to review."
        case .unsupportedFormat: return "Only JPEG, PNG or WebP photos can be uploaded."
        case .tooLarge: return "The photo must be 3 MB or smaller."
        }
    }
}

extension HouseChoreDTO {
    var dueLabelString: String {
        FausCrewDateFormatter.dueLabel(from: dueDate)
    }
}
