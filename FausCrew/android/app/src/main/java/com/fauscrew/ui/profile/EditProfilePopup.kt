package com.fauscrew.ui.profile

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.ProfileChange
import com.fauscrew.ui.components.CompactDatePicker
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.components.PlaceholderColor
import com.fauscrew.ui.components.PopupFooter
import com.fauscrew.ui.components.PopupHeader
import com.fauscrew.ui.components.PopupPrimaryButton
import com.fauscrew.ui.components.PopupSecondaryButton
import com.fauscrew.ui.dashboard.parseApiDate
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.viewmodel.ProfileUiState
import java.time.LocalDate

private val accentOrange = FausCrewColors.accentOrange
private val detailsTint = Color(0xFF33B366)
private val cakeTint = Color(0xFFE6731A)

/** `EditProfilePopup`: 20-day notice, name section, birthdate section, Save / Cancel. */
@Composable
internal fun EditProfileDialog(
    user: AuthProfile,
    state: ProfileUiState,
    strings: LocalizedText,
    onDismiss: () -> Unit,
    onSave: (ProfileChange) -> Unit,
) {
    val focus = LocalFocusManager.current
    val initialBirthday = remember(user.userId, user.birthDay) {
        parseApiDate(user.birthDay)?.toLocalDate() ?: LocalDate.now().minusYears(25)
    }
    var first by rememberSaveable(user.userId) { mutableStateOf(user.firstName) }
    var last by rememberSaveable(user.userId) { mutableStateOf(user.lastName) }
    var birthday by rememberSaveable(user.userId) { mutableStateOf(initialBirthday) }
    val firstChanged = first.trim() != user.firstName.trim()
    val lastChanged = last.trim() != user.lastName.trim()
    val birthdayChanged = birthday != initialBirthday
    val canSave = (firstChanged || lastChanged || birthdayChanged) && first.isNotBlank() && last.isNotBlank()
    val dismiss = { focus.clearFocus(); onDismiss() }
    val initials = (first.take(1) + last.take(1)).ifBlank { user.firstName.take(1) + user.lastName.take(1) }
        .uppercase().ifBlank { "?" }

    FausCrewPopup(
        onDismiss = dismiss,
        dismissEnabled = !state.busy,
        maxBodyHeight = 420.dp,
        header = {
            PopupHeader(onClose = dismiss, closeEnabled = !state.busy, closeDescription = strings.profileValue("common_close"),
                decorativeIcon = FausCrewIcons.personCropCircleFill, height = 60.dp, spacing = Spacing.sm) {
                Box(Modifier.size(34.dp).background(Color.White.copy(alpha = .22f), CircleShape), contentAlignment = Alignment.Center) {
                    Text(initials, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                }
                Column(Modifier.weight(1f, fill = false), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(strings.profileValue("profile_edit_button"), color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text(user.email, color = Color.White.copy(alpha = .72f), fontSize = 11.sp, fontWeight = FontWeight.Medium,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        },
        footer = {
            PopupFooter(spacing = Spacing.sm) {
                PopupPrimaryButton(
                    strings.profileValue(if (state.busy) "common_saving" else "common_save_changes"),
                    enabled = canSave && !state.busy, busy = state.busy, modifier = Modifier.fillMaxWidth(),
                    disabledBrush = Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = .5f), Color.Gray.copy(alpha = .4f))),
                    onClick = {
                        focus.clearFocus()
                        onSave(ProfileChange(
                            firstName = first.trim().takeIf { firstChanged },
                            lastName = last.trim().takeIf { lastChanged },
                            birthDay = birthday.takeIf { birthdayChanged }?.let { "${it}T00:00:00Z" },
                        ))
                    },
                )
                PopupSecondaryButton(strings.profileValue("common_cancel"), !state.busy, dismiss, Modifier.fillMaxWidth())
            }
        },
        bodySpacing = Spacing.md,
    ) {
        Notice(FausCrewIcons.exclamationmarkTriangleFill, accentOrange,
            strings.get("profile_edit_twenty_day_warning",
                "You can update your first name, last name, and birthdate once every 20 days."))
        FieldSection(FausCrewIcons.personFill, accentOrange, strings.get("profile_edit_name_section", "Name")) {
            EditField(FausCrewIcons.personFill, accentOrange, strings.profileValue("profile_first_name_label"), first,
                { first = it }, ImeAction.Next) { focus.moveFocus(FocusDirection.Down) }
            HorizontalDivider(Modifier.padding(start = 66.dp), thickness = .5.dp, color = FausCrewColors.separator)
            EditField(FausCrewIcons.personFill, accentOrange, strings.profileValue("profile_last_name_label"), last,
                { last = it }, ImeAction.Done) { focus.clearFocus() }
        }
        FieldSection(FausCrewIcons.infoCircleFill, detailsTint, strings.get("profile_edit_details_section", "Details")) {
            Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                RowIcon(FausCrewIcons.birthdayCakeFill, cakeTint)
                Text(strings.profileValue("profile_birthdate_label"), Modifier.weight(1f), style = FausCrewType.subheadline,
                    color = FausCrewColors.textSecondary)
                CompactDatePicker(birthday, { birthday = it }, LocalDate.now().minusYears(120)..LocalDate.now(), cakeTint,
                    description = strings.profileValue("profile_birthdate_label"))
            }
        }
        state.error?.let { Notice(FausCrewIcons.exclamationmarkTriangleFill, FausCrewColors.error, it, textColor = FausCrewColors.error) }
    }
}

/** Tinted inline notice (warning or error) used by the profile popups. */
@Composable
internal fun Notice(icon: ImageVector, tint: Color, text: String, textColor: Color = FausCrewColors.textSecondary) {
    val shape = RoundedCornerShape(Radius.md)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(tint.copy(alpha = .1f)).border(1.dp, tint.copy(alpha = .25f), shape)
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(icon, null, Modifier.size(18.dp), tint = tint)
        Text(text, Modifier.weight(1f), style = FausCrewType.caption, color = textColor)
    }
}

