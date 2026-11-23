import Foundation
import Combine
import FausCrewCore

/// Sends chore reminders and remembers, for this process, which chores the signed-in user already
/// reminded. The server answers a repeat with 409 and that stays true, so nothing is persisted.
@MainActor
final class ChoreReminderStore: ObservableObject {
    /// "userID|choreID" keys.
    @Published private(set) var reminded: Set<String> = []
    @Published private(set) var sending: Set<String> = []

    /// The server says the chore is gone (404): the house detail needs a refresh.
    var onChoreNotFound: (() -> Void)?

    private let service: (any NotificationServicing)?
    private let toastStore: ToastStore
    private let localizationStore: LocalizationStore
    private let currentUserID: () -> String?

    init(
        service: (any NotificationServicing)?,
        toastStore: ToastStore,
        localizationStore: LocalizationStore,
        currentUserID: @escaping () -> String?
    ) {
        self.service = service
        self.toastStore = toastStore
        self.localizationStore = localizationStore
        self.currentUserID = currentUserID
    }

    func isReminded(_ choreID: String) -> Bool {
        key(choreID).map(reminded.contains) ?? false
    }

    func isSending(_ choreID: String) -> Bool {
        key(choreID).map(sending.contains) ?? false
    }

    /// Sign-out: the next account starts with nothing reminded.
    func clear() {
        reminded = []
        sending = []
    }

    func remind(choreID: String) async {
        guard let service, let userID = currentUserID(), let key = key(choreID),
              !sending.contains(key), !reminded.contains(key) else { return }
        sending.insert(key)
        do {
            try await service.remind(choreID: choreID)
            guard finish(key, userID: userID) else { return }
            reminded.insert(key)
            toastStore.show(
                message: localizationStore.value(for: "chore_remind_sent", tr: "Hatırlatma gönderildi", en: "Reminder sent"),
                isError: false
            )
        } catch {
            guard finish(key, userID: userID) else { return }
            handle(error, key: key)
        }
    }

    private func handle(_ error: any Error, key: String) {
        guard let failure = error as? NotificationFailure else {
            toastStore.show(message: localizationStore.userMessage(for: error), isError: true)
            return
        }
        switch failure.kind {
        case .alreadyReminded:
            reminded.insert(key)
        case .unauthorized:
            // The session flow has taken over; a toast would only add noise.
            break
        case .notFound:
            toastStore.show(message: failure.message ?? localizationStore.userMessage(for: failure), isError: true)
            onChoreNotFound?()
        case .invalidRequest, .notMember, .server, .invalidResponse:
            toastStore.show(message: failure.message ?? localizationStore.userMessage(for: failure), isError: true)
        }
    }

    /// False when the user changed while the request was running: its answer is not theirs.
    private func finish(_ key: String, userID: String) -> Bool {
        sending.remove(key)
        return currentUserID() == userID
    }

    private func key(_ choreID: String) -> String? {
        currentUserID().map { "\($0)|\(choreID)" }
    }
}
