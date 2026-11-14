package com.fauscrew.ui.games.rockets

import android.graphics.Canvas
import android.graphics.DashPathEffect
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.RocketsColor
import com.fauscrew.platform.RocketsEffect
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** `HouseRocketsRuleClipKind`: each How-to-play rule as a tiny looping clip, with its copy keys. */
internal enum class RocketsRuleClip(val period: Double, val stillPhase: Double, val titleKey: String) {
    STEER(3.6, .4, "house_rockets_clip_steer"),
    THRUST(3.6, .6, "house_rockets_clip_thrust"),
    FIELDS(4.0, .32, "house_rockets_clip_fields"),
    SURVIVE(4.0, .55, "house_rockets_clip_survive");

    val detailKey: String get() = titleKey + "_detail"
}

/**
 * `HouseRocketsRuleClip`: a three- to four-second moment of a flight (steering from an edge,
 * the held heading, the two speed fields, falling behind) on a 160 × 90 slice of the course,
 * drawn on the display clock from the same numbers as iOS. With reduced motion each clip
 * holds one telling frame. Decorative; the rule's sentence is read by TalkBack.
 */
@Composable
internal fun HouseRocketsRuleClipView(kind: RocketsRuleClip, reduceMotion: Boolean, modifier: Modifier = Modifier) {
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
            .border(1.dp, HouseRocketsPreparationTheme.hairline, shape)
            .clearAndSetSemantics {}
            .drawBehind {
                val phase = if (reduceMotion) kind.stillPhase else (millis / 1000.0 / kind.period) % 1.0
                drawIntoCanvas { RocketsClipStage(it.nativeCanvas, size.width).draw(kind, phase) }
            },
    )
}

/**
 * Stage units: 160 wide, 90 high, origin top left, y down; headings in degrees, 0 = right (the
 * course direction), clockwise. A rocket is the course artwork at 0.42.
 */
private class RocketsClipStage(private val canvas: Canvas, width: Float) {
    private val scale = width / WIDTH

    fun draw(kind: RocketsRuleClip, phase: Double) {
        canvas.save()
        canvas.scale(scale, scale)
        when (kind) {
            RocketsRuleClip.STEER -> drawSteer(phase)
            RocketsRuleClip.THRUST -> drawThrust(phase)
            RocketsRuleClip.FIELDS -> drawFields(phase)
            RocketsRuleClip.SURVIVE -> drawSurvive(phase)
        }
        canvas.restore()
    }

    // Timing

    private fun progress(phase: Double, start: Double, end: Double): Float =
        min(1.0, max(0.0, (phase - start) / (end - start))).toFloat()

    private fun smooth(value: Float) = value * value * (3 - 2 * value)

    /** Fades the whole clip out at its end and in at its start, hiding the loop's jump. */
    private fun loopFade(phase: Double, out: Double = .9): Float =
        if (phase < .05) progress(phase, 0.0, .05) else 1 - progress(phase, out, .97)

    private fun flicker(phase: Double) = 1 + .12f * sin(phase * 2 * Math.PI * 14).toFloat()

    /** Integrates a heading (degrees over the loop) into the distance flown, at `speed` per loop. */
    private fun drift(phase: Double, speed: Float, heading: (Double) -> Float): Pair<Float, Float> {
        val steps = max(1, (phase * 120).toInt())
        val step = phase / steps
        var x = 0f
        var y = 0f
        for (index in 0 until steps) {
            val angle = Math.toRadians(heading((index + .5) * step).toDouble())
            x += (cos(angle) * speed * step).toFloat()
            y += (sin(angle) * speed * step).toFloat()
        }
        return x to y
    }

    // Paints

    private fun fill(color: Color, alpha: Float = 1f) = fillPaint(color.copy(alpha = color.alpha * alpha.coerceIn(0f, 1f)))
    private fun stroke(color: Color, width: Float, alpha: Float = 1f, round: Boolean = true) =
        strokePaint(color.copy(alpha = color.alpha * alpha.coerceIn(0f, 1f)), width, round)

    // Pieces

    /** The course: the outer terrain color, the navy track with rails and the sliding centre dashes. */
    private fun background(scroll: Float) {
        canvas.drawRect(0f, 0f, WIDTH, HEIGHT, fill(HouseRocketsPalette.outer))
        canvas.drawRect(0f, TRACK_TOP, WIDTH, TRACK_BOTTOM, fill(HouseRocketsPalette.navy))
        for (y in listOf(TRACK_TOP, TRACK_BOTTOM)) {
            canvas.drawRect(0f, y - .8f, WIDTH, y + .8f, fill(HouseRocketsPalette.blue, .65f))
        }
        val spacing = 20f
        var x = -(scroll % spacing)
        val middle = (TRACK_TOP + TRACK_BOTTOM) / 2
        val dash = fill(HouseRocketsPalette.cream, .14f)
        while (x < WIDTH) {
            canvas.drawRoundRect(x, middle - .5f, x + 8f, middle + .5f, .5f, .5f, dash)
            x += spacing
        }
    }

