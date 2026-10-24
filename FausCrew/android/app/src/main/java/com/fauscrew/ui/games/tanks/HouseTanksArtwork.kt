package com.fauscrew.ui.games.tanks

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.VectorPainter
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksJoker
import com.fauscrew.platform.TanksMapPreview
import com.fauscrew.platform.TanksObstacleStyle
import com.fauscrew.ui.theme.Radius
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.tan

/** `HouseTanksMapPalette`: steel, paper, khaki and slate are fixed brand colors. */
internal object HouseTanksPalette {
    val steel = Color(0xFF0067A5)
    val paper = Color(0xFFF0F8FF)
    val khaki = Color(0xFFBA8C63)
    val slate = Color(0xFF747D83)

    val ink = Color(0xFF1F2C35)
    val graphite = Color(0xFF56616A)
    val deepSteel = Color(0xFF004C7A)
    val sand = Color(0xFFE6DAC6)
    /** Khaki deep enough for text on paper. */
    val umber = Color(0xFF85603F)
    val olive = Color(0xFF6F7556)
    val rust = Color(0xFFA4503B)
    /** Reserved for the aim joker's sight line. */
    val signalRed = Color(0xFFDE1820)
}

/** `HouseTanksFieldTheme`. */
internal object HouseTanksFieldTheme {
    val ink = HouseTanksPalette.ink
    val muted = HouseTanksPalette.graphite
    val accent = HouseTanksPalette.steel
    val danger = HouseTanksPalette.rust
    val surface = HouseTanksPalette.paper.copy(alpha = .94f)
    val hairline = HouseTanksPalette.slate.copy(alpha = .28f)
    val stencil = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
}

/** In-match tank color; the raw value stays the serialized identity. */
internal val TanksColor.ink: Color
    get() = when (this) {
        TanksColor.PLUM -> Color(0xFF6B4C7A)
        TanksColor.ORANGE -> Color(0xFFC8683A)
        TanksColor.BLUE -> HouseTanksPalette.steel
        TanksColor.OLIVE -> Color(0xFF7C8B2E)
        // Crowded-match colors, each a hue or lightness no other tank, wreck or crate shares.
        TanksColor.MUSTARD -> Color(0xFFC9A227)
        TanksColor.CRIMSON -> Color(0xFFA3243B)
        TanksColor.SKY -> Color(0xFF4FA3C7)
        TanksColor.IVORY -> Color(0xFFEDE6D3)
    }

internal val TanksColor.nameKey: String get() = "house_tanks_color_${raw}"

/** Token, on-tank badge and How-to-play color. */
internal val TanksJoker.tint: Color
    get() = when (this) {
        TanksJoker.ROCKET -> HouseTanksPalette.olive
        TanksJoker.RAPID_FIRE -> HouseTanksPalette.rust
        TanksJoker.SPREAD_SHOT -> HouseTanksPalette.umber
        TanksJoker.SHIELD -> HouseTanksPalette.steel
        TanksJoker.AIM -> HouseTanksPalette.signalRed
    }

/** iOS's HSB brightness shift for turrets and barrels. */
internal fun Color.shaded(amount: Float): Color {
    val hsv = FloatArray(3)
    android.graphics.Color.colorToHSV(toArgb(), hsv)
    hsv[2] = (hsv[2] + amount).coerceIn(0f, 1f)
    return Color(android.graphics.Color.HSVToColor((alpha * 255).roundToInt(), hsv))
}

/** Material equivalents of the jokers' SF Symbols; spread shot and the rocket are drawn. */
private val TanksJoker.icon: ImageVector?
    get() = when (this) {
        TanksJoker.RAPID_FIRE -> Icons.Rounded.LocalFireDepartment
        TanksJoker.SHIELD -> Icons.Rounded.Shield
        TanksJoker.AIM -> Icons.Rounded.GpsFixed
        TanksJoker.ROCKET, TanksJoker.SPREAD_SHOT -> null
    }

/** Painters for the glyphs that come from icons, remembered once per composition. */
internal class JokerPainters(val painters: Map<TanksJoker, VectorPainter>)

