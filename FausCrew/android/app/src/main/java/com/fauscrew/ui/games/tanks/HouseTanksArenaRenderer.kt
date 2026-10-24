package com.fauscrew.ui.games.tanks

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import com.fauscrew.platform.TanksArena
import com.fauscrew.platform.TanksEvent
import com.fauscrew.platform.TanksFrame
import com.fauscrew.platform.TanksJoker
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksObstacle
import com.fauscrew.platform.TanksObstacleStyle
import com.fauscrew.platform.TanksRole
import com.fauscrew.platform.TanksTone
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * The SpriteKit scene's drawing on a Compose canvas. Engine positions are dp in SpriteKit's
 * y-up space; [point] flips y once and rotations are negated to match. Transient effects
 * (muzzle flashes, explosions, crate fragments, hull flashes) are timed by wall clock.
 */
internal class HouseTanksArenaRenderer {
    private sealed interface Effect {
        val start: Long
        val duration: Long
    }
    private data class Muzzle(val playerId: String, override val start: Long) : Effect { override val duration = 120_000_000L }
    private data class Burst(val x: Double, val y: Double, override val start: Long) : Effect { override val duration = 340_000_000L }
    private data class Splinters(val x: Double, val y: Double, override val start: Long) : Effect { override val duration = 320_000_000L }
    private data class HullFlash(val playerId: String, override val start: Long) : Effect { override val duration = 170_000_000L }

    private val effects = mutableListOf<Effect>()
    private var lastEventFrame: TanksFrame? = null

    /** Hull flash for armor lost (from the view model) or a shell stopped by a shield. */
    fun flash(playerId: String) {
        effects += HullFlash(playerId, System.nanoTime())
    }

