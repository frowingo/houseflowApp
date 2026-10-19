package com.houseflow.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.houseflow.ui.theme.HouseFlowColors

/** Icons and small accents filled with the brand diagonal. */
internal val FausIconGradient = Brush.linearGradient(
    0f to HouseFlowColors.brandLight,
    .4f to HouseFlowColors.brandOrange,
    1f to Color(0xFF8A2440),
)

/** Orange → berry hero surface with the `BrandHeroCard` geometry: circles top-right, two tilted capsules. */
internal fun Modifier.fausHeroBackground(): Modifier = background(FausHeroGradient).drawBehind { drawHeroGeometry() }

private fun DrawScope.drawHeroGeometry() {
    val w = size.width
    drawCircle(Color.White.copy(alpha = .08f), 79.dp.toPx(), Offset(w - 6.dp.toPx(), 60.dp.toPx()))
    drawCircle(Color.White.copy(alpha = .16f), 59.dp.toPx(), Offset(w - 15.dp.toPx(), 68.dp.toPx()), style = Stroke(1.dp.toPx()))
    drawCircle(Color.White.copy(alpha = .10f), 41.dp.toPx(), Offset(w - 21.dp.toPx(), 74.dp.toPx()), style = Stroke(1.dp.toPx()))
    fun capsule(color: Color, center: Offset, width: Float, height: Float) = rotate(-28f, center) {
        drawRoundRect(color, Offset(center.x - width / 2, center.y - height / 2), Size(width, height), CornerRadius(height / 2))
    }
    capsule(Color.White.copy(alpha = .08f), Offset(w - 20.dp.toPx(), size.height - 70.dp.toPx()), 180.dp.toPx(), 24.dp.toPx())
    capsule(HouseFlowColors.systemOrange.copy(alpha = .22f), Offset(23.dp.toPx(), 92.dp.toPx()), 126.dp.toPx(), 18.dp.toPx())
}

/** `FausBadge`: white circle with two soft halo rings; [content] is drawn on top. */
@Composable
internal fun FausBadge(size: Dp, content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.size(size + 32.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(size + 32.dp).background(Color.White.copy(alpha = .07f), CircleShape))
        Box(Modifier.size(size + 16.dp).background(Color.White.copy(alpha = .16f), CircleShape))
        Box(Modifier.size(size).shadow(12.dp, CircleShape, ambientColor = HouseFlowColors.deepBerry,
            spotColor = HouseFlowColors.deepBerry).background(Color.White, CircleShape))
        content()
    }
}

/** An icon filled with [FausIconGradient] instead of a flat tint. */
@Composable
internal fun FausGradientIcon(icon: ImageVector, size: Dp, modifier: Modifier = Modifier) {
    Icon(icon, null, modifier.size(size)
        .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
        .drawWithCache { onDrawWithContent { drawContent(); drawRect(FausIconGradient, blendMode = BlendMode.SrcIn) } },
        tint = Color.White)
}
