import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var currentPage = 0

    let onboardingPages = [
        OnboardingPage(
            titleKey: "onboarding_page_1_title",
            subtitleKey: "onboarding_page_1_subtitle",
            art: .house
        ),
        OnboardingPage(
            titleKey: "onboarding_page_2_title",
            subtitleKey: "onboarding_page_2_subtitle",
            art: .symbol("person.2.fill")
        ),
        OnboardingPage(
            titleKey: "onboarding_page_games_title",
            subtitleKey: "onboarding_page_games_subtitle",
            art: .games,
            fallbackTitle: "Play together",
            fallbackSubtitle: "Rocket races, tank battles, rock-paper-scissors and more for your crew."
        ),
        OnboardingPage(
            titleKey: "onboarding_page_3_title",
            subtitleKey: "onboarding_page_3_subtitle",
            art: .bell
        )
    ]

    var body: some View {
        ZStack {
            MainScreenBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 52)

                Spacer(minLength: AppDesign.Spacing.lg)

                TabView(selection: $currentPage) {
                    ForEach(onboardingPages.indices, id: \.self) { index in
                        OnboardingPageView(
                            page: onboardingPages[index],
                            title: title(for: onboardingPages[index]),
                            subtitle: subtitle(for: onboardingPages[index]),
                            isActive: currentPage == index
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380)

                pageIndicator
                    .padding(.top, AppDesign.Spacing.lg)

                Spacer(minLength: AppDesign.Spacing.lg)

                ctaButton
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Rectangle()
                    .fill(FausBrand.markGradient)
                    .frame(width: 36, height: 36)
                    .mask(FausMark(size: 36))
                    .accessibilityHidden(true)

                (Text(verbatim: "Faus")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(FausBrand.buttonGradient)
                    + Text(verbatim: "Crew")
                    .font(.system(size: 28, weight: .regular, design: .rounded))
                    .foregroundStyle(FausBrand.deepBerry))
                    .accessibilityLabel("FausCrew")
            }

            Text(verbatim: "Make living together fun")
                .font(.system(size: 14))
                .foregroundColor(AppDesign.Colors.textSecondary)
        }
    }

    // MARK: - Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(onboardingPages.indices, id: \.self) { index in
                let isCurrent = currentPage == index
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { currentPage = index }
                } label: {
                    Capsule()
                        .fill(isCurrent ? AnyShapeStyle(FausBrand.buttonGradient) : AnyShapeStyle(FausBrand.deepBerry.opacity(0.18)))
                        .frame(width: isCurrent ? 26 : 8, height: 8)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1) / \(onboardingPages.count)")
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentPage)
    }

    // MARK: - CTA

    private var isLastPage: Bool {
        currentPage == onboardingPages.count - 1
    }

    private var ctaButton: some View {
        Button {
            if isLastPage {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appViewModel.completeOnboarding()
                }
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    currentPage += 1
                }
            }
        } label: {
            HStack(spacing: AppDesign.Spacing.sm) {
                Text(isLastPage
                     ? appViewModel.localized("onboarding_get_started_button")
                     : appViewModel.localized("common_continue", fallback: "Continue"))
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(isLastPage ? .white : HouseJourneyTheme.accentOrangeInk)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isLastPage ? AnyShapeStyle(FausBrand.buttonGradient) : AnyShapeStyle(AppDesign.Colors.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(FausBrand.orange.opacity(isLastPage ? 0 : 0.45), lineWidth: 1.5)
                    )
            }
            .shadow(color: isLastPage ? FausBrand.deepBerry.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isLastPage)
    }

    // MARK: - Copy

    private func title(for page: OnboardingPage) -> String {
        if let fallback = page.fallbackTitle {
            return appViewModel.localized(page.titleKey, fallback: fallback)
        }
        return appViewModel.localized(page.titleKey)
    }

    private func subtitle(for page: OnboardingPage) -> String {
        if let fallback = page.fallbackSubtitle {
            return appViewModel.localized(page.subtitleKey, fallback: fallback)
        }
        return appViewModel.localized(page.subtitleKey)
    }
}

struct OnboardingPage {
    enum Art {
        case house
        case symbol(String)
        case games
        case bell
    }

    let titleKey: String
    let subtitleKey: String
    let art: Art
    var fallbackTitle: String? = nil
    var fallbackSubtitle: String? = nil
}

// MARK: - Page

/// One onboarding page: animated brand disc, then title and subtitle that rise in
/// every time the page becomes current.
private struct OnboardingPageView: View {
    let page: OnboardingPage
    let title: String
    let subtitle: String
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false

    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            OnboardingArtView(art: page.art, entered: entered)