    fun draw(scope: DrawScope, frame: TanksFrame, reduceMotion: Boolean, painters: JokerPainters) = with(scope) {
        val now = System.nanoTime()
        if (lastEventFrame !== frame) {
            lastEventFrame = frame
            frame.events.forEach { event ->
                when (event) {
                    is TanksEvent.Fired -> if (!reduceMotion) effects += Muzzle(event.playerId, now)
                    is TanksEvent.Shielded -> effects += HullFlash(event.playerId, now)
                    is TanksEvent.CrateBroken -> effects += Splinters(event.x, event.y, now)
                    is TanksEvent.Explosion -> effects += Burst(event.x, event.y, now)
                    is TanksEvent.Eliminated -> effects += Burst(event.x, event.y, now)
                }
            }
        }
        effects.removeAll { now - it.start > it.duration }

        val density = density
        scale(density, density, Offset.Zero) {
            val height = frame.height.toFloat()
            fun point(x: Double, y: Double) = Offset(x.toFloat(), height - y.toFloat())

            val arena = frame.arena
            // Crowded-match maps draw every actor smaller, matching the engine's scale.
            val actor = (arena?.scale ?: 1.0).toFloat()
            drawRect(floorTint(arena?.map), size = Size(frame.width.toFloat(), height))
            if (arena != null) {
                drawFloorPlan(arena, height, ::point)
                drawBoundary(arena, height)
                arena.obstacles.filter { !it.isMovable }.forEach { drawObstacle(it, point(it.x, it.y)) }
                frame.crates.filter { !it.isDestroyed }.forEach { crate ->
                    arena.obstacles.firstOrNull { it.index == crate.index }?.let { drawObstacle(it, point(crate.x, crate.y)) }
                }
            }

            frame.token?.let { token ->
                val center = point(token.x, token.y)
                withTransform({ translate(center.x, center.y); scale(actor, actor, Offset.Zero) }) {
                    drawCircle(token.kind.tint, 14f, Offset.Zero)
                    drawCircle(HouseTanksPalette.paper, 14f, Offset.Zero, style = Stroke(1.5f))
                    drawJokerGlyph(token.kind, 16f, Color.White, painters)
                    drawTimerArc(Offset.Zero, 17f, token.fraction)
                }
            }

            frame.projectiles.forEach { shot ->
                val center = point(shot.x, shot.y)
                withTransform({
                    translate(center.x, center.y)
                    rotate(-Math.toDegrees(shot.rotation).toFloat(), Offset.Zero)
                    scale(actor, actor, Offset.Zero)
                }) {
                    if (shot.isRocket) drawRocket(now, reduceMotion) else {
                        drawRoundRect(shot.color.ink, Offset(-4.5f, -1.75f), Size(9f, 3.5f), CornerRadius(1.75f))
                        drawRoundRect(HouseTanksPalette.ink, Offset(-4.5f, -1.75f), Size(9f, 3.5f), CornerRadius(1.75f), style = Stroke(1f))
                    }
                }
            }

            frame.tanks.forEach { tank ->
                val center = point(tank.x, tank.y)
                val flash = effects.filterIsInstance<HullFlash>().lastOrNull { it.playerId == tank.id }
                val hullAlpha = flash?.let { hullFlashAlpha(now - it.start) } ?: 1f
                withTransform({ translate(center.x, center.y); rotate(-Math.toDegrees(tank.rotation).toFloat(), Offset.Zero) }) {
                    tank.aimLength?.let { length -> drawAimLine(length.toFloat(), 16f * actor) }
                    scale(.38f * actor, .38f * actor, Offset.Zero) {
                        drawTankArtwork(tank.color.ink, tank.role == TanksRole.HUMAN, !tank.isActive, hullAlpha)
                    }
                    effects.filterIsInstance<Muzzle>().lastOrNull { it.playerId == tank.id }?.let { muzzle ->
                        val progress = ((now - muzzle.start) / 80_000_000f).coerceIn(0f, 1f)
                        val fade = 1f - ((now - muzzle.start) / 100_000_000f).coerceIn(0f, 1f)
                        val radius = 3f * (1f + .8f * progress) * actor
                        drawCircle(tank.color.ink.copy(alpha = fade), radius, Offset(13f * actor, 0f))
                        drawCircle(HouseTanksPalette.paper.copy(alpha = fade), radius, Offset(13f * actor, 0f), style = Stroke(1f))
                    }
                }
                if (tank.isActive) tank.power?.let { power ->
                    withTransform({ translate(center.x, center.y); scale(actor, actor, Offset.Zero) }) {
                        drawPowerIndicator(Offset.Zero, power, tank.powerFraction, painters)
                    }
                }
            }

            effects.forEach { effect ->
                val elapsed = (now - effect.start) / 1_000_000_000f
                when (effect) {
                    is Burst -> drawBurst(point(effect.x, effect.y), elapsed, reduceMotion)
                    is Splinters -> drawSplinters(point(effect.x, effect.y), elapsed, reduceMotion)
                    else -> Unit
                }
            }
        }
    }

    private fun hullFlashAlpha(elapsed: Long): Float {
        val seconds = elapsed / 1_000_000_000f
        return if (seconds < .05f) 1f - .72f * (seconds / .05f) else .28f + .72f * ((seconds - .05f) / .12f).coerceIn(0f, 1f)
    }

    // MARK: - Arena

    private fun floorTint(map: TanksMap?): Color = when (map) {
        TanksMap.LIVING_ROOM, null -> HouseTanksPalette.khaki.copy(alpha = .14f)
        TanksMap.CORRIDORS -> HouseTanksPalette.steel.copy(alpha = .07f)
        TanksMap.WAREHOUSE -> HouseTanksPalette.rust.copy(alpha = .08f)
        TanksMap.COURTYARD -> HouseTanksPalette.olive.copy(alpha = .12f)
        // A cool concrete wash for the crowded Basement.
        TanksMap.BASEMENT -> HouseTanksPalette.slate.copy(alpha = .10f)
    }

    private fun floorAccent(map: TanksMap): Color = when (map) {
        TanksMap.LIVING_ROOM -> HouseTanksPalette.umber
        TanksMap.CORRIDORS -> HouseTanksPalette.steel
        TanksMap.WAREHOUSE -> HouseTanksPalette.rust
        TanksMap.COURTYARD -> HouseTanksPalette.olive
        TanksMap.BASEMENT -> HouseTanksPalette.slate
    }

