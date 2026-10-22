package com.fauscrew.ui.profile

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import android.content.Intent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseInfo
import com.fauscrew.platform.HouseInfoMember
import com.fauscrew.platform.HouseInvite
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.components.HouseThumbnail
import com.fauscrew.ui.components.PopupCloseButton
import com.fauscrew.ui.components.PopupFooter
import com.fauscrew.ui.components.PopupPrimaryButton
import com.fauscrew.ui.components.PopupSecondaryButton
import com.fauscrew.ui.components.RemoteImage
import com.fauscrew.ui.components.brandPopupHeaderBackground
import com.fauscrew.ui.house.HouseJourneyBrushes
import com.fauscrew.ui.house.HouseTypeUi
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Motion
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Sizes
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.viewmodel.HouseUiState
import com.fauscrew.viewmodel.ProfileUiState
import kotlinx.coroutines.delay

private val houseTint = ProfileTints.house
private val ownerTint = Color(0xFFEB782E)
private val inviteTint = ProfileTints.join
private const val NAME_LIMIT = 30

/**
 * `HouseInfoPopup`: overview, owner editing (name, member limit, profile image), members
 * with removal, the invite section and Save / Leave in the footer.
 */
@Composable
internal fun HouseInfoDialog(
    houseId: String,
    state: HouseUiState,
    profile: ProfileUiState,
    strings: LocalizedText,
    onDismiss: () -> Unit,
    onRetry: (String) -> Unit,
    onInvite: (String) -> Unit,
    onLoadImages: (String) -> Unit,
    onSave: (String, String, Int, String) -> Unit,
    onRemoveMember: (String, String) -> Unit,
    onLeave: (String) -> Unit,
) {
    val focus = LocalFocusManager.current
    val info = state.info.takeIf { state.infoHouseId == houseId }
    val isOwner = info != null && info.ownerId == state.userId
    val busy = state.profileActionBusy
    var name by remember(houseId) { mutableStateOf("") }
    var limit by remember(houseId) { mutableIntStateOf(2) }
    var image by remember(houseId) { mutableStateOf("") }
    var pendingRemoval by remember { mutableStateOf<HouseInfoMember?>(null) }
    var removingId by remember { mutableStateOf<String?>(null) }
    var leaveConfirmation by remember { mutableStateOf(false) }
    LaunchedEffect(info?.payload) {
        if (info != null) {
            name = info.houseName
            limit = maxOf(2, info.houseMemberCount, info.houseMemberCountLimit)
            image = info.houseProfileImage
        }
    }
    LaunchedEffect(isOwner) { if (isOwner) onLoadImages("house") }
    LaunchedEffect(busy) { if (!busy) removingId = null }
    val minimumLimit = maxOf(2, info?.houseMemberCount ?: 2)
    val maximumLimit = maxOf(8, minimumLimit)
    val canSave = info != null && isOwner && !busy && name.isNotBlank() &&
        (name.trim() != info.houseName || limit != info.houseMemberCountLimit || image != info.houseProfileImage)
    val canLeave = info != null && !isOwner && info.members.any { it.userId == state.userId }
    val dismiss = { focus.clearFocus(); onDismiss() }

    FausCrewPopup(
        onDismiss = dismiss,
        dismissEnabled = !busy,
        maxBodyHeight = 620.dp,
        horizontalInset = Spacing.lg,
        header = { InfoHeader(strings, state.infoBusy, isOwner, !busy, dismiss) },
        footer = {
            // iOS separates this footer with a hairline instead of a shadow.
            HorizontalDivider(thickness = .5.dp, color = FausCrewColors.separator)
            PopupFooter(shadow = false, padding = androidx.compose.foundation.layout.PaddingValues(Spacing.lg, Spacing.md)) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    PopupSecondaryButton(strings.profileValue(if (isOwner) "common_cancel" else "common_close"), !busy, dismiss,
                        Modifier.weight(1f))
                    when {
                        isOwner -> PopupPrimaryButton(
                            strings.profileValue(if (busy && removingId == null) "common_saving" else "common_save_changes"),
                            enabled = canSave, busy = busy && removingId == null, modifier = Modifier.weight(1f),
                            brush = HouseJourneyBrushes.primaryButton,
                            disabledBrush = Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = .42f), Color.Gray.copy(alpha = .32f))),
                            onClick = { focus.clearFocus(); onSave(houseId, name.trim(), limit, image) },
                        )
                        canLeave -> PopupPrimaryButton(
                            strings.get(if (busy) "house_info_leaving" else "house_info_leave_button",
                                if (busy) "Leaving…" else strings.profileValue("house_info_leave_button")),
                            enabled = !busy, busy = busy, modifier = Modifier.weight(1f), icon = FausCrewIcons.logout,
                            brush = SolidColor(FausCrewColors.error), onClick = { leaveConfirmation = true },
                        )
                    }
                }
            }
        },
        bodyPadding = Spacing.lg,
        bodySpacing = Spacing.xl,
    ) {
        when {
            state.infoBusy -> Column(Modifier.fillMaxWidth().padding(vertical = Spacing.huge),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                CircularProgressIndicator(color = ownerTint)
                Text(strings.profileValue("house_info_loading"), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
            }
            info == null -> Column(Modifier.fillMaxWidth().padding(Spacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                Icon(FausCrewIcons.exclamationmarkTriangleFill, null, Modifier.size(34.dp), tint = FausCrewColors.error)
                Text(state.profileError ?: strings.profileValue("house_info_loading"), style = FausCrewType.subheadline,
                    color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
                PopupPrimaryButton(strings.get("common_retry", "Try again"), true, { onRetry(houseId) },
                    icon = FausCrewIcons.arrowClockwise, brush = HouseJourneyBrushes.primaryButton,
                    modifier = Modifier.padding(horizontal = Spacing.xl))
            }
            else -> {
                Overview(info, isOwner, strings)
                if (isOwner) {
                    OwnerEditor(info, name, { name = it.take(NAME_LIMIT) }, limit, minimumLimit, maximumLimit, { limit = it }, strings)
                    val summaryImage = state.houses.firstOrNull { it.id == houseId }?.profileImage
                    val choices = (listOfNotNull(info.houseProfileImage, summaryImage) + profile.images.map { it.url })
                        .map(String::trim).filter(String::isNotEmpty).distinct()
                    ImagePicker(choices, image, profile.loadingImages, strings) { image = it }
                    state.profileError?.let { ErrorBanner(it) }
                } else {
                    ViewerDetails(info, strings)
                }
                MembersSection(info, state.userId, isOwner, busy, removingId, strings) { pendingRemoval = it }
                if (!isOwner) state.profileError?.let { ErrorBanner(it) }
                if (isOwner && info.houseMemberCount < info.houseMemberCountLimit) {
                    InviteSection(houseId, info.houseName, state.invite, state.inviteBusy, strings, onInvite)
                }
            }
        }
    }

    pendingRemoval?.let { member ->
        ConfirmDialog(strings.profileValue("house_info_remove_confirmation_title"), member.name,
            strings.profileValue("house_info_remove_member_button"), strings,
            onConfirm = { pendingRemoval = null; removingId = member.userId; onRemoveMember(houseId, member.userId) },
            onDismiss = { pendingRemoval = null })
    }
    if (leaveConfirmation) {
        ConfirmDialog(strings.profileValue("house_info_leave_confirmation_title"),
            strings.get("house_info_leave_confirmation_message", "You will need a new invite code to join this house again."),
            strings.profileValue("house_info_leave_button"), strings,
            onConfirm = { leaveConfirmation = false; onLeave(houseId); onDismiss() },
            onDismiss = { leaveConfirmation = false })
    }
}

@Composable
private fun InfoHeader(strings: LocalizedText, loading: Boolean, isOwner: Boolean, closeEnabled: Boolean, onClose: () -> Unit) {
    val subtitle = when {
        loading -> strings.profileValue("common_loading")
        isOwner -> strings.get("house_info_owner_subtitle", "Manage details and members")
        else -> strings.get("house_info_viewer_subtitle", "View house details")
    }
    Box(Modifier.fillMaxWidth().height(64.dp).brandPopupHeaderBackground(), contentAlignment = Alignment.Center) {
        Icon(FausCrewIcons.houseFill, null, Modifier.offset(x = 85.dp).size(60.dp), tint = Color.White.copy(alpha = .12f))
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.xl), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(Modifier.size(34.dp).background(Color.White.copy(alpha = .18f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(FausCrewIcons.houseFill, null, Modifier.size(18.dp), tint = Color.White)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(strings.profileValue("house_info_title"), style = FausCrewType.subheadline, fontWeight = FontWeight.Bold,
                    color = Color.White)
                Text(subtitle, style = FausCrewType.caption2, color = Color.White.copy(alpha = .76f), maxLines = 1)
            }
            PopupCloseButton(onClose, closeEnabled, strings.profileValue("common_close"), size = 28.dp, backgroundAlpha = .18f)
        }
    }
}

private fun LocalizedText.memberCount(info: HouseInfo) =
    "${info.houseMemberCount} / ${info.houseMemberCountLimit} " + get("house_info_members_label", "members").lowercase()

private fun LocalizedText.houseType(type: Int): Pair<String, ImageVector> {
    val ui = HouseTypeUi.of(type)
    return (ui?.let { get(it.key) } ?: profileValue("house_info_type_unknown")) to (ui?.icon ?: FausCrewIcons.houseFill)
}

@Composable
private fun Overview(info: HouseInfo, isOwner: Boolean, strings: LocalizedText) {
    val (typeLabel, typeIcon) = strings.houseType(info.houseType)
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.lg)).background(FausCrewColors.secondaryBackground)
            .padding(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        HouseThumbnail(info.houseProfileImage, 72.dp, RoundedCornerShape(20.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(info.houseName, style = FausCrewType.title3, fontWeight = FontWeight.Bold, color = FausCrewColors.textPrimary,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
            IconLabel(typeIcon, typeLabel, FausCrewColors.textSecondary)
            Text(strings.memberCount(info), style = FausCrewType.caption, fontWeight = FontWeight.SemiBold,
                color = FausCrewColors.textPrimary)
        }
        if (isOwner) {
            Row(
                Modifier.defaultMinSize(minHeight = 28.dp).background(ownerTint.copy(alpha = .11f), CircleShape)
                    .padding(horizontal = 10.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Icon(FausCrewIcons.crownFill, null, Modifier.size(15.dp), tint = FausCrewColors.textPrimary)
                Text(strings.profileValue("house_info_owner_badge"), style = FausCrewType.caption, fontWeight = FontWeight.Bold,
                    color = FausCrewColors.textPrimary)
            }
        }
    }
}

@Composable
private fun IconLabel(icon: ImageVector, text: String, color: Color, iconSize: Dp = 15.dp) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Icon(icon, null, Modifier.size(iconSize), tint = color)
        Text(text, style = FausCrewType.caption, color = color)
    }
}

@Composable
private fun SectionTitle(icon: ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Icon(icon, null, Modifier.size(20.dp), tint = FausCrewColors.textPrimary)
        Text(title, style = FausCrewType.subheadline, fontWeight = FontWeight.Bold, color = FausCrewColors.textPrimary)
    }
}