@Composable
private fun FieldSection(icon: ImageVector, tint: Color, title: String, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(Radius.lg)
    Column(Modifier.fillMaxWidth().clip(shape).background(FausCrewColors.secondaryBackground).border(1.dp, tint.copy(alpha = .2f), shape)) {
        Row(Modifier.fillMaxWidth().padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.md, bottom = Spacing.sm),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(Modifier.size(28.dp).background(tint.copy(alpha = .14f), RoundedCornerShape(7.dp)), contentAlignment = Alignment.Center) {
                Icon(icon, null, Modifier.size(16.dp), tint = tint)
            }
            Text(title.uppercase(), fontSize = 11.sp, fontWeight = FontWeight.Bold, color = FausCrewColors.textTertiary,
                letterSpacing = .9.sp)
        }
        HorizontalDivider(Modifier.padding(horizontal = Spacing.lg), thickness = .5.dp, color = FausCrewColors.separator)
        content()
    }
}

@Composable
private fun RowIcon(icon: ImageVector, tint: Color) {
    Box(Modifier.size(34.dp).background(tint.copy(alpha = .13f), RoundedCornerShape(8.dp)), contentAlignment = Alignment.Center) {
        Icon(icon, null, Modifier.size(18.dp), tint = tint)
    }
}

@Composable
private fun EditField(
    icon: ImageVector,
    tint: Color,
    placeholder: String,
    value: String,
    onChange: (String) -> Unit,
    imeAction: ImeAction,
    onIme: () -> Unit,
) {
    Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        RowIcon(icon, tint)
        BasicTextField(
            value, onChange, Modifier.weight(1f),
            textStyle = FausCrewType.subheadline.copy(color = FausCrewColors.textPrimary),
            singleLine = true,
            cursorBrush = SolidColor(FausCrewColors.primary),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = imeAction),
            keyboardActions = KeyboardActions(onNext = { onIme() }, onDone = { onIme() }),
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) Text(placeholder, style = FausCrewType.subheadline, color = PlaceholderColor)
                    inner()
                }
            },
        )
    }
}
