package com.fauscrew.ui.profile

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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseCreationRules
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausButtonGradient
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.components.FausHouseIcon
import com.fauscrew.ui.components.FausIconGradient
import com.fauscrew.ui.components.PlaceholderColor
import com.fauscrew.ui.components.PopupFooter
import com.fauscrew.ui.components.PopupHeader
import com.fauscrew.ui.components.PopupPrimaryButton
import com.fauscrew.ui.components.PopupSecondaryButton
import com.fauscrew.ui.house.HouseTypeUi
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.viewmodel.HouseUiState

private val fieldBorder = Color(0xFFECE7E4)
private val chipFill = Color(0xFFF4F0ED)

/**
 * `CreateHousePopup`: same shell as Join a house — brand header, form body, Cancel / Create
 * footer. Create stays disabled until name, type and member count are all chosen.
 */
@Composable
internal fun CreateHouseDialog(
    state: HouseUiState,
    strings: LocalizedText,
    onDismiss: () -> Unit,
    onCreate: (String, Int, Int) -> Unit,
) {
    val focus = LocalFocusManager.current
    var name by rememberSaveable { mutableStateOf("") }
    var type by rememberSaveable { mutableStateOf<Int?>(null) }
    var count by rememberSaveable { mutableStateOf<Int?>(null) }
    val busy = state.profileActionBusy
    val canCreate = HouseCreationRules.isValid(name, type, count) && !busy
    val dismiss = { focus.clearFocus(); onDismiss() }
    val submit = {
        val chosenType = type
        val chosenCount = count
        if (canCreate && chosenType != null && chosenCount != null) {
            focus.clearFocus()
            onCreate(name.trim(), chosenType, chosenCount)
        }
    }
    FausCrewPopup(
        onDismiss = dismiss, dismissEnabled = !busy, horizontalInset = Spacing.lg, maxBodyHeight = 420.dp,
        bodyPadding = Spacing.lg,
        header = {
            PopupHeader(onClose = dismiss, closeEnabled = !busy, closeDescription = strings.profileValue("common_close"),
                height = 64.dp, spacing = Spacing.sm, closeSize = 28.dp, closeBackgroundAlpha = .18f) {
                Box(Modifier.size(34.dp).background(Color.White.copy(alpha = .18f), CircleShape), contentAlignment = Alignment.Center) {
                    FausHouseIcon(17.dp, color = Color.White)
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(strings.profileValue("profile_house_create_title"), color = Color.White, fontSize = 15.sp,
                        fontWeight = FontWeight.Bold, maxLines = 1)
                    Text(strings.profileValue("profile_house_create_subtitle"), color = Color.White.copy(alpha = .75f),
                        fontSize = 12.sp, fontWeight = FontWeight.Medium, maxLines = 1)
                }
            }
        },
        footer = {
            HorizontalDivider(thickness = .5.dp, color = FausCrewColors.separator)
            PopupFooter(shadow = false, padding = PaddingValues(Spacing.lg, Spacing.md)) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    PopupSecondaryButton(strings.profileValue("common_cancel"), !busy, dismiss, Modifier.weight(1f))
                    PopupPrimaryButton(strings.get(if (busy) "common_creating" else "profile_house_create_button",
                        if (busy) "Creating…" else "Create house"), canCreate, submit, Modifier.weight(1f),
                        icon = FausCrewIcons.plus, busy = busy, brush = FausButtonGradient,
                        disabledBrush = Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = .42f), Color.Gray.copy(alpha = .32f))))
                }
            }
        },
    ) {
        FormSection(strings.get("create_house_name_label", "House name")) {
            NameField(name, { name = it.take(HouseCreationRules.NAME_MAX_LENGTH) }, !busy,
                strings.get("create_house_name_placeholder", "Enter a house name")) { focus.clearFocus() }
        }
        FormSection(strings.get("create_house_type_label", "House type")) {
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                HouseTypeUi.entries.forEach { option ->
                    TypeOption(option, type == option.apiValue, strings.get(option.key), !busy, Modifier.weight(1f)) {
                        type = option.apiValue
                    }
                }
            }
        }
        FormSection(strings.get("create_house_member_count_label", "Number of members")) {
            MemberStepper(count, !busy, strings.profileValue("profile_house_create_member_hint")) { count = it }
        }
        state.profileError?.let { Notice(FausCrewIcons.exclamationmarkTriangleFill, FausCrewColors.error, it, FausCrewColors.error) }
    }
}

