package com.fauscrew.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.fauscrew.ui.theme.FausCrewBrushes
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.softShadow

/**
 * `MainScreenBackground`: white page, a faint diagonal wash and static ink curves that
 * give white space a little depth. Drawn once per size; it never takes input.
 */
internal fun Modifier.mainScreenBackground(): Modifier = drawBehind {
    drawRect(FausCrewColors.background)
    drawRect(
        Brush.linearGradient(
            listOf(
                FausCrewColors.softApricot.copy(alpha = .035f),
                Color.Transparent,
                FausCrewColors.softBerry.copy(alpha = .018f),
            ),
        ),
    )
    AmbientCurves.forEach { drawAmbientCurve(it) }
}

private class AmbientCurve(
    val start: Offset, val control1: Offset, val control2: Offset, val end: Offset,
    val color: Color, val opacity: Float, val width: Float,
)

private val AmbientCurves = listOf(
    AmbientCurve(Offset(-.08f, .17f), Offset(.04f, .05f), Offset(.15f, .01f), Offset(.36f, -.07f), FausCrewColors.softApricot, .17f, .85f),
    AmbientCurve(Offset(-.06f, .30f), Offset(.11f, .17f), Offset(.30f, .07f), Offset(.52f, -.06f), FausCrewColors.softBerry, .18f, .80f),
    AmbientCurve(Offset(-.10f, .08f), Offset(.30f, .14f), Offset(.74f, -.06f), Offset(1.10f, .26f), FausCrewColors.softOrange, .20f, 1.15f),
    AmbientCurve(Offset(1.08f, .02f), Offset(.65f, .24f), Offset(.70f, .50f), Offset(-.08f, .61f), FausCrewColors.softBerry, .18f, .85f),
    AmbientCurve(Offset(.72f, -.07f), Offset(.89f, .05f), Offset(1.02f, .13f), Offset(1.08f, .31f), FausCrewColors.softBerry, .15f, .80f),
    AmbientCurve(Offset(-.12f, .33f), Offset(.28f, .20f), Offset(.58f, .74f), Offset(1.12f, .64f), FausCrewColors.softApricot, .16f, 1.25f),
    AmbientCurve(Offset(.24f, -.06f), Offset(.12f, .39f), Offset(.42f, .59f), Offset(.90f, 1.08f), FausCrewColors.softOrange, .15f, .90f),
    AmbientCurve(Offset(1.10f, .39f), Offset(.55f, .31f), Offset(.23f, .86f), Offset(-.10f, .91f), FausCrewColors.softBerry, .17f, 1.00f),
    AmbientCurve(Offset(-.10f, .72f), Offset(.34f, .49f), Offset(.78f, .83f), Offset(1.08f, 1.02f), FausCrewColors.softApricot, .13f, .80f),
    AmbientCurve(Offset(.62f, 1.08f), Offset(.73f, .90f), Offset(.94f, .92f), Offset(1.08f, .74f), FausCrewColors.softOrange, .15f, .85f),
    AmbientCurve(Offset(.42f, 1.06f), Offset(.58f, .92f), Offset(.83f, .88f), Offset(1.07f, .60f), FausCrewColors.softBerry, .17f, .80f),
)

private fun DrawScope.drawAmbientCurve(curve: AmbientCurve) {
    fun Offset.scaled() = Offset(x * size.width, y * size.height)
    val start = curve.start.scaled()
    val end = curve.end.scaled()
    val path = Path().apply {
        moveTo(start.x, start.y)
        val c1 = curve.control1.scaled()
        val c2 = curve.control2.scaled()
        cubicTo(c1.x, c1.y, c2.x, c2.y, end.x, end.y)
    }
    // Edge-weighted ink: slightly stronger where the curve enters and leaves the screen.
    val ink = Brush.linearGradient(
        0f to curve.color.copy(alpha = curve.opacity),
        .36f to curve.color.copy(alpha = curve.opacity * .64f),
        .64f to curve.color.copy(alpha = curve.opacity * .62f),
        1f to curve.color.copy(alpha = curve.opacity),
        start = start,
        end = end,
    )
    drawPath(path, ink, style = Stroke(width = curve.width.dp.toPx(), cap = StrokeCap.Round))
}

/** Full-screen [mainScreenBackground] host. */
@Composable
internal fun MainScreenBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier.mainScreenBackground(), content = content)
}