    private fun DrawScope.drawFloorPlan(arena: TanksArena, height: Float, point: (Double, Double) -> Offset) {
        val accent = floorAccent(arena.map)
        val lineWidth = max(2f, height * .004f)
        val lines = Path()
        arena.lines.forEach { line ->
            val start = point(line[0], line[1]); val end = point(line[2], line[3])
            lines.moveTo(start.x, start.y); lines.lineTo(end.x, end.y)
        }
        drawPath(lines, accent.copy(alpha = .38f), style = Stroke(lineWidth, cap = StrokeCap.Round,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(lineWidth * 3, lineWidth * 2.5f))))
        val radius = max(5f, height * .011f)
        arena.markers.forEach { marker ->
            val center = point(marker[0], marker[1])
            val color = accent.copy(alpha = .42f)
            drawLine(color, center - Offset(radius * 1.7f, 0f), center + Offset(radius * 1.7f, 0f), 1f)
            drawLine(color, center - Offset(0f, radius * 1.7f), center + Offset(0f, radius * 1.7f), 1f)
            drawCircle(color, radius, center, style = Stroke(1f))
        }
    }

    /** A double neatline with corner brackets frames the arena like a map sheet. */
    private fun DrawScope.drawBoundary(arena: TanksArena, height: Float) {
        val left = arena.frameX.toFloat()
        val top = height - (arena.frameY + arena.frameHeight).toFloat()
        val width = arena.frameWidth.toFloat()
        val frameHeight = arena.frameHeight.toFloat()
        drawRoundRect(HouseTanksPalette.ink.copy(alpha = .62f), Offset(left, top), Size(width, frameHeight), CornerRadius(4f),
            style = Stroke(max(2.5f, height * .006f)))
        val innerLeft = left + 6; val innerTop = top + 6; val innerRight = left + width - 6; val innerBottom = top + frameHeight - 6
        drawRoundRect(HouseTanksPalette.slate.copy(alpha = .4f), Offset(innerLeft, innerTop),
            Size(innerRight - innerLeft, innerBottom - innerTop), CornerRadius(2f), style = Stroke(.8f))
        val length = max(14f, height * .04f)
        val brackets = Path()
        for ((corner, d) in listOf(Offset(innerLeft, innerTop) to Offset(1f, 1f), Offset(innerRight, innerTop) to Offset(-1f, 1f),
            Offset(innerLeft, innerBottom) to Offset(1f, -1f), Offset(innerRight, innerBottom) to Offset(-1f, -1f))) {
            brackets.moveTo(corner.x + length * d.x, corner.y + 4 * d.y)
            brackets.lineTo(corner.x + 4 * d.x, corner.y + 4 * d.y)
            brackets.lineTo(corner.x + 4 * d.x, corner.y + length * d.y)
        }
        drawPath(brackets, HouseTanksPalette.steel.copy(alpha = .55f), style = Stroke(1.5f))
    }

    private fun obstacleColor(tone: TanksTone): Color = when (tone) {
        TanksTone.NAVY -> Color(74, 85, 93)
        TanksTone.TEAL -> Color(88, 128, 124)
        TanksTone.ORANGE -> Color(176, 112, 74)
        TanksTone.BLUE -> Color(79, 111, 140)
        TanksTone.WOOD -> HouseTanksPalette.khaki
        TanksTone.GREEN -> HouseTanksPalette.olive
    }

    /** Furniture and crates; local +y in SpriteKit is local -y here, so decoration offsets flip. */
    private fun DrawScope.drawObstacle(obstacle: TanksObstacle, center: Offset) {
        val w = obstacle.width.toFloat()
        val h = obstacle.height.toFloat()
        val fill = obstacleColor(if (obstacle.isMovable) TanksTone.WOOD else obstacle.tone)
        val white = Color.White
        withTransform({ translate(center.x, center.y); rotate(-Math.toDegrees(obstacle.rotation).toFloat(), Offset.Zero) }) {
            if (obstacle.style.isRound) {
                val radius = min(w, h) / 2
                drawCircle(fill, radius, Offset.Zero)
                drawCircle(HouseTanksPalette.ink.copy(alpha = .55f), radius, Offset.Zero, style = Stroke(1.4f))
            } else {
                val corner = CornerRadius(min(14f, h * .28f))
                drawRoundRect(fill, Offset(-w / 2, -h / 2), Size(w, h), corner)
                drawRoundRect(HouseTanksPalette.ink.copy(alpha = .55f), Offset(-w / 2, -h / 2), Size(w, h), corner, style = Stroke(1.4f))
            }
            when (obstacle.style) {
                TanksObstacleStyle.DIVIDER -> for (yOffset in floatArrayOf(-.26f, 0f, .26f)) {
                    val slat = Size(max(5f, w * .58f), max(3f, h * .055f))
                    drawRoundRect(white.copy(alpha = .20f), Offset(-slat.width / 2, -h * yOffset - slat.height / 2), slat, CornerRadius(2f))
                }
                TanksObstacleStyle.SOFA -> {
                    val back = Size(w * .78f, max(5f, h * .18f))
                    drawRoundRect(white.copy(alpha = .20f), Offset(-back.width / 2, -h * .20f - back.height / 2), back, CornerRadius(3f))
                    for (xOffset in floatArrayOf(-.24f, .24f)) {
                        val seam = Size(max(2f, w * .018f), h * .46f)
                        drawRoundRect(white.copy(alpha = .22f), Offset(w * xOffset - seam.width / 2, -seam.height / 2), seam, CornerRadius(1f))
                    }
                }
                TanksObstacleStyle.ROUND_TABLE -> {
                    val radius = min(w, h) * .27f
                    drawCircle(white.copy(alpha = .14f), radius, Offset.Zero)
                    drawCircle(white.copy(alpha = .22f), radius, Offset.Zero, style = Stroke(1.5f))
                }
                TanksObstacleStyle.CRATE -> {
                    drawLine(white.copy(alpha = .24f), Offset(-w * .27f, h * .27f), Offset(w * .27f, -h * .27f), 2f, StrokeCap.Round)
                    drawLine(white.copy(alpha = .24f), Offset(-w * .27f, -h * .27f), Offset(w * .27f, h * .27f), 2f, StrokeCap.Round)
                }
                TanksObstacleStyle.BOOKSHELF -> for (xOffset in floatArrayOf(-.28f, -.09f, .10f, .29f)) {
                    val book = Size(max(2f, w * .08f), max(4f, h * .58f))
                    drawRoundRect(white.copy(alpha = .18f + abs(xOffset) * .16f), Offset(w * xOffset - book.width / 2, -book.height / 2),
                        book, CornerRadius(1f))
                }
                TanksObstacleStyle.PILLAR -> {
                    val radius = min(w, h) * .28f
                    drawCircle(white.copy(alpha = .16f), radius, Offset.Zero)
                    drawCircle(white.copy(alpha = .28f), radius, Offset.Zero, style = Stroke(1f))
                }
                TanksObstacleStyle.PLANTER -> {
                    val leaf = Size(max(3f, w * .24f), max(5f, h * .42f))
                    for (step in 0 until 6) {
                        val angle = step * Math.PI.toFloat() / 3
                        val position = Offset(cos(angle) * w * .14f, -sin(angle) * h * .14f)
                        withTransform({ translate(position.x, position.y); rotate(-Math.toDegrees((angle - Math.PI / 2)).toFloat(), Offset.Zero) }) {
                            drawOval(white.copy(alpha = .15f), Offset(-leaf.width / 2, -leaf.height / 2), leaf)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actors

    private fun DrawScope.drawRocket(now: Long, reduceMotion: Boolean) {
        val length = 22f
        val radius = 4f
        val flicker = if (reduceMotion) 1f else if ((now / 60_000_000L) % 2L == 0L) 1f else .6f
        val flameSize = Size(length * .55f * flicker, 8f * .8f)
        val flameCenter = Offset(-length * .62f, 0f)
        drawOval(HouseTanksPalette.signalRed, flameCenter - Offset(flameSize.width / 2, flameSize.height / 2), flameSize)
        drawOval(HouseTanksPalette.khaki, flameCenter - Offset(flameSize.width / 2, flameSize.height / 2), flameSize, style = Stroke(1f))
        val fins = Path().apply {
            moveTo(-length * .5f, -radius); lineTo(-length * .62f, -radius * 2.1f); lineTo(-length * .18f, -radius); close()
            moveTo(-length * .5f, radius); lineTo(-length * .62f, radius * 2.1f); lineTo(-length * .18f, radius); close()
        }
        drawPath(fins, HouseTanksPalette.rust)
        drawPath(fins, HouseTanksPalette.ink, style = Stroke(1f))
        drawRoundRect(HouseTanksPalette.olive, Offset(-length / 2, -radius), Size(length, radius * 2), CornerRadius(radius))
        drawRoundRect(HouseTanksPalette.ink, Offset(-length / 2, -radius), Size(length, radius * 2), CornerRadius(radius), style = Stroke(1.4f))
        val nose = Path().apply { moveTo(length * .3f, -radius); lineTo(length * .62f, 0f); lineTo(length * .3f, radius); close() }
        drawPath(nose, HouseTanksPalette.signalRed)
        drawPath(nose, HouseTanksPalette.ink, style = Stroke(1.2f))
    }

    /** Aim joker: a dotted red sight line from the muzzle to the arena wall. */
    private fun DrawScope.drawAimLine(length: Float, start: Float) {
        if (length <= start) return
        drawLine(HouseTanksPalette.signalRed, Offset(start, 0f), Offset(length, 0f), 2.6f, StrokeCap.Round,
            PathEffect.dashPathEffect(floatArrayOf(.1f, 7f)))
    }

    private fun DrawScope.drawPowerIndicator(center: Offset, power: TanksJoker, fraction: Double, painters: JokerPainters) {
        val tint = power.tint
        drawCircle(tint.copy(alpha = if (power == TanksJoker.SHIELD) .22f else .08f), 20f, center)
        drawCircle(tint, 20f, center, style = Stroke(if (power == TanksJoker.SHIELD) 2.5f else 1f))
        val badge = center + Offset(0f, -29f)
        drawCircle(tint, 9f, badge)
        drawCircle(HouseTanksPalette.paper, 9f, badge, style = Stroke(1f))
        translate(badge.x, badge.y) { drawJokerGlyph(power, 11f, Color.White, painters) }
        drawTimerArc(center, 22f, fraction)
    }

    private fun DrawScope.drawTimerArc(center: Offset, radius: Float, fraction: Double) {
        val sweep = 360f * fraction.toFloat().coerceIn(0f, 1f)
        if (sweep <= 0f) return
        drawArc(HouseTanksPalette.ink, -90f, sweep, false, center - Offset(radius, radius), Size(radius * 2, radius * 2),
            style = Stroke(2f, cap = StrokeCap.Round))
    }

    private fun DrawScope.drawBurst(center: Offset, elapsed: Float, reduceMotion: Boolean) {
        val count = if (reduceMotion) 4 else 10
        val travel = (elapsed / if (reduceMotion) .12f else .30f).coerceIn(0f, 1f)
        val fade = 1f - (elapsed / .32f).coerceIn(0f, 1f)
        val distance = if (reduceMotion) 11f else 27f
        for (index in 0 until count) {
            val angle = index.toFloat() / count * Math.PI.toFloat() * 2
            val position = center + Offset(cos(angle) * distance * travel, -sin(angle) * distance * travel)
            drawCircle((if (index % 2 == 0) HouseTanksPalette.rust else HouseTanksPalette.khaki).copy(alpha = fade),
                if (reduceMotion) 1.5f else 2.5f, position, style = Fill)
        }
    }

    private fun DrawScope.drawSplinters(center: Offset, elapsed: Float, reduceMotion: Boolean) {
        val count = if (reduceMotion) 1 else 5
        val travel = if (reduceMotion) 0f else (elapsed / .25f).coerceIn(0f, 1f)
        val fade = 1f - (elapsed / .3f).coerceIn(0f, 1f)
        for (index in 0 until count) {
            val angle = index / 5f * Math.PI.toFloat() * 2
            val position = center + Offset(cos(angle) * 20f * travel, -sin(angle) * 20f * travel)
            drawRoundRect(HouseTanksPalette.khaki.copy(alpha = fade), position - Offset(4f, 1.5f), Size(8f, 3f), CornerRadius(1f))
        }
    }
}
