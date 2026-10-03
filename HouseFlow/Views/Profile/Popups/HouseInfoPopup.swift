import SwiftUI

struct HouseInfoPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let house: AuthHouseSummary
    let onDismiss: () -> Void

    @State private var info: HouseInfoData?
    @State private var availableImages: [UserImageData] = []
    @State private var houseName = ""
    @State private var memberCountLimit = 2
    @State private var selectedImageURL = ""
    @State private var isLoading = true
    @State private var isLoadingImages = false
    @State private var isSaving = false
    @State private var isLeavingHouse = false
    @State private var removingMemberId: String?
    @State private var pendingRemoval: HouseInfoMember?
    @State private var showLeaveConfirmation = false
    @State private var loadError: String?
    @State private var imageLoadError: String?
    @State private var operationError: String?
    @FocusState private var isNameFocused: Bool
    @AccessibilityFocusState private var headerAccessibilityFocused: Bool

    private let houseTint = Color(red: 0.42, green: 0.27, blue: 0.67)
    private let ownerTint = Color(red: 0.92, green: 0.47, blue: 0.18)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard !isBusy else { return }
                        requestDismiss()
                    }

                popupContent
                    .frame(maxWidth: 560)
                    .frame(height: max(0, min(proxy.size.height - 32, 720)))
                    .padding(.horizontal, AppDesign.Spacing.lg)
            }
        }
        .confirmationDialog(
            appViewModel.localized(
                "house_info_remove_confirmation_title",
                fallback: "Remove this member?"
            ),
            isPresented: removalConfirmationBinding,
            titleVisibility: .visible
        ) {
            if let member = pendingRemoval {
                Button(
                    appViewModel.localized(
                        "house_info_remove_member_button",
                        fallback: "Remove member"
                    ),
                    role: .destructive
                ) {
                    Task { await removeMember(member) }
                }
            }
            Button(appViewModel.localized("common_cancel", fallback: "Cancel"), role: .cancel) {
                pendingRemoval = nil
            }
        } message: {
            if let member = pendingRemoval {
                Text(member.name)
            }
        }
        .alert(
            appViewModel.localized(
                "house_info_leave_confirmation_title",
                fallback: "Leave this house?"
            ),
            isPresented: $showLeaveConfirmation
        ) {
            Button(
                appViewModel.localized(
                    "house_info_leave_button",
                    fallback: "Leave house"
                ),
                role: .destructive
            ) {
                Task { await leaveHouse() }
            }
            Button(appViewModel.localized("common_cancel", fallback: "Cancel"), role: .cancel) {}
        } message: {
            Text(
                appViewModel.localized(
                    "house_info_leave_confirmation_message",
                    fallback: "You will need a new invite code to join this house again."
                )
            )
        }
        .task(id: house.houseId) {
            headerAccessibilityFocused = true
            await loadHouseInfo()
        }
    }

    private var popupContent: some View {
        VStack(spacing: 0) {
            header

            Group {
                if isLoading {
                    loadingState
                } else if let loadError, info == nil {
                    errorState(message: loadError)
                } else if let info {
                    detailsContent(info)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .background(MainScreenBackground())
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        ZStack {
            BrandPopupHeaderBackground()

            Image(systemName: "house.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.12))
                .offset(x: 85)

            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: "house.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        appViewModel.localized(
                            "house_info_title",
                            fallback: "House Information"
                        )
                    )
                    .font(AppDesign.Typography.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .accessibilityFocused($headerAccessibilityFocused)

                    Text(headerSubtitle)
                        .font(AppDesign.Typography.caption2)
                        .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                Button(action: requestDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel(appViewModel.localized("common_close", fallback: "Close"))
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 64)
        .zIndex(1)
    }

    private var loadingState: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ProgressView()
                .tint(ownerTint)
                .scaleEffect(1.15)
            Text(
                appViewModel.localized(
                    "house_info_loading",
                    fallback: "Loading house information…"
                )
            )
            .font(AppDesign.Typography.subheadline)
            .foregroundStyle(AppDesign.Colors.textSecondary)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppDesign.Colors.error)
            Text(message)
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadHouseInfo() }
            } label: {
                Label(
                    appViewModel.localized("common_retry", fallback: "Try again"),
                    systemImage: "arrow.clockwise"
                )
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, AppDesign.Spacing.xl)
                .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(HouseJourneyTheme.primaryButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .buttonStyle(.plain)
        }
        .padding(AppDesign.Spacing.xl)
    }

    private func detailsContent(_ info: HouseInfoData) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
                overview(info)

                if isOwner {
                    ownerEditor(info)
                    imagePicker

                    if let operationError {
                        errorBanner(operationError)
                    }
                } else {
                    viewerDetails(info)
                }

                membersSection(info)

                if !isOwner, let operationError {
                    errorBanner(operationError)
                }

                if isOwner, info.houseMemberCount < info.houseMemberCountLimit {
                    HouseInviteCodeSection(
                        houseId: house.houseId,
                        houseName: info.houseName
                    )
                    .environmentObject(appViewModel)
                }
            }
            .padding(AppDesign.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func overview(_ info: HouseInfoData) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppDesign.Spacing.md))
            : AnyLayout(HStackLayout(spacing: AppDesign.Spacing.lg))

        return layout {
            HouseProfileThumbnail(
                imageURLString: info.houseProfileImage,
                size: 72,
                cornerRadius: 20
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(info.houseName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                    .lineLimit(2)

                Label(houseTypeLabel(info.houseType), systemImage: houseTypeIcon(info.houseType))
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(AppDesign.Colors.textSecondary)

                Text(memberCountText(info))
                    .font(AppDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }

            if isOwner {
                Label(
                    appViewModel.localized("house_info_owner_badge", fallback: "Owner"),
                    systemImage: "crown.fill"
                )
                .font(AppDesign.Typography.caption.weight(.bold))
                .foregroundStyle(AppDesign.Colors.textPrimary)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .padding(.vertical, 2)
                .background(ownerTint.opacity(0.11))
                .clipShape(Capsule())
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
    }

    private func ownerEditor(_ info: HouseInfoData) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle(
                appViewModel.localized(
                    "house_info_edit_details_title",
                    fallback: "House details"
                ),
                icon: "slider.horizontal.3"
            )

            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text(appViewModel.localized("house_info_name_label", fallback: "House name"))
                    .font(AppDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppDesign.Colors.textSecondary)

                TextField(
                    appViewModel.localized("house_info_name_placeholder", fallback: "House name"),
                    text: $houseName
                )
                .font(AppDesign.Typography.body)
                .focused($isNameFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { isNameFocused = false }
                .onChange(of: houseName) { _, value in
                    if value.count > 30 {
                        houseName = String(value.prefix(30))
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
                            houseTint.opacity(isNameFocused ? 0.65 : 0.16),
                            lineWidth: isNameFocused ? 1.5 : 1
                        )
                }
            }

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

                    Text(memberLimitHint(info))
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    limitButton(icon: "minus", isEnabled: memberCountLimit > minimumMemberLimit) {
                        memberCountLimit -= 1
                    }

                    Text("\(memberCountLimit)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                        .frame(minWidth: 22)

                    limitButton(icon: "plus", isEnabled: memberCountLimit < maximumMemberLimit) {
                        memberCountLimit += 1
                    }
                }
            }
            .padding(AppDesign.Spacing.md)
            .background(AppDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
    }

    private var imagePicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle(
                appViewModel.localized(
                    "house_info_profile_image_title",
                    fallback: "House profile image"
                ),
                icon: "photo.on.rectangle.angled"
            )

            if isLoadingImages {
                ProgressView()
                    .tint(ownerTint)
                    .frame(maxWidth: .infinity, minHeight: 86)
            } else if imageChoices.isEmpty {
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
                        ForEach(Array(imageChoices.enumerated()), id: \.element) { index, imageURL in
                            imageChoice(imageURL, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let imageLoadError {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(imageLoadError)
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.error)
                        .lineLimit(2)
                    Spacer()
                    Button(appViewModel.localized("common_retry", fallback: "Retry")) {
                        Task { await loadImages() }
                    }
                    .font(AppDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                }
            }
        }
    }

    private func viewerDetails(_ info: HouseInfoData) -> some View {
        VStack(spacing: 0) {
            readOnlyRow(
                icon: "person.2.fill",
                label: appViewModel.localized("house_info_members_label", fallback: "Members"),
                value: memberCountText(info)
            )
            Divider().padding(.leading, 50)
            readOnlyRow(
                icon: houseTypeIcon(info.houseType),
                label: appViewModel.localized("house_info_type_label", fallback: "House type"),
                value: houseTypeLabel(info.houseType)
            )
        }
    }

    private func membersSection(_ info: HouseInfoData) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle(
                appViewModel.localized("house_info_members_title", fallback: "Members"),
                icon: "person.2.fill"
            )

            VStack(spacing: 0) {
                ForEach(info.houseMembers) { member in
                    memberRow(member)
                    if member.id != info.houseMembers.last?.id {
                        Divider().padding(.leading, 62)
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
                    pendingRemoval = member
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
            .fill(houseTint.opacity(0.12))
            .overlay {
                Text(memberInitials(member.name))
                    .font(AppDesign.Typography.caption.weight(.bold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
            }
    }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AppDesign.Spacing.sm) {
                    footerActionButton
                    footerDismissButton
                }
            } else {
                HStack(spacing: AppDesign.Spacing.md) {
                    footerDismissButton
                    footerActionButton
                }
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(AppDesign.Colors.background)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var footerDismissButton: some View {
        Button(action: requestDismiss) {
            Text(
                appViewModel.localized(
                    isOwner ? "common_cancel" : "common_close",
                    fallback: isOwner ? "Cancel" : "Close"
                )
            )
            .font(AppDesign.Typography.headline)
            .foregroundStyle(AppDesign.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
            .padding(.vertical, AppDesign.Spacing.xs)
            .background(AppDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    @ViewBuilder
    private var footerActionButton: some View {
        if isOwner {
            Button {
                Task { await saveChanges() }
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    if isSaving {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(
                        appViewModel.localized(
                            isSaving ? "common_saving" : "common_save_changes",
                            fallback: isSaving ? "Saving…" : "Save changes"
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(saveButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        } else if canLeaveHouse {
            Button {
                showLeaveConfirmation = true
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    if isLeavingHouse {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    Text(
                        appViewModel.localized(
                            isLeavingHouse
                                ? "house_info_leaving"
                                : "house_info_leave_button",
                            fallback: isLeavingHouse ? "Leaving…" : "Leave house"
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(AppDesign.Colors.error)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppDesign.Typography.subheadline.weight(.bold))
            .foregroundStyle(AppDesign.Colors.textPrimary)
    }

    private func readOnlyRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(houseTint)
                .frame(width: 34, height: 34)
                .background(houseTint.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            Text(label)
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(AppDesign.Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppDesign.Colors.textSecondary)
        }
        .padding(.vertical, 11)
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

    private func imageChoice(_ imageURL: String, index: Int) -> some View {
        let isSelected = selectedImageURL == imageURL
        let optionLabel = appViewModel.localized(
            "house_info_profile_image_option",
            fallback: "House profile image"
        )
        return Button {
            withAnimation(AppDesign.Animation.spring) {
                selectedImageURL = imageURL
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                HouseProfileThumbnail(imageURLString: imageURL, size: 76, cornerRadius: 20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isSelected ? ownerTint : Color.clear, lineWidth: 3)
                    }
                    .scaleEffect(isSelected ? 1.04 : 1)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(ownerTint)
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

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(AppDesign.Typography.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppDesign.Colors.error)
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.error.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }

    private var saveButtonBackground: some View {
        Group {
            if canSave {
                HouseJourneyTheme.primaryButtonGradient
            } else {
                LinearGradient(
                    colors: [Color.gray.opacity(0.42), Color.gray.opacity(0.32)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private var isOwner: Bool {
        info?.isOwner(userId: appViewModel.currentUserId) == true
    }

    private var isBusy: Bool {
        isSaving || isLeavingHouse || removingMemberId != nil
    }

    private var canLeaveHouse: Bool {
        guard !isOwner, let userId = appViewModel.currentUserId else { return false }
        return info?.houseMembers.contains(where: { $0.userId == userId }) == true
    }

    private var canSave: Bool {
        isDraftReadyToSave && !isBusy
    }

    private var isDraftReadyToSave: Bool {
        isOwner && !normalizedHouseName.isEmpty && hasChanges
    }

    private var hasChanges: Bool {
        guard let info else { return false }
        return normalizedHouseName != info.houseName
            || memberCountLimit != info.houseMemberCountLimit
            || selectedImageURL != info.houseProfileImage
    }

    private var normalizedHouseName: String {
        houseName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var minimumMemberLimit: Int {
        max(2, info?.houseMemberCount ?? 2)
    }

    private var maximumMemberLimit: Int {
        max(8, minimumMemberLimit)
    }

    private var imageChoices: [String] {
        let candidates = [info?.houseProfileImage, house.houseProfile]
            .compactMap { $0 }
            + availableImages.map(\.fileURL)
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted else { return nil }
            return value
        }
    }

    private var ownerSubtitle: String {
        appViewModel.localized("house_info_owner_subtitle", fallback: "Manage details and members")
    }

    private var viewerSubtitle: String {
        appViewModel.localized("house_info_viewer_subtitle", fallback: "View house details")
    }

    private var headerSubtitle: String {
        if isLoading {
            return appViewModel.localized("common_loading", fallback: "Loading…")
        }
        return isOwner ? ownerSubtitle : viewerSubtitle
    }

    private var removalConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { isPresented in
                if !isPresented { pendingRemoval = nil }
            }
        )
    }

    private func memberCountText(_ info: HouseInfoData) -> String {
        "\(info.houseMemberCount) / \(info.houseMemberCountLimit) "
            + appViewModel.localized("house_info_members_label", fallback: "members")
    }

    private func memberLimitHint(_ info: HouseInfoData) -> String {
        "\(info.houseMemberCount) "
            + appViewModel.localized("house_info_members_current", fallback: "members currently")
    }

    private func houseTypeLabel(_ type: Int) -> String {
        switch type {
        case 1:
            return appViewModel.localized("create_house_type_student", fallback: "Student House")
        case 2:
            return appViewModel.localized("create_house_type_shared", fallback: "Shared House")
        case 3:
            return appViewModel.localized("create_house_type_dorm", fallback: "Dorm Room")
        default:
            return appViewModel.localized("house_info_type_unknown", fallback: "House")
        }
    }

    private func houseTypeIcon(_ type: Int) -> String {
        switch type {
        case 1: return "graduationcap.fill"
        case 2: return "house.fill"
        case 3: return "building.2.fill"
        default: return "house.fill"
        }
    }

    private func canRemove(_ member: HouseInfoMember) -> Bool {
        isOwner && !member.isOwner && member.userId != appViewModel.currentUserId
    }

    private func memberInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    @MainActor
    private func loadHouseInfo() async {
        isLoading = true
        loadError = nil
        operationError = nil
        do {
            let loadedInfo = try await appViewModel.fetchHouseInfo(houseId: house.houseId)
            info = loadedInfo
            applyDraft(from: loadedInfo)
            isLoading = false
            if loadedInfo.isOwner(userId: appViewModel.currentUserId) {
                await loadImages()
            }
        } catch {
            loadError = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
    private func loadImages() async {
        isLoadingImages = true
        imageLoadError = nil
        do {
            availableImages = try await appViewModel.fetchHouseProfileImages().data
        } catch {
            imageLoadError = error.localizedDescription
        }
        isLoadingImages = false
    }

    @MainActor
    private func saveChanges() async {
        guard isDraftReadyToSave, !isBusy, let info else { return }

        // Capture the editable fields before entering the loading state. The
        // overview intentionally continues to render the last committed info.
        let submittedName = normalizedHouseName
        let submittedMemberCountLimit = memberCountLimit
        let submittedImageURL = selectedImageURL
        let submittedHouseType = info.houseType

        isNameFocused = false
        isSaving = true
        operationError = nil
        do {
            let updatedInfo = try await appViewModel.updateHouseProfile(
                houseId: house.houseId,
                name: submittedName,
                memberCountLimit: submittedMemberCountLimit,
                profileImage: submittedImageURL,
                houseType: submittedHouseType
            )
            self.info = updatedInfo
            applyDraft(from: updatedInfo)
            isSaving = false
            appViewModel.showToast(
                message: appViewModel.localized(
                    "house_info_update_success",
                    fallback: "House information updated."
                ),
                isError: false
            )
            requestDismiss()
        } catch {
            operationError = error.localizedDescription
            isSaving = false
            appViewModel.showToast(message: error.localizedDescription, isError: true)
        }
    }

    @MainActor
    private func removeMember(_ member: HouseInfoMember) async {
        guard canRemove(member), removingMemberId == nil else { return }
        pendingRemoval = nil
        removingMemberId = member.userId
        operationError = nil
        do {
            try await appViewModel.removeHouseMember(
                houseId: house.houseId,
                userId: member.userId
            )
            if let refreshedInfo = try? await appViewModel.fetchHouseInfo(houseId: house.houseId) {
                info = refreshedInfo
            } else {
                info = info?.removingMember(userId: member.userId)
            }
            memberCountLimit = max(memberCountLimit, minimumMemberLimit)
        } catch {
            operationError = error.localizedDescription
        }
        removingMemberId = nil
    }

    @MainActor
    private func leaveHouse() async {
        guard canLeaveHouse, !isBusy else { return }
        isLeavingHouse = true
        operationError = nil
        do {
            try await appViewModel.leaveHouse(houseId: house.houseId)
            isLeavingHouse = false
            requestDismiss()
        } catch {
            operationError = error.localizedDescription
            isLeavingHouse = false
        }
    }

    private func applyDraft(from info: HouseInfoData) {
        houseName = info.houseName
        memberCountLimit = max(2, max(info.houseMemberCount, info.houseMemberCountLimit))
        selectedImageURL = info.houseProfileImage
    }

    private func requestDismiss() {
        guard !isBusy else { return }
        isNameFocused = false
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
