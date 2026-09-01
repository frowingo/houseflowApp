import SwiftUI

/// Summary popup showing house creation details before confirmation
struct SummaryPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let houseName: String
    let houseType: String
    let memberCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            backgroundOverlay
            popupContent
        }
    }
    
    // MARK: - Background
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                onCancel()
            }
    }
    
    // MARK: - Popup Content
    
    private var popupContent: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            headerSection
            summaryDetailsSection
            actionButtons
        }
        .padding(AppDesign.Spacing.xxl)
        .background(MainScreenBackground())
        .cornerRadius(AppDesign.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(HouseJourneyTheme.indigo.opacity(0.13), lineWidth: 1)
        )
        .shadow(
            color: AppDesign.Shadow.heavy.color,
            radius: AppDesign.Shadow.heavy.radius,
            x: AppDesign.Shadow.heavy.x,
            y: AppDesign.Shadow.heavy.y
        )
        .padding(.horizontal, AppDesign.Spacing.xxxl)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "house.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(HouseJourneyTheme.indigo)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(HouseJourneyTheme.accentOrange)
                        .frame(width: 8, height: 8)
                }
            
            Text(appViewModel.localized("house_summary_title"))
                .font(AppDesign.Typography.title2)
            
            Text(appViewModel.localized("house_summary_subtitle"))
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Summary Details
    
    private var summaryDetailsSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            SummaryRow(title: appViewModel.localized("house_summary_name_label"), value: houseName)
            SummaryRow(title: appViewModel.localized("house_summary_type_label"), value: houseType)
            SummaryRow(
                title: appViewModel.localized("house_summary_person_count_label"),
                value: appViewModel.localized(
                    "house_summary_person_count_value_template",
                    replacements: ["count": "\(memberCount)"]
                )
            )
        }
        .padding(.vertical, AppDesign.Spacing.lg)
        .padding(.horizontal, AppDesign.Spacing.md)
        .background(HouseJourneyTheme.indigo.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Button(action: onConfirm) {
                Text(appViewModel.localized("house_summary_create_button"))
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeight)
                    .background(HouseJourneyTheme.primaryButtonGradient)
                    .cornerRadius(AppDesign.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(HouseJourneyTheme.accentOrange.opacity(0.32), lineWidth: 1)
                    )
            }
            
            Button(action: onCancel) {
                Text(appViewModel.localized("common_edit"))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(HouseJourneyTheme.accentOrangeInk)
            }
        }
    }
}

// MARK: - Summary Row Component

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.text)
        }
        .padding(.vertical, AppDesign.Spacing.xs)
    }
}

// MARK: - Previews

#Preview("Summary Popup") {
    SummaryPopup(
        houseName: "My Awesome House",
        houseType: "Student House",
        memberCount: 5,
        onConfirm: {},
        onCancel: {}
    )
}

#Preview("Dark Mode") {
    SummaryPopup(
        houseName: "Shared Apartment",
        houseType: "Shared House",
        memberCount: 3,
        onConfirm: {},
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Long Names") {
    SummaryPopup(
        houseName: "The Amazing Incredibly Long House Name That Goes On Forever",
        houseType: "Dorm Room",
        memberCount: 8,
        onConfirm: {},
        onCancel: {}
    )
}
