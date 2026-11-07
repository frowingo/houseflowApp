package com.fauscrew.ui.games.fausswitch

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import com.fauscrew.R
import com.fauscrew.platform.FausSwitchNative
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.SwitchColor

/**
 * `FausSwitchPalette`. The course is a light textured sheet; robots, blocks and rails are
 * dark so they read at a glance. Wine and deep wine carry the accents next to teal and
 * lavender; berry stays for warnings. Panels are sand, fading to a lighter sand.
 */
internal object FausSwitchPalette {
    val mint = Color(0xFFD8FDD4)
    val lime = Color(0xFFD5E8A0)
    val sand = Color(0xFFE6D5B7)
    val lavender = Color(0xFFB6A0CF)
    val green = Color(0xFF3D896D)
    val teal = Color(0xFF164F52)
    val plum = Color(0xFF30021F)
    val berry = Color(0xFF7A2453)
    val wine = Color(0xFF692747)
    val deepWine = Color(0xFF501536)
    /** Sand mixed halfway toward white: the light end of the panel gradient. */
    val lightSand = Color(0xFFF3EBDD)
    /** The robot visor: the darkest teal, so the white eyes carry the face. */
    val visor = Color(0xFF0E2A2C)
    val eye = Color(0xFFF4FFF2)

    val ink = plum
    val secondaryInk = deepWine.copy(alpha = .78f)
    val panel = lightSand.copy(alpha = .96f)
    val panelStroke = wine.copy(alpha = .18f)
    val danger = berry
    /** Section titles, links and the primary action. */
    val accent = wine
    /** Every card and panel: light sand at the top fading to sand. */
    val cardFill = Brush.linearGradient(listOf(lightSand, sand))
}

/** Faus Switch copy: the remote catalog first, then Core's bundled TR/EN table. */
internal class SwitchCopy(private val strings: LocalizedText, private val bundled: Map<String, String>) {
    operator fun invoke(key: String): String = strings.values[key] ?: bundled[key] ?: key

    fun template(key: String, vararg replacements: Pair<String, String>): String =
        replacements.fold(invoke(key)) { text, (name, value) -> text.replace("{$name}", value) }
}

/** A robot color's body tone from Core (`FausSwitchColor.bodyHex`). */
internal fun SwitchColor.tone(hex: Map<SwitchColor, Int>): Color = Color(0xFF000000 or (hex[this] ?: 0xB6A0CF).toLong())

/** Mixed toward black by [amount] (0…1): the robot's limbs and outlines. */
internal fun Color.switchDarkened(amount: Float): Color =
    Color(red * (1 - amount), green * (1 - amount), blue * (1 - amount), alpha)

/** Mixed toward white by [amount] (0…1): head highlights. */
internal fun Color.switchLightened(amount: Float): Color =
    Color(red + (1 - red) * amount, green + (1 - green) * amount, blue + (1 - blue) * amount, alpha)

internal fun fillPaint(color: Color) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.FILL
    this.color = color.toArgb()
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

/**
 * The runner art (`FausSwitchRobotNode` / `FausSwitchRobot`): a wide head with a dark
 * visor, two white eyes and a side ear pad, on a small body with arms and legs. Drawn in
 * y-up units around the robot's center for a 29.4-high box; it faces right.
 */
internal class SwitchRobotArt(base: Color, private val isLocal: Boolean) {
    private class Part(val rect: RectF, val radius: Float, val fill: Paint, val stroke: Paint?)

