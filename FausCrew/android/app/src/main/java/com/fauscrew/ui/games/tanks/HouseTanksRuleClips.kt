package com.fauscrew.ui.games.tanks

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
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
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.rememberVectorPainter
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksJoker
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** `HouseTanksRuleClipKind`: each How-to-play rule as a tiny looping clip, with its copy keys. */
internal enum class TanksRuleClip(val period: Double, val stillPhase: Double, val titleKey: String) {
    FIRE(3.2, .3, "house_tanks_rule_fire"),
    DRIVE(3.6, .45, "house_tanks_rule_drive"),
    SURVIVE(3.6, .62, "house_tanks_rule_survive"),
    CRATES(3.8, .74, "house_tanks_rule_crates"),
    JOKER(4.0, .56, "house_tanks_rule_jokers"),
    SHIELD(3.6, .25, "house_tanks_rule_joker_time");

    val detailKey: String get() = titleKey + "_detail"
}

/**
 * `HouseTanksRuleClip`: a three- to four-second moment of a match (a shot, a drive, a win, a
 * crate, two jokers) on a 160 × 90 top-down stage, drawn on the display clock from the same
 * numbers as iOS. With reduced motion each clip holds one telling frame. Decorative; the
 * rule's sentence is read by TalkBack.
 */
@Composable
internal fun HouseTanksRuleClipView(kind: TanksRuleClip, reduceMotion: Boolean, modifier: Modifier = Modifier) {
    val hand = rememberVectorPainter(Icons.Rounded.TouchApp)
    val jokers = rememberJokerPainters()
    var millis by remember { mutableLongStateOf(0L) }
    LaunchedEffect(reduceMotion) {
        if (reduceMotion) return@LaunchedEffect
        val start = withFrameMillis { it }
        while (true) {
            // About 30 fps is plenty for these clips.
            withFrameMillis { now -> if (now - start - millis >= 33) millis = now - start }
        }
    }
    val shape = RoundedCornerShape(8.dp)
    Box(
        modifier.fillMaxWidth().aspectRatio(16f / 9f).clip(shape)
            .border(1.dp, HouseTanksFieldTheme.hairline, shape)
            .clearAndSetSemantics {}
            .drawBehind {
                val phase = if (reduceMotion) kind.stillPhase else (millis / 1000.0 / kind.period) % 1.0
                TanksClipStage(this, hand, jokers).draw(kind, phase)
            },
    )
}

/**
 * Stage units: 160 wide, 90 high, origin top left, y down; angles in degrees, 0 = right,
 * clockwise. A tank is the arena artwork at 0.3 (barrel tip 10 ahead of its center).
 */