@Composable
internal fun rememberJokerPainters(): JokerPainters {
    val fire = rememberVectorPainter(Icons.Rounded.LocalFireDepartment)
    val shield = rememberVectorPainter(Icons.Rounded.Shield)
    val aim = rememberVectorPainter(Icons.Rounded.GpsFixed)
    return remember(fire, shield, aim) {
        JokerPainters(mapOf(TanksJoker.RAPID_FIRE to fire, TanksJoker.SHIELD to shield, TanksJoker.AIM to aim))
    }
}

/** Draws a joker glyph centered at the origin in a `side`-sized square, y down. */
internal fun DrawScope.drawJokerGlyph(joker: TanksJoker, side: Float, color: Color, painters: JokerPainters) {
    when (joker) {
        TanksJoker.SPREAD_SHOT -> {
            val box = side * 1.2f
            val origin = Offset(0f, box * 0.84f - box / 2)
            val length = box * 0.7f
            for (spread in floatArrayOf(-0.52f, 0f, 0.52f)) {
                val angle = -Math.PI.toFloat() / 2 + spread
                drawLine(color, origin, Offset(origin.x + cos(angle) * length, origin.y + sin(angle) * length),
                    strokeWidth = box * 0.14f, cap = StrokeCap.Round)
            }
            drawCircle(color, box * 0.12f, origin)
        }
        TanksJoker.ROCKET -> {
            val box = side * 1.2f
            val length = box * 0.86f
            val width = box * 0.28f
            rotate(-45f, Offset.Zero) {
                val body = Path().apply {
                    addRoundRect(androidx.compose.ui.geometry.RoundRect(
                        Rect(-length * 0.42f, -width / 2, -length * 0.42f + length * 0.62f, width / 2),
                        CornerRadius(width * 0.3f),
                    ))
                    moveTo(length * 0.2f, -width / 2)
                    lineTo(length * 0.5f, 0f)
                    lineTo(length * 0.2f, width / 2)
                    close()
                    for (sign in floatArrayOf(1f, -1f)) {
                        moveTo(-length * 0.42f, sign * width / 2)
                        lineTo(-length * 0.5f, sign * width * 1.25f)
                        lineTo(-length * 0.18f, sign * width / 2)
                        close()
                    }
                }
                drawPath(body, color)
                drawCircle(color, width * 0.3f, Offset(-length * 0.62f + width * 0.3f, 0f))
            }
        }
        else -> painters.painters[joker]?.let { painter ->
            translate(-side / 2, -side / 2) {
                with(painter) { draw(Size(side, side), colorFilter = ColorFilter.tint(color)) }
            }
        }
    }
}

/** A joker glyph as a composable, for HUD-free surfaces like the How-to-play list. */
@Composable
internal fun JokerGlyph(joker: TanksJoker, size: Dp, modifier: Modifier = Modifier, color: Color = HouseTanksPalette.paper) {
    val painters = rememberJokerPainters()
    Canvas(modifier) {
        val side = size.toPx()
        translate(this.size.width / 2, this.size.height / 2) { drawJokerGlyph(joker, side, color, painters) }
    }
}

/**
 * The arena tank exactly as the engine's renderers build the player's tank: aura, tracks,
 * hull, turret and barrel in artwork units, centered on the origin, barrel along +x.
 */