    private val limb = base.switchDarkened(.32f)
    private val outline = base.switchDarkened(.5f)
    private val limbFill = fillPaint(limb)
    private val leftLeg = Part(rect(-5.6f, -14.7f, 4f, 5f), 1.4f, limbFill, null)
    private val rightLeg = Part(rect(1.6f, -14.7f, 4f, 5f), 1.4f, limbFill, null)
    private val parts = listOf(
        Part(rect(-9.8f, -10.4f, 3.2f, 7f), 1.6f, limbFill, null),
        Part(rect(6.6f, -10.4f, 3.2f, 7f), 1.6f, limbFill, null),
        Part(rect(-6.3f, -10.6f, 12.6f, 7.8f), 2.8f, fillPaint(base.switchDarkened(.1f)), strokePaint(outline, .6f)),
        Part(rect(1.1f, -7.9f, 2.6f, 2.6f), 1.3f, fillPaint(FausSwitchPalette.lime), null),
        Part(rect(-12.6f, -3f, 25.2f, 16.6f), 6.6f, fillPaint(base), strokePaint(outline, .9f)),
        Part(rect(-14.6f, 1.2f, 3.8f, 8.2f), 1.6f, limbFill, null),
        Part(rect(-8.5f, 10.6f, 11f, 1.6f), .8f, fillPaint(base.switchLightened(.45f).copy(alpha = .55f)), null),
        Part(rect(-7.4f, .4f, 18f, 10f), 4.4f, fillPaint(FausSwitchPalette.visor), null),
        Part(rect(-3.6f, 3f, 4.2f, 4.8f), 1.3f, fillPaint(FausSwitchPalette.eye), null),
        Part(rect(3f, 3f, 4.2f, 4.8f), 1.3f, fillPaint(FausSwitchPalette.eye), null),
    )
    private val haloOval = RectF(-20f, -21f, 20f, 21f)
    private val haloFill = fillPaint(FausSwitchPalette.lavender.copy(alpha = .32f))
    private val haloStroke = strokePaint(FausSwitchPalette.lavender.copy(alpha = .8f), 1f)
    private val streaks = listOf(rect(-30f, -4.8f, 14f, 1.6f), rect(-30f, 2.2f, 14f, 1.6f))
    private val streakFill = fillPaint(FausSwitchPalette.green)
    private val marker = Path().apply { moveTo(-4f, 23f); lineTo(4f, 23f); lineTo(0f, 17.5f); close() }
    private val markerFill = fillPaint(FausSwitchPalette.lime)
    private val markerStroke = strokePaint(FausSwitchPalette.plum, 1f)

    /**
     * [rigScaleY] is 1 on the floor and −1 on the ceiling (mid-flip in between); [stride]
     * lifts one leg and drops the other; [trailAlpha] is the boost streaks.
     */
    fun draw(canvas: Canvas, rigScaleY: Float = 1f, stride: Float = 0f, trailAlpha: Float = 0f, showsMarks: Boolean = isLocal) {
        if (showsMarks) {
            canvas.drawOval(haloOval, haloFill)
            canvas.drawOval(haloOval, haloStroke)
        }
        if (trailAlpha > 0f) {
            streakFill.alpha = (trailAlpha * 255).toInt()
            for (streak in streaks) canvas.drawRoundRect(streak, .8f, .8f, streakFill)
        }
        canvas.save()
        canvas.scale(1f, rigScaleY)
        drawPart(canvas, leftLeg, stride)
        drawPart(canvas, rightLeg, -stride)
        for (part in parts) drawPart(canvas, part, 0f)
        if (showsMarks) {
            canvas.drawPath(marker, markerFill)
            canvas.drawPath(marker, markerStroke)
        }
        canvas.restore()
    }

    private fun drawPart(canvas: Canvas, part: Part, offsetY: Float) {
        if (offsetY != 0f) {
            canvas.save()
            canvas.translate(0f, offsetY)
        }
        canvas.drawRoundRect(part.rect, part.radius, part.radius, part.fill)
        part.stroke?.let { canvas.drawRoundRect(part.rect, part.radius, part.radius, it) }
        if (offsetY != 0f) canvas.restore()
    }

    private companion object {
        fun rect(x: Float, y: Float, width: Float, height: Float) = RectF(x, y, x + width, y + height)
    }
}

