package com.fauscrew.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import com.fauscrew.ui.theme.FausGarden
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

// Fause Bloom decoration, mirroring iOS `FausBloom.swift`: the marbled texture, the edge garden
// of vines and flowers and the petal ornaments of hero surfaces. Coordinates are dp from the Bloom
// design canvas (a 390×844 screen); each cluster stays pinned to its own corner.

/** The theme's ebru texture, top-aligned and filling the draw area. */
internal fun DrawScope.drawMarble(image: ImageBitmap, alpha: Float) {
    val scale = max(size.width / image.width, size.height / image.height)
    val width = (image.width * scale).roundToInt()
    val height = (image.height * scale).roundToInt()
    clipRect {
        drawImage(
            image,
            dstOffset = IntOffset(((size.width - width) / 2).roundToInt(), 0),
            dstSize = IntSize(width, height),
            alpha = alpha,
        )
    }
}

/** Which garden arrangement a surface uses (iOS `FausGardenView.Layout`). */
internal enum class GardenLayout { PAGE, POPUP, SHEET }

/** Draws [garden] over this scope, laid out for a surface of [area] dp (the scope's own size by default). */
internal fun DrawScope.drawGarden(garden: FausGarden, layout: GardenLayout, area: Size = size / density) {
    val dp = density
    withTransform({ scale(dp, dp, Offset.Zero) }) {
        val painter = GardenPainter(this, garden, area.width, area.height)
        when (layout) {
            GardenLayout.PAGE -> painter.page()
            GardenLayout.POPUP -> painter.popup()
            GardenLayout.SHEET -> painter.sheet()
        }
    }
}

/** Where a design coordinate is measured from, so a cluster keeps its distance to its corner. */
private enum class Anchor { TOP_START, TOP_END, BOTTOM_START, BOTTOM_END, START_SCALED, END_SCALED }

private class GardenPainter(val scope: DrawScope, val garden: FausGarden, val width: Float, val height: Float) {
    private var designWidth = 390f
    private var designHeight = 844f

    fun point(x: Float, y: Float, anchor: Anchor): Offset = when (anchor) {
        Anchor.TOP_START -> Offset(x, y)
        Anchor.TOP_END -> Offset(width - (designWidth - x), y)
        Anchor.BOTTOM_START -> Offset(x, height - (designHeight - y))
        Anchor.BOTTOM_END -> Offset(width - (designWidth - x), height - (designHeight - y))
        Anchor.START_SCALED -> Offset(x, y / designHeight * height)
        Anchor.END_SCALED -> Offset(width - (designWidth - x), y / designHeight * height)
    }

