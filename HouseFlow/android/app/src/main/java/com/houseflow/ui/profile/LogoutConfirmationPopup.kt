package com.houseflow.ui.profile

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
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.HouseFlowPopup
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing

/** `LogoutConfirmationPopup`: warning glyph, copy and the destructive/cancel pair. */
@Composable
internal fun LogoutConfirmationPopup(strings: LocalizedText, onConfirm: () -> Unit, onCancel: () -> Unit) {
    HouseFlowPopup(
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
            Icon(HouseFlowIcons.exclamationmarkTriangleFill, null, Modifier.size(54.dp), tint = HouseFlowColors.warning)
            Text(strings.get("logout_confirm_title"), style = HouseFlowType.title2, color = HouseFlowColors.textPrimary,
                textAlign = TextAlign.Center)
            Text(strings.get("logout_confirm_message"), Modifier.padding(horizontal = Spacing.lg),
                style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ConfirmButton(strings.get("logout_confirm_button"), Color.White, HouseFlowColors.error, onConfirm)
            ConfirmButton(strings.get("common_cancel"), HouseFlowColors.primary, HouseFlowColors.primary.copy(alpha = .1f), onCancel)
        }
    }
}

@Composable
private fun ConfirmButton(text: String, color: Color, background: Color, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(Radius.md)).background(background).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = HouseFlowType.headline, color = color)
    }
}
