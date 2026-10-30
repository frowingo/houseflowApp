package com.fauscrew.ui.dashboard

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.HouseDetails
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.CompactDatePicker
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.components.PopupError
import com.fauscrew.ui.components.PopupFooter
import com.fauscrew.ui.components.PopupHeader
import com.fauscrew.ui.components.PopupHeaderTitle
import com.fauscrew.ui.components.PopupPrimaryButton
import com.fauscrew.ui.components.PopupSecondaryButton
import com.fauscrew.ui.components.PopupSectionLabel
import com.fauscrew.ui.components.PopupTextField
import com.fauscrew.ui.components.UserAvatar
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Motion
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val accentOrange: Color @Composable @ReadOnlyComposable get() = FausCrewColors.accentOrange

/** `NewChorePopup`: title, description, assignee, difficulty, due date and recurrence. */
@Composable
internal fun NewChorePopup(
    details: HouseDetails,
    strings: LocalizedText,
    busy: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onCreate: (ChoreInput) -> Unit,
) {
    val focus = LocalFocusManager.current
    var title by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }
    var memberId by rememberSaveable(details.id) { mutableStateOf(details.members.firstOrNull()?.id.orEmpty()) }
    var level by rememberSaveable { mutableStateOf(ChoreLevelUi.EASY) }
    var dueDate by remember { mutableStateOf(LocalDate.now()) }
    var recurring by rememberSaveable { mutableStateOf(false) }
    var interval by rememberSaveable { mutableStateOf("7") }
    val canCreate = title.isNotBlank() && memberId.isNotBlank() && details.id.isNotBlank() && !dueDate.isBefore(LocalDate.now())
    val dismiss = { focus.clearFocus(); onDismiss() }

    FausCrewPopup(
        onDismiss = dismiss,
        dismissEnabled = !busy,
        maxBodyHeight = 460.dp,
        header = {
            PopupHeader(onClose = dismiss, closeEnabled = !busy, closeDescription = strings.get("common_close"),
                decorativeIcon = FausCrewIcons.sparkles) {
                PopupHeaderTitle(strings.get("new_chore_title"))
            }
        },
        footer = { PopupFooter {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                PopupSecondaryButton(strings.get("common_cancel"), !busy, dismiss, Modifier.weight(1f))
                PopupPrimaryButton(strings.get("common_create"), canCreate, busy = busy, modifier = Modifier.weight(1f),
                    onClick = {
                        focus.clearFocus()
                        val local = dueDate.atStartOfDay(ZoneId.systemDefault()).toOffsetDateTime()
                        onCreate(ChoreInput(details.id, memberId, title.trim(), description,
                            DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(local), recurring, level.raw,
                            if (recurring) interval.toIntOrNull() ?: 7 else 0))
                    })
            }
        } },
    ) {
        val filledBorder = accentOrange.copy(alpha = .5f)
        PopupError(error)
        FormField(FausCrewIcons.pencil, strings.get("new_chore_task_name_label")) {
            PopupTextField(title, { title = it }, strings.get("new_chore_task_name_placeholder"), Modifier.fillMaxWidth(),
                borderColor = { if (title.isEmpty()) Color.Transparent else filledBorder })
        }
        FormField(FausCrewIcons.textAlignLeft, strings.get("new_chore_description_label")) {
            PopupTextField(description, { description = it }, strings.get("new_chore_description_placeholder"),
                Modifier.fillMaxWidth(), singleLine = false, minLines = 2, maxLines = 4,
                borderColor = { if (description.isEmpty()) Color.Transparent else filledBorder })
        }
        FormField(FausCrewIcons.personFill, strings.get("new_chore_assign_to_label")) {
            MemberPicker(details.members, memberId) { memberId = it }
        }
        FormField(FausCrewIcons.flameFill, strings.get("new_chore_difficulty_label")) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                ChoreLevelUi.entries.forEach { option ->
                    LevelOption(option, option == level, strings, Modifier.weight(1f)) { level = option }
                }
            }
        }
        FormField(FausCrewIcons.calendar, strings.get("new_chore_due_date_label")) {
            DueDateField(dueDate, strings) { dueDate = it }
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                PopupSectionLabel(FausCrewIcons.arrowClockwise, strings.get("new_chore_recurring_label"))
                Spacer(Modifier.weight(1f))
                Switch(recurring, { recurring = it }, colors = iosSwitchColors())
            }
            AnimatedVisibility(recurring, enter = fadeIn(Motion.quick()) + expandVertically(Motion.quick()),
                exit = fadeOut(Motion.quick()) + shrinkVertically(Motion.quick())) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    Text(strings.get("new_chore_every_label"), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
                    PopupTextField(interval, { value -> interval = value.filter(Char::isDigit).take(3) }, "7",
                        Modifier.width(56.dp), textStyle = FausCrewType.bodyBold, textAlign = TextAlign.Center,
                        contentPadding = PaddingValues(vertical = Spacing.sm), cornerRadius = Radius.sm,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                    Text(strings.get("new_chore_days_label"), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun FormField(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        PopupSectionLabel(icon, label)
        content()
    }
}

@Composable
private fun MemberPicker(members: List<HouseMember>, selectedId: String, onSelect: (String) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 2.dp),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        members.forEach { member ->
            val selected = member.id == selectedId
            val badge by animateFloatAsState(if (selected) 1f else 0f, Motion.quick(), label = "memberBadge")
            Column(
                Modifier.clip(RoundedCornerShape(Radius.md))
                    .background(if (selected) accentOrange.copy(alpha = .08f) else Color.Transparent)
                    .clickable(role = Role.RadioButton) { onSelect(member.id) }
                    .semantics { this.selected = selected }
                    .padding(Spacing.sm),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(48.dp).border(3.dp, if (selected) accentOrange else Color.Transparent, CircleShape)
                        .padding(4.dp).background(if (selected) accentOrange.copy(alpha = .15f) else Color.Transparent, CircleShape))
                    UserAvatar(member, 40.dp)
                    if (badge > 0f) {
                        Box(
                            Modifier.align(Alignment.TopEnd).offset(4.dp, (-4).dp).size(18.dp)
                                .graphicsLayer { scaleX = badge; scaleY = badge; alpha = badge }
                                .background(Color.White, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(FausCrewIcons.checkmarkCircleFill, null, Modifier.size(20.dp), tint = accentOrange)
                        }
                    }
                }
                Text(member.firstName, fontSize = 11.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                    color = if (selected) accentOrange else FausCrewColors.textSecondary, maxLines = 1)
            }
        }
    }
}

