package com.fauscrew.ui.dashboard.notifications

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.NotificationItem
import com.fauscrew.ui.components.UserAvatar
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing

/**
 * One notification: sender avatar and name, kind icon, title, message and relative time. An accent
 * bar on the left marks what is newer than the last time the panel was open.
 */
@Composable
internal fun NotificationRow(
    item: NotificationItem,
    /** Null when the sender is no longer in the house. */
    sender: HouseMember?,
    formerMemberLabel: String,
    isUnread: Boolean,
    timeText: String,
    onClick: () -> Unit,
) {
    val accent = FausCrewColors.accentOrange
    val shape = RoundedCornerShape(Radius.lg)
    Box(
        Modifier.fillMaxWidth().clip(shape)
            .background(if (isUnread) accent.copy(alpha = .08f) else FausCrewColors.secondaryBackground)
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) {},
    ) {
        if (isUnread) {
            Box(Modifier.padding(start = 6.dp, top = Spacing.md, bottom = Spacing.md).width(4.dp).fillMaxHeight()
                .background(accent, CircleShape).align(Alignment.CenterStart))
        }
        Row(
            Modifier.fillMaxWidth().padding(start = Spacing.lg + 4.dp, top = Spacing.lg, end = Spacing.lg, bottom = Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            if (sender != null) UserAvatar(sender, 36.dp) else GenericAvatar()
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(sender?.name?.ifBlank { null } ?: formerMemberLabel, Modifier.weight(1f),
                        style = FausCrewType.caption, fontWeight = FontWeight.SemiBold,
                        color = FausCrewColors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.width(Spacing.sm))
                    Text(timeText, style = FausCrewType.caption2, color = FausCrewColors.textTertiary, maxLines = 1)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(kindIcon(item), null, Modifier.padding(top = 3.dp).size(14.dp), tint = FausCrewColors.accentOrangeInk)
                    Text(item.title, fontSize = 15.sp, lineHeight = 20.sp,
                        fontWeight = if (isUnread) FontWeight.Bold else FontWeight.SemiBold, color = FausCrewColors.textPrimary)
                }
                Text(item.message, style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
            }
        }
    }
}

/** Unknown kinds get the bell. */
private fun kindIcon(item: NotificationItem): ImageVector =
    if (item.type == "announcement") FausCrewIcons.megaphoneFill else FausCrewIcons.bellFill

@Composable
private fun GenericAvatar() {
    Box(Modifier.size(36.dp).background(FausCrewColors.systemGray4, CircleShape), contentAlignment = Alignment.Center) {
        Icon(FausCrewIcons.personFill, null, Modifier.size(16.dp), tint = FausCrewColors.textTertiary)
    }
}

/** A placeholder row in the shape of [NotificationRow] while the first page loads. */
@Composable
internal fun NotificationSkeletonRow() {
    val pulse by rememberInfiniteTransition(label = "skeleton").animateFloat(
        1f, .55f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse")
    val bar = FausCrewColors.textTertiary.copy(alpha = .16f)
    Row(
        Modifier.fillMaxWidth().alpha(pulse).clip(RoundedCornerShape(Radius.lg)).background(FausCrewColors.secondaryBackground)
            .padding(start = Spacing.lg + 4.dp, top = Spacing.lg, end = Spacing.lg, bottom = Spacing.lg)
            .clearAndSetSemantics {},
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(Modifier.size(36.dp).background(bar, CircleShape))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.width(90.dp).height(10.dp).background(bar, RoundedCornerShape(4.dp)))
            Box(Modifier.fillMaxWidth().height(14.dp).background(bar, RoundedCornerShape(5.dp)))
            Box(Modifier.width(160.dp).height(10.dp).background(bar.copy(alpha = bar.alpha * .7f), RoundedCornerShape(4.dp)))
        }
    }
}

/** An icon, a message and, when [onClick] is set, the whole card as a retry button. */
@Composable
internal fun NotificationStatusCard(icon: ImageVector, tint: Color, text: String, onClick: (() -> Unit)? = null) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(FausCrewColors.secondaryBackground)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = Spacing.xxl, horizontal = Spacing.lg).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(Modifier.size(60.dp).background(tint.copy(alpha = .12f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(24.dp), tint = tint)
        }
        Text(text, style = FausCrewType.subheadline, color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
    }
}
