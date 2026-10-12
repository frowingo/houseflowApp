package com.houseflow.ui.dashboard

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.HouseChore
import com.houseflow.platform.HouseMember
import com.houseflow.platform.HouseVote
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.HouseFlowPopup
import com.houseflow.ui.components.PopupBusyIndicator
import com.houseflow.ui.components.PopupCloseButton
import com.houseflow.ui.components.PopupError
import com.houseflow.ui.components.PopupFooter
import com.houseflow.ui.components.PopupPrimaryButton
import com.houseflow.ui.components.PopupSecondaryButton
import com.houseflow.ui.components.PopupSectionLabel
import com.houseflow.ui.components.UserAvatar
import com.houseflow.ui.components.brandPopupHeaderBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Sizes
import com.houseflow.ui.theme.Spacing

private val accentOrange = HouseFlowColors.accentOrange

/**
 * `ChoreDetailPopup`: status pipeline, task info, assignee status progression and the
 * review rounds where the other members vote.
 */
@Composable
internal fun ChoreDetailPopup(
    chore: HouseChore,
    members: List<HouseMember>,
    userId: String,
    strings: LocalizedText,
    busy: Boolean,
    reviewing: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onStatus: (String, Int) -> Unit,
    onReview: (String, Boolean) -> Unit,
) {
    val status = ChoreStatusUi.of(chore.status)
    val isAssignee = userId.isNotBlank() && chore.assignedTo == userId
    val nextStatus = if (isAssignee) status.next else null
    val currentVote = chore.reviewVotes.firstOrNull { it.reviewRound == chore.reviewRound && it.reviewerId == userId }
    val canReview = status == ChoreStatusUi.IN_TEST && !isAssignee && userId.isNotBlank() && currentVote == null
    val eligibleReviewers = members.count { it.id != chore.assignedTo }
    val rounds = (chore.reviewVotes.map { it.reviewRound } + listOfNotNull(chore.reviewRound.takeIf { it > 0 }))
        .distinct().sortedDescending()
    val activeRound = chore.reviewRound.takeIf { status == ChoreStatusUi.IN_TEST && it > 0 }
    var expandedRounds by remember(chore.id) { mutableStateOf(emptySet<Int>()) }

    HouseFlowPopup(
        onDismiss = onDismiss,
        dismissEnabled = !busy,
        header = { DetailHeader(chore, strings, !busy, onDismiss) },
        footer = { PopupFooter { PopupSecondaryButton(strings.get("common_close"), !busy, onDismiss, Modifier.fillMaxWidth()) } },
        busyOverlay = if (busy) {
            { PopupBusyIndicator(strings.get(if (reviewing) "chore_detail_submitting_vote" else "chore_detail_updating")) }
        } else null,
    ) {
        PopupError(error)
        StatusPipeline(status, strings)
        InfoSection(chore, members.firstOrNull { it.id == chore.assignedTo }, strings)
        if (nextStatus != null) StatusUpdateSection(status, nextStatus, busy, strings) { onStatus(chore.id, nextStatus.raw) }
        if (rounds.isNotEmpty()) {
            SectionCard(borderColor = status.color.copy(alpha = .2f)) {
                PopupSectionLabel(HouseFlowIcons.checkmarkSealFill, strings.get("chore_detail_review_rounds_label"))
                rounds.forEach { round ->
                    val active = round == activeRound
                    ReviewRoundCard(
                        round = round, active = active, expanded = active || round in expandedRounds,
                        votes = chore.reviewVotes.filter { it.reviewRound == round }, members = members,
                        assigneeId = chore.assignedTo, eligibleReviewers = eligibleReviewers, statusColor = status.color,
                        strings = strings,
                        onToggle = { expandedRounds = if (round in expandedRounds) expandedRounds - round else expandedRounds + round },
                    ) {
                        ReviewActionArea(isAssignee, currentVote, canReview, busy, strings) { approved -> onReview(chore.id, approved) }
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailHeader(chore: HouseChore, strings: LocalizedText, closeEnabled: Boolean, onClose: () -> Unit) {
    val level = ChoreLevelUi.of(chore.level)
    Box(Modifier.fillMaxWidth().height(52.dp).brandPopupHeaderBackground(), contentAlignment = Alignment.Center) {
        Icon(HouseFlowIcons.houseFill, null, Modifier.size(60.dp), tint = Color.White.copy(alpha = .12f))
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.xl), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Row(Modifier.background(Color.White.copy(alpha = .92f), CircleShape).padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Icon(level.icon, null, Modifier.size(13.dp), tint = level.color)
                Text(strings.get(level.key), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = level.color, maxLines = 1)
            }
            Text(chore.title, Modifier.weight(1f), style = HouseFlowType.subheadline, fontWeight = FontWeight.SemiBold,
                color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            PopupCloseButton(onClose, closeEnabled, strings.get("common_close"))
        }
    }
}

@Composable
private fun SectionCard(
    borderColor: Color = Color.Transparent,
    spacing: Dp = Spacing.md,
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(HouseFlowColors.secondaryBackground)
            .border(1.dp, borderColor, shape).padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) { content() }
}

@Composable
private fun StatusPipeline(current: ChoreStatusUi, strings: LocalizedText) {
    SectionCard(borderColor = accentOrange.copy(alpha = .2f), spacing = Spacing.sm) {
        PopupSectionLabel(HouseFlowIcons.arrowTriangle2Circlepath, strings.get("chore_detail_status_label"))
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
            ChoreStatusUi.entries.forEachIndexed { index, step ->
                val isCurrent = step == current
                val isPast = step.raw < current.raw
                Column(Modifier.width(60.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(32.dp).background(
                        when {
                            isCurrent -> accentOrange
                            isPast -> accentOrange.copy(alpha = .3f)
                            else -> HouseFlowColors.secondaryBackground
                        }, CircleShape), contentAlignment = Alignment.Center) {
                        val tint = when {
                            isCurrent -> Color.White
                            isPast -> accentOrange
                            else -> HouseFlowColors.textSecondary
                        }
                        if (isPast) Icon(HouseFlowIcons.checkmark, null, Modifier.size(17.dp), tint = tint)
                        else ChoreStatusGlyph(step, 17.dp, tint)
                    }
                    Text(strings.get(step.key), fontSize = 10.sp,
                        fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal,
                        color = if (isCurrent) accentOrange else HouseFlowColors.textSecondary,
                        textAlign = TextAlign.Center, lineHeight = 12.sp)
                }
                if (index < ChoreStatusUi.entries.lastIndex) {
                    Box(Modifier.weight(1f).padding(top = 15.dp).height(2.dp)
                        .background(if (step.raw < current.raw) accentOrange.copy(alpha = .4f) else HouseFlowColors.secondaryBackground))
                }
            }
        }
    }
}

@Composable
private fun InfoSection(chore: HouseChore, assignee: HouseMember?, strings: LocalizedText) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionCard(spacing = Spacing.sm) {
            PopupSectionLabel(HouseFlowIcons.textBadgeCheckmark, strings.get("chore_detail_task_label"))
            Text(chore.title, style = HouseFlowType.title3, color = HouseFlowColors.textPrimary)
            if (chore.description.isNotBlank()) {
                Text(chore.description, style = HouseFlowType.body, color = HouseFlowColors.textSecondary)
            }
        }
        Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            InfoTile(HouseFlowIcons.personFill, strings.get("chore_detail_assigned_to_label")) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    UserAvatar(assignee, 28.dp)
                    Text(assignee?.firstName ?: strings.get("common_unassigned"), style = HouseFlowType.bodyBold,
                        color = HouseFlowColors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            InfoTile(HouseFlowIcons.calendar, strings.get("chore_detail_due_label")) {
                val color = dueLabel(chore.dueDate).color
                Text(strings.dueText(chore.dueDate),
                    Modifier.background(color.copy(alpha = .12f), RoundedCornerShape(Radius.sm))
                        .padding(horizontal = Spacing.sm, vertical = Spacing.xs),
                    style = HouseFlowType.bodyBold, color = color, maxLines = 1)
            }
        }
    }
}

@Composable
private fun RowScope.InfoTile(icon: ImageVector, label: String, content: @Composable () -> Unit) {
    Column(
        Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(Radius.lg))
            .background(HouseFlowColors.secondaryBackground).padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(icon, null, Modifier.size(13.dp), tint = HouseFlowColors.textSecondary)
            Text(label.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                color = HouseFlowColors.textSecondary, letterSpacing = .4.sp, maxLines = 1)
        }
        content()
    }
}

