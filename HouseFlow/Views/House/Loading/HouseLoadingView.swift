import SwiftUI

struct HouseLoadingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var pulseScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.08
    @State private var dotsPhase: Int = 0
    @State private var dotAnimating: Bool = false
    @State private var dotsTimer: Timer?

    private let dotInterval: TimeInterval = 0.45

    var body: some View {
        ZStack {
            AppDesign.Colors.background
                .ignoresSafeArea()

            VStack(spacing: AppDesign.Spacing.xxxl) {
                Spacer()

                // Animated icon
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .fill(AppDesign.Colors.primary.opacity(ringOpacity))
                        .frame(width: 170, height: 170)
                        .scaleEffect(pulseScale)

                    // Mid ring
                    Circle()
                        .fill(AppDesign.Colors.primary.opacity(0.10))
                        .frame(width: 120, height: 120)

                    // Inner ring
                    Circle()
                        .fill(AppDesign.Colors.primary.opacity(0.15))
                        .frame(width: 88, height: 88)

                    Image(systemName: "house.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(AppDesign.Colors.primary)
                }
                .frame(width: 170, height: 170)

                // Phase text
                VStack(spacing: AppDesign.Spacing.md) {
                    Text(appViewModel.localized(appViewModel.houseLoadingPhase.titleKey))
                        .font(AppDesign.Typography.title2)
                        .foregroundColor(AppDesign.Colors.text)
                        .multilineTextAlignment(.center)
                        .id("phase-title-\(appViewModel.houseLoadingPhase.titleKey)")
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    Text(appViewModel.localized(appViewModel.houseLoadingPhase.subtitleKey))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDesign.Spacing.xxxl)
                        .id("phase-subtitle-\(appViewModel.houseLoadingPhase.subtitleKey)")
                        .transition(.opacity)

                    // Bouncing dots indicator
                    HStack(spacing: AppDesign.Spacing.sm) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(AppDesign.Colors.primary)
                                .frame(width: 8, height: 8)
                                .opacity(dotsPhase == i ? 1.0 : 0.3)
                                .scaleEffect(dotsPhase == i ? 1.35 : 1.0)
                                .animation(AppDesign.Animation.quick, value: dotsPhase)
                        }
                    }
                    .padding(.top, AppDesign.Spacing.sm)
                }
                .animation(AppDesign.Animation.standard, value: appViewModel.houseLoadingPhase.titleKey)

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
    HouseLoadingView()
        .environmentObject({
            let vm = AppViewModel()
            return vm
        }())
}
