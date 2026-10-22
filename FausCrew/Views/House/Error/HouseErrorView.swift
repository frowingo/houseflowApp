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
                ZStack(alignment: .bottomTrailing) {
                    FausFramedMark(size: 150)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(HouseJourneyTheme.errorRed)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: HouseJourneyTheme.errorRed.opacity(0.25), radius: 8, x: 0, y: 4)
                        )
                        .offset(x: -6, y: -6)
                }
                .accessibilityHidden(true)

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
                        Task { await appViewModel.retryHouseLoading() }
                    }) {
                        Text(appViewModel.localized("house_error_retry_button"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeight)
                            .background(FausBrand.buttonGradient)
                            .cornerRadius(AppDesign.CornerRadius.lg)
                            .shadow(
                                color: FausBrand.deepBerry.opacity(0.28),
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
            MainScreenBackground()

            RadialGradient(
                colors: [HouseJourneyTheme.errorRed.opacity(0.055), Color.clear],
                center: .center,
                startRadius: 30,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    HouseErrorView()
        .environmentObject(AppViewModel())
}
