package com.houseflow.ui.dashboard

import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.HouseAnnouncement
import com.houseflow.platform.HouseMember
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow
import java.time.Instant

/** `AnnouncementCard`: collapsible active announcements with per-device read state. */
@Composable
internal fun AnnouncementCard(
    announcements: List<HouseAnnouncement>,
    members: List<HouseMember>,
    readIds: Set<String>,
    expanded: Boolean,
    strings: LocalizedText,
    onToggleExpanded: () -> Unit,
    onToggleRead: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val active = remember(announcements) { announcements.filter { it.isActive } }
    val sorted = remember(active, readIds) {
        active.sortedWith(compareBy<HouseAnnouncement> { it.id in readIds }
            .thenByDescending { parseApiDate(it.createdOn)?.toInstant() ?: Instant.MIN })
    }
    val unread = active.count { it.id !in readIds }
    val shape = RoundedCornerShape(Radius.xl)
    val borderColor by animateColorAsState(
        if (expanded) HouseFlowColors.purple.copy(alpha = .30f) else HouseFlowColors.indigo.copy(alpha = .13f),
        Motion.expand(), label = "announcementBorder",
    )
    val shadowRadius by animateDpAsState(if (expanded) 16.dp else 10.dp, Motion.expand(), label = "announcementShadow")
    Column(
        modifier.fillMaxWidth()
            .softShadow(HouseFlowColors.deepIndigo.copy(alpha = if (expanded) .13f else .07f), shadowRadius,
                y = if (expanded) 7.dp else 4.dp, shape = shape)
            .clip(shape)
            .background(HouseFlowColors.surface)
            .background(Brush.linearGradient(listOf(
                HouseFlowColors.purple.copy(alpha = .075f), HouseFlowColors.teal.copy(alpha = .035f), Color.Transparent,
            )))
            .border(1.dp, borderColor, shape)
            .animateContentSize(Motion.expand()),
    ) {
        AnnouncementHeader(active.size, unread, expanded, strings, onToggleExpanded)
        AnimatedVisibility(expanded, enter = fadeIn() + expandVertically(Motion.expand()),
            exit = fadeOut() + shrinkVertically(Motion.expand())) {
            Column {
                HorizontalDivider(Modifier.padding(horizontal = Spacing.xl), thickness = .5.dp, color = HouseFlowColors.separator)
                if (sorted.isEmpty()) {
                    Column(Modifier.fillMaxWidth().padding(vertical = Spacing.xxxl, horizontal = Spacing.xl),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        Icon(HouseFlowIcons.megaphone, null, Modifier.size(32.dp), tint = HouseFlowColors.indigo.copy(alpha = .55f))
                        Text(emptyTitle(strings), style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary,
                            textAlign = TextAlign.Center)
                    }
                } else {
                    Column(Modifier.padding(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        sorted.forEach { item ->
                            AnnouncementRow(item, members, item.id in readIds, strings) { onToggleRead(item.id) }
                        }
                    }
                }
            }
        }
    }
}

private fun emptyTitle(strings: LocalizedText) =
    strings.get("announcement_empty_title", "There are no active announcements.")

@Composable
private fun AnnouncementHeader(count: Int, unread: Int, expanded: Boolean, strings: LocalizedText, onClick: () -> Unit) {
    val rotation by animateFloatAsState(if (expanded) 180f else 0f, Motion.expand(), label = "chevron")
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(Spacing.xl),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(Modifier.size(46.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(46.dp).background(
                Brush.linearGradient(listOf(HouseFlowColors.purple, HouseFlowColors.indigo)), RoundedCornerShape(12.dp)))
            Icon(HouseFlowIcons.megaphoneFill, null, Modifier.size(23.dp), tint = Color.White)
            AccentDot(7.dp, HouseFlowColors.surface, Modifier.offset((-17).dp, 17.dp))
            if (unread > 0) {
                Box(
                    Modifier.offset(18.dp, (-18).dp).background(HouseFlowColors.surface, CircleShape).padding(2.dp)
                        .defaultMinSize(18.dp, 18.dp).background(HouseFlowColors.accentOrange, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(unread.toString(), Modifier.padding(horizontal = 4.dp), color = Color.White,
                        fontSize = 9.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(strings.get("announcement_title"), style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
            val subtitle = if (count == 0) emptyTitle(strings) else
                strings.template("announcement_count_template", "count" to count.toString(),
                    fallback = "{count} active announcements")
            Text(subtitle, style = HouseFlowType.caption, color = HouseFlowColors.textSecondary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Box(Modifier.size(32.dp).background(HouseFlowColors.indigo.copy(alpha = .10f), CircleShape),
            contentAlignment = Alignment.Center) {
            Icon(HouseFlowIcons.chevronDown, null, Modifier.size(22.dp).rotate(rotation), tint = HouseFlowColors.indigo)
        }
    }
}

@Composable
private fun AnnouncementRow(
    item: HouseAnnouncement,
    members: List<HouseMember>,
    read: Boolean,
    strings: LocalizedText,
    onToggleRead: () -> Unit,
) {
    val haptics = LocalHapticFeedback.current
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        Modifier.fillMaxWidth().clip(shape)
            .background(if (read) HouseFlowColors.background.copy(alpha = .68f) else HouseFlowColors.indigo.copy(alpha = .055f))
            .border(1.dp, if (read) HouseFlowColors.teal.copy(alpha = .10f) else HouseFlowColors.indigo.copy(alpha = .18f), shape)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(Modifier.padding(top = 6.dp).size(8.dp).background(
                if (read) HouseFlowColors.teal.copy(alpha = .45f) else HouseFlowColors.accentOrange, CircleShape))
            Text(item.title, fontSize = 15.sp, fontWeight = if (read) FontWeight.SemiBold else FontWeight.Bold,
                color = if (read) HouseFlowColors.textSecondary else HouseFlowColors.textPrimary)
        }
        Text(item.message, style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary)
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                MetaLine(HouseFlowIcons.clock, displayApiDateTime(item.createdOn), HouseFlowColors.textTertiary,
                    HouseFlowColors.textTertiary)
                val publisher = item.publisherName?.takeIf(String::isNotBlank)
                    ?: members.firstOrNull { it.id == item.publisherId }?.name
                if (!publisher.isNullOrBlank()) {
                    MetaLine(HouseFlowIcons.personCropCircleFill,
                        strings.template("announcement_published_by_template", "name" to publisher,
                            fallback = "Published by {name}"),
                        HouseFlowColors.deepIndigo, HouseFlowColors.accentOrangeInk)
                }
            }
            Spacer(Modifier.width(Spacing.sm))
            val tint = if (read) HouseFlowColors.deepTeal else HouseFlowColors.indigo
            Row(
                Modifier.clip(CircleShape)
                    .background(if (read) HouseFlowColors.teal.copy(alpha = .12f) else HouseFlowColors.indigo.copy(alpha = .10f))
                    .clickable {
                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        onToggleRead()
                    }
                    .padding(horizontal = Spacing.sm, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Icon(if (read) HouseFlowIcons.checkmarkCircleFill else HouseFlowIcons.circle, null, Modifier.size(15.dp), tint = tint)
                Text(if (read) strings.get("announcement_read_label", "Read")
                    else strings.get("announcement_mark_read_button", "Mark as read"),
                    style = HouseFlowType.caption, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1)
            }
        }
    }
}

@Composable
private fun MetaLine(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, color: Color, iconColor: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Icon(icon, null, Modifier.size(13.dp), tint = iconColor)
        Text(text, style = HouseFlowType.caption, color = color, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** `AnnouncementReadStore`: read ids per user and house, kept on this device only. */
internal class AnnouncementReadStore(context: Context) {
    private val prefs = context.getSharedPreferences("houseflow.read-announcements", Context.MODE_PRIVATE)
    private fun key(houseId: String, userId: String) = "$userId:$houseId"
    fun load(houseId: String, userId: String): Set<String> =
        prefs.getStringSet(key(houseId, userId), emptySet())?.toSet() ?: emptySet()
    fun save(houseId: String, userId: String, ids: Set<String>) {
        prefs.edit().putStringSet(key(houseId, userId), ids.toSet()).apply()
    }
}
