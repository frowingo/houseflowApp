import Foundation
import Combine
import FausCrewCore

@MainActor
final class DashboardCoordinator {
    private let authStore: AuthSessionStore
    private let houseStore: HouseSessionStore
    private let dashboardStore: DashboardStore
    private let choreStore: ChoreStore
    private let localizationStore: LocalizationStore
    private let toastStore: ToastStore
    private var cancellables = Set<AnyCancellable>()

    init(
        authStore: AuthSessionStore,
        houseStore: HouseSessionStore,
        dashboardStore: DashboardStore,
        choreStore: ChoreStore,
        localizationStore: LocalizationStore,
        toastStore: ToastStore
    ) {
        self.authStore = authStore
        self.houseStore = houseStore
        self.dashboardStore = dashboardStore
        self.choreStore = choreStore
        self.localizationStore = localizationStore
        self.toastStore = toastStore
        bindStateChanges()
        rebuildDashboardCache()
    }

    var members: [User] { dashboardStore.members }
    var dashboardChores: [Chore] { dashboardStore.chores }

    var chores: [Chore] {
        get { choreStore.chores }
        set {
            choreStore.setChores(newValue)
            if houseStore.currentHouseDetails == nil {
                dashboardStore.setChores(newValue)
            }
        }
    }

    @discardableResult
    func createAnnouncement(title: String, description: String) async -> Bool {
        do {
            _ = try await houseStore.createAnnouncement(title: title, description: description)
            toastStore.show(
                message: localizationStore.value(
                    for: "announcement_created_toast",
                    fallback: "Announcement published."
                ),
                isError: false
            )
            return true
        } catch {
            toastStore.show(message: localizationStore.userMessage(for: error), isError: true)
            return false
        }
    }

    @discardableResult
    func createChore(
        assignedToId: String,
        description: String,
        dueDate: Date,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String,
        category: ChoreCategoryKind
    ) async -> Bool {
        do {
            applyHouseDetailsIfNeeded(try await choreStore.createChore(
                assignedToId: assignedToId,
                description: description,
                dueDate: dueDate,
                houseId: houseId,
                isRecurring: isRecurring,
                level: level,
                recurringInterval: recurringInterval,
                title: title,
                category: category,
                currentHouseDetails: houseStore.currentHouseDetails,
                dashboardMembers: members
            ))
            toastStore.show(message: localized("chore_created_toast"), isError: false)
            return true
        } catch {
            toastStore.show(message: localizationStore.userMessage(for: error), isError: true)
            return false
        }
    }

    func isChoreReviewPhotoRequired(houseId: String?) -> Bool {
        guard let details = houseStore.currentHouseDetails, details.id == houseId else { return false }
        return details.isChoreReviewPhotoRequired
    }

    func updateChoreStatus(
        choreApiId: String,
        houseId: String,
        status: ChoreStatus,
        reviewPhoto: Data? = nil
    ) async -> Bool {
        do {
            let result = try await choreStore.updateStatus(
                choreApiId: choreApiId,
                houseId: houseId,
                status: status,
                isReviewPhotoRequired: isChoreReviewPhotoRequired(houseId: houseId),
                reviewPhoto: reviewPhoto,
                currentHouseDetails: houseStore.currentHouseDetails,
                dashboardMembers: members
            )
            guard result.didUpdate else {
                toastStore.show(message: localized("chore_status_update_failed_toast"), isError: true)
                return false
            }
            applyHouseDetailsIfNeeded(result.updatedDetails)
            toastStore.show(message: localized("chore_status_updated_toast"), isError: false)
            return true
        } catch let photoError as ChoreReviewPhotoError {
            toastStore.show(
                message: localizationStore.value(
                    for: photoError.localizationKey,
                    fallback: photoError.fallbackMessage
                ),
                isError: true
            )
            return false
        } catch {
            toastStore.show(message: localizationStore.userMessage(for: error), isError: true)
            return false
        }
    }

    /// Returns image bytes only; the signed URL is neither stored nor surfaced.
    func loadReviewPhoto(choreApiId: String, round: Int) async -> Data? {
        do {
            return try await choreStore.loadReviewPhoto(choreApiId: choreApiId, round: round)
        } catch NetworkError.serverError(let message) {
            toastStore.show(message: message, isError: true)
        } catch is CancellationError {
        } catch {
            toastStore.show(
                message: localizationStore.value(
                    for: "chore_review_photo_load_failed",
                    fallback: "The review photo could not be loaded."
                ),
                isError: true
            )
        }
        return nil
    }

    func reviewChore(choreApiId: String, isApproved: Bool) async -> Bool {
        do {
            applyHouseDetailsIfNeeded(try await choreStore.review(
                choreApiId: choreApiId,
                isApproved: isApproved,
                currentHouseDetails: houseStore.currentHouseDetails,
                dashboardMembers: members
            ))
            toastStore.show(
                message: localized(isApproved ? "chore_approved_toast" : "chore_sent_back_toast"),
                isError: false
            )
            return true
        } catch {
            toastStore.show(message: localizationStore.userMessage(for: error), isError: true)
            return false
        }
    }

    func clearSession() {
        choreStore.clear()
    }

    private func bindStateChanges() {
        authStore.$currentUserProfile
            .dropFirst()
            .sink { [weak self] profile in
                guard let self else { return }
                self.rebuildDashboardCache(
                    details: self.houseStore.currentHouseDetails,
                    currentUserProfile: profile
                )
            }
            .store(in: &cancellables)

        houseStore.$currentHouseDetails
            .dropFirst()
            .sink { [weak self] details in
                guard let self else { return }
                self.rebuildDashboardCache(
                    details: details,
                    currentUserProfile: self.authStore.currentUserProfile
                )
            }
            .store(in: &cancellables)

        choreStore.$chores
            .dropFirst()
            .sink { [weak self] chores in
                guard let self, self.houseStore.currentHouseDetails == nil else { return }
                self.dashboardStore.setChores(chores)
            }
            .store(in: &cancellables)

        localizationStore.$values
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.houseStore.currentHouseDetails == nil else { return }
                self.rebuildDashboardCache()
            }
            .store(in: &cancellables)
    }

    private func rebuildDashboardCache() {
        rebuildDashboardCache(
            details: houseStore.currentHouseDetails,
            currentUserProfile: authStore.currentUserProfile
        )
    }

    private func rebuildDashboardCache(
        details: HouseDetailsResponse?,
        currentUserProfile: IsAuthUserData?
    ) {
        dashboardStore.rebuild(
            details: details,
            fallbackChores: chores,
            fallbackUnassignedName: localized("common_unassigned"),
            currentUserId: authStore.currentUserId,
            currentUserProfile: currentUserProfile
        )
    }

    private func applyHouseDetailsIfNeeded(_ details: HouseDetailsResponse?) {
        guard let details else { return }
        houseStore.setCurrentHouseDetails(details)
    }

    private func localized(_ key: String) -> String {
        localizationStore.value(for: key)
    }
}
