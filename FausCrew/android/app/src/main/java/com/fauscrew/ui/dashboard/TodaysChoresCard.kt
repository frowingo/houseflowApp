package com.fauscrew.ui.dashboard

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
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
import com.fauscrew.ui.theme.FausCrewBrushes
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Motion
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.gradientForeground
import com.fauscrew.ui.theme.softShadow
import kotlinx.coroutines.delay

/** `TodaysChoresCard`: progress header, divider and the tappable chore rows. */
@Composable
internal fun TodaysChoresCard(
    chores: List<HouseChore>,
    members: List<HouseMember>,
    strings: LocalizedText,
    onChoreTap: (HouseChore) -> Unit,
    modifier: Modifier = Modifier,
) {
    val completed = chores.count { ChoreStatusUi.of(it.status) == ChoreStatusUi.COMPLETED }
    val progress = if (chores.isEmpty()) 0f else completed.toFloat() / chores.size
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.fillMaxWidth()
            .softShadow(FausCrewColors.shadow.copy(alpha = .12f), 16.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.cardBackground)
            .background(Brush.linearGradient(listOf(
                FausCrewColors.primary.copy(alpha = .05f), Color.Transparent, FausCrewColors.secondary.copy(alpha = .05f),
            )))
            .border(1.dp, Brush.linearGradient(listOf(
                FausCrewColors.primary.copy(alpha = .3f), FausCrewColors.secondary.copy(alpha = .3f),
            )), shape),
    ) {
        ChoresHeader(strings, completed, chores.size, progress)
        HorizontalDivider(Modifier.padding(horizontal = Spacing.xl), thickness = .5.dp, color = FausCrewColors.separator)
        if (chores.isEmpty()) {
            ChoresEmptyState(strings)
        } else {
            // Active chores first; Completed and Failed (and unknown) follow as the history.
            val (active, history) = chores.splitByHistory()
            Column(Modifier.padding(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                active.forEach { chore ->
                    ModernChoreRow(chore, members.firstOrNull { it.id == chore.assignedTo }, strings) { onChoreTap(chore) }
                }
                if (history.isNotEmpty() && active.isNotEmpty()) {
                    Text(strings.social("todays_tasks_history_label", "Geçmiş", "History").uppercase(),
                        Modifier.fillMaxWidth().padding(top = Spacing.xs).semantics { heading() },
                        fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = .5.sp,
                        color = FausCrewColors.textTertiary)
                }
                history.forEach { chore ->
                    ModernChoreRow(chore, members.firstOrNull { it.id == chore.assignedTo }, strings) { onChoreTap(chore) }
                }
            }
        }
    }
}

@Composable
private fun ChoresHeader(strings: LocalizedText, completed: Int, total: Int, progress: Float) {
    val haptics = LocalHapticFeedback.current
    var iconPressed by remember { mutableStateOf(false) }
    LaunchedEffect(iconPressed) { if (iconPressed) { delay(1_000); iconPressed = false } }
    val iconScale by animateFloatAsState(if (iconPressed) 1.1f else 1f, Motion.spring(), label = "choreIcon")
    Column(Modifier.padding(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clickable(remember { MutableInteractionSource() }, indication = null) {
                    haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    iconPressed = true
                },
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(44.dp).graphicsLayer {
                    scaleX = iconScale; scaleY = iconScale; alpha = if (iconPressed) .6f else 1f
                }.background(FausCrewBrushes.indigoTeal, CircleShape))
                Icon(FausCrewIcons.listClipboardFill, null, Modifier.size(22.dp), tint = Color.White)
                AccentDot(8.dp, FausCrewColors.cardBackground, Modifier.offset(16.dp, 16.dp))
            }
            Column(Modifier.weight(1f).padding(start = Spacing.sm), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(strings.get("todays_tasks_title"), style = FausCrewType.headline, color = FausCrewColors.textPrimary)
                if (total > 0) {
                    Text(strings.template("todays_tasks_completed_template",
                        "completed" to completed.toString(), "total" to total.toString()),
                        style = FausCrewType.caption, color = FausCrewColors.textSecondary)
                }
            }
            if (total > 0) CircularProgress(progress, strings, Modifier.size(50.dp))
        }
        if (total > 0) {
            val animated by animateFloatAsState(progress, Motion.spring(), label = "choreProgress")
            Box(Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(Radius.sm))
                .background(FausCrewColors.textSecondary.copy(alpha = .2f))) {
                Box(Modifier.fillMaxHeight().fillMaxWidth(animated.coerceIn(0f, 1f))
                    .clip(RoundedCornerShape(Radius.sm))
                    .background(Brush.horizontalGradient(listOf(FausCrewColors.indigo, FausCrewColors.teal))))
            }
        }
    }
}

