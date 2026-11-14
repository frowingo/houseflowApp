package com.fauscrew.ui.games.fausswitch

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.FausSwitchNative
import com.fauscrew.platform.SwitchColor
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** `FausSwitchRuleClipKind`: each rule as a tiny looping clip. */
internal enum class SwitchRuleClip(val period: Double, val stillPhase: Double) {
    TAP(3.2, .3), SOLID(3.2, .5), ROBOTS(3.6, .5), GAP(3.2, .55), BOOST(3.2, .6), SLOW(3.4, .55), PORTAL(3.6, .5),
}

/**
 * `FausSwitchRuleClip`: a two- to three-second moment of the race (a flip, a block, a gap, a
 * pad, a portal) on a 160 × 90 stage, drawn on the display clock. With reduced motion each
 * clip holds one telling frame. Decorative; the rule's sentence is read by TalkBack.
 */
@Composable
internal fun FausSwitchRuleClipView(kind: SwitchRuleClip, playerColor: SwitchColor, reduceMotion: Boolean, modifier: Modifier = Modifier) {
    val hex = remember { FausSwitchNative.constants.colorHex }
    val other = if (playerColor == SwitchColor.BERRY) SwitchColor.OCEAN else SwitchColor.BERRY
    val player = remember(playerColor) { SwitchRobotArt(playerColor.tone(hex), isLocal = false) }
    val rival = remember(other) { SwitchRobotArt(other.tone(hex), isLocal = false) }
    val hand = rememberVectorPainter(Icons.Rounded.TouchApp)
    var millis by remember { mutableLongStateOf(0L) }
    LaunchedEffect(reduceMotion) {
        if (reduceMotion) return@LaunchedEffect
        val start = withFrameMillis { it }
        while (true) {
            // About 30 fps is plenty for these clips.
            withFrameMillis { now -> if (now - start - millis >= 33) millis = now - start }
        }
    }
    val shape = RoundedCornerShape(12.dp)
    androidx.compose.foundation.layout.Box(
        modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(shape)
            .border(1.dp, FausSwitchPalette.wine.copy(alpha = .22f), shape)
            .clearAndSetSemantics {}
            .drawBehind {
                val phase = if (reduceMotion) kind.stillPhase else (millis / 1000.0 / kind.period) % 1.0
                ClipStage(this, player, rival, hand).draw(kind, phase)
            },
    )
}

