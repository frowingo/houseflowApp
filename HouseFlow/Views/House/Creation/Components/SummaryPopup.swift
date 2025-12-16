import SwiftUI

/// Summary popup showing house creation details before confirmation
struct SummaryPopup: View {
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
        .background(AppDesign.Colors.surface)
        .cornerRadius(AppDesign.CornerRadius.xl)
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
                .foregroundColor(AppDesign.Colors.primary)
            
            Text("Summary")
                .font(AppDesign.Typography.title2)
            
            Text("Review the information for the home to be created")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Summary Details
    
    private var summaryDetailsSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            SummaryRow(title: "House Name", value: houseName)
            SummaryRow(title: "House Type", value: houseType)
            SummaryRow(title: "Person count", value: "\(memberCount) persons")
        }
        .padding(.vertical, AppDesign.Spacing.lg)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Button(action: onConfirm) {
                Text("Create House")
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeight)
                    .background(AppDesign.Colors.primary)
                    .cornerRadius(AppDesign.CornerRadius.md)
            }
            
            Button(action: onCancel) {
                Text("Edit")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.primary)
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
