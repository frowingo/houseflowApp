package com.houseflow.ui.theme

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.remember
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.addOutline
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

/**
 * SwiftUI `.shadow(color:radius:x:y:)`: a colored, blurred and offset shadow of [shape].
 * Material elevation cannot tint or offset shadows, so the platform shadow layer is used
 * (hardware accelerated on the app's minSdk 30). Apply before `clip`/`background`.
 */
internal fun Modifier.softShadow(
    color: Color,
    radius: Dp,
    x: Dp = 0.dp,
    y: Dp = 0.dp,
    shape: Shape = RectangleShape,
): Modifier = if (color.alpha == 0f) this else drawBehind {
    val path = Path().apply { addOutline(shape.createOutline(size, layoutDirection, this@drawBehind)) }
    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
        this.color = android.graphics.Color.TRANSPARENT
        setShadowLayer(radius.toPx(), x.toPx(), y.toPx(), color.toArgb())
    }
    drawIntoCanvas { it.nativeCanvas.drawPath(path.asAndroidPath(), paint) }
}

/** SwiftUI `foregroundStyle(LinearGradient)` for icons and text. */
internal fun Modifier.gradientForeground(brush: Brush): Modifier =
    graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
        .drawWithContent {
            drawContent()
            drawRect(brush, blendMode = BlendMode.SrcIn)
        }

/**
 * Staggered card entrance used by the iOS tab screens:
 * `.opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : offset)` with a delayed spring.
 */
@Composable
internal fun rememberEntrance(delayMillis: Int): State<Float> {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(delayMillis.toLong())
        progress.animateTo(1f, Motion.entrance())
    }
    return progress.asState()
}

internal fun Modifier.entrance(progress: State<Float>, offsetY: Dp): Modifier = graphicsLayer {
    val value = progress.value
    alpha = value.coerceIn(0f, 1f)
    translationY = (1f - value) * offsetY.toPx()
}

/**
 * SwiftUI `ScaleButtonStyle`: a borderless tap target that springs to 97 % while pressed.
 * [role] keeps the accessibility semantics of a SwiftUI `Button`.
 */
internal fun Modifier.scaleButton(
    enabled: Boolean = true,
    role: Role = Role.Button,
    onClick: () -> Unit,
): Modifier = composed {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        if (pressed) .97f else 1f,
        spring(dampingRatio = .7f, stiffness = 440f),
        label = "scaleButton",
    )
    graphicsLayer { scaleX = scale; scaleY = scale }
        .clickable(interaction, indication = null, enabled = enabled, role = role, onClick = onClick)
}