@Composable
private fun StatusUpdateSection(
    current: ChoreStatusUi,
    next: ChoreStatusUi,
    busy: Boolean,
    strings: LocalizedText,
    onSave: () -> Unit,
) {
    SectionCard(borderColor = accentOrange.copy(alpha = .2f)) {
        PopupSectionLabel(HouseFlowIcons.pencilCircleFill, strings.get("chore_detail_update_status_label"))
        Text(strings.get("chore_detail_update_status_description"), style = HouseFlowType.caption,
            color = HouseFlowColors.textSecondary)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            StatusStage(current, strings, Modifier.weight(1f))
            Icon(HouseFlowIcons.arrowRight, null, Modifier.size(16.dp), tint = HouseFlowColors.textSecondary)
            StatusStage(next, strings, Modifier.weight(1f))
        }
        PopupPrimaryButton(
            strings.template("chore_detail_move_to_status_template", "status" to strings.get(next.key)),
            enabled = !busy, onClick = onSave, modifier = Modifier.fillMaxWidth(),
            icon = HouseFlowIcons.arrowRightCircleFill, busy = busy,
        )
    }
}

@Composable
private fun StatusStage(status: ChoreStatusUi, strings: LocalizedText, modifier: Modifier) {
    Row(
        modifier.clip(RoundedCornerShape(Radius.md)).background(status.color.copy(alpha = .1f)).padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ChoreStatusGlyph(status, 14.dp, status.color)
        Text(strings.get(status.key), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = status.color, maxLines = 1)
    }
}

