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
        .background(AppDesign.Colors.background)
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
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
                    .font(.title2)
                    .foregroundColor(AppDesign.Colors.text)
            }
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.top, AppDesign.Spacing.xl)
    }
    
    private var headerContent: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: "house.and.flag")
                .font(.system(size: 60))
                .foregroundColor(AppDesign.Colors.primary)
            
            Text("Join a House")
                .font(AppDesign.Typography.largeTitle)
            
            Text("Enter the invite code shared by your friend")
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
            Text("Invite Code")
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
                InfoRow(number: "1", text: "Ask the home owner for the invite code")
                InfoRow(number: "2", text: "Enter the 6–8 character code above")
                InfoRow(number: "3", text: "Tap \"Join House\" button")
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(AppDesign.Colors.primary.opacity(0.05))
        .cornerRadius(AppDesign.CornerRadius.md)
    }
    
    private var infoBoxHeader: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(AppDesign.Colors.primary)
            
            Text("How to get Invite Code ?")
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
            Text("Join House")
                .font(AppDesign.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightLarge)
                .background(inviteCode.isEmpty ? Color.gray.opacity(0.3) : AppDesign.Colors.primary)
                .cornerRadius(AppDesign.CornerRadius.lg)
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
