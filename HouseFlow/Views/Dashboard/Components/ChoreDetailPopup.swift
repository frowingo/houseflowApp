import SwiftUI

private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

/// Premium chore detail sheet.
/// - Shows full status pipeline (Draft → Progress → InTest → Completed).
/// - Status progression is available to the assignee.
/// - Review voting is available to the other house members.
struct ChoreDetailPopup: View {
    let chore: Chore
    let appViewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var isUpdating: Bool = false
    @State private var isReviewing: Bool = false
    @State private var expandedReviewRounds: Set<Int> = []

    init(chore: Chore, appViewModel: AppViewModel, onDismiss: @escaping () -> Void) {
        self.chore = chore
        self.appViewModel = appViewModel
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
        ChoreStatus(rawValue: displayedChore.status) ?? .draft
    }

    private var nextStatus: ChoreStatus? {
        guard isAssignedToCurrentUser else { return nil }
        switch currentStatus {
        case .draft: return .progress
        case .progress: return .inTest
        case .inTest, .completed: return nil
        }
    }

    private var currentRoundVotes: [ChoreReviewVote] {
        displayedChore.reviewVotes.filter { $0.reviewRound == displayedChore.reviewRound }
    }

    private var currentUserVote: ChoreReviewVote? {
        guard let currentUserId = appViewModel.currentUserId else { return nil }
        return currentRoundVotes.first { $0.reviewerId == currentUserId }
    }

    private var canReview: Bool {
        currentStatus == .inTest
            && !isAssignedToCurrentUser
            && appViewModel.currentUserId != nil
            && currentUserVote == nil
    }

    private var eligibleReviewerCount: Int {
        appViewModel.dashboardMembers.filter { $0.apiId != displayedChore.assignedToId }.count
    }

    private var reviewMembers: [User] {
        appViewModel.dashboardMembers
    }

    private var reviewRoundNumbers: [Int] {
        var rounds = Set(displayedChore.reviewVotes.map(\.reviewRound))
        if displayedChore.reviewRound > 0 {
            rounds.insert(displayedChore.reviewRound)
        }
        return rounds.sorted(by: >)
    }

    private var hasReviewRounds: Bool {
        !reviewRoundNumbers.isEmpty
    }

