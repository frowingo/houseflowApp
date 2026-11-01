package com.fauscrew.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.ReadOnlyComposable
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.LocalFausTheme
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin

/** Roof-F colors of the active theme, roof → stem foot; capture before drawing. */
internal val FausMarkColors: List<Color>
    @Composable @ReadOnlyComposable
    get() = listOf(FausCrewColors.brandLight, FausCrewColors.brandOrange, FausCrewColors.markBerry)

/**
 * The roof-shaped "F" of the FausCrew icon on a 1024 grid
 * (source: Design/AppIcon/FausCrew-AppIcon-Light.svg). Polylines run roof right → apex → stem,
 * then the arm, so a partial [progress] draws it like a pen stroke.
 */
private val FausPolylines = listOf(
    listOf(Offset(692f, 398f), Offset(512f, 246f), Offset(332f, 398f), Offset(332f, 778f)),
    listOf(Offset(332f, 578f), Offset(512f, 578f)),
)
private val FausTotalLength = FausPolylines.sumOf { line ->
    line.zipWithNext { a, b -> (b - a).getDistance().toDouble() }.sum()
}.toFloat()

/** `FausMark`: the roof-F glyph plus its "crew" dot, scaled to fit the draw area. */
internal fun DrawScope.drawFausMark(brush: Brush, progress: Float = 1f, dotScale: Float = 1f) {
    val unit = min(size.width, size.height) / 1024f
    val origin = Offset(center.x - 512f * unit, center.y - 512f * unit)
    fun point(p: Offset) = Offset(origin.x + p.x * unit, origin.y + p.y * unit)
    val stroke = Stroke(width = 76f * unit, cap = StrokeCap.Round, join = StrokeJoin.Round)

    var remaining = progress.coerceIn(0f, 1f) * FausTotalLength
    for (line in FausPolylines) {
        if (remaining <= 0f) break
        val path = Path().apply { moveTo(point(line[0]).x, point(line[0]).y) }
        for ((a, b) in line.zipWithNext()) {
            if (remaining <= 0f) break
            val length = hypot(b.x - a.x, b.y - a.y)
            val end = if (remaining >= length) b else a + (b - a) * (remaining / length)
            path.lineTo(point(end).x, point(end).y)
            remaining -= length
        }
        drawPath(path, brush, style = stroke)
    }
    if (dotScale > 0f) drawCircle(brush, radius = 44f * unit * dotScale, center = point(Offset(622f, 578f)))
}

/**
 * `FausFramedMark`: the roof-F in the brand gradient inside a thin orange circle whose inside is
 * cleared to [fill], so the page's ambient lines stop at its edge.
 */
@Composable
internal fun FausFramedMark(
    size: Dp,
    modifier: Modifier = Modifier,
    fill: Color? = null,
    progress: Float = 1f,
    dotScale: Float = 1f,
) {
    val decor = LocalFausTheme.current.decor
    val disc = fill ?: decor.framedMarkFill
    val markColors = FausMarkColors
    Canvas(modifier.size(size)) {
        val unit = this.size.minDimension / 1024f
        if (decor.framedMarkGlow.alpha > 0f) {
            drawCircle(Brush.radialGradient(listOf(decor.framedMarkGlow, decor.framedMarkGlow.copy(alpha = 0f)),
                radius = 470f * unit + 17.dp.toPx()), radius = 470f * unit + 17.dp.toPx())
        }
        drawCircle(disc, radius = 470f * unit)
        if (decor.framedMarkGlow.alpha > 0f) {
            drawCircle(Brush.radialGradient(listOf(decor.framedMarkGlow.copy(alpha = decor.framedMarkGlow.alpha * .5f), Color.Transparent),
                radius = 470f * unit), radius = 470f * unit)
        }
        drawCircle(decor.framedMarkRing, radius = 470f * unit,
            style = Stroke(width = maxOf(1.dp.toPx(), 7f * unit)))
        drawFausMark(fausMarkBrush(unit, markColors), progress, dotScale)
    }
}

