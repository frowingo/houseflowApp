package com.fauscrew.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing

/** `LogoutConfirmationPopup`: warning glyph, copy and the destructive/cancel pair. */
@Composable
internal fun LogoutConfirmationPopup(strings: LocalizedText, onConfirm: () -> Unit, onCancel: () -> Unit) {
    FausCrewPopup(
        onDismiss = onCancel,
        scrimAlpha = .4f,
        horizontalInset = 60.dp,
        header = null,
        bodyPadding = Spacing.xxl,
        bodySpacing = Spacing.xxl,
        scrollableBody = false,
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Icon(FausCrewIcons.exclamationmarkTriangleFill, null, Modifier.size(54.dp), tint = FausCrewColors.warning)
            Text(strings.get("logout_confirm_title"), style = FausCrewType.title2, color = FausCrewColors.textPrimary,
                textAlign = TextAlign.Center)
            Text(strings.get("logout_confirm_message"), Modifier.padding(horizontal = Spacing.lg),
                style = FausCrewType.subheadline, color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ConfirmButton(strings.get("logout_confirm_button"), Color.White, FausCrewColors.error, onConfirm)
            ConfirmButton(strings.get("common_cancel"), FausCrewColors.primary, FausCrewColors.primary.copy(alpha = .1f), onCancel)
        }
    }
}

@Composable
private fun ConfirmButton(text: String, color: Color, background: Color, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(Radius.md)).background(background).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = FausCrewType.headline, color = color)
    }
}