@Composable
private fun OwnerEditor(
    info: HouseInfo,
    name: String,
    onName: (String) -> Unit,
    limit: Int,
    minimum: Int,
    maximum: Int,
    onLimit: (Int) -> Unit,
    strings: LocalizedText,
) {
    val focus = LocalFocusManager.current
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionTitle(FausCrewIcons.sliderHorizontal3, strings.get("house_info_edit_details_title", "House details"))
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(strings.profileValue("house_info_name_label"), style = FausCrewType.caption, fontWeight = FontWeight.SemiBold,
                color = FausCrewColors.textSecondary)
            val interaction = remember { MutableInteractionSource() }
            val focused by interaction.collectIsFocusedAsState()
            val shape = RoundedCornerShape(Radius.md)
            BasicTextField(
                name, onName, Modifier.fillMaxWidth(),
                textStyle = FausCrewType.body.copy(color = FausCrewColors.textPrimary),
                singleLine = true,
                cursorBrush = SolidColor(FausCrewColors.primary),
                interactionSource = interaction,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
                decorationBox = { inner ->
                    Box(
                        Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(shape).background(FausCrewColors.cardBackground)
                            .border(if (focused) 1.5.dp else 1.dp, houseTint.copy(alpha = if (focused) .65f else .16f), shape)
                            .padding(Spacing.md),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        if (name.isEmpty()) Text(strings.get("house_info_name_placeholder", strings.profileValue("house_info_name_label")),
                            style = FausCrewType.body, color = com.fauscrew.ui.components.PlaceholderColor)
                        inner()
                    }
                },
            )
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(FausCrewColors.cardBackground).padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(strings.profileValue("house_info_member_limit_label"), style = FausCrewType.subheadline,
                    fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
                Text("${info.houseMemberCount} " + strings.get("house_info_members_current", "members currently"),
                    style = FausCrewType.caption, color = FausCrewColors.textSecondary)
            }
            LimitButton(FausCrewIcons.minus, limit > minimum, "-") { onLimit(limit - 1) }
            Text(limit.toString(), Modifier.widthIn(min = 22.dp), style = FausCrewType.body, fontWeight = FontWeight.Bold,
                color = FausCrewColors.textPrimary, textAlign = TextAlign.Center)
            LimitButton(FausCrewIcons.plus, limit < maximum, "+") { onLimit(limit + 1) }
        }
    }
}

