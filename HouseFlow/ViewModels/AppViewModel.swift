import Foundation
import Combine

enum NavigationDirection {
    case forward, backward
}

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
    
    func authenticate() {
        navigationDirection = .forward
        isAuthenticated = true
        showAuth = false
        currentUser = sampleUsers[0] // Set Mahmut as current user for demo
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
    
    func joinHouse(with code: String) -> Bool {
        // Demo için basit kod kontrolü - gerçek uygulamada API çağrısı olurdu
        let validCodes = ["HOUSE123", "DEMO456", "TEST789"]
        if validCodes.contains(code.uppercased()) {
            hasSelectedHouse = true
            showJoinHouse = false
            navigationDirection = .forward
            houseName = "Joined House" // Demo house name
            return true
        }
        return false
    }
    
    func createHouse(name: String, type: String, memberCount: Int) {
        navigationDirection = .forward
        houseName = name
        hasSelectedHouse = true
        showCreateHouse = false
    }
    
    func logout() {
        navigationDirection = .backward
        isAuthenticated = false
        hasSelectedHouse = false
        showCreateHouse = false
        showJoinHouse = false
        showAuth = false
        currentUser = nil
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
