import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        NavigationStack {
            currentView
                .id(currentViewId)
                .transition(currentTransition)
                .animation(.easeOut(duration: 0.4), value: currentViewId)
                .onChange(of: appViewModel.showCreateHouse) { _, _ in
                    // Trigger view update
                }
                .onChange(of: appViewModel.showJoinHouse) { _, _ in
                    // Trigger view update
                }
                .onChange(of: appViewModel.showAuth) { _, _ in
                    // Trigger view update
                }
        }
    }
    
    private var currentView: some View {
        Group {
            if !appViewModel.isAuthenticated && !appViewModel.showAuth {
                OnboardingView()
            } else if appViewModel.showAuth {
                AuthView()
            } else if appViewModel.showCreateHouse {
                CreateHouseView()
            } else if appViewModel.showJoinHouse {
                JoinHouseView()
            } else if !appViewModel.hasSelectedHouse {
                HouseSelectionView()
            } else {
                HouseDashboardView()
            }
        }
    }
    
    private var currentViewId: String {
        if !appViewModel.isAuthenticated && !appViewModel.showAuth {
            return "onboarding"
        } else if appViewModel.showAuth {
            return "auth"
        } else if appViewModel.showCreateHouse {
            return "createHouse"
        } else if appViewModel.showJoinHouse {
            return "joinHouse"
        } else if !appViewModel.hasSelectedHouse {
            return "houseSelection"
        } else {
            return "dashboard"
        }
    }
    
    private var currentTransition: AnyTransition {
        if appViewModel.navigationDirection == .forward {
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }
}