internal fun DrawScope.drawTankArtwork(tint: Color, isHuman: Boolean, isDestroyed: Boolean, hullAlpha: Float = 1f) {
    val ink = HouseTanksPalette.ink
    if (!isDestroyed) {
        drawOval(tint.copy(alpha = if (isHuman) .18f else .07f), Offset(-36f, -30f), Size(72f, 60f))
        drawOval(tint.copy(alpha = if (isHuman) .72f else .26f), Offset(-36f, -30f), Size(72f, 60f),
            style = Stroke(if (isHuman) 3f else 1.5f))
    }
    val dead = Color(0xFF1F1F1F)
    val deadStroke = Color(0xFF595959)
    for (y in floatArrayOf(-22f, 12f)) {
        drawRoundRect(if (isDestroyed) dead else ink, Offset(-19f, y), Size(38f, 10f), CornerRadius(5f))
        drawRoundRect(if (isDestroyed) deadStroke else HouseTanksPalette.paper.copy(alpha = .25f), Offset(-19f, y),
            Size(38f, 10f), CornerRadius(5f), style = Stroke(1f))
    }
    val hull = if (isDestroyed) dead else tint
    drawRoundRect(hull.copy(alpha = hull.alpha * hullAlpha), Offset(-22f, -15f), Size(44f, 30f), CornerRadius(9f))
    drawRoundRect(if (isDestroyed) deadStroke else ink, Offset(-22f, -15f), Size(44f, 30f), CornerRadius(9f), style = Stroke(2.5f))
    drawCircle(if (isDestroyed) dead else tint.shaded(-.10f), 10f, Offset.Zero)
    drawCircle(if (isDestroyed) deadStroke else ink, 10f, Offset.Zero, style = Stroke(2f))
    drawRoundRect(if (isDestroyed) Color(0xFF2E2E2E) else tint.shaded(-.16f), Offset(2.5f, -4f), Size(31f, 8f), CornerRadius(4f))
    drawRoundRect(if (isDestroyed) deadStroke else ink, Offset(2.5f, -4f), Size(31f, 8f), CornerRadius(4f), style = Stroke(1.5f))
}

/** `HouseTanksArenaTank`: the player's arena tank at -30°, for pickers, the emblem and the cover. */
@Composable
internal fun HouseTanksArenaTank(tint: Color, modifier: Modifier = Modifier, rotationDegrees: Float = -30f) {
    Canvas(modifier) {
        val scale = min(size.width, size.height) / 76f
        withTransform({
            translate(size.width / 2, size.height / 2)
            scale(scale, scale, Offset.Zero)
            rotate(rotationDegrees, Offset.Zero)
        }) { drawTankArtwork(tint, isHuman = true, isDestroyed = false) }
    }
}

@Composable
internal fun HouseTanksArenaTank(color: TanksColor, modifier: Modifier = Modifier) =
    HouseTanksArenaTank(color.ink, modifier)

/** Registration brackets at the four corners of a field card. */
internal fun DrawScope.drawCornerMarks(color: Color, length: Float, inset: Float, strokeWidth: Float) {
    val left = inset
    val top = inset
    val right = size.width - inset
    val bottom = size.height - inset
    for ((corner, d) in listOf(Offset(left, top) to Offset(1f, 1f), Offset(right, top) to Offset(-1f, 1f),
        Offset(left, bottom) to Offset(1f, -1f), Offset(right, bottom) to Offset(-1f, -1f))) {
        val path = Path().apply {
            moveTo(corner.x + length * d.x, corner.y)
            lineTo(corner.x, corner.y)
            lineTo(corner.x, corner.y + length * d.y)
        }
        drawPath(path, color, style = Stroke(strokeWidth))
    }
}

/** `houseTanksFieldCard`: paper card with a hairline frame and corner brackets. */
internal fun Modifier.fieldCard(padding: Dp = 16.dp): Modifier {
    val shape = RoundedCornerShape(Radius.sm)
    return this
        .fillMaxWidth()
        .background(HouseTanksFieldTheme.surface, shape)
        .border(1.dp, HouseTanksFieldTheme.hairline, shape)
        .drawBehind { drawCornerMarks(HouseTanksPalette.slate.copy(alpha = .55f), 8.dp.toPx(), 4.dp.toPx(), 1.2.dp.toPx()) }
        .padding(padding)
}

/** `hudPanel`: compact paper plate for in-match readouts. */
internal fun Modifier.hudPanel(): Modifier {
    val shape = RoundedCornerShape(Radius.xs)
    return this
        .drawBehind {
            drawRoundRect(HouseTanksPalette.ink.copy(alpha = .12f), Offset(2.dp.toPx(), 2.dp.toPx()), size,
                CornerRadius(Radius.xs.toPx()))
        }
        .background(HouseTanksPalette.paper.copy(alpha = .92f), shape)
        .border(1.dp, HouseTanksPalette.slate.copy(alpha = .45f), shape)
}

