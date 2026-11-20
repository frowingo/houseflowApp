import SwiftUI
import FausCrewCore

private let accentOrange = HouseJourneyTheme.accentOrange

/// Premium chore detail sheet.
/// - Shows full status pipeline (Draft → Progress → InTest → Completed).
/// - Status progression is available to the assignee.
/// - Review voting is available to the other house members.
struct ChoreDetailPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.displayScale) private var displayScale

    let chore: Chore
    let onDismiss: () -> Void

    @State private var isUpdating: Bool = false
    @State private var isReviewing: Bool = false
    @State private var expandedReviewRounds: Set<Int> = []
    @State private var isShowingReviewCamera = false
    @State private var reviewPhotoData: Data?
    @State private var reviewPhotoPreview: UIImage?
    @State private var isPreparingReviewPhoto = false
    /// Decoded images only; signed URLs are never kept in view state.
    @State private var reviewPhotos: [Int: UIImage] = [:]
    @State private var loadingReviewPhotoRound: Int?
    @State private var viewedReviewPhoto: ViewedReviewPhoto?

    init(chore: Chore, onDismiss: @escaping () -> Void) {
        self.chore = chore
        self.onDismiss = onDismiss
    }

    private var isAssignedToCurrentUser: Bool {
        guard let uid = appViewModel.currentUserId,
              let aid = displayedChore.assignedToId else { return false }
        return uid == aid
    }

    private var isBusy: Bool {
        isUpdating || isReviewing
    }

    private var displayedChore: Chore {
        guard let choreApiId = chore.choreApiId else { return chore }
        return appViewModel.dashboardChores.first(where: { $0.choreApiId == choreApiId }) ?? chore
    }

    private var currentStatus: ChoreStatus {
        displayedChore.choreStatus
    }

    /// Nil once the chore leaves the active flow (Completed, Failed, unknown): a refetch that
    /// turns the open chore Failed leaves this sheet read-only.
    private var nextStatus: ChoreStatus? {
        guard isAssignedToCurrentUser else { return nil }
        return currentStatus.nextAssigneeStatus
    }

    private var requiresReviewPhoto: Bool {
        guard let nextStatus else { return false }
        return ChoreReviewPhotoRules.requiresPhoto(
            isChoreReviewPhotoRequired: appViewModel.isChoreReviewPhotoRequired(houseId: displayedChore.houseId),
            targetStatus: nextStatus
        )
    }

    private var canSaveStatus: Bool {
        !isBusy && !isPreparingReviewPhoto && (!requiresReviewPhoto || reviewPhotoData != nil)
    }

    private var reviewSummary: ChoreReviewSummary {
        ChoreReviewSummary(
            status: currentStatus,
            reviewRound: displayedChore.reviewRound,
            votes: displayedChore.reviewVotes,
            assigneeId: displayedChore.assignedToId,
            memberIds: appViewModel.dashboardMembers.compactMap(\.apiId),
            currentUserId: appViewModel.currentUserId
        )
    }

    var body: some View {
        ZStack {
            AppDesign.Colors.scrim
                .ignoresSafeArea()
                .onTapGesture { if !isBusy { requestDismiss() } }

            FausPopupShell(
                watermark: Image(systemName: "house.fill"),
                title: displayedChore.title,
                subtitle: appViewModel.localized(choreLevelObj.localizationKey),
                isCloseDisabled: isBusy,
                onClose: requestDismiss,
                badge: Image(systemName: choreLevelObj.iconName)
                    .font(.system(size: 15, weight: .semibold))
            ) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        if currentStatus == .failed {
                            failedStatusCard
                        } else {
                            statusPipeline
                        }
                        infoSection
                        if nextStatus != nil {
                            statusUpdateSection
                        }
                        if !reviewSummary.rounds.isEmpty {
                            reviewSection
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xl)
                }
                .frame(maxHeight: 500)
                .clipped()
            } footer: {
                dismissButton
            }
            .padding(.horizontal, AppDesign.Spacing.xl)

            if isBusy {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: AppDesign.Spacing.lg) {
                    ProgressView().scaleEffect(1.4).tint(.white)
                    Text(appViewModel.localized(isReviewing ? "chore_detail_submitting_vote" : "chore_detail_updating"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .animation(AppDesign.Animation.standard, value: isBusy)
        // A refetch can end the active flow (e.g. the backend marks the chore Failed): drop the
        // half-done review photo so the sheet is read-only.
        .onChange(of: currentStatus.acceptsActions) { _, acceptsActions in
            guard !acceptsActions else { return }
            isShowingReviewCamera = false
            reviewPhotoData = nil
            reviewPhotoPreview = nil
        }
        .fullScreenCover(isPresented: $isShowingReviewCamera) {
            ChoreReviewCamera(
                onCapture: { image in
                    isShowingReviewCamera = false
                    prepareReviewPhoto(image)
                },
                onCancel: { isShowingReviewCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewedReviewPhoto) { photo in
            ChoreReviewPhotoViewer(
                image: photo.image,
                closeLabel: appViewModel.localized("common_close"),
                blockedTitle: appViewModel.localized(
                    "chore_review_photo_capture_blocked_title",
                    fallback: "Screenshots aren't allowed"
                ),
                blockedMessage: appViewModel.localized(
                    "chore_review_photo_capture_blocked_message",
                    fallback: "Review photos are protected and can't be captured."
                ),
                onClose: { viewedReviewPhoto = nil },
                onCaptureAttempt: closeReviewPhotoAfterCaptureAttempt
            )
        }
    }

    // MARK: - Status Pipeline

    private var statusPipeline: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(icon: "arrow.triangle.2.circlepath", text: appViewModel.localized("chore_detail_status_label"))
            HStack(spacing: 0) {
                ForEach(Array(ChoreStatus.pipeline.enumerated()), id: \.offset) { index, step in
                    // An unknown status marks no step as current or past.
                    let isCurrent = step == currentStatus
                    let isPast    = currentStatus != .unknown && step.rawValue < currentStatus.rawValue

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? accentOrange : (isPast ? accentOrange.opacity(0.3) : AppDesign.Colors.secondaryBackground))
                                .frame(width: 32, height: 32)
                            Image(systemName: isPast ? "checkmark" : step.iconName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isCurrent ? .white : (isPast ? accentOrange : AppDesign.Colors.textSecondary))
                        }
                        Text(appViewModel.statusLabel(step))
                            .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? accentOrange : AppDesign.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 60)
                    }

                    if index < ChoreStatus.pipeline.count - 1 {
                        Rectangle()
                            .fill(isPast ? accentOrange.opacity(0.4) : AppDesign.Colors.secondaryBackground)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -10)
                    }
                }
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(accentOrange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Failed Status

    /// Failed is terminal, so it replaces the pipeline with the outcome and, when the status
    /// history proves it, the reason.
    private var failedStatusCard: some View {
        let color = ChoreStatus.failed.color
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(icon: "arrow.triangle.2.circlepath", text: appViewModel.localized("chore_detail_status_label"))
            HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                Image(systemName: ChoreStatus.failed.iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(appViewModel.statusLabel(.failed))
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundColor(color)
                    Text(appViewModel.failureMessage(displayedChore.failureReason))
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            // Title + description
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                HStack(alignment: .center, spacing: AppDesign.Spacing.sm) {
                    sectionLabel(icon: "text.badge.checkmark", text: appViewModel.localized("chore_detail_task_label"))
                    Spacer(minLength: AppDesign.Spacing.sm)
                    ChoreCategoryTag(kind: displayedChore.categoryKind, style: .pill)
                }
                Text(displayedChore.title)
                    .font(AppDesign.Typography.title3)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                if !displayedChore.description.isEmpty {
                    Text(displayedChore.description)
                        .font(AppDesign.Typography.body)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                    .fill(AppDesign.Colors.secondaryBackground)
            )

            // Meta row
            HStack(spacing: AppDesign.Spacing.md) {
                // Assignee
                infoTile(icon: "person.fill", label: appViewModel.localized("chore_detail_assigned_to_label")) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        UserAvatar(user: displayedChore.assignedTo, size: 28)
                        Text(displayedChore.assignedTo.firstName)
                            .font(AppDesign.Typography.bodyBold)
                            .foregroundColor(AppDesign.Colors.textPrimary)
                    }
                }

                // Due date
                infoTile(icon: "calendar", label: appViewModel.localized("chore_detail_due_label")) {
                    Text(formattedDueDate)
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundColor(dueColor)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(dueColor.opacity(0.12))
                        .cornerRadius(AppDesign.CornerRadius.sm)
                }
            }
        }
    }

    // MARK: - Status Update Section (assignee only)

    private var statusUpdateSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionLabel(icon: "pencil.circle.fill", text: appViewModel.localized("chore_detail_update_status_label"))
            Text(appViewModel.localized("chore_detail_update_status_description"))
                .font(AppDesign.Typography.caption)
                .foregroundColor(AppDesign.Colors.textSecondary)

            if let nextStatus {
                HStack(spacing: AppDesign.Spacing.md) {
                    statusStage(currentStatus)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppDesign.Colors.textSecondary)
                    statusStage(nextStatus)
                }

                if requiresReviewPhoto {
                    reviewPhotoPicker
                }

                Button(action: saveStatus) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        if isUpdating {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(appViewModel.localized(
                            "chore_detail_move_to_status_template",
                            replacements: [
                                "status": appViewModel.localized(nextStatus.localizationKey)
                            ]
                        ))
                            .font(AppDesign.Typography.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightSmall)
                    .background(
                        LinearGradient(
                            colors: [accentOrange, accentOrange.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppDesign.CornerRadius.md)
                    .opacity(canSaveStatus ? 1 : 0.5)
                }
                .disabled(!canSaveStatus)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(accentOrange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var reviewPhotoPicker: some View {
        Button(action: openReviewCamera) {
            HStack(spacing: AppDesign.Spacing.sm) {
                if isPreparingReviewPhoto {
                    ProgressView().scaleEffect(0.8)
                } else if let preview = reviewPhotoPreview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(appViewModel.localized(
                    reviewPhotoData == nil ? "chore_review_photo_add" : "chore_review_photo_change",
                    fallback: reviewPhotoData == nil ? "Add review photo" : "Change photo"
                ))
                .font(AppDesign.Typography.bodyBold)
            }
            .foregroundColor(accentOrange)
            .frame(maxWidth: .infinity)
            .frame(height: AppDesign.Size.buttonHeightSmall)
            .background(accentOrange.opacity(0.1))
            .cornerRadius(AppDesign.CornerRadius.md)
        }
        .disabled(isBusy || isPreparingReviewPhoto)
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionLabel(icon: "checkmark.seal.fill", text: appViewModel.localized("chore_detail_review_rounds_label"))

            ChoreReviewRoundList(
                summary: reviewSummary,
                members: appViewModel.dashboardMembers,
                assigneeId: displayedChore.assignedToId,
                isAssignedToCurrentUser: isAssignedToCurrentUser,
                photoRounds: displayedChore.reviewPhotoRounds,
                loadingPhotoRound: loadingReviewPhotoRound,
                accentColor: currentStatus.color,
                isBusy: isBusy,
                expandedRounds: $expandedReviewRounds,
                onShowPhoto: showReviewPhoto,
                onReview: submitReview
            )
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(currentStatus.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button { if !isBusy { requestDismiss() } } label: {
            Text(appViewModel.localized("common_close"))
                .font(AppDesign.Typography.headline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightSmall)
                .background(AppDesign.Colors.secondaryBackground)
                .cornerRadius(AppDesign.CornerRadius.md)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .background(AppDesign.Colors.popupBackground.shadow(color: AppDesign.Colors.shadow.opacity(0.06), radius: 8, x: 0, y: -4))
    }

    // MARK: - Helpers

    private func saveStatus() {
        guard let choreApiId = displayedChore.choreApiId,
              let houseId = displayedChore.houseId,
              let nextStatus,
              canSaveStatus else { return }
        let reviewPhoto = requiresReviewPhoto ? reviewPhotoData : nil
        isUpdating = true
        Task {
            let didUpdate = await appViewModel.updateChoreStatus(
                choreApiId: choreApiId,
                houseId: houseId,
                status: nextStatus,
                reviewPhoto: reviewPhoto
            )
            isUpdating = false
            if didUpdate {
                requestDismiss()
            }
        }
    }

    private func openReviewCamera() {
        guard ChoreReviewCamera.isAvailable else {
            appViewModel.showToast(message: appViewModel.localized(
                "chore_review_photo_camera_unavailable",
                fallback: "The camera is not available on this device."
            ))
            return
        }
        Task {
            if await ChoreReviewCamera.requestAccess() {
                isShowingReviewCamera = true
            } else {
                appViewModel.showToast(message: appViewModel.localized(
                    "chore_review_photo_camera_denied",
                    fallback: "Allow camera access in Settings to take a review photo."
                ))
            }
        }
    }

    private func prepareReviewPhoto(_ image: UIImage) {
        isPreparingReviewPhoto = true
        let previewScale = 28 * displayScale / max(min(image.size.width, image.size.height), 1)
        let previewSize = CGSize(
            width: (image.size.width * previewScale).rounded(.up),
            height: (image.size.height * previewScale).rounded(.up)
        )
        Task {
            defer { isPreparingReviewPhoto = false }
            let prepared = await Task.detached(priority: .userInitiated) {
                ChoreReviewPhotoEncoder.prepared(from: image)
            }.value
            if let prepared {
                let preview = await image.byPreparingThumbnail(ofSize: previewSize)
                guard currentStatus.acceptsActions else { return }
                reviewPhotoData = prepared
                reviewPhotoPreview = preview
            } else {
                appViewModel.showToast(message: appViewModel.localized(
                    "chore_review_photo_too_large",
                    fallback: "The photo must be 3 MB or smaller."
                ))
            }
        }
    }

    private func showReviewPhoto(round: Int) {
        if let image = reviewPhotos[round] {
            viewedReviewPhoto = ViewedReviewPhoto(round: round, image: image)
            return
        }
        guard let choreApiId = displayedChore.choreApiId, loadingReviewPhotoRound == nil else { return }
        loadingReviewPhotoRound = round
        Task {
            if let data = await appViewModel.loadChoreReviewPhoto(choreApiId: choreApiId, round: round) {
                if let image = UIImage(data: data) {
                    reviewPhotos[round] = image
                    viewedReviewPhoto = ViewedReviewPhoto(round: round, image: image)
                } else {
                    appViewModel.showToast(message: appViewModel.localized(
                        "chore_review_photo_load_failed",
                        fallback: "The review photo could not be loaded."
                    ))
                }
            }
            loadingReviewPhotoRound = nil
        }
    }

    private func closeReviewPhotoAfterCaptureAttempt() {
        guard viewedReviewPhoto != nil else { return }
        viewedReviewPhoto = nil
        appViewModel.showToast(message: appViewModel.localized(
            "chore_review_photo_capture_blocked",
            fallback: "Screenshots and screen recordings are not allowed for review photos."
        ))
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }

    private func submitReview(isApproved: Bool) {
        guard let choreApiId = displayedChore.choreApiId, reviewSummary.canReview else { return }
        isReviewing = true
        Task {
            _ = await appViewModel.reviewChore(
                choreApiId: choreApiId,
                isApproved: isApproved
            )
            isReviewing = false
        }
    }

    private var formattedDueDate: String {
        guard let rawDate = displayedChore.dueDate else { return appViewModel.localizedDueLabel(displayedChore.dueLabel) }
        let formatted = FausCrewDateFormatter.displayDate(from: rawDate)
        return formatted == "—" ? appViewModel.localizedDueLabel(displayedChore.dueLabel) : formatted
    }

    private var dueColor: Color {
        switch displayedChore.dueLabel {
        case "Overdue": return AppDesign.Colors.error
        case "Today":   return AppDesign.Colors.warning
        default:        return AppDesign.Colors.primary
        }
    }

    private var choreLevelObj: ChoreLevel {
        ChoreLevel(rawValue: displayedChore.level) ?? .easy
    }

    private func sectionLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(accentOrange)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func statusStage(_ status: ChoreStatus) -> some View {
        Label(appViewModel.statusLabel(status), systemImage: status.iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(status.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(status.color.opacity(0.1))
            .cornerRadius(AppDesign.CornerRadius.md)
    }

    @ViewBuilder
    private func infoTile<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Label(label, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppDesign.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
        )
    }
}

/// A decoded review photo open in the full-screen viewer.
private struct ViewedReviewPhoto: Identifiable {
    let round: Int
    let image: UIImage
    var id: Int { round }
}

// MARK: - ChoreStatus UI Helpers

extension ChoreStatus {
    var iconName: String {
        switch self {
        case .draft:     return "doc.fill"
        case .progress:  return "arrow.right.circle.fill"
        case .inTest:    return "magnifyingglass.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .failed:    return "xmark.octagon.fill"
        case .unknown:   return "questionmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .draft:     return Color.faus(\.statusDraft)
        case .progress:  return Color.faus(\.statusProgress)
        case .inTest:    return Color.faus(\.statusInTest)
        case .completed: return Color.faus(\.statusCompleted)
        case .failed:    return Color.faus(\.statusFailed)
        case .unknown:   return AppDesign.Colors.textTertiary
        }
    }
}

#if DEBUG
// MARK: - Preview

#Preview {
    ChoreDetailPopup(
        chore: Chore(
            choreApiId: "abc123",
            houseId: "house1",
            assignedToId: "user1",
            title: "Clean the kitchen",
            description: "Wipe down all surfaces and organize items",
            assignedTo: User(name: "John Doe", points: 12),
            dueLabel: "Today",
            status: 1,
            level: 20
        ),
        onDismiss: {}
    )
    .environmentObject(AppViewModel.preview)
}
#endif
