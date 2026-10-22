import SwiftUI
import FausCrewCore

/// Join house screen with invite code input
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct JoinHouseView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var inviteCode = ""
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            contentSection
            actionSection
        }
        .background(joinBackground)
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
    }

    private var joinBackground: some View {
        MainScreenBackground()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            backButton
            headerContent
        }
        .padding(.bottom, AppDesign.Spacing.xxxl)
    }
    
    private var backButton: some View {
        HStack {
            Button(action: {
                appViewModel.backToHouseSelection()
            }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(HouseJourneyTheme.accentOrangeInk)
                    .frame(width: 40, height: 40)
                    .background(HouseJourneyTheme.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(FausBrand.orange.opacity(0.20), lineWidth: 1)
                    )
            }
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.top, AppDesign.Spacing.xl)
    }
    
    private var headerContent: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Circle()
                .fill(Color(.systemBackground))
                .overlay(Circle().stroke(FausBrand.orange.opacity(0.55), lineWidth: 1.5))
                .frame(width: 96, height: 96)
                .overlay(FausHouseIcon(size: 48))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(FausBrand.iconGradient)
                                .shadow(color: FausBrand.deepBerry.opacity(0.3), radius: 4, x: 0, y: 3)
                        )
                        .offset(x: 2, y: -2)
                }
                .accessibilityHidden(true)
            
            Text(appViewModel.localized("join_house_title"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            Text(appViewModel.localized("join_house_subtitle"))
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.Spacing.xxxl)
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            inviteCodeSection
            infoBox
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
    }
    
    private var inviteCodeSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            Text(appViewModel.localized("invite_code_label"))
                .font(AppDesign.Typography.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            OTPInputView(
                code: $inviteCode,
                characterCount: InviteCodeRules.requiredLength,
                automaticallyFocus: true,
                accessibilityLabel: appViewModel.localized("invite_code_label"),
                onSubmit: joinHouse
            )
        }
    }
    
    private var infoBox: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            infoBoxHeader
            
            VStack(spacing: AppDesign.Spacing.sm) {
                InfoRow(number: "1", text: appViewModel.localized("join_house_step_1"))
                InfoRow(number: "2", text: appViewModel.localized("join_house_step_2"))
                InfoRow(number: "3", text: appViewModel.localized("join_house_step_3"))
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(FausBrand.deepBerry.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(FausBrand.deepBerry.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(AppDesign.CornerRadius.md)
    }
    
    private var infoBoxHeader: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(HouseJourneyTheme.accentOrangeInk)
            
            Text(appViewModel.localized("join_house_help_title"))
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Action Section
    
    private var actionSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            joinButton
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xxl)
    }
    
    private var joinButton: some View {
        Button(action: joinHouse) {
            Text(appViewModel.localized("join_house_submit_button"))
                .font(AppDesign.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightLarge)
                .background(
                    !InviteCodeRules.isValid(inviteCode)
                        ? LinearGradient(
                            colors: [Color.gray.opacity(0.30), Color.gray.opacity(0.24)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : FausBrand.buttonGradient
                )
                .cornerRadius(AppDesign.CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(
                            Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: InviteCodeRules.isValid(inviteCode) ? FausBrand.deepBerry.opacity(0.28) : .clear,
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .animation(AppDesign.Animation.quick, value: InviteCodeRules.isValid(inviteCode))
        }
        .disabled(!InviteCodeRules.isValid(inviteCode))
    }
    
    // MARK: - Actions
    
    private func joinHouse() {
        guard InviteCodeRules.isValid(inviteCode) else { return }

        Task {
            await appViewModel.beginJoinFausCrew(inviteCode: inviteCode)
        }
    }
}

#Preview {
    JoinHouseView()
        .environmentObject(AppViewModel())
}
