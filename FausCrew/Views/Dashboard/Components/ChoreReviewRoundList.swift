import SwiftUI
import FausCrewCore

/// The review rounds of a chore, newest first: each round's tally, who voted and, for the
/// active round, the buttons to vote. The popup keeps the state and the actions.
struct ChoreReviewRoundList: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let summary: ChoreReviewSummary
    let members: [User]
    let assigneeId: String?
    let isAssignedToCurrentUser: Bool
    let photoRounds: [Int]
    let loadingPhotoRound: Int?
    let accentColor: Color
    let isBusy: Bool
    @Binding var expandedRounds: Set<Int>
    let onShowPhoto: (Int) -> Void
    let onReview: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            ForEach(summary.rounds, id: \.number) { round in
                roundCard(round)
            }
        }
    }

    private func roundCard(_ round: ChoreReviewSummary.Round) -> some View {
        let isExpanded = round.isActive || expandedRounds.contains(round.number)

        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Button {
                guard !round.isActive else { return }
                withAnimation(AppDesign.Animation.quick) {
                    if expandedRounds.contains(round.number) {
                        expandedRounds.remove(round.number)
                    } else {
                        expandedRounds.insert(round.number)
                    }
                }
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(appViewModel.localized(
                                "chore_detail_round_template",
                                replacements: ["round": "\(round.number)"]
                            ))
                                .font(AppDesign.Typography.bodyBold)
                            Text(appViewModel.localized(round.isActive ? "chore_detail_round_active" : "chore_detail_round_resulted"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(round.isActive ? .white : AppDesign.Colors.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(round.isActive ? accentColor : AppDesign.Colors.textSecondary.opacity(0.14))
                                .cornerRadius(AppDesign.CornerRadius.circle)
                        }
                        Text(appViewModel.localized(
                            "chore_detail_approved_count_template",
                            replacements: [
                                "approved": "\(round.approvedCount)",
                                "eligible": "\(summary.eligibleReviewerCount)"
                            ]
                        ))
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                    }

                    Spacer()

                    if !round.isActive {
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
                if photoRounds.contains(round.number) {
                    photoArea(for: round)
                }
                progressBar(for: round)
                summaryRow(for: round)
                memberList(for: round)

                if round.isActive {
                    actionArea
                }
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.background.opacity(0.68))
        .cornerRadius(AppDesign.CornerRadius.md)
    }

    private func photoArea(for round: ChoreReviewSummary.Round) -> some View {
        Button { onShowPhoto(round.number) } label: {
            HStack(spacing: AppDesign.Spacing.sm) {
                if loadingPhotoRound == round.number {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(appViewModel.localized("chore_review_photo_view", fallback: "View review photo"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(accentColor.opacity(0.1))
            .cornerRadius(AppDesign.CornerRadius.sm)
        }
        .buttonStyle(.plain)
        .disabled(loadingPhotoRound != nil)
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            if isAssignedToCurrentUser {
                Label(appViewModel.localized("chore_detail_assignee_no_vote_message"), systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(AppDesign.Colors.textSecondary)
            } else if let vote = summary.currentUserVote {
                Label(
                    appViewModel.localized(vote.isApproved ? "chore_detail_you_approved_message" : "chore_detail_you_rejected_message"),
                    systemImage: vote.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(AppDesign.Typography.bodyBold)
                .foregroundColor(vote.isApproved ? AppDesign.Colors.success : AppDesign.Colors.error)
            } else if summary.canReview {
                Text(appViewModel.localized("chore_detail_review_prompt"))
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(AppDesign.Colors.textSecondary)

                HStack(spacing: AppDesign.Spacing.md) {
                    reviewButton(
                        title: appViewModel.localized("chore_detail_reject_button"),
                        icon: "xmark.circle.fill",
                        color: AppDesign.Colors.error,
                        isApproved: false
                    )
                    reviewButton(
                        title: appViewModel.localized("chore_detail_approve_button"),
                        icon: "checkmark.circle.fill",
                        color: AppDesign.Colors.success,
                        isApproved: true
                    )
                }
            }
        }
    }

    private func reviewButton(
        title: String,
        icon: String,
        color: Color,
        isApproved: Bool
    ) -> some View {
        Button {
            onReview(isApproved)
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

    private func progressBar(for round: ChoreReviewSummary.Round) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let approvedWidth = width * CGFloat(round.approvedRatio)
            let rejectedWidth = width * CGFloat(round.rejectedRatio)

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
        .accessibilityLabel(Text(appViewModel.localized("chore_detail_review_progress_accessibility")))
        .accessibilityValue(Text(appViewModel.localized(
            "chore_detail_review_percent_voted_template",
            replacements: ["percent": "\(Int(round.completionRatio * 100))"]
        )))
    }

    private func summaryRow(for round: ChoreReviewSummary.Round) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            summaryPill(title: appViewModel.localized("chore_detail_review_approved"), count: round.approvedCount, color: AppDesign.Colors.success)
            summaryPill(title: appViewModel.localized("chore_detail_review_rejected"), count: round.rejectedCount, color: AppDesign.Colors.error)
            summaryPill(title: appViewModel.localized("chore_detail_review_waiting"), count: round.pendingCount, color: AppDesign.Colors.textSecondary)
        }
    }

    private func summaryPill(title: String, count: Int, color: Color) -> some View {
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

    private func memberList(for round: ChoreReviewSummary.Round) -> some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(members) { member in
                memberRow(member, round: round)
            }
        }
    }

    private func memberRow(_ member: User, round: ChoreReviewSummary.Round) -> some View {
        let isAssignee = member.apiId == assigneeId
        let vote = member.apiId.flatMap(round.vote(by:))
        let status = memberStatus(forAssignee: isAssignee, vote: vote)

        return HStack(spacing: AppDesign.Spacing.sm) {
            UserAvatar(user: member, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                    .lineLimit(1)
                if isAssignee {
                    Text(appViewModel.localized("chore_detail_assigned_user_label"))
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            Label(appViewModel.localized(status.titleKey), systemImage: status.icon)
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

    private func memberStatus(forAssignee isAssignee: Bool, vote: ChoreReviewVote?) -> (titleKey: String, icon: String, color: Color) {
        if isAssignee {
            return ("chore_detail_review_no_vote", "minus.circle.fill", AppDesign.Colors.textSecondary)
        }
        guard let vote else {
            return ("chore_detail_review_waiting", "clock.fill", AppDesign.Colors.textSecondary)
        }
        if vote.isApproved {
            return ("chore_detail_review_approved", "checkmark.circle.fill", AppDesign.Colors.success)
        }
        return ("chore_detail_review_rejected", "xmark.circle.fill", AppDesign.Colors.error)
    }
}
