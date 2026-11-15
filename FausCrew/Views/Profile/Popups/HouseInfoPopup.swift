import SwiftUI
import FausCrewCore

struct HouseInfoPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let house: AuthHouseSummary
    let onDismiss: () -> Void

    @State private var draft: HouseInfoDraft?
    @State private var availableImages: [UserImageData] = []
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

    private let houseTint = HouseInfoStyle.houseTint
    private let ownerTint = HouseInfoStyle.ownerTint

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppDesign.Colors.scrim
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
            await loadHouseInfo()
        }
    }

    private var popupContent: some View {
        FausPopupShell(
            watermark: Image(systemName: "house.fill"),
            watermarkOffset: 85,
            title: appViewModel.localized("house_info_title", fallback: "House Information"),
            subtitle: headerSubtitle,
            isCloseDisabled: isBusy,
            onClose: requestDismiss,
            badge: Image(systemName: "house.fill")
                .font(.system(size: 15, weight: .semibold))
        ) {
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
        } footer: {
            footer
        }
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

                if isOwner, let editableDraft = Binding($draft) {
                    HouseInfoOwnerEditor(
                        draft: editableDraft,
                        isNameFocused: $isNameFocused,
                        isBusy: isBusy
                    )
                    HouseInfoImagePicker(
                        selection: editableDraft.profileImageURL,
                        choices: imageChoices,
                        isLoading: isLoadingImages,
                        loadError: imageLoadError,
                        onRetry: { Task { await loadImages() } }
                    )

                    if let operationError {
                        errorBanner(operationError)
                    }
                } else {
                    viewerDetails(info)
                }

                HouseInfoMembersSection(
                    members: info.houseMembers,
                    removingMemberId: removingMemberId,
                    isBusy: isBusy,
                    canRemove: canRemove,
                    onRemove: { pendingRemoval = $0 }
                )

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

    private func viewerDetails(_ info: HouseInfoData) -> some View {
        VStack(spacing: 0) {
            readOnlyRow(
                icon: "person.2.fill",
                label: appViewModel.localized("house_info_members_label", fallback: "Members"),
                value: memberCountText(info)
            )
            Divider().overlay(AppDesign.Colors.separator).padding(.leading, 50)
            readOnlyRow(
                icon: houseTypeIcon(info.houseType),
                label: appViewModel.localized("house_info_type_label", fallback: "House type"),
                value: houseTypeLabel(info.houseType)
            )
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
            Divider().overlay(AppDesign.Colors.separator)
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
                    colors: [AppDesign.Colors.textTertiary.opacity(0.42), AppDesign.Colors.textTertiary.opacity(0.32)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private var info: HouseInfoData? {
        draft?.info
    }

    private var isOwner: Bool {
        info?.isOwner(userId: appViewModel.currentUserId) == true
    }

    private var isBusy: Bool {
        isSaving || isLeavingHouse || removingMemberId != nil
    }

    private var canLeaveHouse: Bool {
        draft?.canLeave(currentUserId: appViewModel.currentUserId) == true
    }

    private var canSave: Bool {
        isDraftReadyToSave && !isBusy
    }

    private var isDraftReadyToSave: Bool {
        draft?.isReadyToSave(currentUserId: appViewModel.currentUserId) == true
    }

    private var imageChoices: [String] {
        draft?.imageChoices(available: availableImages.map(\.fileURL)) ?? []
    }

    private func canRemove(_ member: HouseInfoMember) -> Bool {
        draft?.canRemove(member, currentUserId: appViewModel.currentUserId) == true
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
        guard let houseType = HouseTypeCard.HouseType(apiValue: type) else {
            return appViewModel.localized("house_info_type_unknown", fallback: "House")
        }
        return appViewModel.localized(houseType.localizationKey, fallback: houseType.rawValue)
    }

    private func houseTypeIcon(_ type: Int) -> String {
        HouseTypeCard.HouseType(apiValue: type)?.iconName ?? "house.fill"
    }

    @MainActor
    private func loadHouseInfo() async {
        isLoading = true
        loadError = nil
        operationError = nil
        do {
            let loadedInfo = try await appViewModel.fetchHouseInfo(houseId: house.houseId)
            draft = HouseInfoDraft(info: loadedInfo, summaryImageURL: house.houseProfile)
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
        guard isDraftReadyToSave, !isBusy else { return }

        // Capture the draft before entering the loading state. The overview
        // intentionally continues to render the last committed info.
        guard let submitted = draft else { return }

        isNameFocused = false
        isSaving = true
        operationError = nil
        do {
            let updatedInfo = try await appViewModel.updateHouseProfile(
                houseId: house.houseId,
                name: submitted.normalizedName,
                memberCountLimit: submitted.memberCountLimit,
                profileImage: submitted.profileImageURL,
                houseType: submitted.info.houseType,
                isChoreReviewPhotoRequired: submitted.isChoreReviewPhotoRequired
            )
            draft = HouseInfoDraft(info: updatedInfo, summaryImageURL: house.houseProfile)
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
                draft?.replaceInfo(refreshedInfo)
            } else if let remainingInfo = info?.removingMember(userId: member.userId) {
                draft?.replaceInfo(remainingInfo)
            }
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

    private func requestDismiss() {
        guard !isBusy else { return }
        isNameFocused = false
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
