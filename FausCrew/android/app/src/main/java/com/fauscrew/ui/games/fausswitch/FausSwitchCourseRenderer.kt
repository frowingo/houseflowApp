package com.fauscrew.ui.games.fausswitch

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import androidx.compose.ui.graphics.Color
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchCourse
import com.fauscrew.platform.SwitchGravity
import com.fauscrew.platform.SwitchPhase
import com.fauscrew.platform.SwitchPlatform
import com.fauscrew.platform.SwitchRect
import com.fauscrew.platform.SwitchRunnerStatus
import com.fauscrew.platform.SwitchWorld
import kotlin.math.ceil
import kotlin.math.min
import kotlin.math.sin

/**
 * Draws a frame exactly like `FausSwitchScene` (SpriteKit). The course is static world
 * geometry built once: each straight section's pieces are moved into the world through
 * that section's pose, the bends are arcs. The caller passes a canvas in dp with SpriteKit's
 * y-up origin; Core's camera then maps world to screen with one translate and one scale.
 * It never simulates; robots are posed by Core.
 */
internal class FausSwitchCourseRenderer(
    private val course: SwitchCourse,
    private val colorHex: Map<SwitchColor, Int>,
    private val texture: Bitmap?,
) {
    private class Piece(val path: Path, val paint: Paint, val bounds: RectF)

    /** A gap's hazard stripes, cut to the hole like the scene's crop node. */
    private class Clipped(val clip: Path, val path: Path, val paint: Paint, val bounds: RectF)

    private class Portal(val index: Int, val swirl: Path, val core: Path, val ring: Path, val foot: Path, val bounds: RectF)

    private data class RailStyle(val fill: Color, val surface: Color)

    private data class BlockStyle(val fill: Color, val edge: Color, val panel: Color, val bolt: Color)

    /** Rail colors per straight section (a bend takes the colors of the section after it). */
    private val railStyles = listOf(
        RailStyle(FausSwitchPalette.teal, FausSwitchPalette.green),
        RailStyle(FausSwitchPalette.deepWine, FausSwitchPalette.lavender),
        RailStyle(FausSwitchPalette.wine, FausSwitchPalette.lime),
    )

    /** Obstacle colors, one per group (blocks less than 200 apart), in turn along the course. */
    private val blockStyles = listOf(
        BlockStyle(FausSwitchPalette.teal, FausSwitchPalette.green, FausSwitchPalette.green, FausSwitchPalette.lime),
        BlockStyle(FausSwitchPalette.wine, FausSwitchPalette.lavender, FausSwitchPalette.lavender, FausSwitchPalette.sand),
        BlockStyle(FausSwitchPalette.lavender, FausSwitchPalette.deepWine, FausSwitchPalette.deepWine, FausSwitchPalette.plum),
        BlockStyle(FausSwitchPalette.deepWine, FausSwitchPalette.sand, FausSwitchPalette.sand, FausSwitchPalette.lime),
    )

    private fun railStyle(section: Int) = railStyles[section % railStyles.size]

    private val paints = HashMap<Pair<Color, Float>, Paint>()
    private fun fill(color: Color) = paints.getOrPut(color to -1f) { fillPaint(color) }
    private fun stroke(color: Color, width: Float, round: Boolean = false) =
        paints.getOrPut(color to (width + if (round) 1000f else 0f)) { strokePaint(color, width, round) }

    private val sectionMatrices = course.sections.map { section ->
        Matrix().apply {
            setTranslate(-section.originX.toFloat(), -course.centerY.toFloat())
            postRotate(Math.toDegrees(section.angle).toFloat())
            postTranslate(section.poseX.toFloat(), section.poseY.toFloat())
        }
    }

    // Layers by the scene's zPosition.
    private val ground = ArrayList<Piece>()
    private val obstacles = ArrayList<Piece>()
    private val stripes = ArrayList<Clipped>()
    private val markings = ArrayList<Piece>()
    private val portals = ArrayList<Portal>()
    private val swirlFill = fillPaint(FausSwitchPalette.deepWine.copy(alpha = .55f))
    private val swirlStroke = strokePaint(FausSwitchPalette.lavender.copy(alpha = .8f), 1.2f)
    private val coreFill = fillPaint(FausSwitchPalette.lavender.copy(alpha = .5f))
    private val ringStroke = strokePaint(FausSwitchPalette.wine, 3f)
    private val footFill = fillPaint(FausSwitchPalette.wine)

    private val lostFill = fillPaint(FausSwitchPalette.plum.copy(alpha = .22f))
    private val lostStroke = strokePaint(FausSwitchPalette.berry.copy(alpha = .6f), 3f)
    private val lostPath = Path()
    private var lostZone: Any? = null

    private var platformSource: List<SwitchPlatform>? = null
    private val platformPieces = ArrayList<Piece>()

    private val robots = HashMap<String, RobotState>()
    private var matchId: String? = null

    private val visible = RectF()
    private val backdropPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val backdropShader = texture?.let { BitmapShader(it, Shader.TileMode.MIRROR, Shader.TileMode.MIRROR) }
    private val backdropMatrix = Matrix()

    private class RobotState(val art: SwitchRobotArt, var gravity: SwitchGravity) {
        var from = 1f
        var to = 1f
        var startTime = Double.NEGATIVE_INFINITY
    }

    init {
        backdropPaint.shader = backdropShader
        build()
    }

    // Course

    private fun build() {
        val top = course.worldHeight
        for (rail in course.rails) addRail(rail.section, rail.rect, rail.isFloor)
        course.turns.forEachIndexed { _, turn -> addTurn(turn.section, turn.centerX, turn.centerY, turn.startAngle, turn.isLeft, turn.radius, top) }
        for (block in course.blocks) {
            var style = blockStyles[block.group % blockStyles.size]
            if (style.fill == railStyle(block.section).fill) style = blockStyles[(block.group + 1) % blockStyles.size]
            addBlock(block.section, block.rect, style)
        }
        for (gap in course.gaps) addGap(gap.section, gap.minX, gap.maxX, gap.rail)
        for (pad in course.boosts) addPad(pad.section, pad.rect, boost = true)
        for (pad in course.slows) addPad(pad.section, pad.rect, boost = false)
        course.portals.forEachIndexed { index, portal ->
            addPortal(index, portal.section, portal.x, portal.rail)
            addPortalExit(portal.exitSection, portal.exitX, portal.exitGravity)
        }
        addFinish()
    }

    private fun world(section: Int, build: Path.() -> Unit): Path =
        Path().apply { build(); transform(sectionMatrices[section]) }

    private fun bounds(path: Path, pad: Float): RectF =
        RectF().also { path.computeBounds(it, true); it.inset(-pad, -pad) }

    private fun MutableList<Piece>.add(path: Path, paint: Paint) {
        add(Piece(path, paint, bounds(path, paint.strokeWidth + 1f)))
    }

    private fun rectF(rect: SwitchRect) = RectF(rect.minX.toFloat(), rect.minY.toFloat(), rect.maxX.toFloat(), rect.maxY.toFloat())

    private fun addRail(section: Int, rect: SwitchRect, isFloor: Boolean) {
        val style = railStyle(section)
        val frame = rectF(rect)
        ground.add(world(section) { addRect(frame, Path.Direction.CW) }, fill(style.fill))
        // The running surface: the edge that faces the play band.
        val surfaceY = if (isFloor) frame.bottom - 2.2f else frame.top
        ground.add(world(section) { addRect(frame.left, surfaceY, frame.right, surfaceY + 2.2f, Path.Direction.CW) }, fill(style.surface))
        // Speed ticks inside the rail.
        val tickMid = if (isFloor) frame.bottom - 10 else frame.top + 10
        val ticks = world(section) {
            var x = ceil(rect.minX / 56) * 56
            while (x < rect.maxX - 6) {
                moveTo(x.toFloat(), tickMid - 3)
                lineTo(x.toFloat() + 6, tickMid + 3)
                x += 56
            }
        }
        ground.add(ticks, stroke(style.surface.copy(alpha = .55f), 1.6f, round = true))
    }

    private fun addTurn(section: Int, centerX: Double, centerY: Double, startAngle: Double, isLeft: Boolean, radius: Double, top: Double) {
        val style = railStyle(section)
        val start = Math.toDegrees(startAngle).toFloat()
        val sweep = if (isLeft) 90f else -90f
        val sign = if (isLeft) -1.0 else 1.0
        // Radius of track height y: the ceiling side is inside on a left bend.
        fun radius(y: Double) = (radius + sign * (y - course.centerY)).toFloat()
        fun oval(r: Float) = RectF(centerX.toFloat() - r, centerY.toFloat() - r, centerX.toFloat() + r, centerY.toFloat() + r)
        fun band(a: Double, b: Double) = Path().apply {
            arcTo(oval(radius(a)), start, sweep, true)
            arcTo(oval(radius(b)), start + sweep, -sweep)
            close()
        }
        fun surface(y: Double) = Path().apply { arcTo(oval(radius(y)), start, sweep, true) }
        for (band in listOf(band(0.0, course.floorSurface), band(course.ceilingSurface, top))) {
            ground.add(band, fill(style.fill))
            ground.add(band, stroke(style.fill, .5f))
        }
        val line = Paint(stroke(style.surface, 2.2f)).apply { strokeCap = Paint.Cap.BUTT }
        ground.add(surface(course.floorSurface - 1.1), line)
        ground.add(surface(course.ceilingSurface + 1.1), line)
    }

    private fun addBlock(section: Int, rect: SwitchRect, style: BlockStyle) {
        val frame = rectF(rect)
        val radius = min(5f, min(frame.width() / 4, frame.height() / 4))
        val body = world(section) { addRoundRect(frame, radius, radius, Path.Direction.CW) }
        obstacles.add(body, fill(style.fill))
        obstacles.add(body, stroke(style.edge, 1.4f))
        // A recessed panel and two bolts read as a machined block.
        val inset = RectF(frame).apply { inset(5f, 5f) }
        if (inset.width() > 6 && inset.height() > 6) {
            val panel = world(section) { addRoundRect(inset, 2.5f, 2.5f, Path.Direction.CW) }
            obstacles.add(panel, fill(FausSwitchPalette.plum.copy(alpha = .18f)))
            obstacles.add(panel, stroke(style.panel.copy(alpha = .4f), .8f))
        }
        if (frame.width() > 14 && frame.height() > 14) {
            val bolts = world(section) {
                addCircle(frame.left + 4.5f, frame.bottom - 4.5f, 1.4f, Path.Direction.CW)
                addCircle(frame.right - 4.5f, frame.top + 4.5f, 1.4f, Path.Direction.CW)
            }
            obstacles.add(bolts, fill(style.bolt.copy(alpha = .75f)))
        }
    }

    private fun addGap(section: Int, minX: Double, maxX: Double, rail: SwitchGravity) {
        val isFloor = rail == SwitchGravity.DOWN
        val railMin = if (isFloor) 0.0 else course.ceilingSurface
        val frame = RectF(minX.toFloat(), railMin.toFloat(), maxX.toFloat(), (railMin + course.railThickness).toFloat())
        // Hazard stripes where the rail is missing.
        val clip = world(section) { addRect(frame, Path.Direction.CW) }
        val lines = world(section) {
            var x = frame.left - frame.height()
            while (x < frame.right) {
                moveTo(x, frame.top)
                lineTo(x + frame.height(), frame.bottom)
                x += 14
            }
        }
        val stripe = Paint(stroke(FausSwitchPalette.plum.copy(alpha = .45f), 4f)).apply { strokeCap = Paint.Cap.BUTT }
        stripes += Clipped(clip, lines, stripe, bounds(clip, 2f))
        // Chevrons on both lips point into the hole.
        val surfaceY = (if (isFloor) course.floorSurface else course.ceilingSurface).toFloat()
        val direction = if (isFloor) -1f else 1f
        val chevrons = world(section) {
            for (lip in floatArrayOf(minX.toFloat(), maxX.toFloat())) {
                moveTo(lip - 7, surfaceY - direction * 2)
                lineTo(lip, surfaceY + direction * 8)
                lineTo(lip + 7, surfaceY - direction * 2)
                close()
            }
        }
        obstacles.add(chevrons, fill(FausSwitchPalette.plum))
    }

    /** Boost: green with forward mint chevrons; slow: lavender with backward deep wine ones. */
    private fun addPad(section: Int, rect: SwitchRect, boost: Boolean) {
        val frame = rectF(rect)
        val body = world(section) { addRoundRect(frame, 4f, 4f, Path.Direction.CW) }
        markings.add(body, fill(if (boost) FausSwitchPalette.green else FausSwitchPalette.lavender))
        markings.add(body, stroke(FausSwitchPalette.deepWine, 1.4f))
        val rise = frame.height() * .27f
        val mid = frame.centerY()
        val arrows = world(section) {
            for (index in 0 until 3) {
                if (boost) {
                    val x = frame.left + 12 + index * 11
                    moveTo(x - 3.5f, mid + rise); lineTo(x + 3, mid); lineTo(x - 3.5f, mid - rise)
                } else {
                    val x = frame.right - 12 - index * 11
                    moveTo(x + 3.5f, mid + rise); lineTo(x - 3, mid); lineTo(x + 3.5f, mid - rise)
                }
            }
        }
        markings.add(arrows, stroke(if (boost) FausSwitchPalette.mint else FausSwitchPalette.deepWine, 2.4f, round = true))
    }

    private fun portalFrame(x: Double, gravity: SwitchGravity): RectF {
        val height = (course.portalHeight + 4).toFloat()
        val width = course.portalWidth.toFloat()
        val base = if (gravity == SwitchGravity.DOWN) course.floorSurface.toFloat() else course.ceilingSurface.toFloat() - height
        return RectF(x.toFloat() - width / 2, base, x.toFloat() + width / 2, base + height)
    }

    /** An upright ring standing on (or hanging from) its rail with a pulsing swirl inside. */
    private fun addPortal(index: Int, section: Int, x: Double, rail: SwitchGravity) {
        val frame = portalFrame(x, rail)
        val swirl = world(section) { addOval(RectF(frame).apply { inset(3f, 3f) }, Path.Direction.CW) }
        val core = world(section) { addOval(RectF(frame).apply { inset(7f, 10f) }, Path.Direction.CW) }
        val ring = world(section) { addOval(frame, Path.Direction.CW) }
        // The foot that holds it on the rail.
        val footY = if (rail == SwitchGravity.DOWN) frame.top - 1 else frame.bottom - 3
        val foot = world(section) { addRoundRect(frame.centerX() - 9, footY, frame.centerX() + 9, footY + 4, 2f, 2f, Path.Direction.CW) }
        portals += Portal(index, swirl, core, ring, foot, bounds(ring, 6f))
    }

    /** Where a portal puts a robot: a faint ring on the opposite rail. */
    private fun addPortalExit(section: Int, x: Double, gravity: SwitchGravity) {
        val ring = world(section) { addOval(portalFrame(x, gravity), Path.Direction.CW) }
        markings.add(ring, fill(FausSwitchPalette.lavender.copy(alpha = .18f)))
        markings.add(ring, stroke(FausSwitchPalette.wine.copy(alpha = .45f), 1.5f))
    }

    private fun addFinish() {
        val x = course.finishX.toFloat()
        val bottom = course.floorSurface.toFloat()
        val top = course.ceilingSurface.toFloat()
        val square = 8f
        val section = course.finishSection
        val background = world(section) { addRect(x - square, bottom, x + square, top, Path.Direction.CW) }
        markings.add(background, fill(FausSwitchPalette.mint))
        markings.add(background, stroke(FausSwitchPalette.plum, 1f))
        val checks = world(section) {
            var row = 0
            var y = bottom
            while (y < top) {
                val column = if (row % 2 == 0) 0f else 1f
                addRect(x - square + column * square, y, x + column * square, y + min(square, top - y), Path.Direction.CW)
                y += square
                row += 1
            }
        }
        markings.add(checks, fill(FausSwitchPalette.plum))
    }

    // Frame

    /** The texture fills the screen height and repeats mirrored, with parallax at 28 %. Screen y-down. */
    fun drawBackdrop(canvas: Canvas, world: SwitchWorld?, width: Float, height: Float, reduceMotion: Boolean) {
        canvas.drawColor(android.graphics.Color.rgb(0xD8, 0xFD, 0xD4))
        val bitmap = texture ?: return
        val shader = backdropShader ?: return
        if (height <= 0 || bitmap.height <= 0) return
        val scale = height / bitmap.height
        val factor = if (reduceMotion || world == null) 0f else (world.camera.viewportScale * .28).toFloat()
        val focusX = world?.focusX?.toFloat() ?: 0f
        val focusY = world?.focusY?.toFloat() ?: 0f
        val tileWidth = bitmap.width * scale
        // Offsets kept within two tiles (one mirrored pair) so floats stay small.
        val offsetX = -((focusX * factor) % (tileWidth * 2))
        val offsetY = (focusY * factor) % (height * 2)
        backdropMatrix.setScale(scale, scale)
        backdropMatrix.postTranslate(offsetX, offsetY)
        shader.setLocalMatrix(backdropMatrix)
        canvas.drawRect(0f, 0f, width, height, backdropPaint)
    }

    /** [canvas] is in dp and y-up (SpriteKit's scene space). */
    fun draw(canvas: Canvas, world: SwitchWorld, reduceMotion: Boolean) {
        if (world.matchId != matchId) {
            matchId = world.matchId
            robots.clear()
        }
        val camera = world.camera
        val scale = camera.scale.toFloat()
        if (scale <= 0f) return
        visible.set(
            (-camera.originX / camera.scale).toFloat(), (-camera.originY / camera.scale).toFloat(),
            ((camera.screenWidth - camera.originX) / camera.scale).toFloat(),
            ((camera.screenHeight - camera.originY) / camera.scale).toFloat(),
        )
        canvas.save()
        canvas.translate(camera.originX.toFloat(), camera.originY.toFloat())
        canvas.scale(scale, scale)

        drawPieces(canvas, ground)
        drawPieces(canvas, obstacles)
        for (stripe in stripes) {
            if (!RectF.intersects(stripe.bounds, visible)) continue
            canvas.save()
            canvas.clipPath(stripe.clip)
            canvas.drawPath(stripe.path, stripe.paint)
            canvas.restore()
        }
        drawPlatforms(canvas, world.platforms)
        drawPieces(canvas, markings)
        drawPortals(canvas, world, reduceMotion)
        drawLostZone(canvas, world)
        drawRobots(canvas, world, reduceMotion)
        canvas.restore()
    }

    private fun drawPieces(canvas: Canvas, pieces: List<Piece>) {
        for (piece in pieces) if (RectF.intersects(piece.bounds, visible)) canvas.drawPath(piece.path, piece.paint)
    }

    /** One platform per seat in its robot's color, with a lime line on the face it stands on. */
    private fun drawPlatforms(canvas: Canvas, platforms: List<SwitchPlatform>) {
        if (platforms !== platformSource) {
            platformSource = platforms
            platformPieces.clear()
            val section = course.spawnSection
            for (platform in platforms) {
                val frame = rectF(platform.rect)
                val tone = platform.color.tone(colorHex)
                val slab = world(section) { addRoundRect(frame, 2.5f, 2.5f, Path.Direction.CW) }
                platformPieces.add(slab, fillPaint(tone))
                platformPieces.add(slab, strokePaint(tone.switchDarkened(.35f), 1.2f))
                val stripeY = if (platform.gravity == SwitchGravity.DOWN) frame.bottom - 1.8f else frame.top
                val stripe = world(section) {
                    addRoundRect(frame.left + 3, stripeY, frame.right - 3, stripeY + 1.8f, .9f, .9f, Path.Direction.CW)
                }
                platformPieces.add(stripe, fill(FausSwitchPalette.lime))
            }
        }
        drawPieces(canvas, platformPieces)
    }

    private fun drawPortals(canvas: Canvas, world: SwitchWorld, reduceMotion: Boolean) {
        for (portal in portals) {
            if (!RectF.intersects(portal.bounds, visible)) continue
            val alpha = if (reduceMotion) .75f else (.6 + .3 * sin(world.time * 4 + portal.index)).toFloat()
            withAlpha(swirlFill, .55f * alpha) { canvas.drawPath(portal.swirl, it) }
            withAlpha(swirlStroke, .8f * alpha) { canvas.drawPath(portal.swirl, it) }
            withAlpha(coreFill, .5f * alpha) { canvas.drawPath(portal.core, it) }
            canvas.drawPath(portal.ring, ringStroke)
            canvas.drawPath(portal.foot, footFill)
        }
    }

    private inline fun withAlpha(paint: Paint, alpha: Float, draw: (Paint) -> Unit) {
        paint.alpha = (alpha.coerceIn(0f, 1f) * 255).toInt()
        draw(paint)
    }

    /** Dims the band behind the "left behind" line; in a bend the line crosses the screen. */
    private fun drawLostZone(canvas: Canvas, world: SwitchWorld) {
        val zone = world.lostZone ?: return
        if (zone !== lostZone) {
            lostZone = zone
            lostPath.reset()
            val points = zone.polygon
            for (index in 0 until points.size / 2) {
                if (index == 0) lostPath.moveTo(points[0], points[1]) else lostPath.lineTo(points[index * 2], points[index * 2 + 1])
            }
            lostPath.close()
        }
        canvas.drawPath(lostPath, lostFill)
        val line = zone.line
        canvas.drawLine(line[0], line[1], line[2], line[3], lostStroke)
    }

    private fun drawRobots(canvas: Canvas, world: SwitchWorld, reduceMotion: Boolean) {
        val seen = HashSet<String>()
        // Other robots first; the player's own is drawn on top (zPosition 12 over 10).
        for (pass in 0..1) {
            for (runner in world.runners) {
                if (runner.isLocal != (pass == 1)) continue
                seen += runner.id
                val state = robots.getOrPut(runner.id) {
                    RobotState(SwitchRobotArt(runner.color.tone(colorHex), runner.isLocal), runner.gravity).apply {
                        val target = if (runner.gravity == SwitchGravity.DOWN) 1f else -1f
                        from = target
                        to = target
                    }
                }
                val target = if (runner.gravity == SwitchGravity.DOWN) 1f else -1f
                if (runner.gravity != state.gravity) {
                    state.gravity = runner.gravity
                    state.from = rigScale(state, world.time)
                    state.to = target
                    state.startTime = if (reduceMotion) Double.NEGATIVE_INFINITY else world.time
                }
                if (runner.isHidden) continue
                val alpha = when (runner.status) {
                    SwitchRunnerStatus.CRASHED -> .32f
                    SwitchRunnerStatus.FINISHED -> 1f
                    SwitchRunnerStatus.RUNNING -> if (runner.isConnected) 1f else .55f
                }
                val running = runner.isRunning && world.phase == SwitchPhase.PLAYING && !reduceMotion
                val stride = if (running) (sin(world.tick * .42) * .9).toFloat() else 0f
                val size = (course.runnerHeight / 29.4 * runner.scale).toFloat()
                canvas.save()
                canvas.translate(runner.x.toFloat(), runner.y.toFloat())
                canvas.rotate(Math.toDegrees(runner.angle).toFloat())
                canvas.scale(size, size)
                if (alpha < 1f) canvas.saveLayerAlpha(-32f, -32f, 32f, 32f, (alpha * 255).toInt())
                state.art.draw(canvas, rigScaleY = rigScale(state, world.time), stride = stride,
                    trailAlpha = if (runner.isBoosted && runner.isRunning) .9f else 0f)
                canvas.restore()
                if (alpha < 1f) canvas.restore()
            }
        }
        robots.keys.retainAll(seen)
    }

    /** The 0.14 s ease-in-out turn of the rig toward its new rail. */
    private fun rigScale(state: RobotState, time: Double): Float {
        val progress = ((time - state.startTime) / FLIP_SECONDS).coerceIn(0.0, 1.0).toFloat()
        val eased = progress * progress * (3 - 2 * progress)
        return state.from + (state.to - state.from) * eased
    }

    private companion object {
        const val FLIP_SECONDS = .14
    }
}
