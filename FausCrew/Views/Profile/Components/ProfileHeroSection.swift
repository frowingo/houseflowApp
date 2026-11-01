import SwiftUI

struct ProfileHeroSection: View {
    let imageURLString: String
    let initials: String
    let fullName: String
    let isVisible: Bool
    let onAvatarTap: () -> Void

    @State private var avatarPulse = false

    @Environment(\.fausTheme) private var theme

    var body: some View {
        ZStack {
            BrandHeroCardBackground()

            HStack(spacing: AppDesign.Spacing.lg) {
                Button {
                    withAnimation(AppDesign.Animation.standard) {
                        onAvatarTap()
                    }
                } label: {
                    avatar
                }
                .buttonStyle(.plain)
                .onAppear { avatarPulse = true }

                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Text(fullName)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.92), Color.white.opacity(0.18)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 76, height: 3)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 112)
        .padding(.horizontal, AppDesign.Spacing.lg)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(colors: theme.decor.avatarRing, center: .center),
                    lineWidth: 3
                )
                .frame(width: 84, height: 84)
                .opacity(avatarPulse ? 1 : 0.55)
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: avatarPulse
                )

            Circle()
                .fill(AppDesign.Colors.surface)
                .frame(width: 74, height: 74)

            Group {
                if !imageURLString.isEmpty, let url = URL(string: imageURLString) {
                    CachedRemoteImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        fallbackAvatar
                    } failure: {
                        fallbackAvatar
                    }
                } else {
                    fallbackAvatar
                }
            }
            .frame(width: 74, height: 74)
            .clipShape(Circle())

            if imageURLString.isEmpty {
                Text(initials)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: AppDesign.Colors.shadow.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: theme.decor.avatarFallback,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
