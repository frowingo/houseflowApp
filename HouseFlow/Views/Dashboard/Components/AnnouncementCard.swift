import SwiftUI

/// Collapsible list of active house announcements.
/// Read state stays on this device and is namespaced by user and house.
struct AnnouncementCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let houseId: String
    let readerId: String?
    let announcements: [HouseAnnouncementDTO]
    let members: [HouseMemberDTO]

    @State private var isExpanded = false
    @State private var readAnnouncementIds: Set<String>

    init(
        houseId: String,
        readerId: String? = nil,
        announcements: [HouseAnnouncementDTO],
        members: [HouseMemberDTO] = []
    ) {
        self.houseId = houseId
        self.readerId = readerId
        self.announcements = announcements
        self.members = members
        _readAnnouncementIds = State(
            initialValue: AnnouncementReadStore.load(houseId: houseId, readerId: readerId)
        )
    }

    private var activeAnnouncements: [HouseAnnouncementDTO] {
        announcements.filter(\.isActive)
    }

    private var unreadCount: Int {
        activeAnnouncements.filter { !readAnnouncementIds.contains($0.id) }.count
    }

    private var sortedAnnouncements: [HouseAnnouncementDTO] {
        activeAnnouncements.sorted { lhs, rhs in
            let lhsIsRead = readAnnouncementIds.contains(lhs.id)
            let rhsIsRead = readAnnouncementIds.contains(rhs.id)
            if lhsIsRead != rhsIsRead { return !lhsIsRead }

            let lhsDate = HouseFlowDateFormatter.parseAPIDate(lhs.createdOn) ?? .distantPast
            let rhsDate = HouseFlowDateFormatter.parseAPIDate(rhs.createdOn) ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerButton

            if isExpanded {
                Divider()
                    .padding(.horizontal, AppDesign.Spacing.xl)

                announcementList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                HouseJourneyTheme.surface
                LinearGradient(
                    colors: [
                        HouseJourneyTheme.purple.opacity(0.075),
                        HouseJourneyTheme.teal.opacity(0.035),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .strokeBorder(
                    isExpanded
                        ? HouseJourneyTheme.purple.opacity(0.30)
                        : HouseJourneyTheme.indigo.opacity(0.13),
                    lineWidth: 1
                )
        )
        .shadow(
            color: HouseJourneyTheme.deepIndigo.opacity(isExpanded ? 0.13 : 0.07),
            radius: isExpanded ? 16 : 10,
            x: 0,
            y: isExpanded ? 7 : 4
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isExpanded)
        .animation(AppDesign.Animation.quick, value: readAnnouncementIds)
        .onChange(of: storageNamespace) { _, _ in
            readAnnouncementIds = AnnouncementReadStore.load(
                houseId: houseId,
                readerId: readerId
            )
        }
    }

    private var headerButton: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: AppDesign.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [HouseJourneyTheme.purple, HouseJourneyTheme.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)

                    Circle()
                        .fill(HouseJourneyTheme.accentOrange)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(HouseJourneyTheme.surface, lineWidth: 1.5))
                        .offset(x: -17, y: 17)

                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(HouseJourneyTheme.accentOrange)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(HouseJourneyTheme.surface, lineWidth: 2))
                            .offset(x: 18, y: -18)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(appViewModel.localized("announcement_title"))
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(AppDesign.Colors.textPrimary)

                    Text(headerSubtitle)
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(HouseJourneyTheme.indigo)
                    .frame(width: 32, height: 32)
                    .background(HouseJourneyTheme.indigo.opacity(0.10))
                    .clipShape(Circle())
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(AppDesign.Spacing.xl)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var announcementList: some View {
        if sortedAnnouncements.isEmpty {
            VStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "megaphone")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(HouseJourneyTheme.indigo.opacity(0.55))

                Text(appViewModel.localized(
                    "announcement_empty_title",
                    fallback: "There are no active announcements."
                ))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppDesign.Spacing.xxxl)
            .padding(.horizontal, AppDesign.Spacing.xl)
        } else {
            LazyVStack(spacing: AppDesign.Spacing.md) {
                ForEach(sortedAnnouncements) { announcement in
                    announcementRow(announcement)
                }
            }
            .padding(AppDesign.Spacing.xl)
        }
    }

    private func announcementRow(_ announcement: HouseAnnouncementDTO) -> some View {
        let isRead = readAnnouncementIds.contains(announcement.id)

        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                Circle()
                    .fill(isRead ? HouseJourneyTheme.teal.opacity(0.45) : HouseJourneyTheme.accentOrange)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                Text(announcement.title)
                    .font(.system(size: 15, weight: isRead ? .semibold : .bold))
                    .foregroundStyle(isRead ? AppDesign.Colors.textSecondary : AppDesign.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(announcement.message)
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppDesign.Spacing.sm) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .medium))
                        Text(formattedTimestamp(announcement.createdOn))
                            .lineLimit(1)
                    }

                    if let publisherName = publisherDisplayName(for: announcement) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                            Text(appViewModel.localized(
                                "announcement_published_by_template",
                                fallback: "Published by {name}"
                            ).replacingOccurrences(of: "{name}", with: publisherName))
                                .lineLimit(1)
                        }
                        .foregroundStyle(HouseJourneyTheme.deepIndigo)
                    }
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                Button {
                    toggleRead(announcement.id)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(appViewModel.localized(
                            isRead ? "announcement_read_label" : "announcement_mark_read_button",
                            fallback: isRead ? "Read" : "Mark as read"
                        ))
                            .lineLimit(1)
                    }
                    .font(AppDesign.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isRead ? HouseJourneyTheme.deepTeal : HouseJourneyTheme.indigo)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                isRead
                                    ? HouseJourneyTheme.teal.opacity(0.12)
                                    : HouseJourneyTheme.indigo.opacity(0.10)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .font(AppDesign.Typography.caption)
            .foregroundStyle(AppDesign.Colors.textTertiary)
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(
                    isRead
                        ? AppDesign.Colors.background.opacity(0.68)
                        : HouseJourneyTheme.indigo.opacity(0.055)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .strokeBorder(
                    isRead
                        ? HouseJourneyTheme.teal.opacity(0.10)
                        : HouseJourneyTheme.indigo.opacity(0.18),
                    lineWidth: 1
                )
        )
    }

    private var headerSubtitle: String {
        guard !activeAnnouncements.isEmpty else {
            return appViewModel.localized(
                "announcement_empty_title",
                fallback: "There are no active announcements."
            )
        }

        return appViewModel.localized(
            "announcement_count_template",
            fallback: "{count} active announcements"
        )
        .replacingOccurrences(of: "{count}", with: "\(activeAnnouncements.count)")
    }

    private var storageNamespace: String {
        "\(readerId ?? "anonymous"):\(houseId)"
    }

    private func formattedTimestamp(_ value: String) -> String {
        guard let date = HouseFlowDateFormatter.parseAPIDate(value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func publisherDisplayName(for announcement: HouseAnnouncementDTO) -> String? {
        if let publisherName = announcement.publisherName,
           !publisherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return publisherName
        }

        guard let publisherId = announcement.publisherId else { return nil }
        return members.first(where: { $0.id == publisherId })?.fullName
    }

    private func toggleRead(_ announcementId: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if readAnnouncementIds.contains(announcementId) {
            readAnnouncementIds.remove(announcementId)
        } else {
            readAnnouncementIds.insert(announcementId)
        }

        AnnouncementReadStore.save(
            readAnnouncementIds,
            houseId: houseId,
            readerId: readerId
        )
    }
}