/** Small brand-orange dot with a ring in the card color, used on the dashboard icon tiles. */
@Composable
internal fun AccentDot(size: androidx.compose.ui.unit.Dp, ring: Color, modifier: Modifier = Modifier, ringWidth: androidx.compose.ui.unit.Dp = 1.5.dp) {
    Box(modifier.size(size + ringWidth * 2).background(ring, CircleShape).padding(ringWidth)
        .background(FausCrewColors.accentOrange, CircleShape))
}

/** `CircularProgressView`. */
@Composable
private fun CircularProgress(progress: Float, strings: LocalizedText, modifier: Modifier) {
    val animated by animateFloatAsState(progress, Motion.spring(), label = "ring")
    Box(modifier, contentAlignment = Alignment.Center) {
        val track = FausCrewColors.textSecondary.copy(alpha = .2f)
        val ring = listOf(FausCrewColors.indigo, FausCrewColors.teal)
        Canvas(Modifier.size(50.dp)) {
            val stroke = 4.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(track, 0f, 360f, false,
                Offset(inset, inset), arcSize, style = Stroke(stroke))
            drawArc(Brush.linearGradient(ring),
                -90f, 360f * animated.coerceIn(0f, 1f), false, Offset(inset, inset), arcSize,
                style = Stroke(stroke, cap = StrokeCap.Round))
        }
        Text(strings.template("progress_percent_template", "percent" to (progress * 100).toInt().toString(),
            fallback = "{percent}%"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = FausCrewColors.deepIndigo)
    }
}

@Composable
private fun ChoresEmptyState(strings: LocalizedText) {
    val pulse = rememberInfiniteTransition(label = "emptyPulse")
    val phase by pulse.animateFloat(0f, 1f, infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "phase")
    Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Box(contentAlignment = Alignment.Center) {
            Box(Modifier.size(120.dp).graphicsLayer { val s = 1f + .2f * phase; scaleX = s; scaleY = s }
                .blur(20.dp).background(FausCrewColors.success.copy(alpha = .2f), CircleShape))
            Box(Modifier.size(90.dp).graphicsLayer { val s = 1.2f - .2f * phase; scaleX = s; scaleY = s }
                .blur(15.dp).background(FausCrewColors.secondary.copy(alpha = .3f), CircleShape))
            Icon(FausCrewIcons.checkmarkSealFill, null,
                Modifier.size(56.dp).rotate(-5f + 10f * phase)
                    .gradientForeground(Brush.linearGradient(listOf(FausCrewColors.success, FausCrewColors.secondary))),
                tint = Color.White)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(strings.get("todays_tasks_empty_title"), style = FausCrewType.title3, color = FausCrewColors.textPrimary)
            Text(strings.get("todays_tasks_empty_subtitle"), style = FausCrewType.subheadline,
                color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
        }
    }
}

/** `ModernChoreRow` with its pressed button style. */
@Composable
private fun ModernChoreRow(chore: HouseChore, assignee: HouseMember?, strings: LocalizedText, onTap: () -> Unit) {
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