    /** The course rocket, nose along `heading`; the artwork faces right with y up, so it is flipped. */
    private fun rocket(
        x: Float, y: Float, heading: Float, color: RocketsColor, flame: Float = 1f,
        isPlayer: Boolean = false, effect: RocketsEffect? = null, opacity: Float = 1f,
    ) {
        if (opacity <= .01f) return
        canvas.save()
        canvas.translate(x, y)
        canvas.rotate(heading)
        canvas.scale(ROCKET_SCALE, -ROCKET_SCALE)
        val cream = HouseRocketsPalette.cream
        if (flame > 0f) {
            canvas.save()
            canvas.scale(flame, 1f)
            canvas.drawPath(HouseRocketsArtwork.flame, fill(cream, opacity))
            canvas.drawPath(HouseRocketsArtwork.flame, stroke(HouseRocketsPalette.red, 1.8f, opacity))
            canvas.restore()
        }
        val tint = HouseRocketsPalette.player(color)
        val outline = stroke(cream, 1.8f, opacity)
        listOf(HouseRocketsArtwork.fins to tint, HouseRocketsArtwork.hull to tint,
            HouseRocketsArtwork.collar to HouseRocketsPalette.burgundy, HouseRocketsArtwork.nose to HouseRocketsPalette.red)
            .forEach { (path, part) ->
                canvas.drawPath(path, fill(part, opacity))
                canvas.drawPath(path, outline)
            }
        canvas.drawPath(HouseRocketsArtwork.window, fill(HouseRocketsPalette.navy, opacity))
        canvas.drawPath(HouseRocketsArtwork.window,
            if (color == RocketsColor.MINT) stroke(HouseRocketsPalette.navy, 1.8f, opacity) else outline)
        if (isPlayer) canvas.drawCircle(0f, 0f, 25f, stroke(cream, 1.5f, .65f * opacity))
        effect?.let {
            canvas.drawCircle(0f, 0f, 29f,
                stroke(if (it == RocketsEffect.BOOST) HouseRocketsPalette.blue else cream, 3f, opacity))
        }
        canvas.restore()
    }

    /** A speed field as the course draws it: blue with double chevrons, or red with brake bars. */
    private fun field(effect: RocketsEffect, x: Float, y: Float, opacity: Float) {
        if (opacity <= .01f || x < -FIELD_RADIUS - 2 || x > WIDTH + FIELD_RADIUS + 2) return
        val boost = effect == RocketsEffect.BOOST
        canvas.drawCircle(x, y, FIELD_RADIUS, fill(if (boost) HouseRocketsPalette.blue else HouseRocketsPalette.red, opacity))
        canvas.drawCircle(x, y, FIELD_RADIUS, stroke(HouseRocketsPalette.cream, 1.1f, opacity))
        val symbol = android.graphics.Path()
        if (boost) {
            for (offset in listOf(-3.4f, 1.4f)) {
                symbol.moveTo(x + offset - 1.6f, y - 3.6f)
                symbol.lineTo(x + offset + 1.6f, y)
                symbol.lineTo(x + offset - 1.6f, y + 3.6f)
            }
        } else {
            for (offset in listOf(-2.4f, 2.4f)) {
                symbol.moveTo(x + offset, y - 4f)
                symbol.lineTo(x + offset, y + 4f)
            }
        }
        canvas.drawPath(symbol, stroke(if (boost) HouseRocketsPalette.navy else HouseRocketsPalette.cream, 1.6f, opacity))
    }

    /** The touch zones along both edges, where steering starts. */
    private fun edgeZones(opacity: Float) {
        if (opacity <= .01f) return
        val width = WIDTH * .3f
        val paint = fill(HouseRocketsPalette.cream, .07f * opacity)
        canvas.drawRect(0f, TRACK_TOP, width, TRACK_BOTTOM, paint)
        canvas.drawRect(WIDTH - width, TRACK_TOP, WIDTH, TRACK_BOTTOM, paint)
    }

