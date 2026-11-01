package com.fauscrew.ui.games.rockets

import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import com.fauscrew.platform.RocketsColor
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** `HouseRocketsPalette`: shared by the course, the lobby and the Games cover. */
internal object HouseRocketsPalette {
    val burgundy = Color(0xFF780000)
    val red = Color(0xFFC1121F)
    val cream = Color(0xFFFDF0D5)
    val navy = Color(0xFF003049)
    val blue = Color(0xFF669BBC)
    val ice = Color(0xFFA9D6E5)
    val outer = Color(0xFF1C455E)

    /** Serialized identifiers keep their names; only the visual palette differs. */
    fun player(color: RocketsColor): Color = when (color) {
        RocketsColor.MINT -> cream
        RocketsColor.CORAL -> red
        RocketsColor.BLUE -> blue
        RocketsColor.GOLD -> burgundy
        RocketsColor.VIOLET -> Color(0xFF9D84BE)
        RocketsColor.ORANGE -> Color(0xFFE09960)
        RocketsColor.PINK -> Color(0xFFD895AD)
        RocketsColor.TEAL -> Color(0xFF67AEA7)
    }
}

/** `HouseRocketsTheme`: the dark in-flight surfaces. */
internal object HouseRocketsTheme {
    val background = HouseRocketsPalette.outer
    val panel = HouseRocketsPalette.blue.copy(alpha = .12f)
    val accent = HouseRocketsPalette.cream
    val danger = HouseRocketsPalette.cream
    val ink = HouseRocketsPalette.cream
    val muted = HouseRocketsPalette.cream.copy(alpha = .76f)
}

/** `HouseRocketsPreparationTheme`: the light lobby surfaces. */
internal object HouseRocketsPreparationTheme {
    val ink = HouseRocketsPalette.navy
    val muted = ink.copy(alpha = .72f)
    val accent = HouseRocketsPalette.burgundy
    val danger = HouseRocketsPalette.red
    val surface = HouseRocketsPalette.cream
    val hairline = ink.copy(alpha = .13f)
}

/**
 * `HouseRocketsArtwork`: curved rocket contours normalized to face right, and the nested
 * terrain contours. The same drawing serves the course, the mark and the Games cover.
 */
internal object HouseRocketsArtwork {
    private fun referencePath(draw: Path.() -> Unit): Path {
        val path = Path().apply(draw)
        val k = (0.065 / sqrt(2.0)).toFloat()
        // CGAffineTransform(a: k, b: -k, c: -k, d: -k, tx: 0, ty: 512k).
        path.transform(Matrix().apply { setValues(floatArrayOf(k, -k, 0f, -k, -k, 512 * k, 0f, 0f, 1f)) })
        return path
    }

    val hull: Path = referencePath {
        moveTo(142f, 245f)
        cubicTo(211f, 91f, 368f, 21f, 496f, 16f)
        cubicTo(486f, 184f, 415f, 313f, 264f, 366f)
        close()
    }
    val fins: Path = referencePath {
        moveTo(190f, 153f)
        cubicTo(113f, 129f, 49f, 189f, 17f, 242f)
        lineTo(138f, 247f); close()
        moveTo(359f, 322f)
        cubicTo(384f, 401f, 320f, 466f, 270f, 496f)
        lineTo(265f, 372f); close()
    }
    val collar: Path = referencePath {
        moveTo(142f, 245f); lineTo(264f, 366f)
        lineTo(214f, 420f); lineTo(91f, 297f); close()
    }
    val nose: Path = referencePath {
        moveTo(378f, 38f); lineTo(474f, 134f)
        cubicTo(485f, 96f, 494f, 55f, 496f, 16f)
        cubicTo(455f, 19f, 414f, 26f, 378f, 38f)
        close()
    }
    val window: Path = referencePath { addOval(RectF(282f, 137f, 376f, 231f), Path.Direction.CW) }
    val flame: Path = referencePath {
        moveTo(124f, 328f)
        cubicTo(81f, 368f, 58f, 407f, 53f, 459f)
        cubicTo(108f, 453f, 151f, 428f, 184f, 388f)
        close()
    }

