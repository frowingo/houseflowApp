import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.fausSplashActive) private var splashActive
    
    var body: some View {
        NavigationStack {
            currentView
                .id(router.route.id)
                .transition(currentTransition)
                // Route changes behind the splash land instantly; nobody can see the slide.
                .animation(splashActive ? nil : .easeOut(duration: 0.4), value: router.route.id)
        }
        .overlay(alignment: .top) {
            ToastOverlay()
        }
    }
    
    private var currentView: some View {
        Group {
            switch router.route {
            case .houseLoading:
                HouseLoadingView()
            case .houseError:
                HouseErrorView()
            case .onboarding:
                OnboardingView()
            case .emailVerification(let email):
                EmailVerificationView(
                    email: email,
                    signupSuccessMessage: appViewModel.signupSuccessMessage,
                    onCancel: appViewModel.cancelEmailVerification,
                    onSendCode: {
                        try await appViewModel.sendEmailVerificationCode()
                    },
                    onDismissSignupSuccess: appViewModel.clearSignupSuccessMessage
                )
            case .birthdaySetup:
                BirthdaySetupView()
            case .authentication:
                AuthView(viewModel: appViewModel.authenticationViewModel)
            case .createHouse:
                CreateHouseView()
            case .joinHouse:
                JoinHouseView()
            case .houseSelection:
                HouseSelectionView()
            case .dashboard:
                MainTabView(routeHandler: appViewModel.pushRouteHandler)
            }
        }
    }
    
    private var currentTransition: AnyTransition {
        if router.navigationDirection == .forward {
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

private struct ToastOverlay: View {
    @EnvironmentObject private var toastStore: ToastStore

    var body: some View {
        ZStack {
            if let message = toastStore.message {
                ToastView(message: message, isError: toastStore.isError)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                    .animation(AppDesign.Animation.standard, value: toastStore.message)
            }
        }
        .animation(AppDesign.Animation.standard, value: toastStore.message)
    }
}