/** The roof-F gradient (orange at the roof, berry at the foot), for a mark drawn at [unit] px per grid step. */
internal fun fausMarkBrush(unit: Float, colors: List<Color>) = Brush.linearGradient(
    0f to colors[0],
    .35f to colors[1],
    1f to colors[2],
    start = Offset(332f * unit, 246f * unit),
    end = Offset(692f * unit, 778f * unit),
)

/** Primary call-to-action gradient. */
internal val FausButtonGradient: Brush
    @Composable @ReadOnlyComposable
    get() = Brush.horizontalGradient(
        0f to FausCrewColors.brandLight,
        .35f to FausCrewColors.brandOrange,
        1f to FausCrewColors.markBerry,
    )

/**
 * `FausSpinner`: rounded arc pieces orbit clockwise, bunching into one long arc on the right and
 * splitting apart on the left, with a springy settle when they join and a small pull-back before
 * they leave. The gradient stays fixed while the pieces move through it.
 */
@Composable
internal fun FausSpinner(size: Dp = 46.dp, modifier: Modifier = Modifier) {
    var seconds by remember { mutableFloatStateOf(0f) }
    val splashActive = LocalFausSplashActive.current
    LaunchedEffect(splashActive) {
        // Hold still while the splash covers the screen; resume from where it stopped.
        if (splashActive) return@LaunchedEffect
        val start = withFrameNanos { it } - (seconds * 1_000_000_000f).toLong()
        while (true) withFrameNanos { seconds = (it - start) / 1_000_000_000f }
    }
    val spinnerColors = listOf(FausCrewColors.brandLight, FausCrewColors.spinnerRed, FausCrewColors.spinnerBerry)
    Canvas(modifier.size(size)) {
        val unit = this.size.minDimension / 48f
        val radius = 17f * unit
        val sweep = (12.5f / 17f) * 180f / PI.toFloat()
        val cycle = seconds / SpinnerPeriod
        val brush = Brush.linearGradient(
            0f to spinnerColors[0],
            .5f to spinnerColors[1],
            1f to spinnerColors[2],
            start = Offset(7f * unit, 7f * unit),
            end = Offset(41f * unit, 41f * unit),
        )
        val arcTopLeft = Offset(center.x - radius, center.y - radius)
        val arcSize = Size(radius * 2, radius * 2)
        val angles = List(SpinnerPieces) { index ->
            val phase = (cycle + index.toFloat() / SpinnerPieces) % 1f
            (spinnerPosition(phase) + cycle * .12f) * 360f - sweep / 2
        }
        // Soft colored shadow under the pieces, then the pieces themselves.
        val shadowStroke = Stroke(width = 7f * unit, cap = StrokeCap.Round)
        angles.forEach { start ->
            drawArc(spinnerColors[1].copy(alpha = .14f), start, sweep, false,
                topLeft = arcTopLeft + Offset(0f, 3f * unit), size = arcSize, style = shadowStroke)
        }
        val pieceStroke = Stroke(width = 4.6f * unit, cap = StrokeCap.Round)
        angles.forEach { start ->
            drawArc(brush, start, sweep, false, topLeft = arcTopLeft, size = arcSize, style = pieceStroke)
        }
    }
}

private const val SpinnerPieces = 7
private const val SpinnerPeriod = 2.6f
private const val SpinnerBunching = .82f

/** Where a piece sits (in turns): slow on the right, fast on the left, springy on arrival. */
private fun spinnerPosition(phase: Float): Float {
    var turn = phase - (SpinnerBunching / (2 * PI.toFloat())) * sin(2 * PI.toFloat() * phase)
    val sinceArrival = (phase - .8f + 1f) % 1f
    if (sinceArrival < .45f) turn += .05f * exp(-10f * sinceArrival) * sin(30f * sinceArrival)
    if (phase > .08f && phase < .3f) {
        val progress = (phase - .08f) / .22f
        turn -= .035f * sin(PI.toFloat() * progress) * (1 - progress)
    }
    return turn
}