@Composable
private fun LimitButton(icon: ImageVector, enabled: Boolean, description: String, onClick: () -> Unit) {
    val color = if (enabled) houseTint else FausCrewColors.textTertiary
    Box(Modifier.size(44.dp).clickable(enabled = enabled, role = Role.Button, onClick = onClick)
        .semantics { contentDescription = description }, contentAlignment = Alignment.Center) {
        Box(Modifier.size(34.dp).background(color.copy(alpha = .11f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(18.dp), tint = color)
        }
    }
}

@Composable
private fun ImagePicker(choices: List<String>, selected: String, loading: Boolean, strings: LocalizedText, onSelect: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionTitle(FausCrewIcons.photoOnRectangle, strings.profileValue("house_info_profile_image_title"))
        when {
            loading -> Box(Modifier.fillMaxWidth().heightIn(min = 86.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = ownerTint)
            }
            choices.isEmpty() -> Text(strings.profileValue("house_info_images_empty"), style = FausCrewType.subheadline,
                color = FausCrewColors.textSecondary)
            else -> LazyRow(horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 4.dp, horizontal = 2.dp)) {
                itemsIndexed(choices, key = { _, url -> url }) { _, url ->
                    val isSelected = url == selected
                    val scale by animateFloatAsState(if (isSelected) 1.04f else 1f, Motion.spring(), label = "imageScale")
                    val shape = RoundedCornerShape(20.dp)
                    Box(
                        Modifier.size(80.dp).clickable(role = Role.RadioButton) { onSelect(url) }
                            .semantics { this.selected = isSelected },
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(Modifier.size(76.dp).graphicsLayer { scaleX = scale; scaleY = scale }
                            .border(3.dp, if (isSelected) ownerTint else Color.Transparent, shape).clip(shape)) {
                            HouseThumbnail(url, 76.dp, shape)
                        }
                        if (isSelected) {
                            Box(Modifier.align(Alignment.BottomEnd).size(22.dp).background(ownerTint, CircleShape),
                                contentAlignment = Alignment.Center) {
                                Icon(FausCrewIcons.checkmark, null, Modifier.size(14.dp), tint = Color.White)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ViewerDetails(info: HouseInfo, strings: LocalizedText) {
    val (typeLabel, typeIcon) = strings.houseType(info.houseType)
    Column {
        ReadOnlyRow(FausCrewIcons.person2Fill, strings.profileValue("house_info_members_label"), strings.memberCount(info))
        HorizontalDivider(Modifier.padding(start = 50.dp), thickness = .5.dp, color = FausCrewColors.separator)
        ReadOnlyRow(typeIcon, strings.profileValue("house_info_type_label"), typeLabel)
    }
}

@Composable
private fun ReadOnlyRow(icon: ImageVector, label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 11.dp), verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Box(Modifier.size(34.dp).background(houseTint.copy(alpha = .11f), RoundedCornerShape(9.dp)), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(18.dp), tint = houseTint)
        }
        Text(label, Modifier.weight(1f), style = FausCrewType.subheadline, color = FausCrewColors.textPrimary)
        Text(value, style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = FausCrewColors.textSecondary)
    }
}

@Composable
private fun MembersSection(
    info: HouseInfo,
    userId: String,
    isOwner: Boolean,
    busy: Boolean,
    removingId: String?,
    strings: LocalizedText,
    onRemove: (HouseInfoMember) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionTitle(FausCrewIcons.person2Fill, strings.profileValue("house_info_members_title"))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.lg)).background(FausCrewColors.cardBackground)) {
            info.members.forEachIndexed { index, member ->
                Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.md, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    MemberAvatar(member)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(member.name, style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold,
                            color = FausCrewColors.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        when {
                            member.isOwner -> Row(verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                Icon(FausCrewIcons.crownFill, null, Modifier.size(13.dp), tint = FausCrewColors.textPrimary)
                                Text(strings.profileValue("house_info_owner_badge"), style = FausCrewType.caption2,
                                    fontWeight = FontWeight.Bold, color = FausCrewColors.textPrimary)
                            }
                            member.userId == userId -> Text(strings.get("common_you", "You"), style = FausCrewType.caption,
                                color = FausCrewColors.textSecondary)
                        }
                    }
                    if (isOwner && !member.isOwner && member.userId != userId) {
                        Box(
                            Modifier.size(44.dp).clickable(enabled = !busy, role = Role.Button) { onRemove(member) }
                                .semantics { contentDescription = strings.profileValue("house_info_remove_member_button") },
                            contentAlignment = Alignment.Center,
                        ) {
                            Box(Modifier.size(40.dp).background(FausCrewColors.error.copy(alpha = .10f), CircleShape),
                                contentAlignment = Alignment.Center) {
                                if (removingId == member.userId) {
                                    CircularProgressIndicator(Modifier.size(18.dp), color = FausCrewColors.error, strokeWidth = 2.dp)
                                } else {
                                    Icon(FausCrewIcons.personFillXmark, null, Modifier.size(19.dp), tint = FausCrewColors.error)
                                }
                            }
                        }
                    }
                }
                if (index < info.members.lastIndex) {
                    HorizontalDivider(Modifier.padding(start = 62.dp), thickness = .5.dp, color = FausCrewColors.separator)
                }
            }
        }
    }
}

