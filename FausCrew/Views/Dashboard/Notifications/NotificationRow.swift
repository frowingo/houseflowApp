import SwiftUI
import FausCrewCore

/// One notification: sender avatar and name, kind icon, title, message and relative time. An
/// accent bar on the left marks what is newer than the last time the panel was open.
struct NotificationRow: View {
    let item: HouseNotification
    /// Nil when the sender is no longer in the house.
    let sender: User?
    let formerMemberLabel: String
    let isUnread: Bool
    let timeText: String

    private let accent = HouseJourneyTheme.accentOrange

    private var kindIcon: String {
        switch item.kind {
        case .announcement: "megaphone.fill"
        case .choreReminder, .unknown: "bell.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(sender?.name ?? formerMemberLabel)
                        .font(AppDesign.Typography.caption.weight(.semibold))
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: AppDesign.Spacing.sm)
                    Text(timeText)
                        .font(AppDesign.Typography.caption2)
                        .foregroundStyle(AppDesign.Colors.textTertiary)
                        .lineLimit(1)
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: kindIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                        .padding(.top, 3)
                    Text(item.title)
                        .font(.system(size: 15, weight: isUnread ? .bold : .semibold))
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(item.message)
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(isUnread ? accent.opacity(0.08) : AppDesign.Colors.secondaryBackground)
        )
        .overlay(alignment: .leading) {
            if isUnread {
                Capsule()
                    .fill(accent)
                    .frame(width: 4)
                    .padding(.vertical, AppDesign.Spacing.md)
                    .padding(.leading, 6)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        if let sender {
            UserAvatar(user: sender, size: 36)
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppDesign.Colors.textTertiary)
                .frame(width: 36, height: 36)
                .background(AppDesign.Colors.controlFill, in: Circle())
        }
    }
}

/// "5 min. ago" in the app's language, never in the future (a fast device clock).
enum NotificationTimeText {
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: APILanguage.code)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