    private var activeReviewRound: Int? {
        currentStatus == .inTest && displayedChore.reviewRound > 0 ? displayedChore.reviewRound : nil
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isBusy { onDismiss() } }

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        statusPipeline
                        infoSection
                        if nextStatus != nil {
                            statusUpdateSection
                        }
                        if hasReviewRounds {
                            reviewSection
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xl)
                }
                .frame(maxHeight: 500)
                dismissButton
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)

            if isBusy {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: AppDesign.Spacing.lg) {
                    ProgressView().scaleEffect(1.4).tint(.white)
                    Text(isReviewing ? "Submitting vote..." : "Updating...")
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(.white)
                }
            }
        }
        .animation(AppDesign.Animation.standard, value: isBusy)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            LinearGradient(
                colors: [accentOrange, accentOrange.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
            // Background decorative icon
            Image(systemName: "house.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white.opacity(0.12))

            HStack(spacing: AppDesign.Spacing.sm) {
                // Level badge
                HStack(spacing: 4) {
                    Image(systemName: choreLevelObj.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(choreLevelObj.displayName)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(choreLevelObj.color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.92))
                .cornerRadius(AppDesign.CornerRadius.circle)

                Text(displayedChore.title)
                    .font(AppDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, 12)
        }
        .frame(height: 52)
    }

    // MARK: - Status Pipeline

    private var statusPipeline: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(icon: "arrow.triangle.2.circlepath", text: "Status")
            HStack(spacing: 0) {
                ForEach(Array([ChoreStatus.draft, .progress, .inTest, .completed].enumerated()), id: \.offset) { index, step in
                    let isCurrent = step.rawValue == displayedChore.status
                    let isPast    = step.rawValue < displayedChore.status

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? accentOrange : (isPast ? accentOrange.opacity(0.3) : AppDesign.Colors.secondaryBackground))
                                .frame(width: 32, height: 32)
                            Image(systemName: isPast ? "checkmark" : step.iconName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isCurrent ? .white : (isPast ? accentOrange : AppDesign.Colors.textSecondary))
                        }
                        Text(step.displayName)
                            .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? accentOrange : AppDesign.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 60)
                    }

                    if index < 3 {
                        Rectangle()
                            .fill(step.rawValue < displayedChore.status ? accentOrange.opacity(0.4) : AppDesign.Colors.secondaryBackground)
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

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            // Title + description
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                sectionLabel(icon: "text.badge.checkmark", text: "Task")
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
                infoTile(icon: "person.fill", label: "Assigned To") {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        UserAvatar(user: displayedChore.assignedTo, size: 28)
                        Text(displayedChore.assignedTo.firstName)
                            .font(AppDesign.Typography.bodyBold)
                            .foregroundColor(AppDesign.Colors.textPrimary)
                    }
                }

                // Due date
                infoTile(icon: "calendar", label: "Due") {
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
            sectionLabel(icon: "pencil.circle.fill", text: "Update Status")
            Text("Move this chore to its next allowed stage.")
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

                Button(action: saveStatus) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        if isUpdating {
                            ProgressView().scaleEffect(0.8).tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text("Move to \(nextStatus.displayName)")
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
                }
                .disabled(isBusy)
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

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionLabel(icon: "checkmark.seal.fill", text: "Review Rounds")

            ForEach(reviewRoundNumbers, id: \.self) { round in
                reviewRoundCard(round)
            }
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

    private func reviewRoundCard(_ round: Int) -> some View {
        let isActive = activeReviewRound == round
        let isExpanded = isActive || expandedReviewRounds.contains(round)

        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Button {
                guard !isActive else { return }
                withAnimation(AppDesign.Animation.quick) {
                    if expandedReviewRounds.contains(round) {
                        expandedReviewRounds.remove(round)
                    } else {
                        expandedReviewRounds.insert(round)
                    }
                }
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Round \(round)")
                                .font(AppDesign.Typography.bodyBold)
                            Text(isActive ? "Active" : "Resulted")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isActive ? .white : AppDesign.Colors.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(isActive ? currentStatus.color : AppDesign.Colors.textSecondary.opacity(0.14))
                                .cornerRadius(AppDesign.CornerRadius.circle)
                        }
                        Text("\(approvedVoteCount(for: round)) of \(eligibleReviewerCount) approved")
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                    }

                    Spacer()

                    if !isActive {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppDesign.Colors.textSecondary)
                    }
                }
                .foregroundColor(AppDesign.Colors.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                reviewProgressBar(for: round)
                reviewSummaryRow(for: round)
                reviewMemberList(for: round)

                if isActive {
                    reviewActionArea
                }
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.background.opacity(0.68))
        .cornerRadius(AppDesign.CornerRadius.md)
    }

    private var reviewActionArea: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            if isAssignedToCurrentUser {
                Label("Assigned users cannot vote on their own chore.", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(AppDesign.Colors.textSecondary)
            } else if let vote = currentUserVote {
                Label(
                    vote.isApproved ? "You approved this chore." : "You rejected this chore.",
                    systemImage: vote.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(AppDesign.Typography.bodyBold)
                .foregroundColor(vote.isApproved ? AppDesign.Colors.success : AppDesign.Colors.error)
            } else if canReview {
                Text("Approve the completed work or send it back for another attempt.")
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(AppDesign.Colors.textSecondary)

                HStack(spacing: AppDesign.Spacing.md) {
                    reviewButton(
                        title: "Reject",
                        icon: "xmark.circle.fill",
                        color: AppDesign.Colors.error,
                        isApproved: false
                    )
                    reviewButton(
                        title: "Approve",
                        icon: "checkmark.circle.fill",
                        color: AppDesign.Colors.success,
                        isApproved: true
                    )
                }
            }
        }
    }

    private func reviewProgressBar(for round: Int) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let approvedWidth = width * CGFloat(eligibleReviewerCount == 0 ? 0 : Double(approvedVoteCount(for: round)) / Double(eligibleReviewerCount))
            let rejectedWidth = width * CGFloat(eligibleReviewerCount == 0 ? 0 : Double(rejectedVoteCount(for: round)) / Double(eligibleReviewerCount))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.circle)
                    .fill(AppDesign.Colors.textSecondary.opacity(0.16))

                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.circle)
                    .fill(AppDesign.Colors.success)
                    .frame(width: approvedWidth)

                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.circle)
                    .fill(AppDesign.Colors.error)
                    .frame(width: rejectedWidth)
                    .offset(x: approvedWidth)

                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.circle)
                    .stroke(AppDesign.Colors.textSecondary.opacity(0.18), lineWidth: 1)
            }
        }
        .frame(height: 10)
        .accessibilityLabel("Review progress")
        .accessibilityValue("\(Int(reviewCompletionRatio(for: round) * 100)) percent voted")
    }

    private func reviewSummaryRow(for round: Int) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            reviewSummaryPill(title: "Approved", count: approvedVoteCount(for: round), color: AppDesign.Colors.success)
            reviewSummaryPill(title: "Rejected", count: rejectedVoteCount(for: round), color: AppDesign.Colors.error)
            reviewSummaryPill(title: "Waiting", count: pendingVoteCount(for: round), color: AppDesign.Colors.textSecondary)
        }
    }

    private func reviewMemberList(for round: Int) -> some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(reviewMembers) { member in
                reviewMemberRow(member, round: round)
            }
        }
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Close")
                .font(AppDesign.Typography.headline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightSmall)
                .background(AppDesign.Colors.secondaryBackground)
                .cornerRadius(AppDesign.CornerRadius.md)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .background(AppDesign.Colors.background.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4))
    }

    // MARK: - Helpers

    private func saveStatus() {
        guard let choreApiId = displayedChore.choreApiId,
              let houseId = displayedChore.houseId,
              let nextStatus else { return }
        isUpdating = true
        Task {
            let didUpdate = await appViewModel.updateChoreStatus(
                choreApiId: choreApiId,
                houseId: houseId,
                status: nextStatus
            )
            isUpdating = false
            if didUpdate {
                onDismiss()
            }
        }
    }

    private func submitReview(isApproved: Bool) {
        guard let choreApiId = displayedChore.choreApiId, canReview else { return }
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
        guard let rawDate = displayedChore.dueDate else { return displayedChore.dueLabel }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate)
        guard let date else { return displayedChore.dueLabel }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
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
        Label(status.displayName, systemImage: status.iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(status.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(status.color.opacity(0.1))
            .cornerRadius(AppDesign.CornerRadius.md)
    }

    private func reviewButton(
        title: String,
        icon: String,
        color: Color,
        isApproved: Bool
    ) -> some View {
        Button {
            submitReview(isApproved: isApproved)
        } label: {
            Label(title, systemImage: icon)
                .font(AppDesign.Typography.bodyBold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightSmall)
                .background(color)
                .cornerRadius(AppDesign.CornerRadius.md)
        }
        .disabled(isBusy)
    }

    private func votes(for round: Int) -> [ChoreReviewVote] {
        displayedChore.reviewVotes.filter { $0.reviewRound == round }
    }

    private func vote(for member: User, round: Int) -> ChoreReviewVote? {
        guard let apiId = member.apiId else { return nil }
        return votes(for: round).first { $0.reviewerId == apiId }
    }

    private func approvedVoteCount(for round: Int) -> Int {
        votes(for: round).filter(\.isApproved).count
    }

    private func rejectedVoteCount(for round: Int) -> Int {
        votes(for: round).filter { !$0.isApproved }.count
    }

    private func pendingVoteCount(for round: Int) -> Int {
        max(eligibleReviewerCount - votes(for: round).count, 0)
    }

    private func reviewCompletionRatio(for round: Int) -> Double {
        guard eligibleReviewerCount > 0 else { return 1 }
        return min(Double(votes(for: round).count) / Double(eligibleReviewerCount), 1)
    }

    private func reviewSummaryPill(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(color.opacity(0.1))
        .cornerRadius(AppDesign.CornerRadius.sm)
    }

    private func reviewMemberRow(_ member: User, round: Int) -> some View {
        let isAssignee = member.apiId == displayedChore.assignedToId
        let vote = vote(for: member, round: round)
        let status = reviewStatus(forAssignee: isAssignee, vote: vote)

        return HStack(spacing: AppDesign.Spacing.sm) {
            UserAvatar(user: member, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                    .lineLimit(1)
                if isAssignee {
                    Text("Assigned user")
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            Label(status.title, systemImage: status.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(status.color.opacity(0.1))
                .cornerRadius(AppDesign.CornerRadius.sm)
        }
        .padding(.horizontal, AppDesign.Spacing.sm)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(AppDesign.Colors.background.opacity(0.65))
        .cornerRadius(AppDesign.CornerRadius.md)
    }

    private func reviewStatus(forAssignee isAssignee: Bool, vote: ChoreReviewVote?) -> (title: String, icon: String, color: Color) {
        if isAssignee {
            return ("No vote", "minus.circle.fill", AppDesign.Colors.textSecondary)
        }
        guard let vote else {
            return ("Waiting", "clock.fill", AppDesign.Colors.textSecondary)
        }
        if vote.isApproved {
            return ("Approved", "checkmark.circle.fill", AppDesign.Colors.success)
        }
        return ("Rejected", "xmark.circle.fill", AppDesign.Colors.error)
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

// MARK: - ChoreStatus UI Helpers

extension ChoreStatus {
    var displayName: String {
        switch self {
        case .draft:     return "Draft"
        case .progress:  return "In Progress"
        case .inTest:    return "In Review"
        case .completed: return "Completed"
        }
    }
    var iconName: String {
        switch self {
        case .draft:     return "doc.fill"
        case .progress:  return "arrow.right.circle.fill"
        case .inTest:    return "magnifyingglass.circle.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
    var color: Color {
        switch self {
        case .draft:     return Color(red: 0.55, green: 0.55, blue: 0.6)
        case .progress:  return Color(red: 1.0, green: 0.48, blue: 0.15)
        case .inTest:    return Color(red: 0.5, green: 0.2, blue: 0.85)
        case .completed: return Color(red: 0.2, green: 0.75, blue: 0.4)
        }
    }
}

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
        appViewModel: AppViewModel(),
        onDismiss: {}
    )
}