    /** The floating joystick: it appears where the touch starts and its knob leans the way the finger drags. */
    private fun joystick(x: Float, y: Float, angle: Float, reach: Float, opacity: Float) {
        if (opacity <= .01f) return
        val alpha = .75f * opacity
        canvas.drawCircle(x, y, 13f, fill(HouseRocketsPalette.blue, .35f * alpha))
        canvas.drawCircle(x, y, 13f, stroke(HouseRocketsPalette.cream, .9f, alpha))
        val radians = Math.toRadians(angle.toDouble())
        val knobX = x + (cos(radians) * 8 * reach).toFloat()
        val knobY = y + (sin(radians) * 8 * reach).toFloat()
        canvas.drawCircle(knobX, knobY, 5.4f, fill(HouseRocketsPalette.cream, alpha))
        val tipX = knobX + (cos(radians) * 2.6).toFloat()
        val tipY = knobY + (sin(radians) * 2.6).toFloat()
        val arrow = android.graphics.Path()
        for (side in listOf(140.0, -140.0)) {
            val wing = radians + Math.toRadians(side)
            arrow.moveTo(tipX + (cos(wing) * 2.4).toFloat(), tipY + (sin(wing) * 2.4).toFloat())
            arrow.lineTo(tipX, tipY)
        }
        canvas.drawPath(arrow, stroke(HouseRocketsPalette.navy, 1f, alpha))
    }

    /** A ring spreading from a point: a touch landing, a field taken, a rocket out. */
    private fun ring(
        phase: Double, time: Double, x: Float, y: Float, color: Color,
        from: Float = 4f, reach: Float = 10f, duration: Double = .14,
    ) {
        val spread = progress(phase, time, time + duration)
        if (phase < time || spread >= 1f) return
        canvas.drawCircle(x, y, from + reach * spread, stroke(color, 1.3f, 1 - spread))
    }

    // Clips

    /** A finger on the left edge drags up, then down; the rocket turns to follow it. */
    private fun drawSteer(phase: Double) {
        val touchX = 24f
        val touchY = 62f
        val heading: (Double) -> Float = { t ->
            when {
                t < .18 -> 0f
                t < .4 -> -40 * smooth(progress(t, .18, .4))
                t < .48 -> -40f
                t < .7 -> -40 + 75 * smooth(progress(t, .48, .7))
                t < .78 -> 35 - 35 * smooth(progress(t, .7, .78))
                else -> 0f
            }
        }
        val fade = loopFade(phase)
        background(140 * phase.toFloat())
        edgeZones(fade)
        val (_, dy) = drift(phase, 70f, heading)
        rocket(92f, 45 + dy, heading(phase), PLAYER, flicker(phase), isPlayer = true, opacity = fade)
        if (phase >= .18 && phase < .8) {
            joystick(touchX, touchY, heading(phase), max(.25f, progress(phase, .18, .24)), fade)
        }
        ring(phase, .18, touchX, touchY, HouseRocketsPalette.cream, from = 3f, reach = 9f)
    }

    /** A short drag from the right edge sets a heading; after the release the rocket keeps it. */
    private fun drawThrust(phase: Double) {
        val touchX = 136f
        val touchY = 64f
        val aim = -28f
        val heading: (Double) -> Float = { t -> if (t < .12) 0f else aim * smooth(progress(t, .12, .3)) }
        val fade = loopFade(phase, out = .88)
        background(40 * phase.toFloat())
        val (dx, dy) = drift(phase, 125f, heading)
        val x = 22 + dx
        val y = 60 + dy
        if (phase >= .34) {
            val radians = Math.toRadians(aim.toDouble())
            val dot = fill(HouseRocketsPalette.cream, .45f * fade * progress(phase, .34, .42))
            var distance = 14f
            while (distance < 120f) {
                canvas.drawCircle(x + (cos(radians) * distance).toFloat(), y + (sin(radians) * distance).toFloat(), .7f, dot)
                distance += 5f
            }
        }
        for (puff in 1..5) {
            val time = phase - puff * .05
            if (time <= 0) continue
            val (backX, backY) = drift(time, 125f, heading)
            canvas.drawCircle(22 + backX - 5, 60 + backY, 1.2f + puff * .4f,
                fill(HouseRocketsPalette.cream, fade * .35f * (1 - puff / 6f)))
        }
        rocket(x, y, heading(phase), PLAYER, flicker(phase), isPlayer = true, opacity = fade)
        if (phase >= .12 && phase < .34) {
            joystick(touchX, touchY, heading(phase), max(.25f, progress(phase, .12, .18)), fade)
        }
        ring(phase, .12, touchX, touchY, HouseRocketsPalette.cream, from = 3f, reach = 9f)
    }