/**
 * `HouseTanksRaisedButtonStyle`: a card lifted off the sheet. A tinted block sits behind it
 * and the card presses into it.
 */
@Composable
internal fun RaisedButton(
    depth: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    offset: Dp = 4.dp,
    enabled: Boolean = true,
    content: @Composable BoxScope.() -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shift by animateFloatAsState(if (pressed) offset.value else 0f, tween(100), label = "raised")
    Box(
        modifier
            .drawBehind {
                drawRoundRect(depth.copy(alpha = .55f), Offset(offset.toPx(), offset.toPx()), size,
                    CornerRadius(Radius.sm.toPx()))
            }
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick),
    ) {
        Box(Modifier.offset(shift.dp, shift.dp), content = content)
    }
}

/** `HouseTanksMapPreview`: a small survey sheet of a real arena from its definition. */
@Composable
internal fun HouseTanksMapPreview(preview: TanksMapPreview?, selected: Boolean, modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxWidth().aspectRatio(1180f / 640f)) {
        val palette = HouseTanksPalette
        drawRect(if (selected) palette.paper else palette.sand.copy(alpha = .45f))
        val rise = size.width * tan(Math.PI.toFloat() / 6)
        val grid = Path()
        var offset = -rise
        val spacing = 9.dp.toPx()
        while (offset < size.height + rise) {
            grid.moveTo(0f, offset); grid.lineTo(size.width, offset + rise)
            grid.moveTo(0f, offset + rise); grid.lineTo(size.width, offset)
            offset += spacing
        }
        drawPath(grid, palette.slate.copy(alpha = .14f), style = Stroke(.4.dp.toPx()))
        preview ?: return@Canvas
        // The engine's arena grows upward; flip it for the canvas.
        fun point(x: Double, y: Double) = Offset((x * size.width).toFloat(), ((1 - y) * size.height).toFloat())
        val lines = Path()
        preview.lines.forEach { line ->
            val start = point(line[0], line[1]); val end = point(line[2], line[3])
            lines.moveTo(start.x, start.y); lines.lineTo(end.x, end.y)
        }
        drawPath(lines, palette.steel.copy(alpha = .28f),
            style = Stroke(.8.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx()))))
        preview.obstacles.forEach { obstacle ->
            val scale = preview.obstacleScale * preview.scale
            val height = size.height * obstacle.height * scale
            val width = if (obstacle.style.isRound || obstacle.style == TanksObstacleStyle.CRATE) height
            else size.width * obstacle.width * scale
            val center = point(obstacle.x, obstacle.y)
            withTransform({
                translate(center.x, center.y)
                rotate(-Math.toDegrees(obstacle.rotation).toFloat(), Offset.Zero)
            }) {
                val topLeft = Offset((-width / 2).toFloat(), (-height / 2).toFloat())
                val shapeSize = Size(width.toFloat(), height.toFloat())
                val fill = when (obstacle.style) {
                    TanksObstacleStyle.CRATE -> palette.khaki.copy(alpha = .75f)
                    TanksObstacleStyle.PLANTER -> palette.olive.copy(alpha = .6f)
                    else -> palette.slate.copy(alpha = .6f)
                }
                if (obstacle.style.isRound) {
                    drawOval(fill, topLeft, shapeSize)
                    drawOval(palette.ink.copy(alpha = .35f), topLeft, shapeSize, style = Stroke(.5.dp.toPx()))
                } else {
                    drawRoundRect(fill, topLeft, shapeSize, CornerRadius(1.dp.toPx()))
                    drawRoundRect(palette.ink.copy(alpha = .35f), topLeft, shapeSize, CornerRadius(1.dp.toPx()),
                        style = Stroke(.5.dp.toPx()))
                }
            }
        }
        preview.spawns.forEach { spawn -> drawCircle(palette.steel, 2.5.dp.toPx(), point(spawn[0], spawn[1])) }
        drawRect(palette.slate.copy(alpha = .4f), style = Stroke(1.dp.toPx()))
    }
}

