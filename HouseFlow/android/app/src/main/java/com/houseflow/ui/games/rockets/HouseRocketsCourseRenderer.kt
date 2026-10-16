package com.houseflow.ui.games.rockets

import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.ui.graphics.Color
import com.houseflow.platform.RocketsColor
import com.houseflow.platform.RocketsEffect
import com.houseflow.platform.RocketsFrame
import com.houseflow.platform.RocketsGate
import com.houseflow.platform.RocketsPhase
import com.houseflow.platform.RocketsPlayer
import com.houseflow.platform.RocketsRole
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.sin

/**
 * Draws a frame exactly like `HouseRocketsScene` (SpriteKit). The caller passes a canvas
 * already in dp with SpriteKit's y-up origin, so every node transform maps one to one:
 * position, then rotation, then scale. It never advances physics or decides outcomes.
 */
internal class HouseRocketsCourseRenderer {
    private var topographySize = 0f to 0f
    private var topography: List<Path> = emptyList()
    private val gateTextures = HashMap<String, List<Path>>()
    private val gatePaths = HashMap<String, List<Path>>()

    private val gateFill = fillPaint(HouseRocketsPalette.burgundy)
    private val gateStroke = strokePaint(HouseRocketsPalette.cream, 2f)
    private val iceLine = strokePaint(HouseRocketsPalette.ice.copy(alpha = .17f), 1f)
    private val creamLine = strokePaint(HouseRocketsPalette.cream.copy(alpha = .10f), 1f)
    private val track = fillPaint(HouseRocketsPalette.navy)
    private val rail = fillPaint(HouseRocketsPalette.blue.copy(alpha = .65f))
    private val dash = fillPaint(HouseRocketsPalette.cream.copy(alpha = .12f))
    private val partStroke = strokePaint(HouseRocketsPalette.cream, 1.8f)
    private val flameStroke = strokePaint(HouseRocketsPalette.red, 1.8f)
    private val windowNavyStroke = strokePaint(HouseRocketsPalette.navy, 1.8f)
    private val humanRing = strokePaint(HouseRocketsPalette.cream.copy(alpha = .65f), 1.5f)
    private val boostRing = strokePaint(HouseRocketsPalette.blue, 3f)
    private val slowRing = strokePaint(HouseRocketsPalette.cream, 3f)
    private val fieldStroke = strokePaint(HouseRocketsPalette.cream, 2.5f * FIELD_ARTWORK_SCALE)
    private val boostFill = fillPaint(HouseRocketsPalette.blue)
    private val slowFill = fillPaint(HouseRocketsPalette.red)
    private val boostSymbol = strokePaint(HouseRocketsPalette.navy, 4f)
    private val slowSymbol = strokePaint(HouseRocketsPalette.cream, 4f)
    private val playerFills = HashMap<Color, Paint>()
    private val flameFill = fillPaint(HouseRocketsPalette.cream)
    private val boostPath = Path().apply {
        for (x in floatArrayOf(-9f, 3f)) { moveTo(x - 4, -9f); lineTo(x + 4, 0f); lineTo(x - 4, 9f) }
    }
    private val slowPath = Path().apply {
        for (x in floatArrayOf(-6f, 6f)) { moveTo(x, -10f); lineTo(x, 10f) }
    }

    /** `canvas` is in dp and y-up; `width`/`height` are the scene size in dp. */
    fun draw(canvas: Canvas, frame: RocketsFrame, width: Float, height: Float, reduceMotion: Boolean) {
        canvas.drawColor(android.graphics.Color.rgb(28, 69, 94))
        drawTopography(canvas, width, height)
        val projection = frame.projection ?: return
        val angleDegrees = Math.toDegrees(projection.angle).toFloat()
        val scale = projection.scale.toFloat()

        // Environment: the track follows the rear camera edge.
        val c = cos(projection.angle)
        val s = sin(projection.angle)
        val rearX = (projection.originX + frame.cameraX * c * projection.scale).toFloat()
        val rearY = (projection.originY + frame.cameraX * s * projection.scale).toFloat()
        val length = projection.visibleLength.toFloat()
        canvas.save()
        canvas.translate(rearX, rearY)
        canvas.rotate(angleDegrees)
        canvas.scale(scale, scale)
        canvas.drawRect(0f, 0f, length, TRACK_HEIGHT, track)
        for (y in floatArrayOf(0f, TRACK_HEIGHT)) canvas.drawRect(0f, y - 3, length, y + 3, rail)
        // World-anchored markings make leader-driven camera motion visible.
        val firstDash = floor(frame.cameraX / 68)
        for (index in 0 until 20) {
            val x = ((firstDash + index) * 68 - frame.cameraX).toFloat()
            if (x < 0 || x + 28 > length) continue
            canvas.drawRoundRect(x, TRACK_HEIGHT / 2 - 1, x + 28, TRACK_HEIGHT / 2 + 1, 1f, 1f, dash)
        }
        canvas.restore()

        // World: cropped to the visible course so future segments never float in the margins.
        canvas.save()
        canvas.translate(projection.originX.toFloat(), projection.originY.toFloat())
        canvas.rotate(angleDegrees)
        canvas.scale(scale, scale)
        val cameraX = frame.cameraX.toFloat()
        canvas.clipRect(cameraX, 0f, cameraX + length, TRACK_HEIGHT)
        val activeGates = frame.gates.map { it.id }.toSet()
        gatePaths.keys.retainAll(activeGates)
        gateTextures.keys.retainAll(activeGates)
        frame.gates.forEach { drawGate(canvas, it) }
        frame.fields.forEach { field ->
            canvas.save()
            canvas.translate(field.x.toFloat(), field.y.toFloat())
            canvas.drawCircle(0f, 0f, FIELD_RADIUS, if (field.effect == RocketsEffect.BOOST) boostFill else slowFill)
            canvas.drawCircle(0f, 0f, FIELD_RADIUS, fieldStroke)
            // Center the actual path bounds, including the asymmetric double chevron.
            val boost = field.effect == RocketsEffect.BOOST
            val symbol = if (boost) boostPath else slowPath
            val bounds = RectF().also { symbol.computeBounds(it, true) }
            canvas.translate(-bounds.centerX() * FIELD_ARTWORK_SCALE, -bounds.centerY() * FIELD_ARTWORK_SCALE)
            canvas.scale(FIELD_ARTWORK_SCALE, FIELD_ARTWORK_SCALE)
            canvas.drawPath(symbol, if (boost) boostSymbol else slowSymbol)
            canvas.restore()
        }
        // Bots sit below the human rocket (zPosition 4 vs 5).
        frame.players.filter { it.role != RocketsRole.HUMAN }.forEach { drawRocket(canvas, it, frame.phase, reduceMotion) }
        frame.players.filter { it.role == RocketsRole.HUMAN }.forEach { drawRocket(canvas, it, frame.phase, reduceMotion) }
        canvas.restore()
    }