    /** The rocket crosses a blue field (the course rushes by) and then a red one (it slows). */
    private fun drawFields(phase: Double) {
        val rocketX = 46f
        val y = 45f
        val boostStart = .25
        val boostEnd = .5
        val slowStart = .62
        val slowEnd = .85
        val speed = 150f
        fun overlap(time: Double, start: Double, end: Double) = max(0.0, min(time, end) - start).toFloat()
        fun travelled(time: Double) =
            speed * (time.toFloat() + .45f * overlap(time, boostStart, boostEnd) - .35f * overlap(time, slowStart, slowEnd))
        val distance = travelled(phase)
        val fade = loopFade(phase)
        background(distance)
        val effect = when {
            phase >= boostStart && phase < boostEnd -> RocketsEffect.BOOST
            phase >= slowStart && phase < slowEnd -> RocketsEffect.SLOW
            else -> null
        }
        field(RocketsEffect.BOOST, rocketX + travelled(boostStart) - distance, y, fade)
        field(RocketsEffect.SLOW, rocketX + travelled(slowStart) - distance, y, fade)
        if (effect == RocketsEffect.BOOST) {
            val line = stroke(HouseRocketsPalette.blue, 1f, fade)
            listOf(-7f, 0f, 7f).forEachIndexed { index, offset ->
                val shift = (distance * 1.3f + index * 17) % 40f
                canvas.drawLine(rocketX - 12 - shift, y + offset, rocketX - 22 - shift, y + offset, line)
            }
        }
        val flame = when (effect) { RocketsEffect.BOOST -> 1.7f; RocketsEffect.SLOW -> .65f; null -> 1f } * flicker(phase)
        rocket(rocketX, y, 0f, PLAYER, flame, isPlayer = true, effect = effect, opacity = fade)
        ring(phase, boostStart, rocketX, y, HouseRocketsPalette.blue, from = 10f, reach = 8f)
        ring(phase, slowStart, rocketX, y, HouseRocketsPalette.red, from = 10f, reach = 8f)
    }

    /** A block holds the rival back while the player flies over it; pushed off the rear edge, it is out. */
    private fun drawSurvive(phase: Double) {
        val speed = 160f
        val blockX = 150 - speed * phase.toFloat()
        val blockTop = 50f
        val blockWidth = 14f
        val rivalY = 62f
        val rivalFree = 84f
        val rivalX = min(rivalFree, blockX - blockWidth / 2 - 9)
        val out = .81
        val fade = loopFade(phase)
        background(speed * phase.toFloat())
        val edge = stroke(HouseRocketsPalette.red, 1.2f, .85f * fade, round = false).apply {
            pathEffect = DashPathEffect(floatArrayOf(3f, 2.5f), 0f)
        }
        canvas.drawLine(3f, TRACK_TOP, 3f, TRACK_BOTTOM, edge)
        val left = blockX - blockWidth / 2
        canvas.drawRoundRect(left, blockTop, left + blockWidth, TRACK_BOTTOM, 1.5f, 1.5f, fill(HouseRocketsPalette.burgundy, fade))
        canvas.drawRoundRect(left, blockTop, left + blockWidth, TRACK_BOTTOM, 1.5f, 1.5f,
            stroke(HouseRocketsPalette.cream, .9f, fade))
        if (phase < out) rocket(rivalX, rivalY, 0f, RIVAL, flicker(phase), opacity = fade)
        if (phase >= .3 && rivalX < rivalFree) {
            canvas.drawCircle(rivalX + 9, rivalY, 1.6f, fill(HouseRocketsPalette.cream, .7f * fade))
        }
        ring(phase, out, 6f, rivalY, HouseRocketsPalette.red, from = 3f, reach = 12f, duration = .18)
        ring(phase, out + .02, 6f, rivalY, HouseRocketsPalette.cream, from = 2f, reach = 7f)
        rocket(96f, 34 + 1.5f * sin(phase * 2 * Math.PI * 2).toFloat(), 0f, PLAYER, flicker(phase), isPlayer = true,
            opacity = fade)
        ring(phase, out + .04, 96f, 34f, HouseRocketsPalette.cream, from = 11f, reach = 9f, duration = .2)
    }

    private companion object {
        const val WIDTH = 160f
        const val HEIGHT = 90f
        const val ROCKET_SCALE = .42f
        const val FIELD_RADIUS = 9f
        const val TRACK_TOP = 8f
        const val TRACK_BOTTOM = 82f
        val PLAYER = RocketsColor.MINT
        val RIVAL = RocketsColor.CORAL
    }
}