/** Deterministic noise so the paper looks the same on every launch (and on iOS). */
private class SeededGenerator(private var state: Long) {
    fun next(from: Double, to: Double): Double {
        state = state * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
        val unit = (state ushr 11).toDouble() / (1L shl 53).toDouble()
        return from + unit * (to - from)
    }
}

/**
 * `HouseTanksMapBackdrop`: a washed-out survey sheet — isometric grid, aged paper, faint
 * coordinates — with detail weighted toward the edges so the reading column stays clean.
 */
@Composable
internal fun HouseTanksMapBackdrop(modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    Canvas(modifier) {
        val palette = HouseTanksPalette
        val w = size.width
        val h = size.height
        val center = Offset(w / 2, h / 2)
        val reach = hypot(w, h) / 2
        val unit = 1.dp.toPx()

        drawRect(palette.paper)
        drawRect(Brush.radialGradient(
            0f to Color.Transparent, .35f to palette.sand.copy(alpha = 0f), .675f to palette.sand.copy(alpha = .35f),
            1f to palette.khaki.copy(alpha = .32f), center = center, radius = reach,
        ))

        // Isometric grid.
        val slope = tan(Math.PI.toFloat() / 6)
        val rise = w * slope
        val minor = Path()
        val major = Path()
        var index = 0
        var offset = -rise
        val gridStep = 30 * unit / cos(Math.PI.toFloat() / 6)
        while (offset < h + rise) {
            val path = if (index % 4 == 0) major else minor
            path.moveTo(0f, offset); path.lineTo(w, offset + rise)
            path.moveTo(0f, offset + rise); path.lineTo(w, offset)
            offset += gridStep
            index += 1
        }
        drawPath(minor, palette.slate.copy(alpha = .11f), style = Stroke(.5f * unit))
        drawPath(major, palette.slate.copy(alpha = .17f), style = Stroke(.8f * unit))

        // Coordinate lines.
        val columns = 6
        val rows = max(6, (h / w * 6).roundToInt())
        val coordinates = Path()
        for (column in 1 until columns) {
            val x = w * column / columns
            coordinates.moveTo(x, 0f); coordinates.lineTo(x, h)
        }
        for (row in 1 until rows) {
            val y = h * row / rows
            coordinates.moveTo(0f, y); coordinates.lineTo(w, y)
        }
        drawPath(coordinates, palette.steel.copy(alpha = .10f), style = Stroke(.7f * unit,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(2 * unit, 6 * unit))))

        // Clear the reading column; the ellipse follows the screen's aspect.
        val radius = w * .62f
        withTransform({
            translate(center.x, center.y)
            scale(1f, max(1f, h / max(w, 1f)) * .9f, Offset.Zero)
        }) {
            drawCircle(Brush.radialGradient(
                0f to palette.paper.copy(alpha = .9f), .5f to palette.paper.copy(alpha = .55f), 1f to palette.paper.copy(alpha = 0f),
                center = Offset.Zero, radius = radius,
            ), radius, Offset.Zero)
        }

        drawPaperWear(w, h, center, reach, unit)
        drawContours(w, h, unit)
        drawFieldMarks(w, h, unit, measurer)
        drawNeatline(w, h, unit, columns, rows, measurer)
    }
}

