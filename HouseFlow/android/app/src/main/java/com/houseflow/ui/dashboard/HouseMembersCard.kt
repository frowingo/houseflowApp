package com.houseflow.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.HouseMember
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.UserAvatar
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow

private val MemberTints = listOf(HouseFlowColors.indigo, HouseFlowColors.teal, HouseFlowColors.purple, HouseFlowColors.blue)

/** `HouseMembersCard`: cool-toned member carousel. */
@Composable
internal fun HouseMembersCard(members: List<HouseMember>, strings: LocalizedText, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.fillMaxWidth()
            .softShadow(HouseFlowColors.deepIndigo.copy(alpha = .09f), 14.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(HouseFlowColors.surface)
            .background(Brush.linearGradient(listOf(
                HouseFlowColors.indigo.copy(alpha = .075f), HouseFlowColors.teal.copy(alpha = .035f), Color.Transparent,
            )))
            .drawBehind {
                drawCircle(HouseFlowColors.purple.copy(alpha = .055f), 75.dp.toPx(),
                    Offset(size.width / 2 + 150.dp.toPx(), size.height / 2 - 70.dp.toPx()))
            }
            .border(1.dp, Brush.linearGradient(listOf(
                HouseFlowColors.indigo.copy(alpha = .24f), HouseFlowColors.teal.copy(alpha = .12f),
            )), shape)
            .padding(vertical = Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        Row(Modifier.padding(horizontal = Spacing.xl), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(Modifier.size(42.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(42.dp).background(
                    Brush.linearGradient(listOf(HouseFlowColors.teal, HouseFlowColors.indigo)), RoundedCornerShape(11.dp)))
                Icon(HouseFlowIcons.person3Fill, null, Modifier.size(24.dp), tint = Color.White)
                AccentDot(7.dp, HouseFlowColors.surface, Modifier.offset(15.dp, 15.dp))
            }
            Text(strings.get("house_members_title"), Modifier.weight(1f), style = HouseFlowType.headline,
                color = HouseFlowColors.textPrimary)
            Row(
                Modifier.defaultMinSize(minHeight = 26.dp).background(HouseFlowColors.indigo.copy(alpha = .10f), CircleShape)
                    .padding(horizontal = Spacing.sm),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Box(Modifier.size(5.dp).background(HouseFlowColors.accentOrange, CircleShape))
                Text(members.size.toString(), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = HouseFlowColors.deepIndigo)
            }
        }
        if (members.isEmpty()) {
            Row(Modifier.fillMaxWidth().padding(Spacing.xl), horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically) {
                Icon(HouseFlowIcons.person3Fill, null, Modifier.size(26.dp), tint = HouseFlowColors.indigo.copy(alpha = .55f))
                Text(strings.get("house_members_empty_message", "No house members to show yet."),
                    Modifier.padding(start = Spacing.md), style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary)
            }
        } else {
            // Edge-to-edge like `.scrollClipDisabled()`: tiles slide under the card padding.
            LazyRow(contentPadding = PaddingValues(horizontal = Spacing.xl + 2.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                itemsIndexed(members, key = { _, member -> member.id }) { index, member ->
                    MemberTile(member, MemberTints[index % MemberTints.size])
                }
            }
        }
    }
}

@Composable
private fun MemberTile(member: HouseMember, tint: Color) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        Modifier.size(108.dp, 124.dp)
            .softShadow(tint.copy(alpha = .08f), 7.dp, y = 3.dp, shape = shape)
            .clip(shape)
            .background(tint.copy(alpha = .075f))
            .border(1.dp, tint.copy(alpha = .15f), shape)
            .padding(horizontal = Spacing.sm, vertical = Spacing.md),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(Modifier.size(62.dp)) {
            Box(Modifier.size(62.dp).border(2.5.dp, Brush.sweepGradient(listOf(
                tint.copy(alpha = .35f), tint, HouseFlowColors.accentOrange.copy(alpha = .65f), tint.copy(alpha = .35f),
            )), CircleShape))
            UserAvatar(member, 52.dp, Modifier.align(Alignment.Center))
            Box(
                Modifier.align(Alignment.BottomEnd).offset(1.dp, 1.dp).size(21.dp)
                    .background(HouseFlowColors.surface, CircleShape).padding(3.dp).background(tint, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(HouseFlowIcons.houseFill, null, Modifier.size(9.dp), tint = Color.White)
            }
        }
        Text(member.name, Modifier.fillMaxWidth().defaultMinSize(minHeight = 30.dp), fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold, color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center,
            maxLines = 2, overflow = TextOverflow.Ellipsis, lineHeight = 15.sp)
    }
}
