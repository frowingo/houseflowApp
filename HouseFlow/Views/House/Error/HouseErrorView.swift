import SwiftUI

/// Shown when house/details fails during auto-login.
/// Gives the user options to retry or log out.
struct HouseErrorView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            AppDesign.Colors.background
                .ignoresSafeArea()

            VStack(spacing: AppDesign.Spacing.xxxl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(AppDesign.Colors.error.opacity(0.08))
                        .frame(width: 120, height: 120)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(AppDesign.Colors.error)
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
                            .background(AppDesign.Colors.primary)
                            .cornerRadius(AppDesign.CornerRadius.lg)
                    }

                    Button(action: {
                        withAnimation(AppDesign.Animation.standard) {
                            appViewModel.logout()
                        }
                    }) {
                        Text(appViewModel.localized("house_error_logout_button"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(AppDesign.Colors.error)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeight)
                            .background(AppDesign.Colors.error.opacity(0.08))
                            .cornerRadius(AppDesign.CornerRadius.lg)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xxl)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    HouseErrorView()
        .environmentObject(AppViewModel())
}
