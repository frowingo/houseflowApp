import SwiftUI

/// Join house screen with invite code input
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct JoinHouseView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var inviteCode = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            contentSection
            actionSection
        }
        .background(joinBackground)
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }

    private var joinBackground: some View {
        ZStack {
            HouseJourneyTheme.pageGradient

            Circle()
                .fill(HouseJourneyTheme.teal.opacity(0.07))
                .frame(width: 230, height: 230)
                .offset(x: 165, y: -300)

            Circle()
                .fill(HouseJourneyTheme.accentOrange.opacity(0.035))
                .frame(width: 160, height: 160)
                .offset(x: -185, y: 270)
        }
        .ignoresSafeArea()
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
                            .stroke(HouseJourneyTheme.indigo.opacity(0.10), lineWidth: 1)
                    )
            }
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.top, AppDesign.Spacing.xl)
    }
    
    private var headerContent: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(HouseJourneyTheme.teal.opacity(0.10))
                    .frame(width: 102, height: 102)
                Circle()
                    .fill(HouseJourneyTheme.indigo.opacity(0.08))
                    .frame(width: 78, height: 78)
                Image(systemName: "house.and.flag")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(HouseJourneyTheme.indigo)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(HouseJourneyTheme.accentOrange)
                    .frame(width: 10, height: 10)
                    .offset(x: -2, y: 8)
            }
            
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
            
            InviteCodeTextField(
                text: $inviteCode,
                isError: false,
                isFocused: $isTextFieldFocused,
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
        .background(HouseJourneyTheme.teal.opacity(0.075))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(HouseJourneyTheme.teal.opacity(0.16), lineWidth: 1)
        )
        .cornerRadius(AppDesign.CornerRadius.md)
    }
    
    private var infoBoxHeader: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(HouseJourneyTheme.indigo)
            
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
                    inviteCode.isEmpty
                        ? LinearGradient(
                            colors: [Color.gray.opacity(0.30), Color.gray.opacity(0.24)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : HouseJourneyTheme.joinButtonGradient
                )
                .cornerRadius(AppDesign.CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(
                            inviteCode.isEmpty
                                ? Color.clear
                                : HouseJourneyTheme.accentOrange.opacity(0.34),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: inviteCode.isEmpty ? .clear : HouseJourneyTheme.teal.opacity(0.24),
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .animation(AppDesign.Animation.quick, value: inviteCode.isEmpty)
        }
        .disabled(inviteCode.isEmpty)
    }
    
    // MARK: - Actions
    
    private func joinHouse() {
        guard !inviteCode.isEmpty else { return }
        
        isTextFieldFocused = false

        Task {
            await appViewModel.beginJoinHouseFlow(inviteCode: inviteCode)
        }
    }
}

#Preview {
    JoinHouseView()
        .environmentObject(AppViewModel())
}
