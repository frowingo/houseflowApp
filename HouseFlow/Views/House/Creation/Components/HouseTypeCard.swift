import SwiftUI

/// House type selection card component
/// Displays icon and label for different house types
struct HouseTypeCard: View {
    let type: HouseType
    let isSelected: Bool
    let action: () -> Void
    
    enum HouseType: String, CaseIterable {
        case studentHouse = "Student House"
        case sharedHouse = "Shared House"
        case dormRoom = "Dorm Room"
        
        var iconName: String {
            switch self {
            case .studentHouse: return "graduationcap.fill"
            case .sharedHouse: return "house.fill"
            case .dormRoom: return "building.2.fill"
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
            .foregroundColor(isSelected ? .white : AppDesign.Colors.primary)
    }
    
    private var labelSection: some View {
        Text(type.rawValue)
            .font(AppDesign.Typography.caption)
            .foregroundColor(isSelected ? .white : AppDesign.Colors.text)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }
    
    private var backgroundColor: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
            .fill(isSelected ? AppDesign.Colors.primary : AppDesign.Colors.cardBackground)
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
            .strokeBorder(
                isSelected ? AppDesign.Colors.primary : Color.clear,
                lineWidth: 2
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
