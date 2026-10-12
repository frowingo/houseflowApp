package com.houseflow.ui.dashboard

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.HouseChore
import com.houseflow.platform.HouseMember
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.UserAvatar
import com.houseflow.ui.theme.HouseFlowBrushes
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.gradientForeground
import com.houseflow.ui.theme.softShadow
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
    val completed = chores.count { it.status == ChoreStatusUi.COMPLETED.raw }
    val progress = if (chores.isEmpty()) 0f else completed.toFloat() / chores.size
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.fillMaxWidth()
            .softShadow(Color.Black.copy(alpha = .12f), 16.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(HouseFlowColors.cardBackground)
            .background(Brush.linearGradient(listOf(
                HouseFlowColors.primary.copy(alpha = .05f), Color.Transparent, HouseFlowColors.secondary.copy(alpha = .05f),
            )))
            .border(1.dp, Brush.linearGradient(listOf(
                HouseFlowColors.primary.copy(alpha = .3f), HouseFlowColors.secondary.copy(alpha = .3f),
            )), shape),
    ) {
        ChoresHeader(strings, completed, chores.size, progress)
        HorizontalDivider(Modifier.padding(horizontal = Spacing.xl), thickness = .5.dp, color = HouseFlowColors.separator)
        if (chores.isEmpty()) {
            ChoresEmptyState(strings)
        } else {
            Column(Modifier.padding(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                chores.forEach { chore ->
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
                }.background(HouseFlowBrushes.indigoTeal, CircleShape))
                Icon(HouseFlowIcons.listClipboardFill, null, Modifier.size(22.dp), tint = Color.White)
                AccentDot(8.dp, HouseFlowColors.cardBackground, Modifier.offset(16.dp, 16.dp))
            }
            Column(Modifier.weight(1f).padding(start = Spacing.sm), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(strings.get("todays_tasks_title"), style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
                if (total > 0) {
                    Text(strings.template("todays_tasks_completed_template",
                        "completed" to completed.toString(), "total" to total.toString()),
                        style = HouseFlowType.caption, color = HouseFlowColors.textSecondary)
                }
            }
            if (total > 0) CircularProgress(progress, strings, Modifier.size(50.dp))
        }
        if (total > 0) {
            val animated by animateFloatAsState(progress, Motion.spring(), label = "choreProgress")
            Box(Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(Radius.sm))
                .background(HouseFlowColors.textSecondary.copy(alpha = .2f))) {
                Box(Modifier.fillMaxHeight().fillMaxWidth(animated.coerceIn(0f, 1f))
                    .clip(RoundedCornerShape(Radius.sm))
                    .background(Brush.horizontalGradient(listOf(HouseFlowColors.indigo, HouseFlowColors.teal))))
            }
        }
    }
}

/** Small brand-orange dot with a ring in the card color, used on the dashboard icon tiles. */
@Composable
internal fun AccentDot(size: androidx.compose.ui.unit.Dp, ring: Color, modifier: Modifier = Modifier, ringWidth: androidx.compose.ui.unit.Dp = 1.5.dp) {
    Box(modifier.size(size + ringWidth * 2).background(ring, CircleShape).padding(ringWidth)
        .background(HouseFlowColors.accentOrange, CircleShape))
}

/** `CircularProgressView`. */
@Composable
private fun CircularProgress(progress: Float, strings: LocalizedText, modifier: Modifier) {
    val animated by animateFloatAsState(progress, Motion.spring(), label = "ring")
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(50.dp)) {
            val stroke = 4.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(HouseFlowColors.textSecondary.copy(alpha = .2f), 0f, 360f, false,
                Offset(inset, inset), arcSize, style = Stroke(stroke))
            drawArc(Brush.linearGradient(listOf(HouseFlowColors.indigo, HouseFlowColors.teal)),
                -90f, 360f * animated.coerceIn(0f, 1f), false, Offset(inset, inset), arcSize,
                style = Stroke(stroke, cap = StrokeCap.Round))
        }
        Text(strings.template("progress_percent_template", "percent" to (progress * 100).toInt().toString(),
            fallback = "{percent}%"), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = HouseFlowColors.deepIndigo)
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
                .blur(20.dp).background(HouseFlowColors.success.copy(alpha = .2f), CircleShape))
            Box(Modifier.size(90.dp).graphicsLayer { val s = 1.2f - .2f * phase; scaleX = s; scaleY = s }
                .blur(15.dp).background(HouseFlowColors.secondary.copy(alpha = .3f), CircleShape))
            Icon(HouseFlowIcons.checkmarkSealFill, null,
                Modifier.size(56.dp).rotate(-5f + 10f * phase)
                    .gradientForeground(Brush.linearGradient(listOf(HouseFlowColors.success, HouseFlowColors.secondary))),
                tint = Color.White)
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(strings.get("todays_tasks_empty_title"), style = HouseFlowType.title3, color = HouseFlowColors.textPrimary)
            Text(strings.get("todays_tasks_empty_subtitle"), style = HouseFlowType.subheadline,
                color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
        }
    }
}

/** `ModernChoreRow` with its pressed button style. */
@Composable
private fun ModernChoreRow(chore: HouseChore, assignee: HouseMember?, strings: LocalizedText, onTap: () -> Unit) {
    val status = ChoreStatusUi.of(chore.status)
    val completed = status == ChoreStatusUi.COMPLETED
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
            .background(HouseFlowColors.background)
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
                Brush.linearGradient(listOf(HouseFlowColors.success, HouseFlowColors.secondary))
            } else {
                Brush.linearGradient(listOf(status.color, status.color.copy(alpha = .6f)))
            }
            if (completed) {
                Icon(HouseFlowIcons.checkmarkCircleFill, null, Modifier.size(28.dp).gradientForeground(glyphBrush),
                    tint = Color.White)
            } else {
                ChoreStatusGlyph(status, 26.dp, glyphBrush, Modifier.rotate(-15f))
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(chore.title, style = HouseFlowType.bodyBold,
                color = if (completed) HouseFlowColors.textSecondary else HouseFlowColors.textPrimary,
                textDecoration = if (completed) TextDecoration.LineThrough else null,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                UserAvatar(assignee, 20.dp)
                Text(assignee?.name ?: strings.get("common_unassigned"), Modifier.weight(1f),
                    style = HouseFlowType.caption, color = HouseFlowColors.textSecondary,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
                StatusBadge(status, strings)
            }
        }
        Box(Modifier.size(26.dp).background(status.color.copy(alpha = .10f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(HouseFlowIcons.chevronRight, null, Modifier.size(18.dp), tint = status.color.copy(alpha = .72f))
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
        Text(strings.get(status.key), style = HouseFlowType.caption, fontWeight = FontWeight.Medium,
            color = status.color, maxLines = 1)
    }
}
