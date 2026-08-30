import Foundation
import Combine

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

    var sampleUsers: [User] {
        [
            User(
                firstName: localized("demo_user_mahmut_first_name"),
                lastName: localized("demo_user_mahmut_last_name"),
                points: 12
            ),
            User(
                firstName: localized("demo_user_jane_first_name"),
                lastName: localized("demo_user_jane_last_name"),
                points: 8
            ),
            User(
                firstName: localized("demo_user_abdullatif_first_name"),
                lastName: localized("demo_user_abdullatif_last_name"),
                points: 10
            ),
            User(
                firstName: localized("demo_user_katya_first_name"),
                lastName: localized("demo_user_katya_last_name"),
                points: 6
            )
        ]
    }

    var sampleChores: [Chore] {
        [
            Chore(id: "sample-take-trash", title: localized("demo_chore_take_trash_title"), description: localized("demo_chore_take_trash_description"), assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(id: "sample-kitchen-counter", title: localized("demo_chore_kitchen_counter_title"), description: localized("demo_chore_kitchen_counter_description"), assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(id: "sample-vacuum-living-room", title: localized("demo_chore_vacuum_living_room_title"), description: localized("demo_chore_vacuum_living_room_description"), assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(id: "sample-clean-bathroom", title: localized("demo_chore_clean_bathroom_title"), description: localized("demo_chore_clean_bathroom_description"), assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(id: "sample-laundry", title: localized("demo_chore_laundry_title"), description: localized("demo_chore_laundry_description"), assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
        ]
    }

    var weeklyLeader: User {
        sampleUsers.max(by: { $0.points < $1.points }) ?? sampleUsers[0]
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
            toastStore.show(message: error.localizedDescription, isError: true)
            return false
        }
    }

    func createChore(
        assignedToId: String,
        description: String,
        dueDate: Date,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String
    ) async {
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
                currentHouseDetails: houseStore.currentHouseDetails,
                dashboardMembers: members
            ))
            toastStore.show(message: localized("chore_created_toast"), isError: false)
        } catch {
            toastStore.show(message: error.localizedDescription, isError: true)
        }
    }

    func updateChoreStatus(choreApiId: String, houseId: String, status: ChoreStatus) async -> Bool {
        do {
            let result = try await choreStore.updateStatus(
                choreApiId: choreApiId,
                houseId: houseId,
                status: status,
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
        } catch {
            toastStore.show(message: error.localizedDescription, isError: true)
            return false
        }
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
            toastStore.show(message: error.localizedDescription, isError: true)
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
            fallbackMembers: sampleUsers,
            fallbackChores: chores.isEmpty ? sampleChores : chores,
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