@Composable
private fun FormSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Text(title, style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
        content()
    }
}

@Composable
private fun NameField(value: String, onChange: (String) -> Unit, enabled: Boolean, placeholder: String, onDone: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val shape = RoundedCornerShape(Radius.md)
    BasicTextField(
        value, onChange, Modifier.fillMaxWidth(), enabled = enabled,
        textStyle = FausCrewType.body.copy(color = FausCrewColors.textPrimary),
        singleLine = true,
        cursorBrush = SolidColor(FausCrewColors.brandOrange),
        interactionSource = interaction,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
        keyboardActions = KeyboardActions(onDone = { onDone() }),
        decorationBox = { inner ->
            Row(
                Modifier.fillMaxWidth().heightIn(min = 48.dp).clip(shape).background(Color.White)
                    .border(if (focused) 1.5.dp else 1.dp, if (focused) FausCrewColors.brandOrange else fieldBorder, shape)
                    .padding(horizontal = Spacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Icon(FausCrewIcons.pencil, null, Modifier.size(18.dp),
                    tint = if (focused) FausCrewColors.brandOrange else FausCrewColors.textSecondary)
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) Text(placeholder, style = FausCrewType.body, color = PlaceholderColor, maxLines = 1)
                    inner()
                }
                Text("${value.length}/${HouseCreationRules.NAME_MAX_LENGTH}",
                    style = FausCrewType.caption.copy(fontFeatureSettings = "tnum"), color = FausCrewColors.textSecondary)
            }
        },
    )
}

@Composable
private fun TypeOption(type: HouseTypeUi, selected: Boolean, label: String, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.md)
    Column(
        modifier.clip(shape)
            .background(if (selected) FausCrewColors.brandOrange.copy(alpha = .07f) else Color.White)
            .border(1.5.dp, if (selected) FausCrewColors.brandOrange else fieldBorder, shape)
            .clickable(enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(vertical = 10.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        val tile = RoundedCornerShape(10.dp)
        Box(
            Modifier.size(34.dp).clip(tile).then(
                if (selected) Modifier.background(FausIconGradient, tile) else Modifier.background(chipFill, tile)),
            contentAlignment = Alignment.Center,
        ) {
            val tint = if (selected) Color.White else FausCrewColors.textSecondary
            // Shared house uses the custom glyph so it reads the same on iOS and Android.
            if (type == HouseTypeUi.SHARED) FausHouseIcon(18.dp, color = tint)
            else Icon(type.icon, null, Modifier.size(18.dp), tint = tint)
        }
        Text(label, style = FausCrewType.caption, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, maxLines = 2,
            color = if (selected) FausCrewColors.deepBerry else FausCrewColors.textSecondary)
    }
}

@Composable
private fun MemberStepper(count: Int?, enabled: Boolean, hint: String, onChange: (Int) -> Unit) {
    val range = HouseCreationRules.memberCountRange
    val shape = RoundedCornerShape(Radius.md)
    val canDecrease = enabled && count != null && count > range.first
    val canIncrease = enabled && (count ?: 0) < range.last
    Row(
        Modifier.fillMaxWidth().clip(shape).background(Color.White).border(1.dp, fieldBorder, shape)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Icon(FausCrewIcons.person2Fill, null, Modifier.size(20.dp), tint = FausCrewColors.brandOrange)
        Text(hint, Modifier.weight(1f), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
        StepperButton(FausCrewIcons.minus, canDecrease, "-") { count?.let { onChange(it - 1) } }
        Text(count?.toString() ?: "–", Modifier.widthIn(min = 28.dp), fontSize = 20.sp, fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center, color = if (count == null) FausCrewColors.textSecondary else FausCrewColors.deepBerry)
        StepperButton(FausCrewIcons.plus, canIncrease, "+") { onChange(count?.plus(1) ?: range.first) }
    }
}

@Composable
private fun StepperButton(icon: ImageVector, enabled: Boolean, description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(32.dp).clip(CircleShape)
            .then(if (enabled) Modifier.background(FausButtonGradient, CircleShape) else Modifier.background(chipFill, CircleShape))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(18.dp), tint = if (enabled) Color.White else FausCrewColors.textSecondary)
    }
}
