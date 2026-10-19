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
/// into a circle and reveals the app. The system launch screen uses the same orange
/// (`LaunchBackground`), so the hand-off is seamless.
struct FausSplashView: View {
    /// Called as the gradient starts to open: the app underneath becomes visible from here on.
    var onReveal: () -> Void = {}
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var gradientVisible = false
    @State private var drawProgress: CGFloat = 0
    @State private var dotScale: CGFloat = 0
    @State private var rippling = false
    @State private var lifted = false
    @State private var lettersShown = false
    @State private var mottoShown = false
    @State private var revealProgress: CGFloat = 0

    private let wordmark = Array("FausCrew")
    private let markSize: CGFloat = 132
    private let centerRatio: CGFloat = 0.44

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * centerRatio)
            let diagonal = hypot(proxy.size.width, proxy.size.height) * 2.2

            ZStack {
                Color("LaunchBackground")
                FausHeroBackground()
                    .opacity(gradientVisible ? 1 : 0)

                ripple(delay: 0).position(center)
                ripple(delay: 0.2).position(center)

                FausMark(size: markSize, color: .white, progress: drawProgress, dotScale: dotScale)
                    // Flatten the glyph into one GPU layer so the lift only moves a texture.
                    .drawingGroup()
                    .scaleEffect(lifted ? 0.86 : 1)
                    .offset(y: lifted ? -34 : 0)
                    .position(center)

                VStack(spacing: AppDesign.Spacing.md) {
                    HStack(spacing: 0) {
                        ForEach(wordmark.indices, id: \.self) { index in
                            Text(String(wordmark[index]))
                                .font(.system(size: 34, weight: index < 4 ? .heavy : .regular, design: .rounded))
                                .foregroundColor(.white.opacity(index < 4 ? 1 : 0.9))
                                .offset(y: lettersShown ? 0 : 12)
                                .opacity(lettersShown ? 1 : 0)
                                .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45).delay(Double(index) * 0.06), value: lettersShown)
                        }
                    }

                    Text(verbatim: "Make living together fun")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.82))
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
        }
        .ignoresSafeArea()
        .allowsHitTesting(revealProgress < 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FausCrew")
        .task { await play() }
    }

    private func ripple(delay: Double) -> some View {
        Circle()
            .stroke(Color.white.opacity(0.55), lineWidth: 2)
            .frame(width: 120, height: 120)
            .scaleEffect(rippling ? 2.6 : 0.6)
            .opacity(rippling ? 0 : (dotScale > 0 ? 0.9 : 0))
            .animation(.easeOut(duration: 1.1).delay(delay), value: rippling)
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            gradientVisible = true
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

        withAnimation(.easeOut(duration: 0.3)) { gradientVisible = true }
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

#Preview {
    FausSplashView(onFinished: {})
}
