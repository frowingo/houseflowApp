import SwiftUI

/// Colours and the section heading shared by the sections of `HouseInfoPopup`.
enum HouseInfoStyle {
    static let houseTint = Color(red: 0.42, green: 0.27, blue: 0.67)
    static let ownerTint = HouseJourneyTheme.tintOwner
}

struct HouseInfoSectionTitle: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(AppDesign.Typography.subheadline.weight(.bold))
            .foregroundStyle(AppDesign.Colors.textPrimary)
    }
}