    fun page() {
        designWidth = 390f; designHeight = 844f
        val te = Anchor.TOP_END
        stem(te, .42f, 1.6f) { at ->
            moveTo(at(400f, -10f)); curve(at(350f, 60f), at(372f, 130f), at(318f, 180f)); curve(at(264f, 230f), at(262f, 280f), at(290f, 340f))
        }
        stem(te, .36f, 1.1f) { at -> moveTo(at(352f, 92f)); curve(at(372f, 100f), at(384f, 118f), at(382f, 140f)) }
        leaf(378f, 40f, te, 150f, garden.leaf, .40f)
        leaf(356f, 110f, te, 20f, garden.leafAlt, .38f)
        leaf(322f, 172f, te, 160f, garden.leaf, .40f)
        leaf(290f, 250f, te, 30f, garden.leafAlt, .36f)
        leaf(300f, 318f, te, -20f, garden.leaf, .34f)
        berries(368f, 58f, te, garden.wine, .55f)
        blossom(346f, 140f, te, 1.5f, 12f, garden.rose, .8f)
        blossom(382f, 142f, te, .9f, 0f, garden.petal, .9f)
        bud(318f, 214f, te, 1.1f, garden.mauve, .55f)
        blossom(372f, 250f, te, 1f, 30f, garden.sky, .65f)
        daisy(292f, 340f, te, 1.35f, garden.petal, .95f)

        val bs = Anchor.BOTTOM_START
        stem(bs, .42f, 1.6f) { at ->
            moveTo(at(-10f, 860f)); curve(at(40f, 790f), at(20f, 740f), at(70f, 690f)); curve(at(120f, 640f), at(120f, 600f), at(100f, 540f))
        }
        stem(bs, .5f, 1.2f) { at -> moveTo(at(100f, 540f)); lineTo(at(100f, 556f)) }
        leaf(30f, 780f, bs, -40f, garden.leaf, .40f)
        leaf(64f, 700f, bs, 200f, garden.leafAlt, .38f)
        leaf(106f, 616f, bs, -30f, garden.leaf, .36f)
        leaf(48f, 740f, bs, 150f, garden.leaf, .32f)
        tulip(100f, 548f, bs, 1.5f, -8f, garden.rose, .75f)
        daisy(80f, 652f, bs, 1.25f, garden.petal, .95f)
        blossom(38f, 712f, bs, 1.3f, 20f, garden.wine, .5f)
        berries(22f, 796f, bs, garden.mauve, .6f)
        blossom(118f, 772f, bs, .95f, 0f, garden.sky, .6f)

        val be = Anchor.BOTTOM_END
        stem(be, .36f, 1.3f) { at -> moveTo(at(402f, 690f)); curve(at(372f, 720f), at(360f, 760f), at(336f, 800f)) }
        leaf(380f, 716f, be, 200f, garden.leafAlt, .34f)
        leaf(356f, 768f, be, -60f, garden.leaf, .32f)
        bud(372f, 704f, be, .85f, garden.rose, .6f)
        daisy(336f, 800f, be, 1.1f, garden.petal, .95f)

        petal(36f, 44f, Anchor.TOP_START, 1f, -30f, garden.rose, .45f)
        petal(64f, 24f, Anchor.TOP_START, .8f, 40f, garden.petal, .8f)
        petal(14f, 430f, Anchor.START_SCALED, 1f, 20f, garden.rose, .4f)
        petal(378f, 470f, Anchor.END_SCALED, 1f, -40f, garden.petal, .85f)
        petal(236f, 820f, Anchor.BOTTOM_START, .8f, 60f, garden.rose, .35f)
    }

    fun popup() {
        designWidth = width; designHeight = height
        val w = width
        val y1 = height * .34f
        val y2 = height * .62f
        val ts = Anchor.TOP_START
        stem(ts, .3f, 1.2f) { at -> moveTo(at(w + 8, y1 - 50)); curve(at(w - 24, y1 - 10), at(w - 6, y1 + 30), at(w - 30, y1 + 60)) }
        leaf(w - 12, y1 - 14, ts, 160f, garden.leafAlt, .3f)
        leaf(w - 22, y1 + 40, ts, 20f, garden.leaf, .28f)
        blossom(w - 16, y1 + 12, ts, 1.1f, 0f, garden.rose, .55f)
        daisy(w - 30, y1 + 62, ts, .9f, garden.petal, .85f)
        stem(ts, .28f, 1.2f) { at -> moveTo(at(-8f, y2 + 60)); curve(at(20f, y2 + 30), at(6f, y2), at(26f, y2 - 30)) }
        leaf(8f, y2 + 20, ts, -40f, garden.leaf, .28f)
        tulip(26f, y2 - 26, ts, 1.1f, -10f, garden.rose, .5f)
        berries(12f, y2 + 50, ts, garden.mauve, .45f)
    }

