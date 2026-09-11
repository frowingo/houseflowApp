import SwiftUI

struct HouseLoadingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var router: AppRouter

    @State private var pulseScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.08
    @State private var dotsPhase: Int = 0
    @State private var dotAnimating: Bool = false
    @State private var dotsTimer: Timer?

    private let dotInterval: TimeInterval = 0.45

    var body: some View {
        ZStack {
            loadingBackground

            VStack(spacing: AppDesign.Spacing.xxxl) {
                Spacer()

                // Animated icon
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .fill(phaseColor.opacity(ringOpacity))
                        .frame(width: 170, height: 170)
                        .scaleEffect(pulseScale)

                    // Mid ring
                    Circle()
                        .fill(HouseJourneyTheme.teal.opacity(0.085))
                        .frame(width: 120, height: 120)

                    // Inner ring
                    Circle()
                        .fill(HouseJourneyTheme.surface)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .stroke(phaseColor.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: "house.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(phaseColor)

                    Circle()
                        .fill(HouseJourneyTheme.accentOrange)
                        .frame(width: 10, height: 10)
                        .offset(x: 36, y: -36)
                }
                .frame(width: 170, height: 170)

                // Phase text
                VStack(spacing: AppDesign.Spacing.md) {
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

                    // Bouncing dots indicator
                    HStack(spacing: AppDesign.Spacing.sm) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(dotsPhase == i ? HouseJourneyTheme.accentOrange : phaseColor)
                                .frame(width: 8, height: 8)
                                .opacity(dotsPhase == i ? 1.0 : 0.3)
                                .scaleEffect(dotsPhase == i ? 1.35 : 1.0)
                                .animation(AppDesign.Animation.quick, value: dotsPhase)
                        }
                    }
                    .padding(.top, AppDesign.Spacing.sm)
                }
                .animation(AppDesign.Animation.standard, value: phase.titleKey)

                Spacer()
            }
        }
        .onAppear {
            startPulseAnimation()
            startDotsAnimation()
        }
        .onDisappear {
            stopDotsAnimation()
        }
    }

    private var loadingBackground: some View {
        ZStack {
            MainScreenBackground()

            RadialGradient(
                colors: [phaseColor.opacity(0.07), Color.clear],
                center: .center,
                startRadius: 30,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
        .animation(AppDesign.Animation.standard, value: phase.titleKey)
    }

    private var phaseColor: Color {
        switch phase {
        case .creating:
            return HouseJourneyTheme.purple
        case .joining:
            return HouseJourneyTheme.teal
        case .loadingDetails, .loadingHouse:
            return HouseJourneyTheme.blue
        case .checkingAuth:
            return HouseJourneyTheme.indigo
        case .loadingUser:
            return HouseJourneyTheme.teal
        }
    }

    private var phase: HouseLoadingPhase {
        router.houseLoadingPhase
    }

    // MARK: - Animations

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.3).repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.18
            ringOpacity = 0.04
        }
    }

    private func startDotsAnimation() {
        stopDotsAnimation()
        dotsTimer = Timer.scheduledTimer(withTimeInterval: dotInterval, repeats: true) { _ in
            dotsPhase = (dotsPhase + 1) % 3
        }
    }

    private func stopDotsAnimation() {
        dotsTimer?.invalidate()
        dotsTimer = nil
    }
}

#Preview {
    let viewModel = AppViewModel()
    HouseLoadingView()
        .environmentObject(viewModel)
        .environmentObject(viewModel.router)
}