/** `FausSwitchRobot`: the robot for lobby, color picker, tables and the Games cover. */
@Composable
internal fun FausSwitchRobot(color: SwitchColor, modifier: Modifier = Modifier, isUpsideDown: Boolean = false) {
    val hex = remember { FausSwitchNative.constants.colorHex }
    FausSwitchRobotTone(color.tone(hex), modifier, isUpsideDown)
}

@Composable
internal fun FausSwitchRobotTone(tone: Color, modifier: Modifier = Modifier, isUpsideDown: Boolean = false) {
    val art = remember(tone) { SwitchRobotArt(tone, isLocal = false) }
    Box(
        modifier.aspectRatio(1f).clearAndSetSemantics {}.drawBehind {
            val unit = minOf(size.width, size.height) / 32f
            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                native.save()
                native.translate(size.width / 2, size.height / 2)
                // The art is y-up; upside down keeps it y-down.
                native.scale(unit, if (isUpsideDown) unit else -unit)
                art.draw(native, showsMarks = false)
                native.restore()
            }
        },
    )
}

/** `FausSwitchTextureBackdrop`: the light course texture behind every Faus Switch surface. */
@Composable
internal fun FausSwitchTextureBackdrop(modifier: Modifier = Modifier) {
    Box(modifier.clipToBounds().clearAndSetSemantics {}) {
        Image(painterResource(R.drawable.faus_switch_texture), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(Modifier.fillMaxSize().background(FausSwitchPalette.mint.copy(alpha = .18f)))
    }
}

/** `FausSwitchCoverArtwork`: a slice of the course — two rails, blocks and robots on both rails. */
@Composable
internal fun FausSwitchCoverArtwork(modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier.clipToBounds().clearAndSetSemantics {}) {
        val width = maxWidth
        val height = maxHeight
        val rail = maxOf(9.dp, height * .11f)
        FausSwitchTextureBackdrop(Modifier.fillMaxSize())
        Box(Modifier.fillMaxWidth().height(rail).background(FausSwitchPalette.teal))
        Box(Modifier.fillMaxWidth().height(rail).align(Alignment.BottomStart).background(FausSwitchPalette.teal))
        @Composable
        fun block(w: Float, h: Float, x: Float, y: androidx.compose.ui.unit.Dp, fill: Color, edge: Color) {
            val shape = RoundedCornerShape(3.dp)
            Box(
                Modifier.offset(width * x - width * w / 2, y - height * h / 2).width(width * w).height(height * h)
                    .background(fill, shape).drawBehind {
                        drawRoundRect(edge, cornerRadius = androidx.compose.ui.geometry.CornerRadius(3.dp.toPx()),
                            style = androidx.compose.ui.graphics.drawscope.Stroke(1.dp.toPx()))
                    },
            )
        }
        block(.11f, .3f, .56f, rail + height * .15f, FausSwitchPalette.wine, FausSwitchPalette.lavender)
        block(.11f, .2f, .66f, height * .6f, FausSwitchPalette.lavender, FausSwitchPalette.deepWine)
        block(.1f, .22f, .84f, height - rail - height * .11f, FausSwitchPalette.deepWine, FausSwitchPalette.sand)
        val robot = height * .34f
        FausSwitchRobot(SwitchColor.OCEAN, Modifier.offset(width * .26f - robot / 2, height - rail - height * .15f - robot / 2).size(robot))
        FausSwitchRobot(SwitchColor.BERRY, Modifier.offset(width * .38f - robot / 2, rail + height * .15f - robot / 2).size(robot),
            isUpsideDown = true)
        Box(
            Modifier.offset(width * .76f - 1.5.dp, height * .36f - height * .17f).width(3.dp).height(height * .34f)
                .shadow(4.dp, RoundedCornerShape(1.5.dp), ambientColor = FausSwitchPalette.lavender, spotColor = FausSwitchPalette.lavender)
                .background(FausSwitchPalette.berry, RoundedCornerShape(1.5.dp)),
        )
    }
}