            VStack(spacing: AppDesign.Spacing.sm) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppDesign.Colors.text)
                    .multilineTextAlignment(.center)
                    .offset(y: entered ? 0 : 14)
                    .opacity(entered ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.12), value: entered)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .offset(y: entered ? 0 : 14)
                    .opacity(entered ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.22), value: entered)
            }
            .padding(.horizontal, AppDesign.Spacing.xxxl)
        }
        .onAppear { replay() }
        .onChange(of: isActive) { _, active in
            if active { replay() }
        }
    }

    private func replay() {
        guard isActive else { return }
        guard !reduceMotion else {
            entered = true
            return
        }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { entered = false }
        DispatchQueue.main.async { entered = true }
    }
}

// MARK: - Art

/// White plate with a slowly turning dashed ring, orbiting crew dots and the brand disc,
/// which springs in with its icon; the games page adds bouncing game chips.
private struct OnboardingArtView: View {
    let art: OnboardingPage.Art
    let entered: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false
    @State private var floating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppDesign.Colors.background)
                .overlay(Circle().stroke(FausBrand.orange.opacity(0.35), lineWidth: 1.2))
                .frame(width: 192, height: 192)

            Circle()
                .stroke(FausBrand.deepBerry.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .frame(width: 156, height: 156)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinAnimation(duration: 18), value: spinning)

            orbitDot(size: 12, color: FausBrand.orangeLight.opacity(0.75), radius: 92, startAngle: -90, duration: 7, reverse: false)
            orbitDot(size: 14, color: FausBrand.markBerry.opacity(0.45), radius: 88, startAngle: 10, duration: 11, reverse: true)
            orbitDot(size: 8, color: FausBrand.orange.opacity(0.7), radius: 84, startAngle: 140, duration: 11, reverse: true)

            Circle()
                .fill(FausBrand.iconGradient)
                .frame(width: 120, height: 120)
                .shadow(color: FausBrand.deepBerry.opacity(0.3), radius: 12, x: 0, y: 12)
                .overlay(
                    icon
                        .scaleEffect(entered ? 1 : 0.3)
                        .rotationEffect(.degrees(entered ? 0 : -14))
                        .opacity(entered ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15), value: entered)
                        .offset(y: floating ? -5 : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: floating)
                )
                .scaleEffect(entered ? 1 : 0.4)
                .opacity(entered ? 1 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.6), value: entered)

            if case .games = art {
                gameChip("die.face.5.fill", x: -86, y: -62, delay: 0.35)
                gameChip("trophy.fill", x: 82, y: -72, delay: 0.43)
                gameChip("hand.raised.fill", x: 88, y: 58, delay: 0.51)
                gameChip("star.fill", x: -84, y: 54, delay: 0.59)
            }
        }
        .frame(width: 200, height: 200)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            spinning = true
            floating = true
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch art {
        case .house:
            FausHouseIcon(size: 62, fill: .color(.white))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 50, weight: .semibold))
                .foregroundColor(.white)
        case .games:
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 50, weight: .semibold))
                .foregroundColor(.white)
        case .bell:
            BellIcon()
        }
    }

    private func orbitDot(size: CGFloat, color: Color, radius: CGFloat, startAngle: Double, duration: Double, reverse: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(y: -radius)
            .rotationEffect(.degrees(startAngle + (spinning ? (reverse ? -360 : 360) : 0)))
            .animation(spinAnimation(duration: duration), value: spinning)
    }

    private func gameChip(_ symbol: String, x: CGFloat, y: CGFloat, delay: Double) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(FausBrand.orange)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(AppDesign.Colors.background)
                    .shadow(color: FausBrand.deepBerry.opacity(0.18), radius: 5, x: 0, y: 4)
            )
            .scaleEffect(entered ? 1 : 0)
            .offset(x: x, y: y + (entered ? 0 : 10))
            .opacity(entered ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.55).delay(delay), value: entered)
    }

    private func spinAnimation(duration: Double) -> Animation? {
        reduceMotion ? nil : .linear(duration: duration).repeatForever(autoreverses: false)
    }
}

/// Bell that keeps ringing with a gentle wobble.
private struct BellIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringing = false

    var body: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 48, weight: .semibold))
            .foregroundColor(.white)
            .rotationEffect(.degrees(ringing ? 8 : -8), anchor: .top)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: ringing)
            .onAppear { if !reduceMotion { ringing = true } }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppViewModel())
}