    /** Quiet, nested terrain contours for a drawing area of `width` × `height`. */
    fun topography(width: Float, height: Float): List<Path> = List(20) { index ->
        val path = Path()
        val ring = index % 10
        val radius = 34f + ring * 23f
        val centerX = width * if (index < 10) .86f else .14f
        val centerY = height * if (index < 10) .82f else .12f
        val horizontalRadius = radius * width / 440f
        val verticalRadius = radius * height / 260f
        for (step in 0..96) {
            val angle = step / 96.0 * Math.PI * 2
            val wave = 1 + 0.10 * sin(3 * angle + 0.8) + 0.06 * cos(5 * angle)
            val x = centerX + (cos(angle) * wave * horizontalRadius).toFloat()
            val y = centerY + (sin(angle) * wave * verticalRadius).toFloat()
            if (step == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        path
    }

    /** Outer contours move from cool blue through cream into the two reds. */
    fun outerContourColor(index: Int): Color {
        val ring = index % 10
        return if (index < 10) {
            when (ring) {
                0, 1, 2 -> HouseRocketsPalette.blue
                3, 4, 6 -> HouseRocketsPalette.ice
                5 -> HouseRocketsPalette.cream
                7 -> HouseRocketsPalette.red
                else -> HouseRocketsPalette.burgundy
            }
        } else {
            when (ring) {
                0, 1 -> HouseRocketsPalette.burgundy
                2, 3, 4, 6, 7 -> HouseRocketsPalette.red
                5 -> HouseRocketsPalette.cream
                8 -> HouseRocketsPalette.ice
                else -> HouseRocketsPalette.blue
            }
        }
    }

    fun outerContourOpacity(index: Int): Float {
        val ring = index % 10
        if (ring == 5) return .32f
        if (index < 10) {
            if (ring == 7) return .42f
            if (ring >= 8) return .38f
        } else {
            if (ring <= 1) return .38f
            if (ring in 2..4 || ring in 6..7) return .42f
        }
        return .24f
    }
}

internal fun strokePaint(color: Color, width: Float, round: Boolean = false) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    strokeWidth = width
    this.color = color.toArgb()
    if (round) {
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
}

internal fun fillPaint(color: Color) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.FILL
    this.color = color.toArgb()
}

/** `HouseRocketsTopography`: the in-flight contour field, drawn in dp. */
internal fun DrawScope.drawRocketsTopography(widthDp: Float, heightDp: Float) {
    drawIntoCanvas { canvas ->
        val native = canvas.nativeCanvas
        native.save()
        native.scale(density, density)
        HouseRocketsArtwork.topography(widthDp, heightDp).forEachIndexed { index, path ->
            val color = HouseRocketsArtwork.outerContourColor(index)
            if (index % 3 == 0) native.drawPath(path, strokePaint(color.copy(alpha = .06f), 12f))
            native.drawPath(path, strokePaint(color.copy(alpha = HouseRocketsArtwork.outerContourOpacity(index)),
                if (index % 4 == 0) 1.2f else .75f))
        }
        native.restore()
    }
}

@Composable
internal fun HouseRocketsTopography(modifier: Modifier = Modifier) {
    Canvas(modifier.clipToBounds()) { drawRocketsTopography(size.width / density, size.height / density) }
}

/** `HouseRocketsPreparationBackdrop`: the terrain language softened for reading. */
@Composable
internal fun HouseRocketsPreparationBackdrop(modifier: Modifier = Modifier) {
    val gradient = remember {
        Brush.linearGradient(
            listOf(HouseRocketsPalette.cream, HouseRocketsPalette.ice.copy(alpha = .9f),
                HouseRocketsPalette.blue.copy(alpha = .38f)),
            start = Offset.Zero, end = Offset.Infinite,
        )
    }
    Box(modifier.fillMaxSize().background(HouseRocketsPalette.cream).background(gradient)) {
        Canvas(Modifier.fillMaxSize()) {
            val widthDp = size.width / density
            val heightDp = size.height / density
            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                native.save()
                native.scale(density, density)
                HouseRocketsArtwork.topography(widthDp, heightDp).forEachIndexed { index, path ->
                    native.drawPath(path, strokePaint(HouseRocketsArtwork.outerContourColor(index).copy(alpha = .09f),
                        if (index % 4 == 0) 1.1f else .7f))
                }
                native.restore()
            }
        }
    }
}

/** `HouseRocketsRocketMark`: the cream rocket tilted 40°, outlined in navy. */
@Composable
internal fun HouseRocketsRocketMark(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        drawIntoCanvas { canvas ->
            val native = canvas.nativeCanvas
            native.save()
            native.translate(size.width / 2, size.height / 2)
            val scale = minOf(size.width, size.height) / 52f
            native.scale(scale, -scale)
            native.rotate(40f)
            val outline = strokePaint(HouseRocketsPalette.navy, 1.6f, round = true)
            listOf(
                HouseRocketsArtwork.flame to HouseRocketsPalette.cream,
                HouseRocketsArtwork.fins to HouseRocketsPalette.blue,
                HouseRocketsArtwork.hull to HouseRocketsPalette.cream,
                HouseRocketsArtwork.collar to HouseRocketsPalette.burgundy,
                HouseRocketsArtwork.nose to HouseRocketsPalette.red,
                HouseRocketsArtwork.window to HouseRocketsPalette.navy,
            ).forEach { (path, fill) ->
                native.drawPath(path, fillPaint(fill))
                native.drawPath(path, outline)
            }
            native.restore()
        }
    }
}
