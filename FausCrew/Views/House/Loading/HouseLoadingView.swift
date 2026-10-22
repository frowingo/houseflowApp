import SwiftUI

struct HouseLoadingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.fausSplashActive) private var splashActive

    @State private var markProgress: CGFloat = 0
    @State private var dotPop: CGFloat = 0
    @State private var dotBreath: CGFloat = 1.0

    var body: some View {
        ZStack {
            MainScreenBackground()

            VStack(spacing: AppDesign.Spacing.xl) {
                Spacer()

                // Brand mark: the roof-F draws itself, then the crew dot pops in
                FausFramedMark(
                    size: 190,
                    progress: markProgress,
                    dotScale: dotPop * dotBreath
                )

                // Phase text
                VStack(spacing: AppDesign.Spacing.sm) {
                    Text(appViewModel.localized(phase.titleKey))
                        .font(AppDesign.Typography.title2)
                        .foregroundColor(AppDesign.Colors.text)
                        .multilineTextAlignment(.center)
                        .id("phase-title-\(phase.titleKey)")
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Text(appViewModel.localized(phase.subtitleKey))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDesign.Spacing.xxxl)
                        .id("phase-subtitle-\(phase.subtitleKey)")
                        .transition(.opacity)

                    FausSpinner(size: 46)
                        .padding(.top, AppDesign.Spacing.lg)
                }
                .animation(AppDesign.Animation.standard, value: phase.titleKey)

                Spacer()
            }
        }
        .onAppear {
            // Behind the splash the intro would play unseen; start it when the splash reveals us.
            if !splashActive { startMarkAnimation() }
        }
        .onChange(of: splashActive) { _, active in
            if !active { startMarkAnimation() }
        }
    }

    private var phase: HouseLoadingPhase {
        router.houseLoadingPhase
    }

    // MARK: - Animations

    private func startMarkAnimation() {
        withAnimation(.easeInOut(duration: 1.0)) {
            markProgress = 1
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.5).delay(0.95)) {
            dotPop = 1
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(1.6)) {
            dotBreath = 1.18
        }
    }
}

#Preview {
    let viewModel = AppViewModel()
    HouseLoadingView()
        .environmentObject(viewModel)
        .environmentObject(viewModel.router)
}
