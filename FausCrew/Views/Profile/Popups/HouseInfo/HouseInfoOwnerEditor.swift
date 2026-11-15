import FausCrewCore
import SwiftUI

/// Owner-only fields of `HouseInfoPopup`: name, member limit and the review-photo switch.
struct HouseInfoOwnerEditor: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @Binding var draft: HouseInfoDraft
    var isNameFocused: FocusState<Bool>.Binding
    let isBusy: Bool

    private let houseTint = HouseInfoStyle.houseTint

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HouseInfoSectionTitle(
                title: appViewModel.localized(
                    "house_info_edit_details_title",
                    fallback: "House details"
                ),
                icon: "slider.horizontal.3"
            )

            nameField
            memberLimitRow
            reviewPhotoToggle
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Text(appViewModel.localized("house_info_name_label", fallback: "House name"))
                .font(AppDesign.Typography.caption.weight(.semibold))
                .foregroundStyle(AppDesign.Colors.textSecondary)

            TextField(
                appViewModel.localized("house_info_name_placeholder", fallback: "House name"),
                text: $draft.name
            )
            .font(AppDesign.Typography.body)
            .focused(isNameFocused)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit { isNameFocused.wrappedValue = false }
            .onChange(of: draft.name) { _, value in
                if value.count > HouseCreationRules.nameMaxLength {
                    draft.name = HouseCreationRules.limitedName(value)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.md)
            .padding(.vertical, AppDesign.Spacing.md)
            .frame(minHeight: 48)
            .background(AppDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .strokeBorder(
                        houseTint.opacity(isNameFocused.wrappedValue ? 0.65 : 0.16),
                        lineWidth: isNameFocused.wrappedValue ? 1.5 : 1
                    )
            }
        }
    }

    private var memberLimitRow: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    appViewModel.localized(
                        "house_info_member_limit_label",
                        fallback: "Member limit"
                    )
                )
                .font(AppDesign.Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppDesign.Colors.textPrimary)

                Text(memberLimitHint)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 12) {
                limitButton(icon: "minus", isEnabled: draft.memberCountLimit > draft.minimumMemberLimit) {
                    draft.memberCountLimit -= 1
                }

                Text("\(draft.memberCountLimit)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                    .frame(minWidth: 22)

                limitButton(icon: "plus", isEnabled: draft.memberCountLimit < draft.maximumMemberLimit) {
                    draft.memberCountLimit += 1
                }
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }

    private var reviewPhotoToggle: some View {
        Toggle(isOn: $draft.isChoreReviewPhotoRequired) {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    appViewModel.localized(
                        "house_info_review_photo_label",
                        fallback: "Review photo required"
                    )
                )
                .font(AppDesign.Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppDesign.Colors.textPrimary)

                Text(
                    appViewModel.localized(
                        "house_info_review_photo_hint",
                        fallback: "Chores need a photo before they go to review."
                    )
                )
                .font(AppDesign.Typography.caption)
                .foregroundStyle(AppDesign.Colors.textSecondary)
            }
        }
        .tint(houseTint)
        .disabled(isBusy)
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }

    private var memberLimitHint: String {
        "\(draft.info.houseMemberCount) "
            + appViewModel.localized("house_info_members_current", fallback: "members currently")
    }

    private func limitButton(icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isEnabled ? houseTint : AppDesign.Colors.textTertiary)
                .frame(width: 34, height: 34)
                .background((isEnabled ? houseTint : AppDesign.Colors.textTertiary).opacity(0.11))
                .clipShape(Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Owner-only picker for the house profile image.
struct HouseInfoImagePicker: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @Binding var selection: String
    let choices: [String]
    let isLoading: Bool
    let loadError: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HouseInfoSectionTitle(
                title: appViewModel.localized(
                    "house_info_profile_image_title",
                    fallback: "House profile image"
                ),
                icon: "photo.on.rectangle.angled"
            )

            if isLoading {
                ProgressView()
                    .tint(HouseInfoStyle.ownerTint)
                    .frame(maxWidth: .infinity, minHeight: 86)
            } else if choices.isEmpty {
                Text(
                    appViewModel.localized(
                        "house_info_images_empty",
                        fallback: "No house images are available."
                    )
                )
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: AppDesign.Spacing.md) {
                        ForEach(Array(choices.enumerated()), id: \.element) { index, imageURL in
                            imageChoice(imageURL, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let loadError {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(loadError)
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.error)
                        .lineLimit(2)
                    Spacer()
                    Button(appViewModel.localized("common_retry", fallback: "Retry"), action: onRetry)
                    .font(AppDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                }
            }
        }
    }

    private func imageChoice(_ imageURL: String, index: Int) -> some View {
        let isSelected = selection == imageURL
        let optionLabel = appViewModel.localized(
            "house_info_profile_image_option",
            fallback: "House profile image"
        )
        return Button {
            withAnimation(AppDesign.Animation.spring) {
                selection = imageURL
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                HouseProfileThumbnail(imageURLString: imageURL, size: 76, cornerRadius: 20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isSelected ? HouseInfoStyle.ownerTint : Color.clear, lineWidth: 3)
                    }
                    .scaleEffect(isSelected ? 1.04 : 1)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(HouseInfoStyle.ownerTint)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(optionLabel) \(index + 1)")
        .accessibilityValue(
            appViewModel.localized(
                isSelected ? "common_selected" : "common_not_selected",
                fallback: isSelected ? "Selected" : "Not selected"
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