@Composable
private fun ReviewRoundCard(
    round: Int,
    active: Boolean,
    expanded: Boolean,
    votes: List<HouseVote>,
    members: List<HouseMember>,
    assigneeId: String,
    eligibleReviewers: Int,
    statusColor: Color,
    strings: LocalizedText,
    onToggle: () -> Unit,
    actions: @Composable () -> Unit,
) {
    val approved = votes.count { it.isApproved }
    val rejected = votes.count { !it.isApproved }
    val pending = (eligibleReviewers - votes.size).coerceAtLeast(0)
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md))
            .background(HouseFlowColors.background.copy(alpha = .68f)).padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(Modifier.fillMaxWidth().clickable(enabled = !active, onClick = onToggle),
            verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(strings.template("chore_detail_round_template", "round" to round.toString()),
                        style = HouseFlowType.bodyBold, color = HouseFlowColors.textPrimary)
                    Text(strings.get(if (active) "chore_detail_round_active" else "chore_detail_round_resulted"),
                        Modifier.background(if (active) statusColor else HouseFlowColors.textSecondary.copy(alpha = .14f), CircleShape)
                            .padding(horizontal = 7.dp, vertical = 3.dp),
                        fontSize = 10.sp, fontWeight = FontWeight.Bold,
                        color = if (active) Color.White else HouseFlowColors.textSecondary)
                }
                Text(strings.template("chore_detail_approved_count_template",
                    "approved" to approved.toString(), "eligible" to eligibleReviewers.toString()),
                    style = HouseFlowType.caption, color = HouseFlowColors.textSecondary)
            }
            if (!active) {
                Icon(if (expanded) HouseFlowIcons.chevronUp else HouseFlowIcons.chevronDown, null,
                    Modifier.size(20.dp), tint = HouseFlowColors.textSecondary)
            }
        }
        AnimatedVisibility(expanded, enter = fadeIn(Motion.quick()) + expandVertically(Motion.quick()),
            exit = fadeOut(Motion.quick()) + shrinkVertically(Motion.quick())) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                ReviewProgressBar(approved, rejected, votes.size, eligibleReviewers, strings)
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    SummaryPill(strings.get("chore_detail_review_approved"), approved, HouseFlowColors.success, Modifier.weight(1f))
                    SummaryPill(strings.get("chore_detail_review_rejected"), rejected, HouseFlowColors.error, Modifier.weight(1f))
                    SummaryPill(strings.get("chore_detail_review_waiting"), pending, HouseFlowColors.textSecondary, Modifier.weight(1f))
                }
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    members.forEach { member ->
                        ReviewMemberRow(member, member.id == assigneeId,
                            votes.firstOrNull { it.reviewerId == member.id }, strings)
                    }
                }
                if (active) actions()
            }
        }
    }
}

@Composable
private fun ReviewProgressBar(approved: Int, rejected: Int, voted: Int, eligible: Int, strings: LocalizedText) {
    val approvedFraction = if (eligible == 0) 0f else approved.toFloat() / eligible
    val rejectedFraction = if (eligible == 0) 0f else rejected.toFloat() / eligible
    val completion = if (eligible == 0) 1f else (voted.toFloat() / eligible).coerceAtMost(1f)
    val label = strings.get("chore_detail_review_progress_accessibility")
    val value = strings.template("chore_detail_review_percent_voted_template", "percent" to (completion * 100).toInt().toString())
    Row(
        Modifier.fillMaxWidth().height(10.dp).clip(CircleShape)
            .background(HouseFlowColors.textSecondary.copy(alpha = .16f))
            .border(1.dp, HouseFlowColors.textSecondary.copy(alpha = .18f), CircleShape)
            .semantics { contentDescription = label; stateDescription = value },
    ) {
        if (approvedFraction > 0f) Box(Modifier.fillMaxHeight().weight(approvedFraction).clip(CircleShape).background(HouseFlowColors.success))
        if (rejectedFraction > 0f) Box(Modifier.fillMaxHeight().weight(rejectedFraction).clip(CircleShape).background(HouseFlowColors.error))
        val rest = 1f - approvedFraction - rejectedFraction
        if (rest > 0f) Spacer(Modifier.weight(rest))
    }
}