private class TanksClipStage(
    private val scope: DrawScope,
    private val hand: Painter,
    private val jokers: JokerPainters,
) {
    private val scale = scope.size.width / WIDTH

    fun draw(kind: TanksRuleClip, phase: Double) {
        background()
        when (kind) {
            TanksRuleClip.FIRE -> drawFire(phase)
            TanksRuleClip.DRIVE -> drawDrive(phase)
            TanksRuleClip.SURVIVE -> drawSurvive(phase)
            TanksRuleClip.CRATES -> drawCrates(phase)
            TanksRuleClip.JOKER -> drawJoker(phase)
            TanksRuleClip.SHIELD -> drawShield(phase)
        }
    }

    // Geometry

    private fun point(x: Float, y: Float) = Offset(x * scale, y * scale)

    private fun rect(x: Float, y: Float, width: Float, height: Float) = Rect(x * scale, y * scale, (x + width) * scale, (y + height) * scale)

    private fun fillCircle(x: Float, y: Float, radius: Float, color: Color) = scope.drawCircle(color, radius * scale, point(x, y))

    private fun strokeCircle(x: Float, y: Float, radius: Float, color: Color, width: Float) =
        scope.drawCircle(color, radius * scale, point(x, y), style = Stroke(width * scale))

    private fun arc(x: Float, y: Float, radius: Float, fraction: Float, color: Color, width: Float) {
        val r = radius * scale
        scope.drawArc(color, -90f, 360f * max(0f, fraction), false, Offset(x * scale - r, y * scale - r), Size(r * 2, r * 2),
            style = Stroke(width * scale, cap = StrokeCap.Round))
    }

    // Pieces

    private fun background() {
        scope.drawRect(HouseTanksPalette.paper)
        scope.drawRect(HouseTanksPalette.sand.copy(alpha = .5f))
        val line = HouseTanksPalette.slate.copy(alpha = .14f)
        var x = 16f
        while (x < WIDTH) {
            scope.drawLine(line, point(x, 0f), point(x, HEIGHT), .6f)
            x += 16f
        }
        var y = 15f
        while (y < HEIGHT) {
            scope.drawLine(line, point(0f, y), point(WIDTH, y), .6f)
            y += 15f
        }
    }

    private fun tank(x: Float, y: Float, angle: Float, color: Color, isPlayer: Boolean = true, isDestroyed: Boolean = false,
                     opacity: Float = 1f) {
        if (opacity <= .01f) return
        val unit = TANK_SCALE * scale
        scope.withTransform({
            translate(x * scale, y * scale)
            rotate(angle, Offset.Zero)
            scale(unit, unit, Offset.Zero)
        }) {
            if (opacity >= .99f) {
                drawTankArtwork(color, isPlayer, isDestroyed)
            } else {
                // One layer for the whole tank, so its overlapping parts fade together.
                drawContext.canvas.saveLayer(Rect(-40f, -32f, 40f, 32f), Paint().apply { alpha = opacity })
                drawTankArtwork(color, isPlayer, isDestroyed)
                drawContext.canvas.restore()
            }
        }
    }

    private fun shell(position: Offset, angle: Float, color: Color) {
        scope.withTransform({
            translate(position.x * scale, position.y * scale)
            rotate(angle, Offset.Zero)
        }) {
            val body = Size(5.4f * scale, 2.1f * scale)
            val topLeft = Offset(-2.7f * scale, -1.05f * scale)
            drawRoundRect(color, topLeft, body, CornerRadius(1.05f * scale))
            drawRoundRect(HouseTanksPalette.ink, topLeft, body, CornerRadius(1.05f * scale), style = Stroke(.5f * scale))
        }
    }

    private fun muzzleFlash(phase: Double, time: Double, origin: Offset) {
        val flash = progress(phase, time, time + .05)
        if (phase < time || flash >= 1f) return
        fillCircle(origin.x, origin.y, 2.5f + 2 * flash, HouseTanksPalette.khaki.copy(alpha = 1 - flash))
    }

    private fun ring(phase: Double, time: Double, x: Float, y: Float, color: Color, from: Float = 4f, reach: Float = 11f,
                     duration: Double = .16) {
        val spread = progress(phase, time, time + duration)
        if (phase < time || spread >= 1f) return
        strokeCircle(x, y, from + reach * spread, color.copy(alpha = 1 - spread), 1.4f)
    }

    private fun hand(phase: Double, taps: List<Double> = emptyList(), holds: List<ClosedFloatingPointRange<Double>> = emptyList()) {
        val tapGlow = taps.maxOfOrNull { max(0.0, 1 - abs(phase - it) / .07) } ?: 0.0
        val glow = (if (holds.any { phase in it }) 1.0 else tapGlow).toFloat()
        val side = (15 + 3 * glow) * scale
        scope.translate((WIDTH - 6) * scale - side, (HEIGHT - 5) * scale - side) {
            with(hand) { draw(Size(side, side), alpha = .35f + .65f * glow, colorFilter = ColorFilter.tint(HouseTanksPalette.steel)) }
        }
    }

    private fun crate(x: Float, y: Float, side: Float = 14f, opacity: Float = 1f) {
        if (opacity <= .01f) return
        val frame = rect(x - side / 2, y - side / 2, side, side)
        scope.drawRoundRect(HouseTanksPalette.khaki.copy(alpha = opacity), frame.topLeft, frame.size, CornerRadius(1.4f * scale))
        scope.drawRoundRect(HouseTanksPalette.ink.copy(alpha = .55f * opacity), frame.topLeft, frame.size, CornerRadius(1.4f * scale),
            style = Stroke(.7f * scale))
        val inset = side * .23f
        val white = Color.White.copy(alpha = .35f * opacity)
        scope.drawLine(white, point(x - side / 2 + inset, y - side / 2 + inset), point(x + side / 2 - inset, y + side / 2 - inset),
            scale, StrokeCap.Round)
        scope.drawLine(white, point(x - side / 2 + inset, y + side / 2 - inset), point(x + side / 2 - inset, y - side / 2 + inset),
            scale, StrokeCap.Round)
    }

    private fun splinters(phase: Double, time: Double, x: Float, y: Float) {
        val spread = progress(phase, time, time + .16)
        if (phase < time || spread >= 1f) return
        floatArrayOf(-135f, -45f, 45f, 135f).forEachIndexed { index, angle ->
            val direction = direction(angle + index * 9)
            val distance = 3 + 13 * spread
            scope.withTransform({
                translate((x + direction.x * distance) * scale, (y + direction.y * distance) * scale)
                rotate(angle + 160 * spread, Offset.Zero)
            }) {
                drawRoundRect(HouseTanksPalette.khaki.copy(alpha = 1 - spread), Offset(-3.5f * scale, -1.2f * scale),
                    Size(7f * scale, 2.4f * scale), CornerRadius(.6f * scale))
            }
        }
    }

    private fun explosion(phase: Double, time: Double, x: Float, y: Float) {
        val spread = progress(phase, time, time + .18)
        if (phase < time || spread >= 1f) return
        fillCircle(x, y, 6 + 10 * spread, HouseTanksPalette.ink.copy(alpha = .35f * (1 - spread)))
        strokeCircle(x, y, 5 + 14 * spread, HouseTanksPalette.rust.copy(alpha = 1 - spread), 2f)
    }

    private fun jokerGlyph(joker: TanksJoker, x: Float, y: Float, side: Float, opacity: Float) {
        scope.translate(x * scale, y * scale) {
            drawJokerGlyph(joker, side * scale, HouseTanksPalette.paper.copy(alpha = opacity), jokers)
        }
    }

    private fun token(joker: TanksJoker, x: Float, y: Float, pulse: Double, timer: Float, opacity: Float) {
        if (opacity <= .01f) return
        val radius = 6 + .6f * sin(pulse * 2 * Math.PI * 3).toFloat()
        fillCircle(x, y, radius, joker.tint.copy(alpha = opacity))
        strokeCircle(x, y, radius, HouseTanksPalette.paper.copy(alpha = opacity), 1f)
        arc(x, y, radius + 2.2f, timer, joker.tint.copy(alpha = .8f * opacity), 1.1f)
        jokerGlyph(joker, x, y, 7f, opacity)
    }

    private fun badge(joker: TanksJoker, tankX: Float, tankY: Float, left: Float, opacity: Float) {
        if (opacity <= .01f) return
        val x = tankX + 9
        val y = tankY - 11
        fillCircle(x, y, 4.6f, joker.tint.copy(alpha = opacity))
        strokeCircle(x, y, 4.6f, HouseTanksPalette.paper.copy(alpha = opacity), .8f)
        arc(x, y, 6.3f, left, joker.tint.copy(alpha = opacity), 1f)
        jokerGlyph(joker, x, y, 5.4f, opacity)
    }

    // Clips

    private fun drawFire(phase: Double) {
        val x = 48f
        val y = 45f
        fun angle(at: Double) = -90f + 360f * at.toFloat()
        val shots = listOf(.22, .62)
        for (time in shots) {
            val origin = muzzle(x, y, angle(time))
            shellPosition(phase, time, origin, angle(time), 380f)?.let { shell(it, angle(time), PLAYER) }
        }
        tank(x, y, angle(phase), PLAYER)
        for (time in shots) {
            muzzleFlash(phase, time, muzzle(x, y, angle(time)))
            ring(phase, time, x, y, HouseTanksPalette.steel, from = 9f, reach = 8f)
        }
        hand(phase, taps = shots)
    }

    private fun drawDrive(phase: Double) {
        val start = Offset(30f, 52f)
        val aim = -20f
        val drive = progress(phase, .2, .62)
        val direction = direction(aim)
        val x = start.x + direction.x * 95 * drive
        val y = start.y + direction.y * 95 * drive
        val angle = when {
            phase < .2 -> -110 + 90 * progress(phase, 0.0, .2)
            phase < .62 -> aim
            else -> aim + 90 * progress(phase, .62, .9)
        }
        val fade = loopFade(phase)
        if (drive > 0) {
            val normal = Offset(-direction.y, direction.x)
            val mark = HouseTanksPalette.umber.copy(alpha = .35f * fade)
            var step = 0f
            while (step < 95 * drive - 6) {
                for (side in floatArrayOf(-4.2f, 4.2f)) {
                    val from = Offset(start.x + direction.x * step + normal.x * side, start.y + direction.y * step + normal.y * side)
                    scope.drawLine(mark, point(from.x, from.y), point(from.x + direction.x * 2.4f, from.y + direction.y * 2.4f),
                        1.1f * scale)
                }
                step += 4.5f
            }
        }
        tank(x, y, angle, PLAYER, opacity = fade)
        if (phase in .2..0.62) {
            val breathe = (.5 + .5 * sin(phase * 2 * Math.PI * 6)).toFloat()
            strokeCircle(x, y, 10 + breathe, HouseTanksPalette.steel.copy(alpha = .55f), 1.2f)
        }
        hand(phase, holds = listOf(.2..0.62))
    }

    private fun drawSurvive(phase: Double) {
        val player = Offset(34f, 48f)
        val rival = Offset(126f, 48f)
        val shots = listOf(.18, .43)
        val speed = 625f
        val origin = muzzle(player.x, player.y, 0f)
        val hits = shots.map { it + (rival.x - 8 - origin.x) / speed }
        shots.zip(hits).forEach { (shot, hit) ->
            shellPosition(phase, shot, origin, 0f, speed, until = hit)?.let { shell(it, 0f, PLAYER) }
        }
        val fade = loopFade(phase)
        val destroyed = phase >= hits[1]
        val flicker = if (hits.any { phase >= it && phase < it + .05 }) .45f else 1f
        tank(rival.x, rival.y, 180f, RIVAL, isPlayer = false, isDestroyed = destroyed, opacity = fade * flicker)
        tank(player.x, player.y, 0f, PLAYER, opacity = fade)
        shots.forEach { muzzleFlash(phase, it, origin) }
        ring(phase, hits[0], rival.x - 6, rival.y, HouseTanksPalette.rust, from = 2f, reach = 7f)
        explosion(phase, hits[1], rival.x, rival.y)

        val armor = when {
            phase < hits[0] -> 2
            phase < hits[1] -> 1
            else -> 0
        }
        for (index in 0 until 5) {
            val frame = rect(rival.x - 11 + index * 4.6f, rival.y - 17, 3.6f, 2.2f)
            val color = if (index < armor) HouseTanksPalette.rust else HouseTanksPalette.slate.copy(alpha = .3f)
            scope.drawRoundRect(color.copy(alpha = color.alpha * fade), frame.topLeft, frame.size, CornerRadius(.6f * scale))
        }
        val winAt = hits[1] + .1
        for (index in 0 until 3) {
            val cx = WIDTH / 2 - 9 + index * 9
            val won = index < 2 || phase >= winAt
            val pop = if (index == 2 && phase >= winAt) 1 + .5f * (1 - progress(phase, winAt, winAt + .08)) else 1f
            val fill = if (won) PLAYER else HouseTanksPalette.slate.copy(alpha = .25f)
            fillCircle(cx, 9f, 2.8f * pop, fill.copy(alpha = fill.alpha * fade))
            strokeCircle(cx, 9f, 2.8f * pop, HouseTanksPalette.ink.copy(alpha = .5f * fade), .6f)
        }
        hand(phase, taps = shots)
    }

    private fun drawCrates(phase: Double) {
        val y = 60f
        val drive = progress(phase, .05, .4)
        val x = 18 + 44 * drive
        val pushed = max(46f, x + 14)
        val aim = -40 * smooth(progress(phase, .45, .58))
        val fired = .6
        val origin = muzzle(62f, y, -40f)
        val toward = direction(-40f)
        val target = Offset(origin.x + toward.x * 55, origin.y + toward.y * 55)
        val speed = 570f
        val hit = fired + 48 / speed
        val fade = loopFade(phase, out = .88)
        crate(pushed, y, opacity = fade)
        if (phase < hit) crate(target.x, target.y, opacity = progress(phase, 0.0, .06))
        shellPosition(phase, fired, origin, -40f, speed, until = hit)?.let { shell(it, -40f, PLAYER) }
        tank(x, y, aim, PLAYER, opacity = fade)
        muzzleFlash(phase, fired, origin)
        splinters(phase, hit, target.x, target.y)
        hand(phase, taps = listOf(fired), holds = listOf(.05..0.4))
    }

    private fun drawJoker(phase: Double) {
        val y = 46f
        val tokenX = 76f
        val taken = .32
        val x = 22 + (tokenX - 22) * progress(phase, .05, taken)
        val fade = loopFade(phase)
        if (phase < taken) {
            token(TanksJoker.SPREAD_SHOT, tokenX, y, phase, .8f - .25f * phase.toFloat(), progress(phase, 0.0, .05))
        }
        val shots = listOf(.5, .72)
        for (time in shots) {
            val origin = muzzle(x, y, 0f)
            for (spread in floatArrayOf(-24f, -12f, 0f, 12f, 24f)) {
                shellPosition(phase, time, origin, spread, 420f)?.let { shell(it, spread, PLAYER) }
            }
        }
        tank(x, y, 0f, PLAYER, opacity = fade)
        shots.forEach { muzzleFlash(phase, it, muzzle(x, y, 0f)) }
        ring(phase, taken, tokenX, y, TanksJoker.SPREAD_SHOT.tint, from = 6f, reach = 10f, duration = .12)
        if (phase >= taken) {
            badge(TanksJoker.SPREAD_SHOT, x, y, 1 - .55f * progress(phase, taken, 1.0), fade * progress(phase, taken, taken + .04))
        }
        hand(phase, taps = shots, holds = listOf(.05..taken))
    }

    private fun drawShield(phase: Double) {
        val player = Offset(40f, 48f)
        val rival = Offset(128f, 48f)
        val shots = listOf(.12, .42)
        val speed = 540f
        val bubble = 13f
        val origin = muzzle(rival.x, rival.y, 180f)
        val impacts = shots.map { it + (origin.x - (player.x + bubble)) / speed }
        val expires = .8
        val shieldOpacity = progress(phase, 0.0, .06) * (1 - progress(phase, expires, expires + .08))
        val fade = loopFade(phase)
        shots.zip(impacts).forEach { (shot, impact) ->
            shellPosition(phase, shot, origin, 180f, speed, until = impact)?.let { shell(it, 180f, RIVAL) }
        }
        tank(rival.x, rival.y, 180f, RIVAL, isPlayer = false, opacity = fade)
        tank(player.x, player.y, 0f, PLAYER, opacity = fade)
        if (shieldOpacity > .01f) {
            val flash = (impacts.maxOfOrNull { max(0.0, 1 - abs(phase - it) / .06) } ?: 0.0).toFloat()
            fillCircle(player.x, player.y, bubble, HouseTanksPalette.steel.copy(alpha = (.14f + .2f * flash) * shieldOpacity))
            strokeCircle(player.x, player.y, bubble, HouseTanksPalette.steel.copy(alpha = .75f * shieldOpacity), 1.2f + .8f * flash)
        }
        shots.zip(impacts).forEach { (shot, impact) ->
            muzzleFlash(phase, shot, origin)
            ring(phase, impact, player.x + bubble, player.y, HouseTanksPalette.steel, from = 1.5f, reach = 6f, duration = .1)
        }
        badge(TanksJoker.SHIELD, player.x, player.y, 1 - (phase / expires).toFloat(), shieldOpacity * fade)
    }

    private companion object {
        const val WIDTH = 160f
        const val HEIGHT = 90f
        const val TANK_SCALE = .3f
        const val BARREL_TIP = 10f
        val PLAYER = TanksColor.BLUE.ink
        val RIVAL = TanksColor.ORANGE.ink

        fun progress(phase: Double, start: Double, end: Double): Float = min(1.0, max(0.0, (phase - start) / (end - start))).toFloat()

        fun smooth(value: Float) = value * value * (3 - 2 * value)

        fun direction(degrees: Float): Offset {
            val radians = Math.toRadians(degrees.toDouble())
            return Offset(cos(radians).toFloat(), sin(radians).toFloat())
        }

        /** Fades the whole clip out at its end and in at its start, hiding the loop's jump. */
        fun loopFade(phase: Double, out: Double = .9): Float =
            if (phase < .05) progress(phase, 0.0, .05) else 1 - progress(phase, out, .97)

        fun muzzle(x: Float, y: Float, angle: Float): Offset {
            val direction = direction(angle)
            return Offset(x + direction.x * BARREL_TIP, y + direction.y * BARREL_TIP)
        }

        /** A shell fired at [time]; null before it is fired, after [until], or off the stage. */
        fun shellPosition(phase: Double, time: Double, origin: Offset, angle: Float, speed: Float, until: Double = 1.0): Offset? {
            if (phase < time || phase >= until) return null
            val travel = speed * (phase - time).toFloat()
            val direction = direction(angle)
            val position = Offset(origin.x + direction.x * travel, origin.y + direction.y * travel)
            return position.takeIf { it.x > -6 && it.x < WIDTH + 6 && it.y > -6 && it.y < HEIGHT + 6 }
        }
    }
}
