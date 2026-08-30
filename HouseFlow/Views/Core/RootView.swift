import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        NavigationStack {
            currentView
                .id(appViewModel.route.id)
                .transition(currentTransition)
                .animation(.easeOut(duration: 0.4), value: appViewModel.route.id)
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
            switch appViewModel.route {
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
                AuthView()
            case .createHouse:
                CreateHouseView()
            case .joinHouse:
                JoinHouseView()
            case .houseSelection:
                HouseSelectionView()
            case .dashboard:
                MainTabView()
            }
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
