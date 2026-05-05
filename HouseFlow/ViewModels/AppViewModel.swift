import Foundation
import Combine

enum NavigationDirection {
    case forward, backward
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var hasSelectedHouse: Bool = false
    @Published var showCreateHouse: Bool = false
    @Published var showJoinHouse: Bool = false
    @Published var showAuth: Bool = false
    @Published var currentUser: User?
    @Published var houseName: String = ""
    @Published var chores: [Chore] = []
    @Published var navigationDirection: NavigationDirection = .forward

    // MARK: - Auth State
    @Published var isLoading: Bool = false
    @Published var authError: String?
    @Published var successToast: String?

    // MARK: - House State
    @Published var currentHouse: HouseResponse?
    @Published var currentHouseDetails: HouseDetailsResponse?
    @Published var houseIsLoading: Bool = false
    @Published var houseError: String?

    private let authService = AuthService.shared
    private let houseService = HouseService.shared
    
    // Sample data for demo
    let sampleUsers = [
        User(name: "Mahmut", points: 12),
        User(name: "Jane", points: 8),
        User(name: "Abdüllatif", points: 10),
        User(name: "Katya", points: 6)
    ]
    
    var sampleChores: [Chore] {
        [
            Chore(title: "Take out the trash", description: "Empty all trash bins and take bags to the dumpster", assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(title: "Clean kitchen counter", description: "Wipe down all surfaces, clean sink and organize items", assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(title: "Vacuum living room", description: "Vacuum carpet and clean under furniture", assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(title: "Clean bathroom", description: "Clean toilet, shower, sink and mirror", assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(title: "Do laundry", description: "Wash, dry and fold clothes", assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
        ]
    }
    
    var weeklyLeader: User {
        sampleUsers.max(by: { $0.points < $1.points }) ?? sampleUsers[0]
    }
    
    func showAuthScreen() {
        navigationDirection = .forward
        showAuth = true
    }
    
    // MARK: - Real Auth (API)

    func login(email: String, password: String) async {
        isLoading = true
        authError = nil
        do {
            _ = try await authService.login(email: email, password: password)
            isLoading = false
            successToast = "Welcome back! 👋"
            try? await Task.sleep(for: .milliseconds(1400))
            successToast = nil
            didAuthenticate()
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }

    func signup(email: String, password: String, firstName: String, lastName: String) async {
        isLoading = true
        authError = nil
        do {
            _ = try await authService.signup(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            isLoading = false
            successToast = "Account created! 🎉"
            try? await Task.sleep(for: .milliseconds(1400))
            successToast = nil
            didAuthenticate()
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }

    private func didAuthenticate() {
        navigationDirection = .forward
        isAuthenticated = true
        showAuth = false
        currentUser = sampleUsers[0]
        initializeChores()
    }
    
    func selectHouse(name: String) {
        navigationDirection = .forward
        houseName = name
        hasSelectedHouse = true
        showCreateHouse = false
    }
    
    func showCreateHouseScreen() {
        navigationDirection = .forward
        showCreateHouse = true
    }
    
    func backToHouseSelection() {
        navigationDirection = .backward
        showCreateHouse = false
        showJoinHouse = false
    }
    
    func showJoinHouseScreen() {
        navigationDirection = .forward
        showJoinHouse = true
    }

    // MARK: - House API

    /// Calls POST house/create. Returns the created house on success, nil on failure (sets houseError).
    func createHouseAPI(name: String, type: Int, maxMemberCount: Int) async -> HouseResponse? {
        houseIsLoading = true
        houseError = nil
        do {
            let house = try await houseService.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
            currentHouse = house
            houseIsLoading = false
            return house
        } catch {
            houseError = error.localizedDescription
            houseIsLoading = false
            return nil
        }
    }

    /// Calls POST house/join. Returns the joined house on success, nil on failure (sets houseError).
    func joinHouseAPI(inviteCode: String) async -> HouseResponse? {
        houseIsLoading = true
        houseError = nil
        do {
            let house = try await houseService.joinHouse(inviteCode: inviteCode)
            currentHouse = house
            houseIsLoading = false
            return house
        } catch {
            houseError = error.localizedDescription
            houseIsLoading = false
            return nil
        }
    }

    /// Calls GET house/details. Stores result in currentHouseDetails.
    func fetchHouseDetails(houseId: String) async {
        do {
            currentHouseDetails = try await houseService.fetchDetails(houseId: houseId)
        } catch {
            // Non-blocking — dashboard falls back to cached state
            print("[HouseDetails] fetch failed: \(error.localizedDescription)")
        }
    }

    /// Finalizes navigation after a successful create or join.
    func finalizeHouseSelection(house: HouseResponse) {
        currentHouse = house
        houseName = house.name
        navigationDirection = .forward
        hasSelectedHouse = true
        showCreateHouse = false
        showJoinHouse = false
        // Kick off details fetch in background
        Task { await fetchHouseDetails(houseId: house.id) }
    }
    
    func logout() {
        authService.logout()
        navigationDirection = .backward
        isAuthenticated = false
        hasSelectedHouse = false
        showCreateHouse = false
        showJoinHouse = false
        showAuth = false
        currentUser = nil
        currentHouse = nil
        currentHouseDetails = nil
        houseName = ""
        chores = []
    }
    
    private func initializeChores() {
        chores = [
            Chore(title: "Take out the trash", description: "Empty all trash bins and take bags to the dumpster", assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(title: "Clean kitchen counter", description: "Wipe down all surfaces, clean sink and organize items", assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(title: "Vacuum living room", description: "Vacuum carpet and clean under furniture", assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(title: "Clean bathroom", description: "Clean toilet, shower, sink and mirror", assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(title: "Do laundry", description: "Wash, dry and fold clothes", assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
        ]
    }
    
    func toggleChoreCompletion(_ choreId: UUID) {
        if let index = chores.firstIndex(where: { $0.id == choreId }) {
            let currentChore = chores[index]
            let newChore = Chore(
                title: currentChore.title,
                description: currentChore.description,
                assignedTo: currentChore.assignedTo,
                dueLabel: currentChore.dueLabel,
                isDone: !currentChore.isDone
            )
            chores[index] = newChore
        }
    }
}
