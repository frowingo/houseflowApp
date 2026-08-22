import SwiftUI

/// Create house screen with form inputs and confirmation flow
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct CreateHouseView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var houseName = ""
    @State private var selectedHouseType: HouseTypeCard.HouseType = .studentHouse
    @State private var memberCount = 3
    @State private var showSummaryPopup = false
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            headerSection
            formScrollView
            createButton
        }
        .background(createBackground)
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .overlay(popupsOverlay)
    }

    private var createBackground: some View {
        ZStack {
            HouseJourneyTheme.pageGradient

            Circle()
                .fill(HouseJourneyTheme.purple.opacity(0.065))
                .frame(width: 250, height: 250)
                .offset(x: 170, y: -330)

            Circle()
                .fill(HouseJourneyTheme.teal.opacity(0.04))
                .frame(width: 190, height: 190)
                .offset(x: -185, y: 285)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            backButton
            
            Text(appViewModel.localized("create_house_title"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            Text(appViewModel.localized("create_house_subtitle"))
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
            Text(appViewModel.localized("create_house_name_label"))
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
        TextField(appViewModel.localized("create_house_name_placeholder"), text: $houseName)
            .font(AppDesign.Typography.body)
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.md)
            .background(HouseJourneyTheme.surface)
            .cornerRadius(AppDesign.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .strokeBorder(
                        houseName.isEmpty
                            ? HouseJourneyTheme.indigo.opacity(0.10)
                            : HouseJourneyTheme.accentOrange,
                        lineWidth: houseName.isEmpty ? 1 : 2
                    )
            )
            .shadow(
                color: houseName.isEmpty
                    ? Color.black.opacity(0.03)
                    : HouseJourneyTheme.accentOrange.opacity(0.10),
                radius: 8,
                x: 0,
                y: 3
            )
            .animation(AppDesign.Animation.quick, value: houseName.isEmpty)
            .onChange(of: houseName) { _, newValue in
                if newValue.count > 30 {
                    houseName = String(newValue.prefix(30))
                }
            }
    }
    
    private var characterCountLabel: some View {
        Text(appViewModel.localized(
            "create_house_name_count_template",
            replacements: ["count": "\(houseName.count)"]
        ))
            .font(AppDesign.Typography.caption2)
            .foregroundColor(AppDesign.Colors.textSecondary)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - House Type Section
    
    private var houseTypeSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Text(appViewModel.localized("create_house_type_label"))
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
            Text(appViewModel.localized("create_house_submit_button"))
                .font(AppDesign.Typography.headline)
                .foregroundColor(isFormValid ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeight)
                .background(
                    isFormValid
                        ? HouseJourneyTheme.primaryButtonGradient
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.30), Color.gray.opacity(0.24)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(AppDesign.CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(
                            isFormValid
                                ? HouseJourneyTheme.accentOrange.opacity(0.34)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isFormValid ? HouseJourneyTheme.indigo.opacity(0.22) : .clear,
                    radius: 12,
                    x: 0,
                    y: 6
                )
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
                    houseType: appViewModel.localized(selectedHouseType.localizationKey),
                    memberCount: memberCount,
                    onConfirm: {
                        showSummaryPopup = false
                        Task {
                            await appViewModel.beginCreateHouseFlow(
                                name: houseName,
                                type: selectedHouseType.apiValue,
                                maxMemberCount: memberCount
                            )
                        }
                    },
                    onCancel: {
                        showSummaryPopup = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(AppDesign.Animation.standard, value: showSummaryPopup)
    }
    
    // MARK: - Helper Methods
    
    private var isFormValid: Bool {
        !houseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    CreateHouseView()
        .environmentObject(AppViewModel())
}