@Composable
private fun MemberAvatar(member: HouseInfoMember) {
    val initials = member.name.split(" ").filter(String::isNotBlank).take(2).joinToString("") { it.take(1) }.uppercase()
    RemoteImage(member.profileImage, Modifier.size(42.dp).clip(CircleShape), member.name) {
        Box(Modifier.size(42.dp).background(houseTint.copy(alpha = .12f), CircleShape), contentAlignment = Alignment.Center) {
            Text(initials, style = FausCrewType.caption, fontWeight = FontWeight.Bold, color = FausCrewColors.textPrimary)
        }
    }
}

/** `HouseInviteCodeSection`. */
@Composable
private fun InviteSection(
    houseId: String,
    houseName: String,
    invite: HouseInvite?,
    generating: Boolean,
    strings: LocalizedText,
    onInvite: (String) -> Unit,
) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(inviteTint.copy(alpha = .075f)).border(1.dp, inviteTint.copy(alpha = .16f), shape)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        SectionTitle(FausCrewIcons.personBadgePlus, strings.profileValue("house_info_invite_title"))
        if (invite == null) {
            PopupPrimaryButton(
                strings.profileValue(if (generating) "house_info_invite_generating" else "house_info_invite_generate_button"),
                enabled = !generating, busy = generating, onClick = { onInvite(houseId) }, modifier = Modifier.fillMaxWidth(),
                icon = FausCrewIcons.keyFill, brush = SolidColor(inviteTint), disabledBrush = SolidColor(inviteTint),
            )
        } else {
            GeneratedCode(houseId, houseName, invite, generating, strings, onInvite)
        }
    }
}

