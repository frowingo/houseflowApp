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
        case .failed: return "chore_status_failed"
        case .unknown: return "chore_status_unknown"
        }
    }

    /// Built-in copy for when the localization service has no value yet (Android `ChoreStatusUi`).
    var fallbackLabel: (tr: String, en: String) {
        switch self {
        case .draft: return ("Taslak", "Draft")
        case .progress: return ("Devam ediyor", "In progress")
        case .inTest: return ("İncelemede", "In review")
        case .completed: return ("Tamamlandı", "Completed")
        case .failed: return ("Başarısız", "Failed")
        case .unknown: return ("Bilinmiyor", "Unknown")
        }
    }
}

extension ChoreFailureReason {
    var localizationKey: String {
        switch self {
        case .dueDatePassed: return "chore_failed_reason_due_date"
        case .unspecified: return "chore_failed_reason_generic"
        }
    }

    var fallbackMessage: (tr: String, en: String) {
        switch self {
        case .dueDatePassed: return ("Son teslim tarihi geçtiği için başarısız oldu.", "Failed because the due date passed.")
        case .unspecified: return ("Görev başarısız oldu.", "The chore failed.")
        }
    }
}

extension AppViewModel {
    func statusLabel(_ status: ChoreStatus) -> String {
        localized(status.localizationKey, tr: status.fallbackLabel.tr, en: status.fallbackLabel.en)
    }

    func failureMessage(_ reason: ChoreFailureReason?) -> String {
        let reason = reason ?? .unspecified
        return localized(reason.localizationKey, tr: reason.fallbackMessage.tr, en: reason.fallbackMessage.en)
    }

    /// Caption above the history part of a chore list.
    var choreHistoryLabel: String {
        localized("todays_tasks_history_label", tr: "Geçmiş", en: "History")
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
