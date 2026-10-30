package com.fauscrew.ui.profile

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseSummary
import com.fauscrew.ui.components.BrandHeroCard
import com.fauscrew.ui.components.FausHouseIcon
import com.fauscrew.ui.components.HouseThumbnail
import com.fauscrew.ui.components.RemoteImage
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow

/** Tints from ProfileCards.swift / ProfileHouseInformationCard.swift. */
internal object ProfileTints {
    val account = Color(0xFF268CD9)
    val phone = Color(0xFF33B366)
    val memberSince = Color(0xFF8C59E6)
    val verified = Color(0xFF33BF73)
    val personalTeal = Color(0xFF338085)
    val personalSage = Color(0xFF5E9E80)
    val personalSlate = Color(0xFF5C7A9C)
    val house = Color(0xFF6B45AB)
    val join = Color(0xFF1F8C8A)
    val create = Color(0xFFE5620F)
    val notifications = Color(0xFFF2731A)
    val privacy = Color(0xFF598CE0)
    val theme = Color(0xFFD94A80)
}

/** `ProfileHeroSection`: brand card with the pulsing avatar ring and the full name. */
@Composable
internal fun ProfileHeroSection(
    imageUrl: String,
    initials: String,
    fullName: String,
    avatarDescription: String,
    onAvatarTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    BrandHeroCard(modifier.fillMaxWidth().height(112.dp), contentAlignment = Alignment.CenterStart) {
        Row(Modifier.padding(horizontal = Spacing.xl), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.lg)) {
            ProfileHeroAvatar(imageUrl, initials, avatarDescription, onAvatarTap)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                BasicText(fullName, style = TextStyle(color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 16.sp, maxFontSize = 23.sp))
                Box(Modifier.size(76.dp, 3.dp).background(
                    Brush.horizontalGradient(listOf(Color.White.copy(alpha = .92f), Color.White.copy(alpha = .18f))), CircleShape))
            }
        }
    }
}

@Composable
private fun ProfileHeroAvatar(imageUrl: String, initials: String, description: String, onTap: () -> Unit) {
    val pulse by rememberInfiniteTransition(label = "avatarPulse")
        .animateFloat(.55f, 1f, infiniteRepeatable(tween(2_000), RepeatMode.Reverse), label = "ring")
    val fallback = Brush.linearGradient(listOf(Color(0xFFF27F14), Color(0xFFC75208)))
    Box(
        Modifier.size(84.dp)
            .softShadow(FausCrewColors.shadow.copy(alpha = .22f), 12.dp, y = 6.dp, shape = CircleShape)
            .clip(CircleShape)
            .clickable(role = Role.Button, onClick = onTap)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.fillMaxSize().alpha(pulse).border(3.dp, Brush.sweepGradient(listOf(
            Color(0xFFFFC766), FausCrewColors.brandOrange, Color(0xFFA6330D), Color(0xFFFFC766),
        )), CircleShape))
        Box(Modifier.size(74.dp).background(FausCrewColors.surface, CircleShape))
        RemoteImage(imageUrl, Modifier.size(74.dp).clip(CircleShape)) {
            Box(Modifier.fillMaxSize().background(fallback), contentAlignment = Alignment.Center) {
                if (imageUrl.isBlank()) {
                    Text(initials, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

/** `ProfileModernCard`: tinted header chip, uppercase title, divider and rows. */
@Composable
internal fun ProfileModernCard(
    headerIcon: ImageVector,
    headerTint: Color,
    title: String,
    gradient: List<Color>,
    modifier: Modifier = Modifier,
    uppercaseTitle: Boolean = true,
    borderColors: List<Color> = listOf(headerTint.copy(alpha = .3f), FausCrewColors.textTertiary.copy(alpha = .1f)),
    trailing: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.fillMaxWidth()
            .softShadow(FausCrewColors.shadow.copy(alpha = .12f), 16.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.cardBackground)
            .background(Brush.linearGradient(gradient))
            .border(1.dp, Brush.linearGradient(borderColors), shape),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.md, bottom = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Box(Modifier.size(28.dp).background(headerTint.copy(alpha = .14f), RoundedCornerShape(7.dp)),
                contentAlignment = Alignment.Center) {
                Icon(headerIcon, null, Modifier.size(16.dp), tint = headerTint)
            }
            Text(if (uppercaseTitle) title.uppercase() else title, Modifier.weight(1f), fontSize = 11.sp,
                fontWeight = FontWeight.Bold, color = FausCrewColors.textTertiary, letterSpacing = .9.sp, maxLines = 1)
            trailing?.invoke()
        }
        HorizontalDivider(Modifier.padding(horizontal = Spacing.lg), thickness = .5.dp, color = FausCrewColors.separator)
        content()
    }
}

@Composable
internal fun ProfileRowIcon(icon: ImageVector, tint: Color) {
    Box(Modifier.size(34.dp).background(tint.copy(alpha = .13f), RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(18.dp), tint = tint)
    }
}

/** `ProfileCardDivider`: inset past the row icon. */
@Composable
internal fun ProfileCardDivider() {
    HorizontalDivider(Modifier.padding(start = 66.dp), thickness = .5.dp, color = FausCrewColors.separator)
}

@Composable
internal fun ProfileInfoRow(icon: ImageVector, tint: Color, label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        ProfileRowIcon(icon, tint)
        Text(label, style = FausCrewType.subheadline, color = FausCrewColors.textPrimary)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = FausCrewColors.textSecondary,
            maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
internal fun ProfileCommunicationRow(
    icon: ImageVector,
    tint: Color,
    label: String,
    value: String,
    isVerified: Boolean,
    verificationLabel: String,
    onVerificationTap: (() -> Unit)? = null,
) {
    Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        ProfileRowIcon(icon, tint)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = FausCrewColors.textTertiary)
            BasicText(value, style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, color = FausCrewColors.textPrimary),
                maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 10.5.sp, maxFontSize = 14.sp))
        }
        val iconModifier = if (onVerificationTap != null) {
            Modifier.size(34.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onVerificationTap)
        } else Modifier
        Box(iconModifier.semantics { contentDescription = verificationLabel }, contentAlignment = Alignment.Center) {
            Icon(if (isVerified) FausCrewIcons.checkmarkCircleFill else FausCrewIcons.xmarkCircleFill, null,
                Modifier.size(23.dp), tint = if (isVerified) ProfileTints.verified else FausCrewColors.error)
        }
    }
}

