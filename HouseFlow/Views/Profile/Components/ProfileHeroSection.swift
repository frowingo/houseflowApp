import SwiftUI

struct ProfileHeroSection: View {
    let imageURLString: String
    let initials: String
    let fullName: String
    let email: String
    let isVisible: Bool
    let onAvatarTap: () -> Void

    @State private var avatarPulse = false

    private let brandOrange = Color(red: 1.0, green: 0.48, blue: 0.15)
    private let fallbackColors = [
        Color(red: 0.95, green: 0.50, blue: 0.08),
        Color(red: 0.78, green: 0.32, blue: 0.03)
    ]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 0.85, brightness: 0.95),
                            Color(hue: 0.05, saturation: 0.75, brightness: 0.80),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 190)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .offset(x: 140, y: -46)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 110, height: 110)
                .offset(x: 250, y: 52)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.15))
                .offset(x: 230, y: -50)

            HStack(alignment: .bottom, spacing: AppDesign.Spacing.lg) {
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(email)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.bottom, AppDesign.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .shadow(color: Color.orange.opacity(0.35), radius: 16, x: 0, y: 6)
        .padding(.horizontal, AppDesign.Spacing.lg)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 1.0, green: 0.78, blue: 0.40),
                            brandOrange,
                            Color(red: 0.65, green: 0.20, blue: 0.05),
                            Color(red: 1.0, green: 0.78, blue: 0.40)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 108, height: 108)
                .opacity(avatarPulse ? 1 : 0.55)
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: avatarPulse
                )

            Circle()
                .fill(Color.white)
                .frame(width: 96, height: 96)

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
            .frame(width: 96, height: 96)
            .clipShape(Circle())

            if imageURLString.isEmpty {
                Text(initials)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 7)
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: fallbackColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
