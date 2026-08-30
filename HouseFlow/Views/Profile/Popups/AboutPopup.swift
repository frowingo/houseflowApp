import SwiftUI

// MARK: - About HouseFlow Popup

struct AboutPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let onDismiss: () -> Void

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { requestDismiss() }

            VStack(spacing: 0) {
                // ── Top bar (identical pattern to EditProfilePopup / AvatarPickerPopup)
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "house.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("profile_about_label"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.localized("profile_about_version"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Button(action: requestDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 64)

                // ── Body
                VStack(spacing: AppDesign.Spacing.lg) {
                    // Quote card
                    ZStack {
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                            .fill(accentOrange.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                                    .strokeBorder(accentOrange.opacity(0.2), lineWidth: 1)
                            )

                        VStack(spacing: 14) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(accentOrange.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(appViewModel.localized("profile_about_quote"))
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(accentOrange)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity)

                            Image(systemName: "quote.closing")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(accentOrange.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(20)
                    }

                    // Made with love
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(accentOrange)
                        Text(appViewModel.localized("profile_about_made_with_love"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppDesign.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xl)

                // ── Footer (same as AvatarPickerPopup)
                Button(action: requestDismiss) {
                    Text(appViewModel.localized("profile_about_close_button"))
                        .font(AppDesign.Typography.headline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(AppDesign.Colors.secondaryBackground)
                        .cornerRadius(AppDesign.CornerRadius.md)
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(
                    AppDesign.Colors.background
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
                )
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