private fun DrawScope.drawPaperWear(w: Float, h: Float, center: Offset, reach: Float, unit: Float) {
    val random = SeededGenerator(0x7A11)
    val palette = HouseTanksPalette
    // Stains sit in the corners, soft-edged like the iOS blur.
    for (corner in listOf(Offset(0f, 0f), Offset(w, h * .08f), Offset(w * .04f, h), Offset(w, h))) {
        val width = (w * random.next(.32, .5)).toFloat()
        val height = (width * random.next(.6, 1.0)).toFloat()
        withTransform({ translate(corner.x, corner.y); scale(1f, height / width, Offset.Zero) }) {
            drawCircle(Brush.radialGradient(0f to palette.khaki.copy(alpha = .16f), 1f to Color.Transparent,
                center = Offset.Zero, radius = width / 2 + 26 * unit), width / 2 + 26 * unit, Offset.Zero)
        }
    }
    repeat(1_100) {
        val point = Offset((random.next(0.0, 1.0) * w).toFloat(), (random.next(0.0, 1.0) * h).toFloat())
        val edge = hypot(point.x - center.x, point.y - center.y) / reach
        if (random.next(0.0, 1.0) >= edge.toDouble().pow(1.6)) return@repeat
        val tone = if (random.next(0.0, 1.0) < .55) palette.slate else palette.khaki
        val opacity = random.next(.05, .16).toFloat()
        if (random.next(0.0, 1.0) < .18) {
            val angle = random.next(0.0, 2 * Math.PI).toFloat()
            val length = random.next(3.0, 9.0).toFloat() * unit
            drawLine(tone.copy(alpha = opacity), point, Offset(point.x + cos(angle) * length, point.y + sin(angle) * length),
                strokeWidth = .5f * unit)
        } else {
            val diameter = random.next(.6, 1.8).toFloat() * unit
            drawOval(tone.copy(alpha = opacity), point, Size(diameter, diameter))
        }
    }
    // Two old fold creases: a lit edge beside a soft shadow.
    for ((start, end) in listOf(Offset(w * .5f, 0f) to Offset(w * .52f, h), Offset(0f, h * .36f) to Offset(w, h * .34f))) {
        drawLine(palette.slate.copy(alpha = .07f), start, end, strokeWidth = 1.4f * unit)
        drawLine(Color.White.copy(alpha = .5f), start + Offset(.8f * unit, .8f * unit), end + Offset(.8f * unit, .8f * unit),
            strokeWidth = .6f * unit)
    }
}

private fun DrawScope.drawContours(w: Float, h: Float, unit: Float) {
    val palette = HouseTanksPalette
    for ((center, base, tone) in listOf(Triple(Offset(w * .96f, h * .1f), w * .06f, palette.khaki),
        Triple(Offset(w * .02f, h * .9f), w * .07f, palette.olive))) {
        for (ring in 0 until 7) {
            val radius = base + ring * w * .035f
            val path = Path()
            for (step in 0..72) {
                val angle = step / 72f * Math.PI.toFloat() * 2
                val wave = 1 + .12f * sin(3 * angle + ring * .4f) + .05f * cos(5 * angle)
                val point = Offset(center.x + cos(angle) * radius * wave * 1.15f, center.y + sin(angle) * radius * wave * .8f)
                if (step == 0) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y)
            }
            path.close()
            drawPath(path, tone.copy(alpha = if (ring % 3 == 0) .26f else .16f),
                style = Stroke((if (ring % 3 == 0) .9f else .6f) * unit))
        }
    }
}

private fun DrawScope.label(measurer: TextMeasurer, text: String, center: Offset, color: Color, size: Float) {
    val layout = measurer.measure(text, TextStyle(fontFamily = FontFamily.Monospace, fontSize = size.sp,
        fontWeight = FontWeight.SemiBold, color = color))
    drawText(layout, topLeft = Offset(center.x - layout.size.width / 2f, center.y - layout.size.height / 2f))
}