@Composable
private fun GeneratedCode(
    houseId: String,
    houseName: String,
    invite: HouseInvite,
    generating: Boolean,
    strings: LocalizedText,
    onInvite: (String) -> Unit,
) {
    @Suppress("DEPRECATION") val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) { if (copied) { delay(1_500); copied = false } }
    val seconds = invite.expiresInSeconds
    val duration = when {
        seconds >= 3_600 -> "${seconds / 3_600}h ${(seconds % 3_600) / 60}m"
        seconds >= 60 -> "${seconds / 60}m"
        else -> "${seconds.coerceAtLeast(0)}s"
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(invite.code, fontFamily = FontFamily.Monospace, fontSize = 22.sp, fontWeight = FontWeight.Bold,
                letterSpacing = 2.sp, color = FausCrewColors.textPrimary)
            Text(strings.profileValue("house_info_invite_expiration_template").replace("{duration}", duration),
                style = FausCrewType.caption, color = FausCrewColors.textSecondary)
        }
        val copyTint = if (copied) FausCrewColors.success else inviteTint
        Box(
            Modifier.size(44.dp).clickable(role = Role.Button) {
                clipboard.setText(AnnotatedString(invite.code)); copied = true
            }.semantics { contentDescription = strings.get("common_copy", "Copy") },
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.size(36.dp).background(copyTint.copy(alpha = .11f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(if (copied) FausCrewIcons.checkmark else FausCrewIcons.docOnDoc, null, Modifier.size(18.dp), tint = copyTint)
            }
        }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        InviteAction(FausCrewIcons.arrowClockwise, strings.profileValue("house_info_invite_refresh_button"),
            FausCrewColors.cardBackground, FausCrewColors.textPrimary, !generating, Modifier.weight(1f)) { onInvite(houseId) }
        InviteAction(FausCrewIcons.squareAndArrowUp, strings.get("common_share", "Share"), inviteTint, Color.White,
            !generating, Modifier.weight(1f)) {
            val message = strings.get("invite_share_message_template", "Join {house_name} on FausCrew with invite code {invite_code}.")
                .replace("{house_name}", houseName).replace("{invite_code}", invite.code)
            context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, message)
            }, null))
        }
    }
}