    fun sheet() {
        designWidth = 390f; designHeight = 556f
        val bs = Anchor.BOTTOM_START
        stem(bs, .36f, 1.5f) { at ->
            moveTo(at(-10f, 570f)); curve(at(40f, 500f), at(20f, 450f), at(70f, 400f)); curve(at(120f, 350f), at(120f, 330f), at(100f, 290f))
        }
        leaf(32f, 498f, bs, -40f, garden.leaf, .36f)
        leaf(66f, 420f, bs, 200f, garden.leafAlt, .34f)
        leaf(104f, 352f, bs, -30f, garden.leaf, .32f)
        tulip(100f, 292f, bs, 1.4f, -8f, garden.rose, .72f)
        daisy(80f, 452f, bs, 1.2f, garden.petal, .95f)
        blossom(36f, 540f, bs, 1.2f, 0f, garden.wine, .45f)
        val be = Anchor.BOTTOM_END
        stem(be, .32f, 1.3f) { at -> moveTo(at(402f, 420f)); curve(at(372f, 450f), at(360f, 490f), at(336f, 530f)) }
        leaf(378f, 448f, be, 200f, garden.leafAlt, .32f)
        daisy(340f, 528f, be, 1.1f, garden.petal, .95f)
        bud(372f, 432f, be, .85f, garden.rose, .6f)
    }

    private fun Path.moveTo(p: Offset) = moveTo(p.x, p.y)
    private fun Path.lineTo(p: Offset) = lineTo(p.x, p.y)
    private fun Path.curve(c1: Offset, c2: Offset, end: Offset) = cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)

    private fun stem(anchor: Anchor, alpha: Float, width: Float, build: Path.((Float, Float) -> Offset) -> Unit) {
        val path = Path().apply { build { x, y -> point(x, y, anchor) } }
        scope.drawPath(path, garden.vine, alpha, Stroke(width, cap = StrokeCap.Round))
    }

    private fun motif(x: Float, y: Float, anchor: Anchor, scale: Float, rotation: Float, draw: DrawScope.() -> Unit) {
        val origin = point(x, y, anchor)
        scope.withTransform({
            translate(origin.x, origin.y)
            rotate(rotation, Offset.Zero)
            scale(scale, scale, Offset.Zero)
        }, draw)
    }

    private fun leaf(x: Float, y: Float, anchor: Anchor, rotation: Float, color: Color, alpha: Float) =
        motif(x, y, anchor, 1f, rotation) { drawPath(BloomShapes.leaf, color, alpha) }

    private fun blossom(x: Float, y: Float, anchor: Anchor, scale: Float, rotation: Float, color: Color, alpha: Float) =
        motif(x, y, anchor, scale, rotation) {
            drawPath(BloomShapes.blossom, color, alpha)
            drawCircle(garden.blossomHeart, 2.8f, Offset.Zero, alpha)
        }

    private fun daisy(x: Float, y: Float, anchor: Anchor, scale: Float, color: Color, alpha: Float) =
        motif(x, y, anchor, scale, 0f) {
            drawPath(BloomShapes.daisy, color, alpha)
            drawCircle(garden.pollen, 3f, Offset.Zero, alpha)
        }

    private fun tulip(x: Float, y: Float, anchor: Anchor, scale: Float, rotation: Float, color: Color, alpha: Float) =
        motif(x, y, anchor, scale, rotation) { drawPath(BloomShapes.tulip, color, alpha) }

    private fun bud(x: Float, y: Float, anchor: Anchor, scale: Float, color: Color, alpha: Float) =
        motif(x, y, anchor, scale, 0f) {
            drawCircle(color, 8f, Offset.Zero, alpha)
            drawPath(BloomShapes.budSpiral, Color.White, alpha * .6f, Stroke(1.1f, cap = StrokeCap.Round))
        }

    private fun berries(x: Float, y: Float, anchor: Anchor, color: Color, alpha: Float) =
        motif(x, y, anchor, 1f, 0f) {
            drawCircle(color, 2.6f, Offset.Zero, alpha)
            drawCircle(color, 2.1f, Offset(4.5f, -3f), alpha)
            drawCircle(color, 1.9f, Offset(-3.4f, -4.4f), alpha)
        }

    private fun petal(x: Float, y: Float, anchor: Anchor, scale: Float, rotation: Float, color: Color, alpha: Float) =
        motif(x, y, anchor, scale, rotation) { drawPath(ellipse(0f, 0f, 2.4f, 4.4f, 0f), color, alpha) }
}