@Composable
internal fun ProfileSettingsRow(icon: ImageVector, tint: Color, label: String, value: String? = null, onClick: (() -> Unit)? = null) {
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button) { onClick?.invoke() }
            .padding(horizontal = Spacing.lg, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        ProfileRowIcon(icon, tint)
        Text(label, Modifier.weight(1f), style = FausCrewType.subheadline, color = FausCrewColors.textPrimary)
        // Current choice before the chevron (e.g. the active theme).
        value?.let { Text(it, style = FausCrewType.caption, color = FausCrewColors.textTertiary, maxLines = 1) }
        Icon(FausCrewIcons.chevronRight, null, Modifier.size(18.dp), tint = FausCrewColors.textTertiary)
    }
}

/** `ProfileHouseInformationCard`: one row per house with a View pill, then Join / Create a house. */
@Composable
internal fun ProfileHouseInformationCard(
    title: String,
    houses: List<HouseSummary>,
    emptyMessage: String,
    viewTitle: String,
    joinTitle: String,
    joinSubtitle: String,
    createTitle: String,
    createSubtitle: String,
    showsAddHouseOptions: Boolean,
    onSelect: (HouseSummary) -> Unit,
    onJoin: () -> Unit,
    onCreate: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tint = ProfileTints.house
    ProfileModernCard(FausCrewIcons.houseFill, tint, title, listOf(tint.copy(alpha = .07f), Color.Transparent), modifier) {
        if (houses.isEmpty()) {
            Row(Modifier.fillMaxWidth().padding(Spacing.lg), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                ProfileRowIcon(FausCrewIcons.houseFill, tint)
                Text(emptyMessage, style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
            }
        }
        houses.forEachIndexed { index, house ->
            Row(
                Modifier.fillMaxWidth().clickable(role = Role.Button, onClickLabel = viewTitle) { onSelect(house) }
                    .padding(horizontal = Spacing.lg, vertical = 11.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                HouseThumbnail(house.profileImage, 44.dp)
                Text(house.name, Modifier.weight(1f), style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold,
                    color = FausCrewColors.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Row(
                    Modifier.defaultMinSize(minHeight = 30.dp).background(tint.copy(alpha = .11f), CircleShape)
                        .padding(horizontal = 10.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Text(viewTitle, style = FausCrewType.caption, fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
                    Icon(FausCrewIcons.chevronRight, null, Modifier.size(14.dp), tint = FausCrewColors.textPrimary)
                }
            }
            if (index < houses.lastIndex) ProfileCardDivider()
        }
        if (showsAddHouseOptions) {
            ProfileCardDivider()
            HouseActionRow(joinTitle, joinSubtitle, ProfileTints.join, FausCrewIcons.chevronRight, onJoin) {
                ProfileRowIcon(FausCrewIcons.person2BadgePlus, ProfileTints.join)
            }
            ProfileCardDivider()
            HouseActionRow(createTitle, createSubtitle, ProfileTints.create, FausCrewIcons.plus, onCreate) {
                Box(Modifier.size(34.dp).background(ProfileTints.create.copy(alpha = .13f), RoundedCornerShape(8.dp)),
                    contentAlignment = Alignment.Center) {
                    FausHouseIcon(19.dp, color = ProfileTints.create)
                }
            }
        }
    }
}

@Composable
private fun HouseActionRow(
    title: String,
    subtitle: String,
    tint: Color,
    trailingIcon: ImageVector,
    onClick: () -> Unit,
    icon: @Composable () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        icon()
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
            Text(subtitle, style = FausCrewType.caption, color = FausCrewColors.textSecondary, maxLines = 2)
        }
        Spacer(Modifier.width(Spacing.sm))
        Box(Modifier.size(32.dp).background(tint.copy(alpha = .11f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(trailingIcon, null, Modifier.size(18.dp), tint = tint)
        }
    }
}

/** Personal info header action: the round pencil button. */
@Composable
internal fun ProfileEditButton(description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(30.dp).clip(CircleShape).background(ProfileTints.personalTeal.copy(alpha = .12f))
            .clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(FausCrewIcons.pencil, null, Modifier.size(15.dp), tint = ProfileTints.personalTeal)
    }
}
