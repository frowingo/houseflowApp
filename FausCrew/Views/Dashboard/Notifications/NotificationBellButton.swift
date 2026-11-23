import SwiftUI

/// The dashboard hero's bell: the megaphone's 40pt circle plus the unread badge (1–9, then "9+").
struct NotificationBellButton: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.fausTheme) private var theme
    @ObservedObject var store: NotificationStore
    let action: () -> Void

    private var badgeText: String {
        store.unreadCount > 9 ? "9+" : "\(store.unreadCount)"
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell.fill")
                .font(.system(size: AppDesign.Size.iconMedium))
                .foregroundStyle(AppDesign.Colors.onHero.opacity(0.9))
                .frame(width: 40, height: 40)
                .background(theme.decor.heroOrnament.opacity(0.18))
                .clipShape(Circle())
        }
        .overlay(alignment: .topTrailing) {
            if store.unreadCount > 0 {
                Text(badgeText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(HouseJourneyTheme.accentOrange, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                    .offset(x: 5, y: -5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(appViewModel.localized(
            "notifications_open_accessibility_label",
            tr: "Bildirimleri aç",
            en: "Open notifications"
        ))
        .accessibilityValue(store.unreadCount > 0 ? unreadAccessibilityText : "")
    }

    private var unreadAccessibilityText: String {
        appViewModel.localized(
            "notifications_unread_badge_accessibility",
            tr: "%d okunmamış",
            en: "%d unread"
        )
        .replacingOccurrences(of: "%d", with: "\(store.unreadCount)")
        .replacingOccurrences(of: "{count}", with: "\(store.unreadCount)")
    }
}