@Composable
private fun SummaryPill(title: String, count: Int, color: Color, modifier: Modifier) {
    Row(
        modifier.clip(RoundedCornerShape(Radius.sm)).background(color.copy(alpha = .1f)).padding(horizontal = 8.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(7.dp).background(color, CircleShape))
        Text(count.toString(), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = color)
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = color, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun ReviewMemberRow(member: HouseMember, isAssignee: Boolean, vote: HouseVote?, strings: LocalizedText) {
    val (key, icon, color) = when {
        isAssignee -> Triple("chore_detail_review_no_vote", HouseFlowIcons.minusCircleFill, HouseFlowColors.textSecondary)
        vote == null -> Triple("chore_detail_review_waiting", HouseFlowIcons.clockFill, HouseFlowColors.textSecondary)
        vote.isApproved -> Triple("chore_detail_review_approved", HouseFlowIcons.checkmarkCircleFill, HouseFlowColors.success)
        else -> Triple("chore_detail_review_rejected", HouseFlowIcons.xmarkCircleFill, HouseFlowColors.error)
    }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(HouseFlowColors.background.copy(alpha = .65f))
            .padding(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        UserAvatar(member, 28.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(member.name, style = HouseFlowType.bodyBold, color = HouseFlowColors.textPrimary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (isAssignee) Text(strings.get("chore_detail_assigned_user_label"), style = HouseFlowType.caption,
                color = HouseFlowColors.textSecondary)
        }
        IconLabel(icon, strings.get(key), color,
            Modifier.background(color.copy(alpha = .1f), RoundedCornerShape(Radius.sm)).padding(horizontal = 8.dp, vertical = 6.dp))
    }
}

@Composable
private fun ReviewActionArea(
    isAssignee: Boolean,
    vote: HouseVote?,
    canReview: Boolean,
    busy: Boolean,
    strings: LocalizedText,
    onReview: (Boolean) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        when {
            isAssignee -> IconLabel(HouseFlowIcons.personCropCircleBadgeExclamationmark,
                strings.get("chore_detail_assignee_no_vote_message"), HouseFlowColors.textSecondary, textSize = 12)
            vote != null -> IconLabel(
                if (vote.isApproved) HouseFlowIcons.checkmarkCircleFill else HouseFlowIcons.xmarkCircleFill,
                strings.get(if (vote.isApproved) "chore_detail_you_approved_message" else "chore_detail_you_rejected_message"),
                if (vote.isApproved) HouseFlowColors.success else HouseFlowColors.error, textSize = 17, weight = FontWeight.Medium)
            canReview -> {
                Text(strings.get("chore_detail_review_prompt"), style = HouseFlowType.caption, color = HouseFlowColors.textSecondary)
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    ReviewButton(strings.get("chore_detail_reject_button"), HouseFlowIcons.xmarkCircleFill,
                        HouseFlowColors.error, !busy, Modifier.weight(1f)) { onReview(false) }
                    ReviewButton(strings.get("chore_detail_approve_button"), HouseFlowIcons.checkmarkCircleFill,
                        HouseFlowColors.success, !busy, Modifier.weight(1f)) { onReview(true) }
                }
            }
        }
    }
}

@Composable
private fun ReviewButton(title: String, icon: ImageVector, color: Color, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier.height(Sizes.buttonHeightSmall).clip(RoundedCornerShape(Radius.md)).background(color)
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, Modifier.size(18.dp), tint = Color.White)
        Text(title, style = HouseFlowType.bodyBold, color = Color.White, maxLines = 1)
    }
}

/** SwiftUI `Label(title, systemImage:)`. */
@Composable
private fun IconLabel(
    icon: ImageVector,
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    textSize: Int = 11,
    weight: FontWeight = FontWeight.SemiBold,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Icon(icon, null, Modifier.size((textSize + 3).dp), tint = color)
        Text(text, fontSize = textSize.sp, fontWeight = weight, color = color)
    }
}