/** World units: 160 wide, 90 high, origin bottom left. The camera stands still; the world slides left. */
private class ClipStage(
    private val scope: DrawScope,
    private val player: SwitchRobotArt,
    private val rival: SwitchRobotArt,
    private val hand: Painter,
) {
    private val scale = scope.size.width / WIDTH

    fun draw(kind: SwitchRuleClip, phase: Double) {
        scope.drawRect(FausSwitchPalette.mint)
        when (kind) {
            SwitchRuleClip.TAP -> drawTap(phase)
            SwitchRuleClip.SOLID -> drawSolid(phase)
            SwitchRuleClip.ROBOTS -> drawRobots(phase)
            SwitchRuleClip.GAP -> drawGap(phase)
            SwitchRuleClip.BOOST -> drawBoost(phase)
            SwitchRuleClip.SLOW -> drawSlow(phase)
            SwitchRuleClip.PORTAL -> drawPortal(phase)
        }
    }

    // Geometry

    private fun rect(x: Float, y: Float, width: Float, height: Float) =
        Rect(x * scale, scope.size.height - (y + height) * scale, (x + width) * scale, scope.size.height - y * scale)

    private fun point(x: Float, y: Float) = Offset(x * scale, scope.size.height - y * scale)

    private fun fill(frame: Rect, color: Color, radius: Float = 1.6f) {
        scope.drawRoundRect(color, frame.topLeft, frame.size, CornerRadius(radius * scale))
    }

    private fun slide(start: Float, phase: Double) = start - TRAVEL * phase.toFloat()

    // Pieces

    /** Both rails, with holes at [floorGaps] (screen x ranges) and stripes sliding left. */
    private fun rails(phase: Double, floorGaps: List<ClosedFloatingPointRange<Float>> = emptyList()) {
        val floorParts = railParts(-10f, WIDTH + 10, floorGaps)
        for (part in floorParts) {
            val length = part.endInclusive - part.start
            fill(rect(part.start, 0f, length, RAIL), FausSwitchPalette.teal, 0f)
            fill(rect(part.start, RAIL - 1.2f, length, 1.2f), FausSwitchPalette.lime, 0f)
        }
        fill(rect(-10f, CEILING, WIDTH + 20, RAIL), FausSwitchPalette.teal, 0f)
        fill(rect(-10f, CEILING, WIDTH + 20, 1.2f), FausSwitchPalette.lime, 0f)
        // Stripes show the course moving.
        val offset = (phase.toFloat() * TRAVEL) % 20
        var x = -offset
        while (x < WIDTH + 20) {
            val onFloor = floorParts.any { x in it && (x + 6) in it }
            if (onFloor) fill(rect(x, 2f, 6f, 1.4f), FausSwitchPalette.green.copy(alpha = .7f), .7f)
            fill(rect(x + 10, CEILING + 3.6f, 6f, 1.4f), FausSwitchPalette.green.copy(alpha = .7f), .7f)
            x += 20
        }
        for (gap in floorGaps) {
            fill(rect(gap.start - 1.4f, 0f, 1.4f, RAIL), FausSwitchPalette.berry, 0f)
            fill(rect(gap.endInclusive, 0f, 1.4f, RAIL), FausSwitchPalette.berry, 0f)
        }
    }

    private fun robot(art: SwitchRobotArt, x: Float, y: Float, flipped: Boolean, opacity: Float = 1f) {
        if (opacity <= .01f) return
        // The robot art spans about 28 of its 32-unit square vertically.
        val unit = ROBOT_HEIGHT / 28f * scale
        val center = point(x, y)
        scope.drawIntoCanvas { canvas ->
            val native = canvas.nativeCanvas
            native.save()
            native.translate(center.x, center.y)
            native.scale(unit, if (flipped) unit else -unit)
            if (opacity < 1f) native.saveLayerAlpha(-20f, -20f, 20f, 20f, (opacity * 255).toInt())
            art.draw(native, showsMarks = false)
            if (opacity < 1f) native.restore()
            native.restore()
        }
    }

    private fun player(x: Float, y: Float, flipped: Boolean, opacity: Float = 1f) = robot(player, x, y, flipped, opacity)

    /** A tap: a ring spreading from the robot. */
    private fun tap(phase: Double, at: Double, x: Float, y: Float) {
        val spread = progress(phase, at, at + .16)
        if (phase < at || spread >= 1f) return
        scope.drawCircle(FausSwitchPalette.wine.copy(alpha = 1 - spread), (5 + 13 * spread) * scale, point(x, y),
            style = Stroke(1.6f * scale))
    }

    /** The finger in the corner lights up on each tap. */
    private fun hand(phase: Double, taps: List<Double>) {
        val glow = taps.maxOf { max(0.0, 1 - abs(phase - it) / .07) }.toFloat()
        val side = 15 + 3 * glow
        val frame = rect(WIDTH - side - 6, 26 - side / 2, side, side)
        scope.translate(frame.left, frame.top) {
            with(hand) { draw(frame.size, alpha = .35f + .65f * glow, colorFilter = ColorFilter.tint(FausSwitchPalette.plum)) }
        }
    }

    private fun chevrons(frame: Rect, color: Color, backward: Boolean) {
        val path = Path()
        val rise = frame.height * .28f
        for (index in 0 until 3) {
            val x = if (backward) frame.right - frame.width * (.28f + index * .22f) else frame.left + frame.width * (.28f + index * .22f)
            val arm = (if (backward) 1 else -1) * frame.height * .22f
            path.moveTo(x + arm, frame.center.y - rise)
            path.lineTo(x, frame.center.y)
            path.lineTo(x + arm, frame.center.y + rise)
        }
        scope.drawPath(path, color, style = Stroke(1.1f * scale, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }

    private fun portalRing(x: Float, onFloor: Boolean, pulse: Double, faint: Boolean = false) {
        val height = 21f
        val width = 11f
        val base = if (onFloor) FLOOR else CEILING - height
        val frame = rect(x - width / 2, base, width, height)
        if (faint) {
            scope.drawOval(FausSwitchPalette.lavender.copy(alpha = .35f), frame.topLeft, frame.size)
            scope.drawOval(FausSwitchPalette.wine.copy(alpha = .45f), frame.topLeft, frame.size, style = Stroke(1f * scale))
            return
        }
        scope.drawOval(FausSwitchPalette.deepWine, frame.topLeft, frame.size)
        val core = (.45 + .15 * sin(pulse * 2 * Math.PI * 3)).toFloat()
        val inner = Size(frame.width * core, frame.height * core)
        scope.drawOval(FausSwitchPalette.lavender, frame.center - Offset(inner.width / 2, inner.height / 2), inner)
        scope.drawOval(FausSwitchPalette.wine, frame.topLeft, frame.size, style = Stroke(1.8f * scale))
    }

    // Clips

    /** Tap on the floor: up to the ceiling; tap on the ceiling: back down. */
    private fun drawTap(phase: Double) {
        rails(phase)
        val x = 60f
        val (y, flipped) = when {
            phase < .25 -> FLOOR_CENTER to false
            phase < .65 -> flight(phase, .25, .37, up = true) to true
            else -> flight(phase, .65, .77, up = false) to false
        }
        player(x, y, flipped)
        tap(phase, .25, x, FLOOR_CENTER)
        tap(phase, .65, x, CEILING_CENTER)
        hand(phase, listOf(.25, .65))
    }

    /** A floor wall and its island slide in; the robot flips over to the ceiling and back. */
    private fun drawSolid(phase: Double) {
        rails(phase)
        val wall = slide(170f, phase)
        fill(rect(wall, FLOOR, 14f, 40f), FausSwitchPalette.wine)
        fill(rect(wall + 20, 50f, 20f, 8f), FausSwitchPalette.wine)
        val x = 50f
        val (y, flipped) = when {
            phase < .3 -> FLOOR_CENTER to false
            phase < .72 -> flight(phase, .3, .42, up = true) to true
            else -> flight(phase, .72, .84, up = false) to false
        }
        player(x, y, flipped)
        tap(phase, .3, x, FLOOR_CENTER)
        tap(phase, .72, x, CEILING_CENTER)
    }

    /** The player drops onto another robot's head, rides it, then flips away. */
    private fun drawRobots(phase: Double) {
        rails(phase)
        val x = 70f
        robot(rival, x, FLOOR_CENTER, flipped = false)
        val head = FLOOR_CENTER + ROBOT_HEIGHT
        val (y, flipped) = when {
            phase < .2 -> CEILING_CENTER to true
            phase < .62 -> {
                val fall = progress(phase, .2, .3)
                CEILING_CENTER - (CEILING_CENTER - head) * fall * fall to false
            }
            else -> {
                val rise = progress(phase, .62, .72)
                head + (CEILING_CENTER - head) * rise * rise to true
            }
        }
        player(x, y, flipped)
        tap(phase, .2, x, CEILING_CENTER)
        tap(phase, .62, x, head)
    }

    /** The player flips over a floor gap in time; the robot ahead does not and falls. */
    private fun drawGap(phase: Double) {
        val gap = slide(170f, phase)
        rails(phase, listOf(gap..(gap + 30)))
        val fallen = progress(phase, .37, .56)
        val fallerOpacity = if (phase > .86) progress(phase, .86, 1.0) else 1 - fallen * .6f
        val fallerY = if (phase > .86) FLOOR_CENTER else FLOOR_CENTER - 60 * fallen * fallen
        robot(rival, 92f, fallerY, flipped = false, opacity = fallerOpacity)
        val x = 40f
        val (y, flipped) = when {
            phase < .3 -> FLOOR_CENTER to false
            phase < .78 -> flight(phase, .3, .42, up = true) to true
            else -> flight(phase, .78, .9, up = false) to false
        }
        player(x, y, flipped)
        tap(phase, .3, x, FLOOR_CENTER)
    }

    /** Mid-flip through a floating speed pad: the robot surges forward for a moment. */
    private fun drawBoost(phase: Double) {
        rails(phase)
        val pad = slide(170f, phase)
        val used = phase > .5
        val frame = rect(pad - 12, 40f, 24f, 10f)
        fill(frame, FausSwitchPalette.green.copy(alpha = if (used) .35f else 1f), 2f)
        scope.drawRoundRect(FausSwitchPalette.deepWine.copy(alpha = if (used) .3f else 1f), frame.topLeft, frame.size,
            CornerRadius(2 * scale), style = Stroke(.8f * scale))
        chevrons(frame, FausSwitchPalette.mint.copy(alpha = if (used) .4f else 1f), backward = false)
        val surge = when {
            phase < .5 -> 0f
            phase < .6 -> smooth(progress(phase, .5, .6))
            else -> 1 - smooth(progress(phase, .7, .95))
        }
        val x = 50 + 30 * surge
        val (y, flipped) = when {
            phase < .42 -> FLOOR_CENTER to false
            phase < .84 -> flight(phase, .42, .54, up = true) to true
            else -> flight(phase, .84, .96, up = false) to false
        }
        if (surge > .05f) {
            floatArrayOf(-4f, 0f, 4f).forEachIndexed { index, offset ->
                val length = (10 + (index % 2) * 5) * surge
                fill(rect(x - 9 - length, y + offset - .6f, length, 1.2f), FausSwitchPalette.green.copy(alpha = .8f), .6f)
            }
        }
        player(x, y, flipped)
        tap(phase, .42, 50f, FLOOR_CENTER)
    }

    /** Running over a slow pad on the floor: the robot drops back for a moment. */
    private fun drawSlow(phase: Double) {
        rails(phase)
        val pad = slide(176f, phase)
        val used = phase > .42
        val frame = rect(pad - 12, FLOOR, 24f, 7f)
        fill(frame, FausSwitchPalette.lavender.copy(alpha = if (used) .45f else 1f), 1.5f)
        scope.drawRoundRect(FausSwitchPalette.deepWine.copy(alpha = if (used) .35f else 1f), frame.topLeft, frame.size,
            CornerRadius(1.5f * scale), style = Stroke(.8f * scale))
        chevrons(frame, FausSwitchPalette.deepWine.copy(alpha = if (used) .4f else 1f), backward = true)
        val drop = when {
            phase < .42 -> 0f
            phase < .62 -> smooth(progress(phase, .42, .62))
            else -> 1 - smooth(progress(phase, .75, .98))
        }
        val x = 72 - 32 * drop
        if (drop > .05f) {
            scope.drawCircle(FausSwitchPalette.lavender.copy(alpha = .45f * drop), 13 * scale, point(x, FLOOR_CENTER))
        }
        player(x, FLOOR_CENTER, flipped = false)
    }

    /** Into a floor portal: out on the ceiling, farther back, then on with the race. */
    private fun drawPortal(phase: Double) {
        rails(phase)
        val portal = slide(178f, phase)
        portalRing(portal - 52, onFloor = false, pulse = phase, faint = true)
        portalRing(portal, onFloor = true, pulse = phase)
        val entered = .38
        val back = 178 - TRAVEL * entered.toFloat() - 52
        when {
            phase < entered -> player(80f, FLOOR_CENTER, flipped = false)
            phase < .42 -> {
                val flash = progress(phase, entered, .42)
                scope.drawCircle(FausSwitchPalette.lavender.copy(alpha = 1 - flash), (4 + 12 * flash) * scale,
                    point(portal, FLOOR + 10), style = Stroke(2 * scale))
            }
            else -> {
                val x = if (phase < .74) back else back + (80 - back) * smooth(progress(phase, .74, 1.0))
                val y = if (phase < .62) CEILING_CENTER else flight(phase, .62, .74, up = false)
                player(x, y, flipped = phase < .62, opacity = progress(phase, .42, .47))
                if (phase >= .62) tap(phase, .62, back, CEILING_CENTER)
            }
        }
    }

    private companion object {
        const val WIDTH = 160f
        const val RAIL = 7f
        const val FLOOR = 7f
        const val CEILING = 83f
        const val ROBOT_HEIGHT = 17f
        const val FLOOR_CENTER = FLOOR + ROBOT_HEIGHT / 2
        const val CEILING_CENTER = CEILING - ROBOT_HEIGHT / 2
        /** How far the world slides per loop. */
        const val TRAVEL = 240f

        fun progress(phase: Double, start: Double, end: Double): Float =
            min(1.0, max(0.0, (phase - start) / (end - start))).toFloat()

        fun smooth(value: Float) = value * value * (3 - 2 * value)

        /** A flip from one rail to the other, accelerating like gravity. */
        fun flight(phase: Double, start: Double, end: Double, up: Boolean): Float {
            val fall = progress(phase, start, end)
            val travel = (CEILING_CENTER - FLOOR_CENTER) * fall * fall
            return if (up) FLOOR_CENTER + travel else CEILING_CENTER - travel
        }
    }
}

/**
 * `FausSwitchClipRails.parts`: the floor rail's solid pieces between [start] and [end] with
 * [gaps] cut out. Gaps may lie partly or wholly outside the stage; no piece is empty or reversed.
 */
internal fun railParts(start: Float, end: Float, gaps: List<ClosedFloatingPointRange<Float>>): List<ClosedFloatingPointRange<Float>> {
    val parts = ArrayList<ClosedFloatingPointRange<Float>>()
    var cursor = start
    for (gap in gaps.sortedBy { it.start }) {
        if (cursor >= end) break
        val cut = min(gap.start, end)
        if (cut > cursor) parts += cursor..cut
        cursor = max(cursor, gap.endInclusive)
    }
    if (cursor < end) parts += cursor..end
    return parts
}
