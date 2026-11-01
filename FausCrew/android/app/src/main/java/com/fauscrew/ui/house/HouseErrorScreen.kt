package com.fauscrew.ui.house

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
import androidx.compose.foundation.layout.offset
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausButtonGradient
import com.fauscrew.ui.components.FausFramedMark
import com.fauscrew.ui.components.mainScreenBackground
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing

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
    val red = FausCrewColors.errorRed
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
            Box {
                FausFramedMark(150.dp)
                Box(
                    Modifier.align(Alignment.BottomEnd).offset((-6).dp, (-6).dp).size(42.dp)
                        .shadow(8.dp, CircleShape, ambientColor = red, spotColor = red)
                        .background(FausCrewColors.background, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(FausCrewIcons.exclamationmarkTriangleFill, null, Modifier.size(22.dp), tint = red)
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                Text(strings.get("house_error_title"), style = FausCrewType.title2, color = FausCrewColors.textPrimary,
                    textAlign = TextAlign.Center)
                Text(strings.get("house_error_message"), Modifier.padding(horizontal = Spacing.xxxl),
                    style = FausCrewType.subheadline, color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
            }
            Column(Modifier.padding(horizontal = Spacing.xxl), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                HouseJourneyButton(strings.get("house_error_retry_button"), true, FausButtonGradient,
                    glow = FausCrewColors.deepBerry, onClick = retry)
                val shape = RoundedCornerShape(Radius.lg)
                Box(
                    Modifier.fillMaxWidth().height(48.dp).clip(shape).background(FausCrewColors.surface)
                        .border(1.dp, red.copy(alpha = .20f), shape).clickable(role = Role.Button, onClick = logout),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(strings.get("house_error_logout_button"), style = FausCrewType.headline, color = red)
                }
            }
        }
    }
}
