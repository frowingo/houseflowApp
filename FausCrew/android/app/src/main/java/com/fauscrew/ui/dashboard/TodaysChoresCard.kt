package com.fauscrew.ui.dashboard

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GridView
import com.fauscrew.ui.dashboard.catalog.ChoreCatalogMosaicButton
import com.fauscrew.ui.dashboard.catalog.catalog
import com.fauscrew.ui.dashboard.catalog.catalogPress
import com.fauscrew.ui.components.fausCardSheen
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.auth.social
import com.fauscrew.ui.components.UserAvatar
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.gradientForeground
import com.fauscrew.ui.theme.softShadow

/** `TodaysChoresCard`: the plain "Active Chores" header, divider and the tappable chore rows. */
@Composable
internal fun TodaysChoresCard(
    chores: List<HouseChore>,
    members: List<HouseMember>,
    strings: LocalizedText,
    onChoreTap: (HouseChore) -> Unit,
    modifier: Modifier = Modifier,
    /** Opens the chore catalog (header tile while chores are listed, empty-state button otherwise); `null` hides both. */
    onAddChore: (() -> Unit)? = null,
    /** Opens the archive of older closed chores; `null` hides the entry row. */
    onOpenArchive: (() -> Unit)? = null,
) {
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.fillMaxWidth()
            .softShadow(FausCrewColors.shadow.copy(alpha = .12f), 16.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.cardBackground)
            .fausCardSheen()
            .background(Brush.linearGradient(listOf(
                FausCrewColors.primary.copy(alpha = .05f), Color.Transparent, FausCrewColors.secondary.copy(alpha = .05f),
            )))
            .border(1.dp, Brush.linearGradient(listOf(
                FausCrewColors.primary.copy(alpha = .3f), FausCrewColors.secondary.copy(alpha = .3f),
            )), shape),
    ) {
        ChoresHeader(strings, onAddChore.takeIf { chores.isNotEmpty() })
        HorizontalDivider(Modifier.padding(horizontal = Spacing.xl), thickness = .5.dp, color = FausCrewColors.separator)
        if (chores.isEmpty()) {
            ChoresEmptyState(strings, onAddChore)
        } else {
            // Active chores first; Completed and Failed (and unknown) follow as the history.
            val (active, history) = remember(chores) { chores.splitByHistory() }
            val historyHeaderId = history.firstOrNull()?.id.takeIf { active.isNotEmpty() }
            Column(Modifier.padding(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                (active + history).forEach { chore ->
                    if (chore.id == historyHeaderId) {
                        Text(strings.social("todays_tasks_history_label", "Geçmiş", "History").uppercase(),
                            Modifier.fillMaxWidth().padding(top = Spacing.xs).semantics { heading() },
                            fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = .5.sp,
                            color = FausCrewColors.textTertiary)
                    }
                    key(chore.id) {
                        ModernChoreRow(chore, members.firstOrNull { it.id == chore.assignedTo }, strings) { onChoreTap(chore) }
                    }
                }
            }
        }
        onOpenArchive?.let { ArchiveEntryRow(strings, it) }
    }
}

/** A subtle full-width row at the card's bottom that opens the archive. */
@Composable
private fun ArchiveEntryRow(strings: LocalizedText, onClick: () -> Unit) {
    HorizontalDivider(Modifier.padding(horizontal = Spacing.xl), thickness = .5.dp, color = FausCrewColors.separator)
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = Spacing.xl, vertical = Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(FausCrewIcons.clock, null, Modifier.size(16.dp), tint = FausCrewColors.textSecondary)
        Text(strings.social("chore_archive_entry", "Tüm geçmiş", "Full history"), Modifier.weight(1f),
            style = FausCrewType.subheadline, fontWeight = FontWeight.Medium, color = FausCrewColors.textSecondary)
        Icon(FausCrewIcons.chevronRight, null, Modifier.size(18.dp), tint = FausCrewColors.textTertiary)
    }
}

/** Same badge as House Members' header, in this card's indigo → teal order; [onAddChore] adds the catalog tile. */
@Composable
private fun ChoresHeader(strings: LocalizedText, onAddChore: (() -> Unit)?) {
    Row(
        Modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp).padding(Spacing.xl),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(Modifier.size(42.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(42.dp).background(
                Brush.linearGradient(listOf(FausCrewColors.indigo, FausCrewColors.teal)), RoundedCornerShape(11.dp)))
            Icon(FausCrewIcons.checklist, null, Modifier.size(22.dp), tint = Color.White)
            AccentDot(7.dp, FausCrewColors.cardBackground, Modifier.offset(15.dp, 15.dp))
        }
        Text(strings.social("active_chores_title", "Aktif Görevler", "Active Chores"),
            Modifier.weight(1f).semantics { heading() }, style = FausCrewType.headline, color = FausCrewColors.textPrimary)
        onAddChore?.let { ChoreCatalogMosaicButton(strings, it) }
    }
}

/** Small brand-orange dot with a ring in the card color, used on the dashboard icon tiles. */
@Composable
internal fun AccentDot(size: androidx.compose.ui.unit.Dp, ring: Color, modifier: Modifier = Modifier, ringWidth: androidx.compose.ui.unit.Dp = 1.5.dp) {
    Box(modifier.size(size + ringWidth * 2).background(ring, CircleShape).padding(ringWidth)
        .background(FausCrewColors.accentOrange, CircleShape))
}

