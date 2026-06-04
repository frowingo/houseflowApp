import SwiftUI

struct ComingSoonView: View {
    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppDesign.Colors.background.ignoresSafeArea()

            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppDesign.Colors.primary.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .scaleEffect(pulse ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: pulse
                )

            VStack(spacing: AppDesign.Spacing.xxl) {

                // Icon
                ZStack {
                    Circle()
                        .fill(AppDesign.Colors.primary.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppDesign.Colors.primary, AppDesign.Colors.primary.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

                // Text block
                VStack(spacing: AppDesign.Spacing.md) {
                    Text("Coming Soon")
                        .font(AppDesign.Typography.title2)
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("We're working on this feature.\nStay tuned for new updates!")
                        .font(AppDesign.Typography.subheadline)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                // Badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppDesign.Colors.success)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 1.3 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    Text("In development")
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.textTertiary)
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.vertical, AppDesign.Spacing.sm)
                .background(AppDesign.Colors.secondaryBackground)
                .clipShape(Capsule())
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            pulse = true
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}
