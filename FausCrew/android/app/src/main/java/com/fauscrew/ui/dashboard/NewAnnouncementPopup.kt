package com.fauscrew.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.components.PopupError
import com.fauscrew.ui.components.PopupFooter
import com.fauscrew.ui.components.PopupHeader
import com.fauscrew.ui.components.PopupHeaderTitle
import com.fauscrew.ui.components.PopupPrimaryButton
import com.fauscrew.ui.components.PopupTextField
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow

private const val TITLE_LIMIT = 30
private const val MESSAGE_LIMIT = 150
private val accentOrange = FausCrewColors.accentOrange

/** `NewAnnouncementPopup`: stays open while publishing so a failed request keeps the draft. */
@Composable
internal fun NewAnnouncementPopup(
    strings: LocalizedText,
    busy: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onPublish: (String, String) -> Unit,
) {
    val focus = LocalFocusManager.current
    val haptics = LocalHapticFeedback.current
    var title by rememberSaveable { mutableStateOf("") }
    var message by rememberSaveable { mutableStateOf("") }
    val canPublish = title.isNotBlank() && message.isNotBlank() && !busy
    val dismiss = { focus.clearFocus(); onDismiss() }
    val activeBorder = { focused: Boolean -> if (focused) accentOrange.copy(alpha = .60f) else Color.Transparent }

    FausCrewPopup(
        onDismiss = dismiss,
        dismissEnabled = !busy,
        maxBodyHeight = 430.dp,
        cornerRadius = Radius.xxl,
        scrimAlpha = .52f,
        borderColor = accentOrange.copy(alpha = .16f),
        header = {
            PopupHeader(
                onClose = dismiss, closeEnabled = !busy, closeDescription = strings.get("common_close"),
                decorativeIcon = FausCrewIcons.megaphoneFill, decorativeIconSize = 64.dp, decorativeIconAlpha = .10f,
                decorativeOffsetX = 84.dp, height = 62.dp, closeSize = 30.dp, closeBackgroundAlpha = .18f,
            ) {
                Box(Modifier.size(34.dp).background(Color.White.copy(alpha = .18f), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(FausCrewIcons.megaphoneFill, null, Modifier.size(18.dp), tint = Color.White)
                }
                PopupHeaderTitle(strings.get("new_announcement_title", "New announcement"))
            }
        },
        footer = {
            PopupFooter(shadow = false, spacing = Spacing.sm,
                padding = PaddingValues(start = Spacing.xl, end = Spacing.xl, top = Spacing.md, bottom = Spacing.xl)) {
                PopupPrimaryButton(
                    text = if (busy) strings.get("common_publishing", "Publishing...")
                        else strings.get("new_announcement_publish_button", "Publish announcement"),
                    enabled = canPublish,
                    busy = busy,
                    icon = FausCrewIcons.paperplaneFill,
                    brush = Brush.horizontalGradient(listOf(accentOrange, Color(0xFFE65714))),
                    disabledBrush = Brush.horizontalGradient(listOf(FausCrewColors.systemGray3, FausCrewColors.systemGray4)),
                    height = 50.dp,
                    cornerRadius = Radius.lg,
                    modifier = Modifier.fillMaxWidth().softShadow(
                        if (canPublish) accentOrange.copy(alpha = .28f) else Color.Transparent, 9.dp, y = 4.dp,
                        shape = RoundedCornerShape(Radius.lg)),
                    onClick = {
                        focus.clearFocus()
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onPublish(title.trim(), message.trim())
                    },
                )
                Box(Modifier.fillMaxWidth().height(44.dp).clickable(enabled = !busy, onClick = dismiss),
                    contentAlignment = Alignment.Center) {
                    Text(strings.get("common_cancel"), style = FausCrewType.headline, color = FausCrewColors.textSecondary)
                }
            }
        },
    ) {
        Text(strings.get("new_announcement_subtitle", "Share an important update with everyone in your house."),
            Modifier.fillMaxWidth(), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary,
            textAlign = TextAlign.Center)
        PopupError(error)
        CountedField(FausCrewIcons.textFormat, strings.get("new_announcement_title_label", "Title"), title.length, TITLE_LIMIT) {
            PopupTextField(title, { title = it.take(TITLE_LIMIT) },
                strings.get("new_announcement_title_placeholder", "What should everyone know?"), Modifier.fillMaxWidth(),
                borderColor = activeBorder,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                keyboardActions = KeyboardActions(onNext = { focus.moveFocus(FocusDirection.Down) }))
        }
        CountedField(FausCrewIcons.textAlignLeft, strings.get("new_announcement_message_label", "Message"), message.length, MESSAGE_LIMIT) {
            PopupTextField(message, { message = it.take(MESSAGE_LIMIT) },
                strings.get("new_announcement_message_placeholder", "Write the announcement details..."),
                Modifier.fillMaxWidth().height(132.dp), singleLine = false, borderColor = activeBorder,
                contentPadding = PaddingValues(horizontal = 17.dp, vertical = Spacing.lg))
        }
    }
}

@Composable
private fun CountedField(icon: ImageVector, label: String, count: Int, limit: Int, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Icon(icon, null, Modifier.size(15.dp), tint = accentOrange)
            Text(label, style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
            Spacer(Modifier.weight(1f))
            Text("$count/$limit", style = FausCrewType.caption2.copy(fontFeatureSettings = "tnum"),
                color = FausCrewColors.textTertiary)
        }
        content()
    }
}