private enum AnnouncementReadStore {
    private static let keyPrefix = "houseflow.read-announcements"

    static func load(houseId: String, readerId: String?) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(houseId: houseId, readerId: readerId)) ?? [])
    }

    static func save(_ ids: Set<String>, houseId: String, readerId: String?) {
        UserDefaults.standard.set(
            Array(ids).sorted(),
            forKey: key(houseId: houseId, readerId: readerId)
        )
    }

    private static func key(houseId: String, readerId: String?) -> String {
        "\(keyPrefix).\(readerId ?? "anonymous").\(houseId)"
    }
}

#Preview {
    AnnouncementCard(
        houseId: "preview-house",
        readerId: "preview-user",
        announcements: [
            HouseAnnouncementDTO(
                id: "1",
                title: "Kitchen maintenance",
                message: "The kitchen sink will be unavailable tomorrow morning.",
                createdOn: HouseFlowDateFormatter.apiString(from: Date()),
                publisherId: "preview-user"
            ),
            HouseAnnouncementDTO(
                id: "2",
                title: "Monthly meeting",
                message: "Let’s meet on Sunday to plan next month’s chores.",
                createdOn: HouseFlowDateFormatter.apiString(from: Date().addingTimeInterval(-86_400))
            )
        ],
        members: [
            HouseMemberDTO(
                id: "preview-user",
                firstName: "Alex",
                lastName: "Morgan",
                email: "alex@example.com",
                imageUrl: "",
                isActive: true,
                isVerifyEmail: true,
                isVerifyPhone: false,
                phoneNumber: "",
                birthDate: nil,
                houseIds: ["preview-house"],
                createdOn: "",
                updatedOn: "",
                lastLogin: ""
            )
        ]
    )
    .environmentObject(AppViewModel())
    .padding()
}
