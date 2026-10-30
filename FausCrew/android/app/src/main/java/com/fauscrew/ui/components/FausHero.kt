package com.fauscrew.ui.components

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
import androidx.compose.foundation.border
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.SolidColor
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.linear

/** Icons and small accents filled with the brand diagonal. */
internal val FausIconGradient: Brush
    @Composable @ReadOnlyComposable
    get() = Brush.linearGradient(
        0f to FausCrewColors.brandLight,
        .4f to FausCrewColors.brandOrange,
        1f to FausCrewColors.markBerry,
    )

/**
 * Full-bleed hero surface (auth headers, splash) with the `BrandHeroCard` geometry: circles
 * top-right and two tilted capsules, over the theme's header gradient and glows.
 */
@Composable
internal fun Modifier.fausHeroBackground(): Modifier {
    val decor = LocalFausTheme.current.decor
    val accentCapsule = FausCrewColors.systemOrange
    return background(decor.headerStops.linear()).drawBehind {
        drawCornerGlow(decor.heroGlow.copy(alpha = decor.heroGlow.alpha * .85f), reach = .75f)
        if (decor.headerGlow.alpha > 0f) {
            drawRect(Brush.radialGradient(
                listOf(decor.headerGlow, decor.headerGlow.copy(alpha = 0f)),
                center = Offset(size.width / 2, size.height * .48f), radius = size.width * .42f,
            ))
        }
        drawHeroGeometry(decor.heroOrnament, accentCapsule)
    }
}

private fun DrawScope.drawHeroGeometry(ornament: Color, accentCapsule: Color) {
    val w = size.width
    drawCircle(ornament.copy(alpha = .08f), 79.dp.toPx(), Offset(w - 6.dp.toPx(), 60.dp.toPx()))
    drawCircle(ornament.copy(alpha = .16f), 59.dp.toPx(), Offset(w - 15.dp.toPx(), 68.dp.toPx()), style = Stroke(1.dp.toPx()))
    drawCircle(ornament.copy(alpha = .10f), 41.dp.toPx(), Offset(w - 21.dp.toPx(), 74.dp.toPx()), style = Stroke(1.dp.toPx()))
    fun capsule(color: Color, center: Offset, width: Float, height: Float) = rotate(-28f, center) {
        drawRoundRect(color, Offset(center.x - width / 2, center.y - height / 2), Size(width, height), CornerRadius(height / 2))
    }
    capsule(ornament.copy(alpha = .08f), Offset(w - 20.dp.toPx(), size.height - 70.dp.toPx()), 180.dp.toPx(), 24.dp.toPx())
    capsule(accentCapsule.copy(alpha = .22f), Offset(23.dp.toPx(), 92.dp.toPx()), 126.dp.toPx(), 18.dp.toPx())
}

/**
 * The form sheet that rises over [fausHeroBackground] (iOS `FausSheetBackground`): the theme's
 * sheet gradient over its first 660dp, optional mesh texture and a lit top edge. Apply after the
 * caller's rounded clip.
 */
@Composable
internal fun Modifier.fausSheetBackground(cornerRadius: Dp = 32.dp): Modifier {
    val decor = LocalFausTheme.current.decor
    return drawWithCache {
        val mesh = decor.sheetMesh?.let { MeshLayer(it, size, density, masked = false) }
        val band = 660.dp.toPx()
        val stops = decor.sheetStops
        val base = if (stops.size == 1) SolidColor(stops.first().second)
            else Brush.verticalGradient(*stops.map { (it.first * band / size.height).coerceAtMost(1f) to it.second }.toTypedArray())
        onDrawBehind {
            drawRect(base)
            mesh?.let { drawMesh(it) }
            if (decor.sheetEdge.alpha > 0f) {
                val edge = Brush.verticalGradient(listOf(decor.sheetEdge, Color.Transparent), endY = 48.dp.toPx())
                val glow = Brush.verticalGradient(listOf(decor.sheetEdgeGlow, Color.Transparent), endY = 18.dp.toPx())
                drawRect(glow)
                val inset = .75.dp.toPx()
                drawRoundRect(edge, Offset(inset, inset), Size(size.width - inset * 2, size.height),
                    CornerRadius(cornerRadius.toPx()), style = Stroke(1.5.dp.toPx()))
            }
        }
    }
}

/** `FausBadge`: the theme's badge disc with two soft halo rings; [content] is drawn on top. */
@Composable
internal fun FausBadge(size: Dp, content: @Composable BoxScope.() -> Unit) {
    val decor = LocalFausTheme.current.decor
    val fill = decor.badgeFill.let { if (it.size == 1) SolidColor(it.first()) else Brush.linearGradient(it) }
    Box(Modifier.size(size + 32.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(size + 32.dp).background(decor.badgeHalo.copy(alpha = .07f), CircleShape))
        Box(Modifier.size(size + 16.dp).background(decor.badgeHalo.copy(alpha = .16f), CircleShape))
        Box(Modifier.size(size).shadow(12.dp, CircleShape, ambientColor = FausCrewColors.deepBerry,
            spotColor = FausCrewColors.deepBerry).background(fill, CircleShape)
            .drawBehind {
                if (decor.headerGlow.alpha > 0f) drawCircle(Brush.radialGradient(
                    listOf(decor.headerGlow, decor.headerGlow.copy(alpha = 0f)), radius = this.size.minDimension / 2))
            }
            .border(1.5.dp, decor.badgeBorder, CircleShape))
        content()
    }
}

/** An icon filled with [FausIconGradient] instead of a flat tint. */
@Composable
internal fun FausGradientIcon(icon: ImageVector, size: Dp, modifier: Modifier = Modifier) {
    val gradient = FausIconGradient
    Icon(icon, null, modifier.size(size)
        .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
        .drawWithCache { onDrawWithContent { drawContent(); drawRect(gradient, blendMode = BlendMode.SrcIn) } },
        tint = Color.White)
}
