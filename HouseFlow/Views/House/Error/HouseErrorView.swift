import SwiftUI

/// Shown when house/details fails during auto-login.
/// Gives the user options to retry or log out.
struct HouseErrorView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            errorBackground

            VStack(spacing: AppDesign.Spacing.xxxl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(HouseJourneyTheme.errorRed.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(HouseJourneyTheme.accentOrange.opacity(0.18), lineWidth: 1)
                        )

                    Circle()
                        .fill(HouseJourneyTheme.errorRed.opacity(0.06))
                        .frame(width: 88, height: 88)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(HouseJourneyTheme.errorRed)
                }

                // Message
                VStack(spacing: AppDesign.Spacing.md) {
                    Text(appViewModel.localized("house_error_title"))
                        .font(AppDesign.Typography.title2)
                        .foregroundColor(AppDesign.Colors.text)
                        .multilineTextAlignment(.center)

                    Text(appViewModel.localized("house_error_message"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDesign.Spacing.xxxl)
                }

                // Actions
                VStack(spacing: AppDesign.Spacing.lg) {
                    Button(action: {
                        Task { await appViewModel.performAutoLogin() }
                    }) {
                        Text(appViewModel.localized("house_error_retry_button"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeight)
                            .background(HouseJourneyTheme.primaryButtonGradient)
                            .cornerRadius(AppDesign.CornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                                    .stroke(HouseJourneyTheme.accentOrange.opacity(0.30), lineWidth: 1)
                            )
                            .shadow(
                                color: HouseJourneyTheme.indigo.opacity(0.20),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                    }

                    Button(action: {
                        withAnimation(AppDesign.Animation.standard) {
                            appViewModel.logout()
                        }
                    }) {
                        Text(appViewModel.localized("house_error_logout_button"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(HouseJourneyTheme.errorRed)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeight)
                            .background(HouseJourneyTheme.surface)
                            .cornerRadius(AppDesign.CornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                                    .stroke(HouseJourneyTheme.errorRed.opacity(0.20), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xxl)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private var errorBackground: some View {
        ZStack {
            HouseJourneyTheme.pageBackground

            RadialGradient(
                colors: [HouseJourneyTheme.errorRed.opacity(0.075), Color.clear],
                center: .center,
                startRadius: 30,
                endRadius: 360
            )

            LinearGradient(
                colors: [HouseJourneyTheme.indigo.opacity(0.035), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    HouseErrorView()
        .environmentObject(AppViewModel())
}
