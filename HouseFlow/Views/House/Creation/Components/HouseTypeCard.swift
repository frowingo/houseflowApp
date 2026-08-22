import SwiftUI

/// House type selection card component
/// Displays icon and label for different house types
struct HouseTypeCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let type: HouseType
    let isSelected: Bool
    let action: () -> Void
    
    enum HouseType: String, CaseIterable {
        case studentHouse = "Student House"
        case sharedHouse = "Shared House"
        case dormRoom = "Dorm Room"

        var localizationKey: String {
            switch self {
            case .studentHouse: return "create_house_type_student"
            case .sharedHouse:  return "create_house_type_shared"
            case .dormRoom:     return "create_house_type_dorm"
            }
        }
        
        var iconName: String {
            switch self {
            case .studentHouse: return "graduationcap.fill"
            case .sharedHouse: return "house.fill"
            case .dormRoom: return "building.2.fill"
            }
        }

        var tint: Color {
            switch self {
            case .studentHouse: return HouseJourneyTheme.purple
            case .sharedHouse: return HouseJourneyTheme.teal
            case .dormRoom: return HouseJourneyTheme.blue
            }
        }

        /// API integer value: StudentHouse=1, SharedHouse=2, DormRoom=3
        var apiValue: Int {
            switch self {
            case .studentHouse: return 1
            case .sharedHouse:  return 2
            case .dormRoom:     return 3
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppDesign.Spacing.md) {
                iconSection
                labelSection
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(backgroundColor)
            .overlay(borderOverlay)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(AppDesign.Animation.quick, value: isSelected)
    }
    
    // MARK: - Subviews
    
    private var iconSection: some View {
        Image(systemName: type.iconName)
            .font(.system(size: AppDesign.Size.iconMedium, weight: .medium))
            .foregroundColor(type.tint)
    }
    
    private var labelSection: some View {
        Text(appViewModel.localized(type.localizationKey))
            .font(AppDesign.Typography.caption)
            .foregroundColor(isSelected ? AppDesign.Colors.textPrimary : AppDesign.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
    
    private var backgroundColor: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
            .fill(isSelected ? type.tint.opacity(0.15) : HouseJourneyTheme.surface)
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
            .strokeBorder(
                isSelected
                    ? HouseJourneyTheme.accentOrange
                    : type.tint.opacity(0.12),
                lineWidth: isSelected ? 2 : 1
            )
    }
}

// MARK: - Previews

#Preview("Not Selected") {
    HouseTypeCard(
        type: .studentHouse,
        isSelected: false,
        action: {}
    )
    .frame(width: 100)
    .padding()
}

#Preview("Selected") {
    HouseTypeCard(
        type: .sharedHouse,
        isSelected: true,
        action: {}
    )
    .frame(width: 100)
    .padding()
}

#Preview("All Types") {
    HStack(spacing: 12) {
        ForEach(HouseTypeCard.HouseType.allCases, id: \.self) { type in
            HouseTypeCard(
                type: type,
                isSelected: type == .sharedHouse,
                action: {}
            )
        }
    }
    .padding()
}

#Preview("Dark Mode") {
    HStack(spacing: 12) {
        ForEach(HouseTypeCard.HouseType.allCases, id: \.self) { type in
            HouseTypeCard(
                type: type,
                isSelected: type == .dormRoom,
                action: {}
            )
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
