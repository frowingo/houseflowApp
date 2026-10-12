package com.houseflow.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow
import kotlinx.coroutines.delay

private const val TOAST_DURATION_MILLIS = 4_000L

/**
 * iOS `ToastView` + `ToastStore`: slides in from the top, auto-hides after four seconds and
 * can be dismissed with a tap. [message] null hides it.
 */
@Composable
internal fun HouseFlowToast(message: String?, isError: Boolean, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    // Keep the last text while the exit animation runs.
    var shown by remember { mutableStateOf(message) }
    if (message != null) shown = message
    LaunchedEffect(message) {
        if (message != null) {
            delay(TOAST_DURATION_MILLIS)
            onDismiss()
        }
    }
    AnimatedVisibility(
        visible = message != null,
        modifier = modifier,
        enter = slideInVertically(Motion.standard()) { -it } + fadeIn(Motion.standard()),
        exit = slideOutVertically(Motion.standard()) { -it } + fadeOut(Motion.standard()),
    ) {
        val tint = if (isError) HouseFlowColors.error else HouseFlowColors.success
        val shape = RoundedCornerShape(Radius.md)
        Row(
            Modifier.fillMaxWidth().padding(horizontal = Spacing.xxl)
                .softShadow(androidx.compose.ui.graphics.Color.Black.copy(alpha = .12f), 16.dp, y = 6.dp, shape = shape)
                .clip(shape)
                .background(HouseFlowColors.cardBackground)
                .border(1.dp, tint.copy(alpha = .35f), shape)
                .clickable(onClick = onDismiss)
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Icon(if (isError) HouseFlowIcons.xmarkCircleFill else HouseFlowIcons.checkmarkCircleFill, null,
                Modifier.size(20.dp), tint = tint)
            Text(shown.orEmpty(), Modifier.weight(1f), style = HouseFlowType.subheadline,
                color = HouseFlowColors.textPrimary, maxLines = 3)
        }
    }
}
