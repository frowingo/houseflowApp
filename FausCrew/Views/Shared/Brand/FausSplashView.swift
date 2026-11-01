import SwiftUI

/// True while `FausSplashView` covers the app: screens underneath skip their own animations
/// (route slides, spinners, intros) so the splash keeps the main thread to itself, and start
/// them once the splash reveals the app.
private struct FausSplashActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var fausSplashActive: Bool {
        get { self[FausSplashActiveKey.self] }
        set { self[FausSplashActiveKey.self] = newValue }
    }
}

/// Cold-start brand intro shown over the app while it loads underneath (~3.2s):
/// the roof-F draws itself, the crew dot pops with two ripples, the mark lifts while
/// "FausCrew" rises letter by letter, the motto fades in, then the gradient closes
/// into a circle and reveals the app. It starts on the system launch screen's orange
/// (`LaunchBackground`), so the hand-off is seamless; dark themes then condense that orange into
/// the ember behind the mark (`FausLaunchHandOff`).
struct FausSplashView: View {
    /// Called as the gradient starts to open: the app underneath becomes visible from here on.
    var onReveal: () -> Void = {}
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fausTheme) private var theme

    @State private var drawProgress: CGFloat = 0
    @State private var dotScale: CGFloat = 0
    @State private var rippling = false
    @State private var lifted = false
    @State private var lettersShown = false
    @State private var mottoShown = false
    @State private var revealProgress: CGFloat = 0
    /// Launch screen → theme hand-off, 0...1.
    @State private var handOff: CGFloat = 0

    private var condenses: Bool { theme.decor.splash.launchHandOff == .condense }

    private let wordmark = Array("FausCrew")
    private let markSize: CGFloat = 132
    private let centerRatio: CGFloat = 0.44

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * centerRatio)
            let diagonal = hypot(proxy.size.width, proxy.size.height) * 2.2

            ZStack {
                Color("LaunchBackground")
                if condenses {
                    FausHeroBackground()
                    LaunchCondense(progress: handOff, color: Color("LaunchBackground"), center: UnitPoint(x: 0.5, y: centerRatio),
                                   radius: hypot(proxy.size.width, proxy.size.height) * 0.85)
                } else {
                    FausHeroBackground()
                        .opacity(handOff)
                }

                ripple(delay: 0).position(center)
                ripple(delay: 0.2).position(center)

                splashMark
                    // Flatten the glyph into one GPU layer so the lift only moves a texture.
                    .drawingGroup()
                    .shadow(color: theme.decor.splash.markGlow, radius: 9, x: 0, y: 6)
                    .scaleEffect(lifted ? 0.86 : 1)
                    .offset(y: lifted ? -34 : 0)
                    .position(center)

                VStack(spacing: AppDesign.Spacing.md) {
                    HStack(spacing: 0) {
                        ForEach(wordmark.indices, id: \.self) { index in
                            Text(String(wordmark[index]))
                                .font(.system(size: 34, weight: index < 4 ? .heavy : .regular, design: .rounded))
                                .foregroundColor(index < 4 ? theme.decor.splash.wordmark : theme.decor.splash.wordmarkAccent)
                                .offset(y: lettersShown ? 0 : 12)
                                .opacity(lettersShown ? 1 : 0)
                                .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45).delay(Double(index) * 0.06), value: lettersShown)
                        }
                    }

                    Text(verbatim: "Make living together fun")
                        .font(.system(size: 15))
                        .foregroundColor(theme.decor.splash.motto)
                        .opacity(mottoShown ? 1 : 0)
                        .offset(y: mottoShown ? 0 : 8)
                }
                .drawingGroup()
                .position(x: center.x, y: center.y + 64)
            }
            .mask {
                Circle()
                    .frame(width: diagonal * (1 - revealProgress), height: diagonal * (1 - revealProgress))
                    .position(center)
            }

            if revealProgress > 0, revealProgress < 1 {
                Circle()
                    .stroke(theme.decor.splash.revealRim, lineWidth: 1.5)
                    .shadow(color: theme.decor.splash.revealRim, radius: 13)
                    .frame(width: diagonal * (1 - revealProgress), height: diagonal * (1 - revealProgress))
                    .position(center)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(revealProgress < 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FausCrew")
        .task { await play() }
    }

    @ViewBuilder
    private var splashMark: some View {
        let colors = theme.decor.splash.mark
        if colors.count > 1 {
            Rectangle()
                .fill(LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: 332 / 1024, y: 246 / 1024),
                    endPoint: UnitPoint(x: 692 / 1024, y: 778 / 1024)
                ))
                .frame(width: markSize, height: markSize)
                .mask(FausMark(size: markSize, progress: drawProgress, dotScale: dotScale))
        } else {
            FausMark(size: markSize, color: colors.first ?? .white, progress: drawProgress, dotScale: dotScale)
        }
    }

    private func ripple(delay: Double) -> some View {
        Circle()
            .stroke(theme.decor.splash.ripple, lineWidth: 2)
            .frame(width: 120, height: 120)
            .scaleEffect(rippling ? 2.6 : 0.6)
            .opacity(rippling ? 0 : (dotScale > 0 ? 0.9 : 0))
            .animation(.easeOut(duration: 1.1).delay(delay), value: rippling)
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            handOff = 1
            drawProgress = 1
            dotScale = 1
            lifted = true
            lettersShown = true
            mottoShown = true
            try? await Task.sleep(for: .milliseconds(700))
            onReveal()
            withAnimation(.easeOut(duration: 0.3)) { revealProgress = 1 }
            try? await Task.sleep(for: .milliseconds(300))
            onFinished()
            return
        }

        if condenses {
            withAnimation(.timingCurve(0.5, 0, 0.25, 1, duration: 0.65)) { handOff = 1 }
            // The ember-colored mark would vanish against the orange, so it waits for the dark.
            await wait(until: 0.3, from: 0)
        } else {
            withAnimation(.easeOut(duration: 0.3)) { handOff = 1 }
        }
        await wait(until: 0.25, from: 0)
        withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.9)) { drawProgress = 1 }
        await wait(until: 1.05, from: 0.25)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { dotScale = 1 }
        // Let the ripples become visible before they start spreading out.
        await wait(until: 1.1, from: 1.05)
        rippling = true
        await wait(until: 1.45, from: 1.1)
        // Critically damped spring: no velocity jump at the start or the end of the lift.
        withAnimation(.spring(response: 0.6, dampingFraction: 1)) { lifted = true }
        await wait(until: 1.55, from: 1.45)
        lettersShown = true
        await wait(until: 2.1, from: 1.55)
        withAnimation(.easeOut(duration: 0.5)) { mottoShown = true }
        await wait(until: 2.55, from: 2.1)
        onReveal()
        withAnimation(.timingCurve(0.7, 0, 0.3, 1, duration: 0.7)) { revealProgress = 1 }
        await wait(until: 3.25, from: 2.55)
        onFinished()
    }

    private func wait(until end: Double, from start: Double) async {
        try? await Task.sleep(for: .milliseconds(Int((end - start) * 1000)))
    }
}

/// The launch screen's orange shrinking into a soft disc at the mark, where the dark header's
/// ember glow takes over. Shared math with Android `drawLaunchCondense`.
private struct LaunchCondense: View, Animatable {
    var progress: CGFloat
    let color: Color
    let center: UnitPoint
    /// Start radius: the solid core just reaches the far corners from `center`.
    let radius: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: color, location: 0),
                .init(color: color, location: 0.72),
                .init(color: color.opacity(0), location: 1)
            ],
            center: center,
            startRadius: 0,
            endRadius: max(radius * (1 - progress), 1)
        )
        // Fades out over the last quarter so it never ends as a hard dot.
        .opacity(Double(min(1, (1 - progress) * 4)))
        .allowsHitTesting(false)
    }
}

#Preview {
    FausSplashView(onFinished: {})
}
