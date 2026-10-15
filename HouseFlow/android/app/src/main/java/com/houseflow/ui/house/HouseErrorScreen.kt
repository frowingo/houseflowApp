package com.houseflow.ui.house

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing

/**
 * `HouseErrorView`: shown when restoring the session or loading the house fails; the user
 * can only retry or log out. Like iOS, the copy is the localized message, not the raw error.
 */
@Composable
internal fun HouseErrorScreen(
    strings: LocalizedText,
    retry: () -> Unit,
    logout: () -> Unit,
) {
    val red = HouseFlowColors.errorRed
    Box(
        Modifier.fillMaxSize().mainScreenBackground().drawBehind {
            drawRect(Brush.radialGradient(listOf(red.copy(alpha = .055f), Color.Transparent), radius = 360.dp.toPx()))
        },
    ) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.xxxl, Alignment.CenterVertically),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Box(Modifier.size(120.dp).background(red.copy(alpha = .08f), CircleShape)
                    .border(1.dp, HouseFlowColors.accentOrange.copy(alpha = .18f), CircleShape))
                Box(Modifier.size(88.dp).background(red.copy(alpha = .06f), CircleShape))
                Icon(HouseFlowIcons.exclamationmarkTriangleFill, null, Modifier.size(54.dp), tint = red)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                Text(strings.get("house_error_title"), style = HouseFlowType.title2, color = HouseFlowColors.textPrimary,
                    textAlign = TextAlign.Center)
                Text(strings.get("house_error_message"), Modifier.padding(horizontal = Spacing.xxxl),
                    style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
            }
            Column(Modifier.padding(horizontal = Spacing.xxl), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                HouseJourneyButton(strings.get("house_error_retry_button"), true, HouseJourneyBrushes.primaryButton,
                    glow = HouseFlowColors.indigo, onClick = retry)
                val shape = RoundedCornerShape(Radius.lg)
                Box(
                    Modifier.fillMaxWidth().height(48.dp).clip(shape).background(HouseFlowColors.surface)
                        .border(1.dp, red.copy(alpha = .20f), shape).clickable(role = Role.Button, onClick = logout),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(strings.get("house_error_logout_button"), style = HouseFlowType.headline, color = red)
                }
            }
        }
    }
}