    private fun drawTopography(canvas: Canvas, width: Float, height: Float) {
        if (topographySize != width to height) {
            topographySize = width to height
            topography = HouseRocketsArtwork.topography(width, height)
        }
        topography.forEachIndexed { index, path ->
            val color = HouseRocketsArtwork.outerContourColor(index)
            if (index % 3 == 0) canvas.drawPath(path, strokePaint(color.copy(alpha = .06f), 12f))
            canvas.drawPath(path, strokePaint(color.copy(alpha = HouseRocketsArtwork.outerContourOpacity(index)),
                if (index % 4 == 0) 1.2f else .75f))
        }
    }

    private fun drawGate(canvas: Canvas, gate: RocketsGate) {
        val polygons = gatePaths.getOrPut(gate.id) {
            gate.polygons.map { points ->
                Path().apply {
                    moveTo(points[0].toFloat(), points[1].toFloat())
                    var index = 2
                    while (index < points.size) {
                        lineTo(points[index].toFloat(), points[index + 1].toFloat())
                        index += 2
                    }
                    close()
                }
            }
        }
        val texture = gateTextures.getOrPut(gate.id) {
            val textureWidth = max(gate.width, 220.0).toFloat()
            val shift = Matrix().apply { setTranslate(-textureWidth / 2, 0f) }
            HouseRocketsArtwork.topography(textureWidth, TRACK_HEIGHT).map { Path(it).apply { transform(shift) } }
        }
        canvas.save()
        canvas.translate(gate.x.toFloat(), 0f)
        polygons.forEach { polygon ->
            canvas.drawPath(polygon, gateFill)
            canvas.drawPath(polygon, gateStroke)
            canvas.save()
            canvas.clipPath(polygon)
            texture.forEachIndexed { index, line -> canvas.drawPath(line, if (index % 4 == 0) iceLine else creamLine) }
            canvas.restore()
        }
        canvas.restore()
    }

    private fun drawRocket(canvas: Canvas, player: RocketsPlayer, phase: RocketsPhase, reduceMotion: Boolean) {
        canvas.save()
        canvas.translate(player.x.toFloat(), player.y.toFloat())
        canvas.rotate(Math.toDegrees(player.courseHeading).toFloat())
        canvas.scale(.5f, .5f)
        // SpriteKit multiplies node alpha into each child; it does not composite a group.
        val fade = if (player.isAlive) 1f else .25f
        fun Paint.faded(): Paint = if (fade == 1f) this else Paint(this).also { it.alpha = (it.alpha * fade).toInt() }
        if (phase == RocketsPhase.PLAYING && player.isAlive && !reduceMotion) {
            canvas.save()
            canvas.scale(when (player.effect) { RocketsEffect.BOOST -> 1.7f; RocketsEffect.SLOW -> .65f; null -> 1f }, 1f)
            canvas.drawPath(HouseRocketsArtwork.flame, flameFill)
            canvas.drawPath(HouseRocketsArtwork.flame, flameStroke)
            canvas.restore()
        }
        val tint = playerFills.getOrPut(HouseRocketsPalette.player(player.color)) {
            fillPaint(HouseRocketsPalette.player(player.color))
        }.faded()
        val stroke = partStroke.faded()
        listOf(HouseRocketsArtwork.fins to tint, HouseRocketsArtwork.hull to tint,
            HouseRocketsArtwork.collar to gateFill.faded(), HouseRocketsArtwork.nose to slowFill.faded()).forEach { (path, fill) ->
            canvas.drawPath(path, fill)
            canvas.drawPath(path, stroke)
        }
        canvas.drawPath(HouseRocketsArtwork.window, track.faded())
        canvas.drawPath(HouseRocketsArtwork.window, if (player.color == RocketsColor.MINT) windowNavyStroke.faded() else stroke)
        if (player.role == RocketsRole.HUMAN) canvas.drawCircle(0f, 0f, 25f, humanRing.faded())
        player.effect?.let { canvas.drawCircle(0f, 0f, 29f, (if (it == RocketsEffect.BOOST) boostRing else slowRing).faded()) }
        canvas.restore()
    }

    private companion object {
        const val TRACK_HEIGHT = 360f
        const val FIELD_ARTWORK_SCALE = .7f
        const val FIELD_RADIUS = 22f * FIELD_ARTWORK_SCALE
    }
}