@Composable
private fun InviteAction(icon: ImageVector, label: String, background: Color, content: Color, enabled: Boolean,
    modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier.heightIn(min = Sizes.buttonHeightSmall).clip(RoundedCornerShape(Radius.md)).background(background)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(vertical = Spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, Modifier.size(18.dp), tint = content)
        Text(label, style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = content)
    }
}

@Composable
private fun ErrorBanner(message: String) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(FausCrewColors.error.copy(alpha = .09f))
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(FausCrewIcons.exclamationmarkTriangleFill, null, Modifier.size(16.dp), tint = FausCrewColors.error)
        Text(message, Modifier.weight(1f), style = FausCrewType.caption, color = FausCrewColors.error)
    }
}

/** Destructive confirmation (iOS alert / confirmation dialog). */
@Composable
private fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    strings: LocalizedText,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = FausCrewColors.background,
        title = { Text(title, style = FausCrewType.headline, color = FausCrewColors.textPrimary) },
        text = { Text(message, style = FausCrewType.subheadline, color = FausCrewColors.textSecondary) },
        confirmButton = {
            TextButton(onClick = onConfirm) { Text(confirmLabel, style = FausCrewType.headline, color = FausCrewColors.error) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(strings.profileValue("common_cancel"), style = FausCrewType.headline, color = FausCrewColors.primary)
            }
        },
    )
}
