import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        NavigationStack {
            currentView
                .id(currentViewId)
                .transition(currentTransition)
                .animation(.easeOut(duration: 0.4), value: currentViewId)
                .onChange(of: appViewModel.showCreateHouse) { _, _ in }
                .onChange(of: appViewModel.showJoinHouse) { _, _ in }
                .onChange(of: appViewModel.showAuth) { _, _ in }
                .onChange(of: appViewModel.showHouseLoading) { _, _ in }
                .onChange(of: appViewModel.showHouseError) { _, _ in }
                .onChange(of: appViewModel.isInitializing) { _, _ in }
        }
        .overlay(alignment: .top) {
            if let message = appViewModel.toastMessage {
                ToastView(message: message, isError: appViewModel.toastIsError)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                    .animation(AppDesign.Animation.standard, value: appViewModel.toastMessage)
            }
        }
        .animation(AppDesign.Animation.standard, value: appViewModel.toastMessage)
    }
    
    private var currentView: some View {
        Group {
            if appViewModel.isInitializing || appViewModel.showHouseLoading {
                HouseLoadingView()
            } else if appViewModel.showHouseError {
                HouseErrorView()
            } else if !hasSeenOnboarding {
                OnboardingView()
            } else if !appViewModel.isAuthenticated || appViewModel.showAuth {
                AuthView()
            } else if appViewModel.showCreateHouse {
                CreateHouseView()
            } else if appViewModel.showJoinHouse {
                JoinHouseView()
            } else if !appViewModel.hasSelectedHouse {
                HouseSelectionView()
            } else {
                MainTabView()
            }
        }
    }
    
    private var currentViewId: String {
        if appViewModel.isInitializing || appViewModel.showHouseLoading {
            return "houseLoading"
        } else if appViewModel.showHouseError {
            return "houseError"
        } else if !hasSeenOnboarding {
            return "onboarding"
        } else if !appViewModel.isAuthenticated || appViewModel.showAuth {
            return "auth"
        } else if appViewModel.showCreateHouse {
            return "createHouse"
        } else if appViewModel.showJoinHouse {
            return "joinHouse"
        } else if !appViewModel.hasSelectedHouse {
            return "houseSelection"
        } else {
            return "mainTab"
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