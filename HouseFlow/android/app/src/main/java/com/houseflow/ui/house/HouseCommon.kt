package com.houseflow.ui.house

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow

/** `HouseJourneyTheme` gradients for the create / join / house-state journey. */
internal object HouseJourneyBrushes {
    val primaryButton = Brush.horizontalGradient(listOf(HouseFlowColors.indigo, HouseFlowColors.deepIndigo))
    val joinButton = Brush.horizontalGradient(listOf(HouseFlowColors.deepTeal, HouseFlowColors.buttonBlue))
    val disabledButton = Brush.horizontalGradient(listOf(Color.Gray.copy(alpha = .30f), Color.Gray.copy(alpha = .24f)))
}

/** Round back control shared by the house journey screens (`chevron.left` in a surface circle). */
@Composable
internal fun HouseBackButton(description: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.xxl)) {
        Box(
            Modifier.size(40.dp).clip(CircleShape).background(HouseFlowColors.surface)
                .border(1.dp, HouseFlowColors.brandOrange.copy(alpha = .20f), CircleShape)
                .clickable(role = Role.Button, onClick = onClick)
                .semantics { contentDescription = description },
            contentAlignment = Alignment.Center,
        ) {
            Icon(HouseFlowIcons.chevronLeft, null, Modifier.size(24.dp), tint = HouseFlowColors.accentOrangeInk)
        }
    }
}

/**
 * Full-width journey CTA: indigo gradient with an orange hairline and indigo glow when
 * enabled, gray otherwise.
 */
@Composable
internal fun HouseJourneyButton(
    label: String,
    enabled: Boolean,
    brush: Brush,
    modifier: Modifier = Modifier,
    height: Dp = 48.dp,
    glow: Color = HouseFlowColors.indigo,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.lg)
    Box(
        modifier.fillMaxWidth().height(height)
            .softShadow(if (enabled) glow.copy(alpha = .22f) else Color.Transparent, 12.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(if (enabled) brush else HouseJourneyBrushes.disabledButton)
            .border(1.dp, if (enabled) HouseFlowColors.accentOrange.copy(alpha = .34f) else Color.Transparent, shape)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, style = HouseFlowType.headline, color = if (enabled) Color.White else Color.Gray)
    }
}
