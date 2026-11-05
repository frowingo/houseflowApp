package com.fauscrew.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.fauscrew.R
import com.fauscrew.ui.theme.FausOrnament
import com.fauscrew.ui.theme.LocalFausTheme
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

// Faus Web decoration, mirroring iOS `FausWeb.swift`: the orb-web geometry of the mark's
// web dot, the corner web and silk strand of hero surfaces and the card sheen. Placements are dp
// from the Faus Web design canvas (a 390×844 screen).

/** An orb web: straight spokes from the hub and rings whose chords sag toward the hub. */
internal fun fausWebPath(
    center: Offset,
    radius: Float,
    spokes: Int = 8,
    rings: Int = 3,
    rotation: Double = -PI / 2,
    sag: Float = .72f,
): Path {
    val angles = List(spokes) { rotation + it * 2 * PI / spokes }
    fun point(angle: Double, r: Float) = Offset(center.x + cos(angle).toFloat() * r, center.y + sin(angle).toFloat() * r)
    return Path().apply {
        for (angle in angles) {
            moveTo(center.x, center.y)
            point(angle, radius).let { lineTo(it.x, it.y) }
        }
        for (ring in 1..rings) {
            val r = radius * ring / rings
            point(angles[0], r).let { moveTo(it.x, it.y) }
            for (index in 0 until spokes) {
                val start = angles[index]
                val end = if (index + 1 < spokes) angles[index + 1] else angles[0] + 2 * PI
                val control = point((start + end) / 2, r * sag)
                val to = point(end, r)
                quadraticTo(control.x, control.y, to.x, to.y)
            }
            close()
        }
    }
}

/** Center of the Faus Web mark's web dot on the mark's 1024 grid. */
internal val FausWebDotCenter = Offset(652f, 578f)

/** The web dot replacing the mark's round dot (8 spokes, 3 rings, turned 22.5°) around [hub], at [scale] px per grid step. */
internal fun fausWebDotPath(hub: Offset, scale: Float): Path = fausWebPath(hub, 78f * scale, rotation = -PI / 2 + PI / 8)

/** Which hero surface a web ornament decorates (iOS `FausWebOrnament.Surface`). */
internal enum class WebOrnamentSurface { HERO_CARD, POPUP_HEADER, TAB_BAR, HEADER }

/** The corner web and strand images, loaded only while the theme draws [FausOrnament.WEB]. */
internal class WebOrnamentImages(val corner: ImageBitmap, val strand: ImageBitmap)

@Composable
internal fun rememberWebOrnamentImages(): WebOrnamentImages? {
    if (LocalFausTheme.current.decor.ornament != FausOrnament.WEB) return null
    return WebOrnamentImages(
        corner = ImageBitmap.imageResource(R.drawable.web_corner),
        strand = ImageBitmap.imageResource(R.drawable.web_strand),
    )
}

/**
 * Faus Web's decoration for hero surfaces: a crimson glow from the top-start corner and a sky
 * glow from the bottom-end one, a cream orb web hanging in the top-end corner and an angled silk
 * strand across the surface.
 */
internal fun DrawScope.drawWebOrnament(surface: WebOrnamentSurface, images: WebOrnamentImages, ornament: Color) {
    if (surface != WebOrnamentSurface.TAB_BAR) {
        val reach = hypot(size.width, size.height) * .55f
        drawRect(Brush.radialGradient(listOf(Color(0x6BE23A42), Color(0x00E23A42)), center = Offset.Zero, radius = reach))
        drawRect(Brush.radialGradient(listOf(Color(0x428FB2FF), Color(0x008FB2FF)), center = Offset(size.width, size.height), radius = reach))
    }
    val tint = ColorFilter.tint(ornament)
    val (side, cornerAlpha) = when (surface) {
        WebOrnamentSurface.HERO_CARD -> 120f to .18f
        WebOrnamentSurface.POPUP_HEADER -> 70f to .2f
        WebOrnamentSurface.TAB_BAR -> 80f to .16f
        WebOrnamentSurface.HEADER -> 170f to .16f
    }
    val cornerPx = (side * density).roundToInt()
    drawImage(
        images.corner,
        dstOffset = IntOffset((size.width - cornerPx).roundToInt(), 0),
        dstSize = IntSize(cornerPx, cornerPx),
        alpha = cornerAlpha,
        colorFilter = tint,
    )

    val widthDp = size.width / density
    // Leading, top, width, height, rotation and alpha on the 390dp design canvas.
    val strand = when (surface) {
        WebOrnamentSurface.HERO_CARD -> floatArrayOf(-30f, 68f, 420f, 63f, -5f, .4f)
        WebOrnamentSurface.POPUP_HEADER -> floatArrayOf(-65f, -8f, 240f, 36f, -17f, .55f)
        WebOrnamentSurface.TAB_BAR -> floatArrayOf(widthDp - 187f, -6f, 260f, 39f, 17f, .5f)
        WebOrnamentSurface.HEADER -> floatArrayOf(-40f, 220f, 480f, 72f, -5f, .5f)
    }
    val (x, y, w, h) = strand.take(4).map { it * density }
    rotate(strand[4], pivot = Offset(x + w / 2, y + h / 2)) {
        drawImage(
            images.strand,
            dstOffset = IntOffset(x.roundToInt(), y.roundToInt()),
            dstSize = IntSize(w.roundToInt(), h.roundToInt()),
            alpha = strand[5],
            colorFilter = tint,
        )
    }
}

/** The tab bar's inner crimson light: the bar stops as an ellipse around (40%, 30%). */
internal fun DrawScope.drawWebTabBarLight(stops: List<Pair<Float, Color>>) {
    withTransform({ scale(1f, size.height / size.width * 1.33f, Offset(size.width * .4f, size.height * .3f)) }) {
        drawRect(
            Brush.radialGradient(*stops.toTypedArray(), center = Offset(size.width * .4f, size.height * .3f), radius = size.width * .75f),
            topLeft = Offset(0f, -size.height * 4),
            size = androidx.compose.ui.geometry.Size(size.width, size.height * 9),
        )
    }
}

/**
 * The lighter tone a main card fades from at its top-end corner (`FausDecor.cardSheen`); draws
 * nothing for flat cards. Call over the card fill, inside its clip.
 */
internal fun DrawScope.drawCardSheen(sheen: Color) {
    if (sheen.alpha == 0f) return
    drawRect(Brush.linearGradient(
        0f to sheen,
        .72f to sheen.copy(alpha = 0f),
        start = Offset(size.width, 0f),
        end = Offset(0f, size.height),
    ))
}

/** [drawCardSheen] behind the content; put it right after the card's fill. */
@Composable
internal fun Modifier.fausCardSheen(): Modifier {
    val sheen = LocalFausTheme.current.decor.cardSheen
    return if (sheen.alpha == 0f) this else drawBehind { drawCardSheen(sheen) }
}