@Composable
private fun LevelOption(level: ChoreLevelUi, selected: Boolean, strings: LocalizedText, modifier: Modifier, onClick: () -> Unit) {
    Row(
        modifier.clip(RoundedCornerShape(Radius.md))
            .background(if (selected) level.color else level.color.copy(alpha = .12f))
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = Spacing.md, vertical = 9.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val tint = if (selected) Color.White else level.color
        Icon(level.icon, null, Modifier.size(15.dp), tint = tint)
        Text(strings.get(level.key), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1)
    }
}

/** Compact iOS date picker in the filled field; the calendar opens as a floating card. */
@Composable
private fun DueDateField(date: LocalDate, strings: LocalizedText, onChange: (LocalDate) -> Unit) {
    val today = LocalDate.now()
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(FausCrewColors.secondaryBackground)
        .padding(horizontal = Spacing.md, vertical = Spacing.sm)) {
        CompactDatePicker(date, onChange, today..today.plusYears(5), accentOrange,
            description = strings.get("new_chore_due_date_label"))
    }
}

/** iOS `Toggle` tinted with the brand orange. */
@Composable
internal fun iosSwitchColors() = SwitchDefaults.colors(
    checkedThumbColor = Color.White,
    checkedTrackColor = accentOrange,
    checkedBorderColor = Color.Transparent,
    uncheckedThumbColor = Color.White,
    uncheckedTrackColor = Color(0xFFE9E9EB),
    uncheckedBorderColor = Color.Transparent,
)
