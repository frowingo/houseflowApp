package com.fauscrew.ui.profile

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.PlatformLanguage
import com.fauscrew.platform.ProfileChange
import com.fauscrew.ui.auth.OtpField
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.components.PlaceholderColor
import com.fauscrew.ui.components.PopupFooter
import com.fauscrew.ui.components.PopupHeader
import com.fauscrew.ui.components.PopupPrimaryButton
import com.fauscrew.ui.components.PopupSecondaryButton
import com.fauscrew.ui.components.RemoteImage
import com.fauscrew.ui.house.HouseJourneyBrushes
import com.fauscrew.ui.theme.FausCrewBrushes
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Motion
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow
import com.fauscrew.viewmodel.HouseUiState
import com.fauscrew.viewmodel.ProfileUiState

private val accentOrange = FausCrewColors.accentOrange
private val accentBlue = ProfileTints.account
private val disabledGray = Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = .5f), Color.Gray.copy(alpha = .4f)))
private const val INVITE_CODE_LENGTH = 8

/**
 * The 64pt title bar shared by the profile popups: optional leading glyph badge, bold title,
 * muted subtitle, faint oversized glyph and the round close control.
 */
@Composable
internal fun ProfilePopupHeader(
    title: String,
    subtitle: String?,
    decorativeIcon: ImageVector,
    closeEnabled: Boolean,
    closeDescription: String,
    onClose: () -> Unit,
    leadingIcon: ImageVector? = null,
    decorativeOffsetX: Dp = 0.dp,
    height: Dp = 64.dp,
) {
    PopupHeader(onClose = onClose, closeEnabled = closeEnabled, closeDescription = closeDescription,
        decorativeIcon = decorativeIcon, decorativeOffsetX = decorativeOffsetX, height = height, spacing = Spacing.sm,
        closeSize = if (leadingIcon != null) 28.dp else 26.dp, closeBackgroundAlpha = if (leadingIcon != null) .18f else .2f) {
        leadingIcon?.let {
            Box(Modifier.size(34.dp).background(Color.White.copy(alpha = .18f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(it, null, Modifier.size(18.dp), tint = Color.White)
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold, maxLines = 1,
                overflow = TextOverflow.Ellipsis)
            subtitle?.let {
                Text(it, color = Color.White.copy(alpha = .75f), fontSize = 12.sp, fontWeight = FontWeight.Medium,
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** Orange Save + gray Cancel footer used by the edit-style profile popups. */
@Composable
private fun SaveCancelFooter(strings: LocalizedText, canSave: Boolean, busy: Boolean, onSave: () -> Unit, onCancel: () -> Unit) {
    PopupFooter(spacing = Spacing.sm) {
        PopupPrimaryButton(strings.profileValue(if (busy) "common_saving" else "common_save_changes"),
            enabled = canSave && !busy, busy = busy, onClick = onSave, modifier = Modifier.fillMaxWidth(),
            brush = FausCrewBrushes.orangeAction, disabledBrush = disabledGray)
        PopupSecondaryButton(strings.profileValue("common_cancel"), !busy, onCancel, Modifier.fillMaxWidth())
    }
}

@Composable
private fun GridPlaceholder(icon: ImageVector, message: String) {
    Column(Modifier.fillMaxWidth().heightIn(min = 180.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterVertically)) {
        Icon(icon, null, Modifier.size(40.dp), tint = FausCrewColors.textTertiary)
        Text(message, style = FausCrewType.subheadline, color = FausCrewColors.textTertiary, textAlign = TextAlign.Center)
    }
}

@Composable
private fun GridLoading() {
    Box(Modifier.fillMaxWidth().heightIn(min = 180.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = accentOrange)
    }
}

/** Selected artwork tile: orange ring, slight scale, check badge and tinted shadow. */
@Composable
private fun SelectableTile(
    selected: Boolean,
    enabled: Boolean,
    size: Dp,
    onClick: () -> Unit,
    badgeOffset: Dp = 4.dp,
    content: @Composable () -> Unit,
) {
    val scale by animateFloatAsState(if (selected) 1.04f else 1f, Motion.spring(), label = "tileScale")
    val shape = RoundedCornerShape(14.dp)
    Box(
        Modifier.size(size + 8.dp).clickable(enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier.size(size).graphicsLayer { scaleX = scale; scaleY = scale }
                .softShadow((if (selected) accentOrange else Color.Black).copy(alpha = if (selected) .35f else .1f),
                    if (selected) 8.dp else 4.dp, y = 3.dp, shape = shape)
                .clip(shape).border(3.dp, if (selected) accentOrange else Color.Transparent, shape),
        ) { content() }
        if (selected) {
            Box(Modifier.align(Alignment.BottomEnd).offset(badgeOffset - 4.dp, badgeOffset - 4.dp).size(22.dp)
                .background(accentOrange, CircleShape), contentAlignment = Alignment.Center) {
                Icon(FausCrewIcons.checkmark, null, Modifier.size(14.dp), tint = Color.White)
            }
        }
    }
}

@Composable
private fun FooterError(message: String?) {
    message?.let {
        Box(Modifier.padding(horizontal = Spacing.xl)) {
            Notice(FausCrewIcons.exclamationmarkTriangleFill, FausCrewColors.error, it, FausCrewColors.error)
        }
    }
}

/** `AvatarPickerPopup`: superhero avatar grid; the current avatar is preselected when listed. */
@Composable
internal fun AvatarDialog(user: AuthProfile, state: ProfileUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onSave: (ProfileChange) -> Unit) {
    var selected by remember(user.userId) { mutableStateOf<String?>(null) }
    LaunchedEffect(state.images) {
        if (selected == null) selected = state.images.firstOrNull { it.url == user.imageUrl }?.url
    }
    FausCrewPopup(
        onDismiss = onDismiss, dismissEnabled = !state.busy, maxBodyHeight = 340.dp, scrollableBody = false, bodyPadding = 0.dp,
        header = {
            ProfilePopupHeader(strings.profileValue("profile_avatar_choose_title"), strings.profileValue("profile_avatar_choose_subtitle"),
                FausCrewIcons.personCropCircleFill, !state.busy, strings.profileValue("common_close"), onDismiss)
        },
        footer = {
            FooterError(state.error)
            SaveCancelFooter(strings, selected != null && selected != user.imageUrl, state.busy,
                { selected?.let { onSave(ProfileChange(imageUrl = it)) } }, onDismiss)
        },
    ) {
        when {
            state.loadingImages -> GridLoading()
            state.images.isEmpty() -> GridPlaceholder(FausCrewIcons.photoOnRectangle, strings.profileValue("profile_avatar_empty_message"))
            else -> LazyVerticalGrid(GridCells.Fixed(3), Modifier.fillMaxWidth(), contentPadding = PaddingValues(Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                items(state.images, key = { it.publicId }) { image ->
                    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        SelectableTile(image.url == selected, !state.busy, 90.dp, { selected = image.url }) {
                            RemoteImage(image.url, Modifier.fillMaxSize()) {
                                Box(Modifier.fillMaxSize().background(FausCrewColors.secondaryBackground), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(Modifier.size(20.dp), color = accentOrange, strokeWidth = 2.dp)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** `LanguageSettingsPopup`: flag grid with "coming soon" badges; saving requires signing in again. */
@Composable
internal fun LanguageDialog(user: AuthProfile, state: ProfileUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onSave: (String) -> Unit) {
    val current = user.language?.trim()?.lowercase()?.ifBlank { null }
    var selected by remember(user.userId) { mutableStateOf(current) }
    LaunchedEffect(state.languages) {
        if (selected == null) selected = state.languages.firstOrNull { it.isDefault }?.prefix?.lowercase()
    }
    val canSave = !state.busy && selected != null && selected != current &&
        state.languages.any { it.prefix.lowercase() == selected && it.isActive }
    FausCrewPopup(
        onDismiss = onDismiss, dismissEnabled = !state.busy, maxBodyHeight = 360.dp, scrollableBody = false, bodyPadding = 0.dp,
        header = {
            ProfilePopupHeader(strings.profileValue("language_settings_title"), strings.profileValue("language_settings_subtitle"),
                FausCrewIcons.globeFill, !state.busy, strings.profileValue("common_close"), onDismiss)
        },
        footer = {
            FooterError(state.error)
            SaveCancelFooter(strings, canSave, state.busy, { selected?.let(onSave) }, onDismiss)
        },
    ) {
        when {
            state.loadingLanguages && state.languages.isEmpty() -> GridLoading()
            state.languages.isEmpty() -> GridPlaceholder(FausCrewIcons.globeFill, strings.profileValue("language_settings_empty_message"))
            else -> LazyVerticalGrid(GridCells.Fixed(3), Modifier.fillMaxWidth(), contentPadding = PaddingValues(Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                items(state.languages, key = { it.prefix }) { language ->
                    LanguageCell(language, language.prefix.lowercase() == selected, !state.busy, strings) {
                        selected = language.prefix.lowercase()
                    }
                }
            }
        }
    }
}

@Composable
private fun LanguageCell(language: PlatformLanguage, selected: Boolean, enabled: Boolean, strings: LocalizedText, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(vertical = Spacing.sm), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Box(contentAlignment = Alignment.Center) {
            SelectableTile(selected, enabled && language.isActive, 86.dp, onClick, badgeOffset = 11.dp) {
                RemoteImage(language.image, Modifier.fillMaxSize().alpha(if (language.isActive) 1f else .38f)) {
                    Box(Modifier.fillMaxSize().background(FausCrewColors.secondaryBackground), contentAlignment = Alignment.Center) {
                        Icon(FausCrewIcons.globeFill, null, Modifier.size(30.dp), tint = FausCrewColors.textTertiary)
                    }
                }
            }
            if (!language.isActive) {
                Text(strings.profileValue("language_settings_coming_soon_badge"),
                    Modifier.background(Color.Black.copy(alpha = .58f), CircleShape).padding(horizontal = 8.dp, vertical = 5.dp),
                    fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1)
            }
        }
        Text(language.nativeName, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
            color = if (language.isActive) FausCrewColors.textPrimary else FausCrewColors.textTertiary)
    }
}

/** `PhoneManagementPopup`: status, backend-pending notice, Update/Verify segments; actions only show the notice. */
@Composable
internal fun PhoneManagementDialog(user: AuthProfile, strings: LocalizedText, onDismiss: () -> Unit) {
    val focus = LocalFocusManager.current
    var verifyMode by rememberSaveable { mutableStateOf(false) }
    var number by rememberSaveable(user.userId) { mutableStateOf(user.phoneNumber) }
    var code by rememberSaveable { mutableStateOf("") }
    var requested by rememberSaveable { mutableStateOf(false) }
    var pendingShown by remember { mutableStateOf(false) }
    val verified = user.isVerifyPhone
    val statusColor = if (verified) ProfileTints.verified else FausCrewColors.error
    val dismiss = { focus.clearFocus(); onDismiss() }
    FausCrewPopup(
        onDismiss = dismiss, maxBodyHeight = 430.dp, bodySpacing = Spacing.lg,
        header = {
            PopupHeader(onClose = dismiss, closeDescription = strings.profileValue("common_close"),
                decorativeIcon = FausCrewIcons.phoneFill, decorativeIconSize = 62.dp, decorativeOffsetX = 85.dp,
                height = 62.dp, closeSize = 30.dp, closeBackgroundAlpha = .18f) {
                Box(Modifier.size(34.dp).background(Color.White.copy(alpha = .18f), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(FausCrewIcons.phoneFill, null, Modifier.size(18.dp), tint = Color.White)
                }
                Text(strings.get("profile_phone_management_title", "Phone settings"), style = FausCrewType.headline, color = Color.White)
            }
        },
        footer = {
            PopupFooter(shadow = false) {
                PopupSecondaryButton(strings.profileValue("common_close"), true, dismiss, Modifier.fillMaxWidth())
            }
        },
    ) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.lg)).background(FausCrewColors.secondaryBackground).padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Box(Modifier.size(40.dp).background(statusColor.copy(alpha = .12f), RoundedCornerShape(10.dp)), contentAlignment = Alignment.Center) {
                Icon(if (verified) FausCrewIcons.checkmarkShieldFill else FausCrewIcons.exclamationmarkShieldFill, null,
                    Modifier.size(24.dp), tint = statusColor)
            }
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(user.phoneNumber.ifBlank { strings.get("common_empty_value", "—") }, style = FausCrewType.headline,
                    color = FausCrewColors.textPrimary)
                Text(strings.profileValue(if (verified) "common_verified" else "common_not_verified"), style = FausCrewType.caption,
                    color = statusColor)
            }
        }
        Notice(FausCrewIcons.infoCircleFill, accentBlue, strings.get("profile_phone_backend_pending_notice",
            "Phone update and verification screens are ready. Backend integration will be connected later."))
        SegmentedControl(listOf(strings.get("profile_phone_update_tab", "Update number"), strings.get("profile_phone_verify_tab", "Verify")),
            if (verifyMode) 1 else 0) { verifyMode = it == 1; focus.clearFocus() }
        AnimatedContent(verifyMode, transitionSpec = { fadeIn(Motion.standard()) togetherWith fadeOut(Motion.standard()) },
            label = "phoneMode") { verify ->
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                if (!verify) {
                    Text(strings.get("profile_phone_new_number_label", "New phone number"), style = FausCrewType.subheadline,
                        fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
                    PhoneField(number, { number = it }, strings.get("profile_edit_phone_placeholder", "Phone number"),
                        KeyboardType.Phone, FausCrewIcons.phoneFill)
                    PhoneAction(strings.get("profile_phone_update_button", "Update phone number"), FausCrewIcons.arrowTriangle2Circlepath,
                        number.trim().isNotEmpty() && number.trim() != user.phoneNumber) { pendingShown = true }
                } else {
                    Text(strings.get("profile_phone_verification_instruction",
                        "Request a verification code for your current phone number, then enter the six-digit code."),
                        style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
                    if (requested) {
                        PhoneField(code, { code = it.filter(Char::isDigit).take(6) }, strings.get("profile_phone_code_placeholder",
                            "Verification code"), KeyboardType.NumberPassword, null, monospaced = true)
                        PhoneAction(strings.get("profile_phone_verify_button", "Verify phone number"), FausCrewIcons.checkmarkShieldFill,
                            code.length == 6) { pendingShown = true }
                    } else {
                        PhoneAction(strings.get("profile_phone_send_code_button", "Send verification code"), FausCrewIcons.paperplaneFill,
                            user.phoneNumber.isNotBlank()) { requested = true; pendingShown = true }
                    }
                }
            }
        }
        // iOS confirms the pending integration with a toast; inside the popup window this is an inline notice.
        if (pendingShown) Notice(FausCrewIcons.checkmarkCircleFill, FausCrewColors.success,
            strings.get("profile_phone_backend_pending_toast", "Phone backend integration is pending."), FausCrewColors.textPrimary)
    }
}

/** iOS `.pickerStyle(.segmented)`. */
@Composable
private fun SegmentedControl(options: List<String>, selectedIndex: Int, onSelect: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().height(34.dp).clip(RoundedCornerShape(9.dp)).background(Color(0x1F767680)).padding(2.dp)) {
        options.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            val shape = RoundedCornerShape(7.dp)
            Box(
                Modifier.weight(1f).fillMaxSize()
                    .then(if (selected) Modifier.softShadow(Color.Black.copy(alpha = .12f), 4.dp, y = 2.dp, shape = shape)
                        .background(Color.White, shape) else Modifier)
                    .clip(shape).clickable(role = Role.Tab) { onSelect(index) }.semantics { this.selected = selected },
                contentAlignment = Alignment.Center,
            ) {
                Text(label, fontSize = 13.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    color = FausCrewColors.textPrimary, maxLines = 1)
            }
        }
    }
}

@Composable
private fun PhoneField(value: String, onChange: (String) -> Unit, placeholder: String, keyboard: KeyboardType,
    icon: ImageVector?, monospaced: Boolean = false) {
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val shape = RoundedCornerShape(Radius.md)
    val style = if (monospaced) FausCrewType.body.copy(fontSize = 22.sp, fontWeight = FontWeight.SemiBold,
        fontFamily = FontFamily.Monospace, textAlign = TextAlign.Center) else FausCrewType.body
    BasicTextField(
        value, onChange, Modifier.fillMaxWidth(), textStyle = style.copy(color = FausCrewColors.textPrimary), singleLine = true,
        interactionSource = interaction, cursorBrush = SolidColor(FausCrewColors.primary),
        keyboardOptions = KeyboardOptions(keyboardType = keyboard),
        decorationBox = { inner ->
            Row(
                Modifier.fillMaxWidth().clip(shape).background(FausCrewColors.secondaryBackground)
                    .border(1.5.dp, accentBlue.copy(alpha = if (focused) .55f else .14f), shape).padding(Spacing.md),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                icon?.let { Icon(it, null, Modifier.size(18.dp), tint = accentBlue) }
                Box(Modifier.weight(1f), contentAlignment = if (monospaced) Alignment.Center else Alignment.CenterStart) {
                    if (value.isEmpty()) Text(placeholder, style = style, color = PlaceholderColor)
                    inner()
                }
            }
        },
    )
}

@Composable
private fun PhoneAction(label: String, icon: ImageVector, enabled: Boolean, onClick: () -> Unit) {
    PopupPrimaryButton(label, enabled, onClick, Modifier.fillMaxWidth(), icon = icon, brush = SolidColor(accentBlue),
        disabledBrush = SolidColor(FausCrewColors.systemGray3))
}

/** `JoinHousePopup`: 8-character code boxes with counter, error banner, Cancel / Join house. */
@Composable
internal fun JoinHouseDialog(state: HouseUiState, strings: LocalizedText, onDismiss: () -> Unit, onJoin: (String) -> Unit) {
    val focus = LocalFocusManager.current
    var code by rememberSaveable { mutableStateOf("") }
    val busy = state.profileActionBusy
    val valid = code.matches(Regex("[A-Z0-9]{$INVITE_CODE_LENGTH}"))
    val canJoin = valid && !busy
    val dismiss = { focus.clearFocus(); onDismiss() }
    val submit = { if (canJoin) { focus.clearFocus(); onJoin(code) } }
    FausCrewPopup(
        onDismiss = dismiss, dismissEnabled = !busy, horizontalInset = Spacing.lg, maxBodyHeight = 260.dp,
        bodyPadding = Spacing.lg,
        header = {
            ProfilePopupHeader(strings.profileValue("profile_house_join_title"), strings.profileValue("profile_house_join_subtitle"),
                FausCrewIcons.houseFill, !busy, strings.profileValue("common_close"), dismiss,
                leadingIcon = FausCrewIcons.person2BadgePlus, decorativeOffsetX = 85.dp)
        },
        footer = {
            HorizontalDivider(thickness = .5.dp, color = FausCrewColors.separator)
            PopupFooter(shadow = false, padding = PaddingValues(Spacing.lg, Spacing.md)) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    PopupSecondaryButton(strings.profileValue("common_cancel"), !busy, dismiss, Modifier.weight(1f))
                    PopupPrimaryButton(strings.get(if (busy) "common_joining" else "profile_house_join_button",
                        if (busy) "Joining…" else "Join house"), canJoin, submit, Modifier.weight(1f),
                        icon = FausCrewIcons.arrowRightCircleFill, busy = busy, brush = HouseJourneyBrushes.joinButton,
                        disabledBrush = Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = .42f), Color.Gray.copy(alpha = .32f))))
                }
            }
        },
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Text(strings.profileValue("profile_house_join_prompt"), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
            OtpField(code, { code = it }, strings.profileValue("profile_house_join_code_accessibility_label"), false, INVITE_CODE_LENGTH)
            Row {
                val counterColor = if (valid) FausCrewColors.textPrimary else FausCrewColors.textSecondary
                Text(strings.profileValue("profile_house_join_code_hint"), Modifier.weight(1f), style = FausCrewType.caption,
                    color = counterColor)
                Text("${code.length}/$INVITE_CODE_LENGTH", style = FausCrewType.caption.copy(fontFeatureSettings = "tnum"),
                    color = counterColor)
            }
        }
        state.profileError?.let { Notice(FausCrewIcons.exclamationmarkTriangleFill, FausCrewColors.error, it, FausCrewColors.error) }
    }
}

/** `AboutPopup`: quote card and "made with love" line. */
@Composable
internal fun AboutDialog(strings: LocalizedText, onDismiss: () -> Unit) {
    FausCrewPopup(
        onDismiss = onDismiss, bodySpacing = Spacing.lg,
        header = {
            ProfilePopupHeader(strings.profileValue("profile_about_label"), strings.get("profile_about_version", "").ifBlank { null },
                FausCrewIcons.houseFill, true, strings.profileValue("common_close"), onDismiss)
        },
        footer = {
            PopupFooter { PopupSecondaryButton(strings.profileValue("profile_about_close_button"), true, onDismiss, Modifier.fillMaxWidth()) }
        },
    ) {
        val shape = RoundedCornerShape(Radius.lg)
        Column(
            Modifier.fillMaxWidth().clip(shape).background(accentOrange.copy(alpha = .06f)).border(1.dp, accentOrange.copy(alpha = .2f), shape)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(FausCrewIcons.quoteClosing, null, Modifier.size(28.dp).rotate(180f), tint = accentOrange.copy(alpha = .6f))
            Text(strings.profileValue("profile_about_quote"), Modifier.fillMaxWidth(), fontSize = 19.sp, lineHeight = 28.sp,
                fontWeight = FontWeight.Bold, color = accentOrange, textAlign = TextAlign.Center)
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                Icon(FausCrewIcons.quoteClosing, null, Modifier.size(22.dp), tint = accentOrange.copy(alpha = .4f))
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically) {
            Icon(FausCrewIcons.heartFill, null, Modifier.size(13.dp), tint = accentOrange)
            Text(strings.profileValue("profile_about_made_with_love"), fontSize = 12.sp, fontWeight = FontWeight.Medium,
                color = FausCrewColors.textTertiary)
        }
    }
}
