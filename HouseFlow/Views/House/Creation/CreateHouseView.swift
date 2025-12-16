import SwiftUI

/// Create house screen with form inputs and confirmation flow
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct CreateHouseView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var houseName = ""
    @State private var selectedHouseType: HouseTypeCard.HouseType = .studentHouse
    @State private var memberCount = 3
    @State private var showSummaryPopup = false
    @State private var showInviteCodePopup = false
    @State private var generatedInviteCode = ""
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            headerSection
            formScrollView
            createButton
        }
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .overlay(popupsOverlay)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            backButton
            
            Text("Create New House")
                .font(AppDesign.Typography.largeTitle)
            
            Text("Start by entering your home details")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppDesign.Spacing.xxxl)
    }
    
    private var backButton: some View {
        HStack {
            Button(action: {
                withAnimation(AppDesign.Animation.standard) {
                    appViewModel.backToHouseSelection()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppDesign.Colors.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.xxl)
    }
    
    // MARK: - Form Scroll View
    
    private var formScrollView: some View {
        ScrollView {
            VStack(spacing: AppDesign.Spacing.xxl) {
                houseNameSection
                houseTypeSection
                MemberCountPicker(memberCount: $memberCount)
                
                Spacer(minLength: AppDesign.Spacing.xxxl)
            }
            .padding(.horizontal, AppDesign.Spacing.xxl)
        }
    }
    
    // MARK: - House Name Section
    
    private var houseNameSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Text("House Name")
                .font(AppDesign.Typography.headline)
            
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                houseNameTextField
                
                if !houseName.isEmpty {
                    characterCountLabel
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var houseNameTextField: some View {
        TextField("Enter House Name", text: $houseName)
            .font(AppDesign.Typography.body)
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.md)
            .background(AppDesign.Colors.cardBackground)
            .cornerRadius(AppDesign.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .strokeBorder(
                        houseName.isEmpty ? Color.clear : AppDesign.Colors.primary,
                        lineWidth: 2
                    )
            )
            .animation(AppDesign.Animation.quick, value: houseName.isEmpty)
            .onChange(of: houseName) { _, newValue in
                if newValue.count > 30 {
                    houseName = String(newValue.prefix(30))
                }
            }
    }
    
    private var characterCountLabel: some View {
        Text("\(houseName.count)/30 char")
            .font(AppDesign.Typography.caption2)
            .foregroundColor(AppDesign.Colors.textSecondary)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - House Type Section
    
    private var houseTypeSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Text("House Type")
                .font(AppDesign.Typography.headline)
            
            HStack(spacing: AppDesign.Spacing.md) {
                ForEach(HouseTypeCard.HouseType.allCases, id: \.self) { type in
                    HouseTypeCard(
                        type: type,
                        isSelected: selectedHouseType == type
                    ) {
                        withAnimation(AppDesign.Animation.quick) {
                            selectedHouseType = type
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        Button(action: {
            withAnimation(AppDesign.Animation.standard) {
                showSummaryPopup = true
            }
        }) {
            Text("Create Home")
                .font(AppDesign.Typography.headline)
                .foregroundColor(isFormValid ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeight)
                .background(isFormValid ? AppDesign.Colors.primary : Color.gray.opacity(0.3))
                .cornerRadius(AppDesign.CornerRadius.lg)
                .animation(AppDesign.Animation.quick, value: isFormValid)
        }
        .disabled(!isFormValid)
        .padding(.horizontal, AppDesign.Spacing.xxl)
        .padding(.bottom, 50)
    }
    
    // MARK: - Popups Overlay
    
    private var popupsOverlay: some View {
        Group {
            if showSummaryPopup {
                SummaryPopup(
                    houseName: houseName,
                    houseType: selectedHouseType.rawValue,
                    memberCount: memberCount,
                    onConfirm: {
                        showSummaryPopup = false
                        generatedInviteCode = generateInviteCode()
                        showInviteCodePopup = true
                    },
                    onCancel: {
                        showSummaryPopup = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            if showInviteCodePopup {
                InviteCodePopup(
                    inviteCode: generatedInviteCode,
                    houseName: houseName,
                    onContinue: {
                        showInviteCodePopup = false
                        appViewModel.createHouse(
                            name: houseName,
                            type: selectedHouseType.rawValue,
                            memberCount: memberCount
                        )
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(AppDesign.Animation.standard, value: showSummaryPopup)
        .animation(AppDesign.Animation.standard, value: showInviteCodePopup)
    }
    
    // MARK: - Helper Methods
    
    private func generateInviteCode() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyazABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!*"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
    
    private var isFormValid: Bool {
        !houseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    CreateHouseView()
        .environmentObject(AppViewModel())
}
