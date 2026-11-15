import FausCrewCore
import SwiftUI

/// The member list of `HouseInfoPopup`. The owner gets a remove button on every other member.
struct HouseInfoMembersSection: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let members: [HouseInfoMember]
    let removingMemberId: String?
    let isBusy: Bool
    let canRemove: (HouseInfoMember) -> Bool
    let onRemove: (HouseInfoMember) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HouseInfoSectionTitle(
                title: appViewModel.localized("house_info_members_title", fallback: "Members"),
                icon: "person.2.fill"
            )

            VStack(spacing: 0) {
                ForEach(members) { member in
                    memberRow(member)
                    if member.id != members.last?.id {
                        Divider().overlay(AppDesign.Colors.separator).padding(.leading, 62)
                    }
                }
            }
            .background(AppDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        }
    }

    private func memberRow(_ member: HouseInfoMember) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            memberAvatar(member)

            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(AppDesign.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                    .lineLimit(1)

                if member.isOwner {
                    Label(
                        appViewModel.localized("house_info_owner_badge", fallback: "Owner"),
                        systemImage: "crown.fill"
                    )
                    .font(AppDesign.Typography.caption2.weight(.bold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                } else if member.userId == appViewModel.currentUserId {
                    Text(appViewModel.localized("common_you", fallback: "You"))
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                }
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            if canRemove(member) {
                Button {
                    onRemove(member)
                } label: {
                    Group {
                        if removingMemberId == member.userId {
                            ProgressView()
                                .tint(AppDesign.Colors.error)
                        } else {
                            Image(systemName: "person.fill.xmark")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(AppDesign.Colors.error)
                    .frame(width: 40, height: 40)
                    .background(AppDesign.Colors.error.opacity(0.10))
                    .clipShape(Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel(
                    appViewModel.localized(
                        "house_info_remove_member_button",
                        fallback: "Remove member"
                    )
                )
            }
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .padding(.vertical, 10)
    }

    private func memberAvatar(_ member: HouseInfoMember) -> some View {
        Group {
            let trimmedURL = member.profileImage.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedURL.isEmpty, let url = URL(string: trimmedURL) {
                CachedRemoteImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    memberPlaceholder(member)
                } failure: {
                    memberPlaceholder(member)
                }
            } else {
                memberPlaceholder(member)
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(Circle())
    }

    private func memberPlaceholder(_ member: HouseInfoMember) -> some View {
        Circle()
            .fill(HouseInfoStyle.houseTint.opacity(0.12))
            .overlay {
                Text(memberInitials(member.name))
                    .font(AppDesign.Typography.caption.weight(.bold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
            }
    }

    private func memberInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