/** Bloom's motifs in dp, each centered on the origin (iOS `FausBloomShapes`). */
internal object BloomShapes {
    val leaf = Path().apply {
        moveTo(0f, 0f)
        cubicTo(5f, -9f, 15f, -12f, 24f, -8f)
        cubicTo(17f, -1f, 8f, 3f, 0f, 0f)
        close()
    }
    val tulip = Path().apply {
        moveTo(0f, 0f)
        cubicTo(-7f, -1f, -8f, -10f, -6f, -15f)
        lineTo(-3f, -11f); lineTo(0f, -16f); lineTo(3f, -11f); lineTo(6f, -15f)
        cubicTo(8f, -10f, 7f, -1f, 0f, 0f)
        close()
    }
    val budSpiral = Path().apply {
        moveTo(0f, -1f)
        cubicTo(3f, -1f, 3f, 3f, 0f, 3f)
        cubicTo(-4f, 3f, -4f, -3f, 0f, -4f)
        cubicTo(5f, -4f, 6f, 3f, 2f, 5.5f)
    }
    val blossom = petals(5, 4.2f, 7f)
    val daisy = petals(8, 2.3f, 6f, offset = 7f)

    /** [count] petals of radii [rx]×[ry] whose centers sit [offset] (default [ry]) from the origin. */
    fun petals(count: Int, rx: Float, ry: Float, offset: Float = ry, rotation: Float = 0f): Path = Path().apply {
        for (index in 0 until count) {
            val degrees = rotation + index * 360f / count
            addPath(ellipse(0f, -offset, rx, ry, degrees))
        }
    }
}

/** An ellipse centered at ([cx], [cy]) rotated [degrees] about the origin, as four cubics. */
private fun ellipse(cx: Float, cy: Float, rx: Float, ry: Float, degrees: Float): Path {
    val k = .5523f
    val rad = Math.toRadians(degrees.toDouble())
    val c = cos(rad).toFloat()
    val s = sin(rad).toFloat()
    fun p(x: Float, y: Float): Offset {
        val px = cx + x
        val py = cy + y
        return Offset(px * c - py * s, px * s + py * c)
    }
    return Path().apply {
        val start = p(rx, 0f); moveTo(start.x, start.y)
        val segments = listOf(
            Triple(p(rx, ry * k), p(rx * k, ry), p(0f, ry)),
            Triple(p(-rx * k, ry), p(-rx, ry * k), p(-rx, 0f)),
            Triple(p(-rx, -ry * k), p(-rx * k, -ry), p(0f, -ry)),
            Triple(p(rx * k, -ry), p(rx, -ry * k), p(rx, 0f)),
        )
        for ((c1, c2, end) in segments) cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)
        close()
    }
}

/** Which hero surface a Bloom ornament decorates (iOS `FausBloomOrnament.Surface`). */
internal enum class BloomOrnamentSurface { HERO_CARD, POPUP_HEADER, TAB_BAR, HEADER }

/**
 * Bloom's decoration for hero surfaces, in place of the circles and capsules: a large petal
 * flower at the top-end corner with its outline, a leaf along the bottom-end edge and a blush
 * sprig at the top-start corner.
 */