@Composable
private fun ChoresEmptyState(strings: LocalizedText, onAddChore: (() -> Unit)?) {
    val pulse = rememberInfiniteTransition(label = "emptyPulse")
    val phase by pulse.animateFloat(0f, 1f, infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "phase")
    Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Box(contentAlignment = Alignment.Center) {
            Box(Modifier.size(120.dp).graphicsLayer { val s = 1f + .2f * phase; scaleX = s; scaleY = s }
                .blur(20.dp).background(FausCrewColors.indigo.copy(alpha = .18f), CircleShape))
            Box(Modifier.size(90.dp).graphicsLayer { val s = 1.2f - .2f * phase; scaleX = s; scaleY = s }
                .blur(15.dp).background(FausCrewColors.teal.copy(alpha = .25f), CircleShape))
            // An empty list is not "all done": the icon invites adding, it does not celebrate.
            Icon(FausCrewIcons.listClipboard, null,
                Modifier.size(56.dp)
                    .gradientForeground(Brush.linearGradient(listOf(FausCrewColors.indigo, FausCrewColors.teal))),
                tint = Color.White)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(strings.social("active_chores_empty_title", "Şu anda aktif bir iş yok", "No active chores right now"), style = FausCrewType.title3, color = FausCrewColors.textPrimary)
            Text(strings.social("active_chores_empty_subtitle", "Eklemeye ne dersin?", "How about adding one?"), style = FausCrewType.subheadline,
                color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
        }
        onAddChore?.let { open ->
            val haptics = LocalHapticFeedback.current
            Row(
                Modifier.height(38.dp).clip(CircleShape).background(FausCrewColors.accentOrange.copy(alpha = .12f))
                    .catalogPress(.96f) { haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove); open() }
                    .padding(horizontal = Spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Rounded.GridView, null, Modifier.size(16.dp), tint = FausCrewColors.accentOrangeInk)
                Text(strings.catalog("todays_tasks_empty_add", "Katalogdan iş ekle", "Add from the catalog"),
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = FausCrewColors.accentOrangeInk)
            }
        }
    }
}

/**
 * `ModernChoreRow` with its pressed button style. A non-null [detail] is an extra caption line
 * below the assignee row.
 */
@Composable
internal fun ModernChoreRow(
    chore: HouseChore,
    assignee: HouseMember?,
    strings: LocalizedText,
    detail: String? = null,
    onTap: () -> Unit,
) {
    val status = ChoreStatusUi.of(chore.status)
    val completed = status == ChoreStatusUi.COMPLETED
    // Failed reads as closed but not done: muted title, no strikethrough.
    val closed = status.group.isHistory
    val haptics = LocalHapticFeedback.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) .985f else 1f, tween(160), label = "rowScale")
    val shape = RoundedCornerShape(Radius.md)
    Row(
        Modifier.fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale; translationY = if (pressed) 1.dp.toPx() else 0f }
            .softShadow(status.color.copy(alpha = if (pressed) .16f else .07f), if (pressed) 5.dp else 9.dp,
                y = if (pressed) 2.dp else 5.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.background)
            .border(if (pressed) 1.5.dp else 1.dp, status.color.copy(alpha = if (pressed) .42f else .12f), shape)
            .clickable(interaction, indication = null, role = Role.Button) {
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onTap()
            }
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        Box(Modifier.width(32.dp), contentAlignment = Alignment.Center) {
            if (!completed) Box(Modifier.size(32.dp).background(status.color.copy(alpha = .15f), CircleShape))
            val glyphBrush = if (completed) {
                Brush.linearGradient(listOf(FausCrewColors.success, FausCrewColors.secondary))
            } else {
                Brush.linearGradient(listOf(status.color, status.color.copy(alpha = .6f)))
            }
            if (completed) {
                Icon(FausCrewIcons.checkmarkCircleFill, null, Modifier.size(28.dp).gradientForeground(glyphBrush),
                    tint = Color.White)
            } else {
                ChoreStatusGlyph(status, 26.dp, glyphBrush, Modifier.rotate(-15f))
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            ChoreCategoryTag(chore.categoryKind, strings)
            Text(chore.title, style = FausCrewType.bodyBold,
                color = if (closed) FausCrewColors.textSecondary else FausCrewColors.textPrimary,
                textDecoration = if (completed) TextDecoration.LineThrough else null,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                UserAvatar(assignee, 20.dp)
                Text(assignee?.name ?: strings.get("common_unassigned"), Modifier.weight(1f),
                    style = FausCrewType.caption, color = FausCrewColors.textSecondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                StatusBadge(status, strings)
            }
            if (detail != null) {
                Text(detail, style = FausCrewType.caption, color = FausCrewColors.textSecondary,
                    maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
        }
        Box(Modifier.size(26.dp).background(status.color.copy(alpha = .10f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(FausCrewIcons.chevronRight, null, Modifier.size(18.dp), tint = status.color.copy(alpha = .72f))
        }
    }
}

@Composable
private fun StatusBadge(status: ChoreStatusUi, strings: LocalizedText) {
    Row(
        Modifier.background(status.color.copy(alpha = .12f), CircleShape).padding(horizontal = Spacing.sm, vertical = Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        ChoreStatusGlyph(status, 11.dp, status.color)
        Text(status.label(strings), style = FausCrewType.caption, fontWeight = FontWeight.Medium,
            color = status.color, maxLines = 1)
    }
}