private fun DrawScope.drawFieldMarks(w: Float, h: Float, unit: Float, measurer: TextMeasurer) {
    val palette = HouseTanksPalette
    for ((x, y, height) in listOf(Triple(.09f, .15f, "412"), Triple(.2f, .22f, "388"), Triple(.07f, .42f, "356"))) {
        val point = Offset(w * x, h * y)
        val triangle = Path().apply {
            moveTo(point.x, point.y - 4 * unit)
            lineTo(point.x + 4 * unit, point.y + 3 * unit)
            lineTo(point.x - 4 * unit, point.y + 3 * unit)
            close()
        }
        drawPath(triangle, palette.slate.copy(alpha = .4f), style = Stroke(.7f * unit))
        label(measurer, height, Offset(point.x + 14 * unit, point.y), palette.slate.copy(alpha = .5f), 8f)
    }
    val route = Path().apply {
        moveTo(w * .98f, h * .62f)
        cubicTo(w * .86f, h * .56f, w * .95f, h * .46f, w * .86f, h * .4f)
    }
    drawPath(route, palette.steel.copy(alpha = .24f), style = Stroke(1.1f * unit, cap = StrokeCap.Round,
        pathEffect = PathEffect.dashPathEffect(floatArrayOf(5 * unit, 4 * unit))))
    val tip = Offset(w * .86f, h * .4f)
    drawPath(Path().apply {
        moveTo(tip.x - 5 * unit, tip.y + 2 * unit); lineTo(tip.x, tip.y); lineTo(tip.x + 2 * unit, tip.y + 6 * unit)
    }, palette.steel.copy(alpha = .3f), style = Stroke(1.1f * unit))
    for ((x, y) in listOf(.24f to .84f, .8f to .76f)) {
        val point = Offset(w * x, h * y)
        drawCircle(palette.rust.copy(alpha = .2f), 7 * unit, point, style = Stroke(.8f * unit))
        drawLine(palette.rust.copy(alpha = .2f), point - Offset(11 * unit, 0f), point + Offset(11 * unit, 0f), .8f * unit)
        drawLine(palette.rust.copy(alpha = .2f), point - Offset(0f, 11 * unit), point + Offset(0f, 11 * unit), .8f * unit)
    }
    val compass = Offset(w - 44 * unit, h - 76 * unit)
    drawCircle(palette.slate.copy(alpha = .32f), 18 * unit, compass, style = Stroke(.7f * unit))
    val needle = Path().apply {
        moveTo(compass.x, compass.y - 24 * unit); lineTo(compass.x + 4 * unit, compass.y)
        lineTo(compass.x, compass.y + 24 * unit); lineTo(compass.x - 4 * unit, compass.y); close()
    }
    drawPath(needle, palette.khaki.copy(alpha = .28f))
    drawPath(needle, palette.slate.copy(alpha = .36f), style = Stroke(.6f * unit))
    label(measurer, "N", Offset(compass.x, compass.y - 31 * unit), palette.slate.copy(alpha = .55f), 8f)
}

private fun DrawScope.drawNeatline(w: Float, h: Float, unit: Float, columns: Int, rows: Int, measurer: TextMeasurer) {
    val palette = HouseTanksPalette
    val outer = Rect(8 * unit, 8 * unit, w - 8 * unit, h - 8 * unit)
    val inner = Rect(outer.left + 5 * unit, outer.top + 5 * unit, outer.right - 5 * unit, outer.bottom - 5 * unit)
    drawRect(palette.slate.copy(alpha = .24f), outer.topLeft, outer.size, style = Stroke(.8f * unit))
    drawRect(palette.slate.copy(alpha = .14f), inner.topLeft, inner.size, style = Stroke(.5f * unit))
    val ticks = Path()
    for (column in 0 until columns) {
        val x = w * (column + .5f) / columns
        label(measurer, ('A' + column).toString(), Offset(x, outer.bottom - 10 * unit), palette.slate.copy(alpha = .5f), 7f)
        val edge = w * column / columns
        ticks.moveTo(edge, outer.top); ticks.lineTo(edge, inner.top)
        ticks.moveTo(edge, outer.bottom); ticks.lineTo(edge, inner.bottom)
    }
    for (row in 0 until rows) {
        val y = h * (row + .5f) / rows
        label(measurer, "%02d".format(row + 1), Offset(inner.left + 9 * unit, y), palette.slate.copy(alpha = .5f), 7f)
        val edge = h * row / rows
        ticks.moveTo(outer.left, edge); ticks.lineTo(inner.left, edge)
        ticks.moveTo(outer.right, edge); ticks.lineTo(inner.right, edge)
    }
    drawPath(ticks, palette.slate.copy(alpha = .3f), style = Stroke(.6f * unit))
}