internal fun DrawScope.drawBloomOrnament(surface: BloomOrnamentSurface, ornament: Color, sprig: Color) {
    val dp = density
    withTransform({ scale(dp, dp, Offset.Zero) }) {
        val w = size.width / density
        val h = size.height / density
        when (surface) {
            BloomOrnamentSurface.HERO_CARD -> {
                petalFlower(Offset(w - 40, 6f), 20f, 34f, ornament, .09f)
                petalOutline(Offset(w - 40, 6f), 13f, 24f, ornament, .18f)
                leafBand(Offset(w - 190, 0f), 1f, ornament, .08f)
                sprigBranch(Offset(-6f, -6f), 1f, sprig, 1f)
            }
            BloomOrnamentSurface.POPUP_HEADER -> {
                petalFlower(Offset(w * .84f, 0f), 16f, 28f, ornament, .09f)
                petalOutline(Offset(w * .84f, 0f), 10f, 19f, ornament, .15f)
                leafBand(Offset(w * .84f - 76, -48f), .7f, ornament, .07f)
                sprigBranch(Offset(-6f, -14f), .6f, sprig, .9f)
            }
            BloomOrnamentSurface.TAB_BAR -> {
                petalFlower(Offset(w - 26, 4f), 13f, 22f, ornament, .09f)
                petalOutline(Offset(w - 26, 4f), 9f, 16f, ornament, .15f)
                sprigBranch(Offset(-10f, -10f), .62f, sprig, .9f)
            }
            BloomOrnamentSurface.HEADER -> {
                petalFlower(Offset(w - 50, 40f), 28f, 50f, ornament, .08f)
                petalOutline(Offset(w - 50, 40f), 18f, 34f, ornament, .16f)
                leafBand(Offset(w - 230, h - 110), 1.2f, ornament, .08f)
                sprigBranch(Offset(-4f, 24f), 1.3f, sprig, 1f)
                withTransform({ translate(w - 60, h - 64) }) { drawPath(BloomShapes.blossom, sprig, .4f) }
            }
        }
    }
}

private fun DrawScope.petalFlower(center: Offset, rx: Float, ry: Float, color: Color, alpha: Float) =
    withTransform({ translate(center.x, center.y) }) { drawPath(BloomShapes.petals(5, rx, ry), color, alpha) }

private fun DrawScope.petalOutline(center: Offset, rx: Float, ry: Float, color: Color, alpha: Float) =
    withTransform({ translate(center.x, center.y) }) {
        drawPath(BloomShapes.petals(5, rx, ry, rotation = 36f), color, alpha, Stroke(1f))
    }

/** A long leaf rising toward the end edge, on a 190×112 frame. */
private fun DrawScope.leafBand(origin: Offset, scale: Float, color: Color, alpha: Float) =
    withTransform({ translate(origin.x, origin.y); scale(scale, scale, Offset.Zero) }) {
        val leaf = Path().apply {
            moveTo(30f, 120f)
            cubicTo(70f, 90f, 120f, 80f, 200f, 52f)
            cubicTo(140f, 96f, 80f, 110f, 30f, 120f)
            close()
        }
        drawPath(leaf, color, alpha)
    }

/** A thin stem with two leaves, on a 120×70 frame. */
private fun DrawScope.sprigBranch(origin: Offset, scale: Float, color: Color, alpha: Float) =
    withTransform({ translate(origin.x, origin.y); scale(scale, scale, Offset.Zero) }) {
        val stem = Path().apply { moveTo(2f, 64f); cubicTo(30f, 40f, 60f, 26f, 112f, 10f) }
        drawPath(stem, color, .5f * alpha, Stroke(1.6f / scale, cap = StrokeCap.Round))
        val leaves = Path().apply {
            moveTo(34f, 42f); cubicTo(36f, 30f, 46f, 24f, 56f, 26f); cubicTo(52f, 36f, 44f, 42f, 34f, 42f); close()
            moveTo(66f, 26f); cubicTo(72f, 16f, 84f, 12f, 94f, 16f); cubicTo(86f, 24f, 76f, 28f, 66f, 26f); close()
        }
        drawPath(leaves, color, .38f * alpha)
    }

/** The small blossom tucked on a brand badge's halo (iOS `FausBadgeBlossom`). */
@Composable
internal fun FausBadgeBlossom(garden: FausGarden, size: Dp, modifier: Modifier = Modifier) {
    Canvas(modifier.size(size)) {
        val k = size.toPx() / 32f
        withTransform({ translate(center.x, center.y); scale(k, k, Offset.Zero) }) {
            drawPath(BloomShapes.blossom, garden.petal)
            drawCircle(garden.pollen, 2.8f, Offset.Zero)
        }
    }
}