/**
 * `BrandHeroCardBackground`: the prominent orange → berry card at the top of main tabs,
 * with its decorative circles/capsules, hairline highlight border and berry shadow.
 */
@Composable
internal fun BrandHeroCard(
    modifier: Modifier = Modifier,
    contentAlignment: Alignment = Alignment.TopStart,
    content: @Composable BoxScope.() -> Unit,
) {
    val shape = RoundedCornerShape(Radius.xl)
    Box(
        modifier
            .softShadow(FausCrewColors.deepBerry.copy(alpha = .28f), 18.dp, y = 8.dp, shape = shape)
            .clip(shape)
            .drawBehind {
                drawRect(FausCrewBrushes.brandHero)
                val center = Offset(size.width / 2, size.height / 2)
                fun at(x: Float, y: Float) = center + Offset(x.dp.toPx(), y.dp.toPx())
                drawCircle(Color.White.copy(alpha = .08f), 79.dp.toPx(), at(145f, -62f))
                drawCircle(Color.White.copy(alpha = .16f), 59.dp.toPx(), at(136f, -54f), style = Stroke(1.dp.toPx()))
                drawCircle(Color.White.copy(alpha = .10f), 41.dp.toPx(), at(130f, -48f), style = Stroke(1.dp.toPx()))
                drawCapsule(Color.White.copy(alpha = .08f), at(130f, 58f), 180.dp, 24.dp, -28f)
                drawCapsule(FausCrewColors.systemOrange.copy(alpha = .22f), at(-145f, -58f), 126.dp, 18.dp, -28f)
            }
            .border(
                1.dp,
                Brush.linearGradient(listOf(Color.White.copy(alpha = .42f), Color.White.copy(alpha = .06f))),
                shape,
            ),
        contentAlignment = contentAlignment,
        content = content,
    )
}

/**
 * `BrandPopupHeaderBackground`: compact brand treatment for popup title bars. The popup
 * card owns corner clipping, so this stays edge to edge and ends in a white hairline.
 */
internal fun Modifier.brandPopupHeaderBackground(): Modifier = drawBehind {
    drawRect(FausCrewBrushes.brandHero)
    val center = Offset(size.width / 2, size.height / 2)
    fun at(xFraction: Float, y: Float) = center + Offset(size.width * xFraction, y.dp.toPx())
    drawCircle(Color.White.copy(alpha = .08f), 56.dp.toPx(), at(.34f, -42f))
    drawCircle(Color.White.copy(alpha = .15f), 39.dp.toPx(), at(.32f, -34f), style = Stroke(1.dp.toPx()))
    drawCapsule(Color.White.copy(alpha = .07f), at(.31f, 28f), 132.dp, 16.dp, -24f)
    drawCapsule(FausCrewColors.systemOrange.copy(alpha = .20f), at(-.39f, -24f), 94.dp, 12.dp, -24f)
    val hairline = .5.dp.toPx()
    drawRect(Color.White.copy(alpha = .14f), Offset(0f, size.height - hairline), Size(size.width, hairline))
}

/** `CustomTabBar` background: soft brand gradient, decoration and highlight border. */
internal fun Modifier.tabBarBackground(): Modifier = drawBehind {
    drawRect(FausCrewBrushes.tabBar)
    val w = size.width
    val h = size.height
    fun at(x: Float, y: Float) = Offset(x, y)
    drawCircle(Color.White.copy(alpha = .08f), 52.dp.toPx(), at(w - 24.dp.toPx(), 6.dp.toPx()))
    drawCircle(Color.White.copy(alpha = .15f), 38.dp.toPx(), at(w - 24.dp.toPx(), 6.dp.toPx()), style = Stroke(1.dp.toPx()))
    drawCapsule(Color.White.copy(alpha = .07f), at(w - 38.dp.toPx(), h - 12.5.dp.toPx()), 112.dp, 15.dp, -24f)
    drawCapsule(FausCrewColors.systemOrange.copy(alpha = .2f), at(16.dp.toPx(), 3.dp.toPx()), 88.dp, 12.dp, -24f)
}

private fun DrawScope.drawCapsule(color: Color, center: Offset, width: Dp, height: Dp, degrees: Float) {
    val size = Size(width.toPx(), height.toPx())
    rotate(degrees, pivot = center) {
        drawRoundRect(
            color = color,
            topLeft = center - Offset(size.width / 2, size.height / 2),
            size = size,
            cornerRadius = CornerRadius(size.height / 2),
        )
    }
}
