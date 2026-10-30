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
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Rect
import android.graphics.BitmapShader
import android.graphics.ComposeShader
import android.graphics.PorterDuff
import android.graphics.RadialGradient
import android.graphics.Shader
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import kotlin.math.ceil
import com.fauscrew.ui.theme.FausBackdrop
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausMeshTexture
import com.fauscrew.ui.theme.FausPalette
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.linear
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.softShadow

/** Which [FausBackdrop] recipe a surface uses (iOS `MainScreenBackground.Surface`). */
internal enum class BackdropSurface { PAGE, POPUP }

/**
 * `MainScreenBackground`: the theme's base, a faint diagonal wash, an optional perforated mesh
 * texture and static ink curves that give empty space a little depth. Drawn once per size;
 * it never takes input.
 */
@Composable
internal fun Modifier.mainScreenBackground(surface: BackdropSurface = BackdropSurface.PAGE): Modifier {
    val theme = LocalFausTheme.current
    val backdrop = if (surface == BackdropSurface.POPUP) theme.decor.popupBackdrop else theme.decor.backdrop
    val palette = theme.palette
    return drawWithCache {
        val mesh = backdrop.mesh?.let { MeshLayer(it, size, density, masked = true) }
        onDrawBehind {
            val stops = backdrop.baseStops
            if (stops.size == 1) drawRect(stops.first().second)
            else drawRect(Brush.linearGradient(*stops.toTypedArray(),
                start = Offset(size.width * backdrop.baseStartX, 0f), end = Offset(size.width * backdrop.baseEndX, size.height)))
            mesh?.let { drawMesh(it) }
            drawRect(Brush.linearGradient(backdrop.wash))
            drawCornerGlow(backdrop.glow, reach = .6f)
            if (backdrop.drawsLines) AmbientCurves.forEach { drawAmbientCurve(it, backdrop, palette) }
        }
    }
}

private enum class Ink { APRICOT, ORANGE, BERRY }

private class AmbientCurve(
    val start: Offset, val control1: Offset, val control2: Offset, val end: Offset,
    val ink: Ink, val opacity: Float, val width: Float,
)

private val AmbientCurves = listOf(
    AmbientCurve(Offset(-.08f, .17f), Offset(.04f, .05f), Offset(.15f, .01f), Offset(.36f, -.07f), Ink.APRICOT, .17f, .85f),
    AmbientCurve(Offset(-.06f, .30f), Offset(.11f, .17f), Offset(.30f, .07f), Offset(.52f, -.06f), Ink.BERRY, .18f, .80f),
    AmbientCurve(Offset(-.10f, .08f), Offset(.30f, .14f), Offset(.74f, -.06f), Offset(1.10f, .26f), Ink.ORANGE, .20f, 1.15f),
    AmbientCurve(Offset(1.08f, .02f), Offset(.65f, .24f), Offset(.70f, .50f), Offset(-.08f, .61f), Ink.BERRY, .18f, .85f),
    AmbientCurve(Offset(.72f, -.07f), Offset(.89f, .05f), Offset(1.02f, .13f), Offset(1.08f, .31f), Ink.BERRY, .15f, .80f),
    AmbientCurve(Offset(-.12f, .33f), Offset(.28f, .20f), Offset(.58f, .74f), Offset(1.12f, .64f), Ink.APRICOT, .16f, 1.25f),
    AmbientCurve(Offset(.24f, -.06f), Offset(.12f, .39f), Offset(.42f, .59f), Offset(.90f, 1.08f), Ink.ORANGE, .15f, .90f),
    AmbientCurve(Offset(1.10f, .39f), Offset(.55f, .31f), Offset(.23f, .86f), Offset(-.10f, .91f), Ink.BERRY, .17f, 1.00f),
    AmbientCurve(Offset(-.10f, .72f), Offset(.34f, .49f), Offset(.78f, .83f), Offset(1.08f, 1.02f), Ink.APRICOT, .13f, .80f),
    AmbientCurve(Offset(.62f, 1.08f), Offset(.73f, .90f), Offset(.94f, .92f), Offset(1.08f, .74f), Ink.ORANGE, .15f, .85f),
    AmbientCurve(Offset(.42f, 1.06f), Offset(.58f, .92f), Offset(.83f, .88f), Offset(1.07f, .60f), Ink.BERRY, .17f, .80f),
)

private fun DrawScope.drawAmbientCurve(curve: AmbientCurve, backdrop: FausBackdrop, palette: FausPalette) {
    fun Offset.scaled() = Offset(x * size.width, y * size.height)
    val (color, strength) = when (curve.ink) {
        Ink.APRICOT -> palette.softApricot to backdrop.apricotStrength
        Ink.ORANGE -> palette.softOrange to backdrop.orangeStrength
        Ink.BERRY -> palette.softBerry to backdrop.berryStrength
    }
    val opacity = (curve.opacity * strength).coerceAtMost(.66f)
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
        0f to color.copy(alpha = opacity),
        .36f to color.copy(alpha = opacity * .64f),
        .64f to color.copy(alpha = opacity * .62f),
        1f to color.copy(alpha = opacity),
        start = start,
        end = end,
    )
    drawPath(path, ink, style = Stroke(width = (curve.width + backdrop.lineWidthBoost).dp.toPx(), cap = StrokeCap.Round))
}

/**
 * A [FausMeshTexture] for one surface size, built in `drawWithCache`. The ~15k holes are drawn
 * once into a [MeshRaster] bitmap shared by every surface; each frame then draws a single
 * shader-filled rect, with the radial fade composed into the shader instead of a `saveLayer`.
 */
internal class MeshLayer(val texture: FausMeshTexture, size: Size, density: Float, val masked: Boolean) {
    val paint: android.graphics.Paint? = MeshRaster.bitmap(texture, size, density)?.let { raster ->
        val holes = BitmapShader(raster, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        android.graphics.Paint().apply {
            shader = if (!masked) holes else ComposeShader(
                holes,
                RadialGradient(
                    size.width * .72f, size.height * .22f, maxOf(size.width * 1.1f, size.height * .7f),
                    intArrayOf(Color.Black.toArgb(), Color.Black.copy(alpha = .88f).toArgb(), Color.Black.copy(alpha = .78f).toArgb()),
                    floatArrayOf(0f, .55f, 1f), Shader.TileMode.CLAMP,
                ),
                PorterDuff.Mode.DST_IN,
            )
        }
    }
}

/** The unmasked hole grid per texture and density, grown to the largest surface it has covered. */
private object MeshRaster {
    private val rasters = HashMap<Pair<FausMeshTexture, Float>, android.graphics.Bitmap>()

    fun bitmap(texture: FausMeshTexture, size: Size, density: Float): android.graphics.Bitmap? {
        val width = ceil(size.width).toInt()
        val height = ceil(size.height).toInt()
        if (width <= 0 || height <= 0) return null
        val key = texture to density
        val cached = rasters[key]
        if (cached != null && cached.width >= width && cached.height >= height) return cached
        return draw(texture, density, maxOf(width, cached?.width ?: 0), maxOf(height, cached?.height ?: 0))
            .also { rasters[key] = it }
    }

    private fun draw(texture: FausMeshTexture, density: Float, width: Int, height: Int): android.graphics.Bitmap {
        val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        val rimPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            style = android.graphics.Paint.Style.STROKE
            strokeWidth = .5f * density
            color = texture.rim.toArgb()
        }
        val holePaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = texture.hole.toArgb() }
        val pitch = texture.pitch * density
        val rowPitch = texture.rowPitch * density
        val rows = (height / rowPitch).toInt() + 2
        val columns = (width / pitch).toInt() + 2
        // Rims first, then holes, matching the former stroked-then-filled paths.
        for (paint in listOf(rimPaint, holePaint)) {
            val radius = (if (paint === rimPaint) texture.rimRadius else texture.holeRadius) * density
            for (row in 0 until rows) {
                val y = row * rowPitch + pitch / 2
                val shift = if (row % 2 == 0) 0f else pitch / 2
                for (column in 0 until columns) canvas.drawCircle(column * pitch + pitch / 2 + shift, y, radius, paint)
            }
        }
        return bitmap
    }
}

/**
 * Faus Dark's perforated metal: strongest toward the top-end light and never fully gone at the
 * bottom (radial fade when masked), plus faint sheens.
 */
internal fun DrawScope.drawMesh(mesh: MeshLayer) {
    val texture = mesh.texture
    val masked = mesh.masked
    mesh.paint?.let { paint -> drawIntoCanvas { it.nativeCanvas.drawRect(0f, 0f, size.width, size.height, paint) } }
    drawRect(Brush.radialGradient(
        listOf(texture.sheen.copy(alpha = if (masked) .06f else .05f), texture.sheen.copy(alpha = 0f)),
        center = Offset(size.width * .74f, size.height * .20f), radius = size.width * .5f,
    ))
    if (masked) {
        drawRect(Brush.radialGradient(
            listOf(texture.sheen.copy(alpha = .035f), texture.sheen.copy(alpha = 0f)),
            center = Offset(size.width * .30f, size.height * .88f), radius = size.width * .63f,
        ))
    }
}

/** Top-end bloom over a hero gradient; draws nothing when the theme's glow is transparent. */
internal fun DrawScope.drawCornerGlow(color: Color, reach: Float = .62f) {
    if (color.alpha == 0f) return
    drawRect(Brush.radialGradient(
        listOf(color, color.copy(alpha = 0f)),
        center = Offset(size.width, 0f), radius = maxOf(size.width, size.height) * reach,
    ))
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
    val decor = LocalFausTheme.current.decor
    val accentCapsule = FausCrewColors.systemOrange
    Box(
        modifier
            .softShadow(decor.heroShadow, 18.dp, y = 8.dp, shape = shape)
            .clip(shape)
            .drawBehind {
                drawRect(decor.heroStops.linear())
                drawCornerGlow(decor.heroGlow)
                val ornament = decor.heroOrnament
                val center = Offset(size.width / 2, size.height / 2)
                fun at(x: Float, y: Float) = center + Offset(x.dp.toPx(), y.dp.toPx())
                drawCircle(ornament.copy(alpha = .08f), 79.dp.toPx(), at(145f, -62f))
                drawCircle(ornament.copy(alpha = .16f), 59.dp.toPx(), at(136f, -54f), style = Stroke(1.dp.toPx()))
                drawCircle(ornament.copy(alpha = .10f), 41.dp.toPx(), at(130f, -48f), style = Stroke(1.dp.toPx()))
                drawCapsule(ornament.copy(alpha = .08f), at(130f, 58f), 180.dp, 24.dp, -28f)
                drawCapsule(accentCapsule.copy(alpha = .22f), at(-145f, -58f), 126.dp, 18.dp, -28f)
            }
            .border(1.dp, Brush.linearGradient(decor.heroBorder), shape),
        contentAlignment = contentAlignment,
        content = content,
    )
}

/**
 * `BrandPopupHeaderBackground`: compact brand treatment for popup title bars. The popup
 * card owns corner clipping, so this stays edge to edge and ends in a white hairline.
 */
@Composable
internal fun Modifier.brandPopupHeaderBackground(): Modifier {
    val theme = LocalFausTheme.current
    val decor = theme.decor
    val accentCapsule = FausCrewColors.systemOrange
    return drawBehind {
        drawRect(decor.heroStops.linear())
        drawCornerGlow(decor.heroGlow, reach = .9f)
        val ornament = decor.heroOrnament
        val center = Offset(size.width / 2, size.height / 2)
        fun at(xFraction: Float, y: Float) = center + Offset(size.width * xFraction, y.dp.toPx())
        drawCircle(ornament.copy(alpha = .08f), 56.dp.toPx(), at(.34f, -42f))
        drawCircle(ornament.copy(alpha = .15f), 39.dp.toPx(), at(.32f, -34f), style = Stroke(1.dp.toPx()))
        drawCapsule(ornament.copy(alpha = .07f), at(.31f, 28f), 132.dp, 16.dp, -24f)
        drawCapsule(accentCapsule.copy(alpha = .20f), at(-.39f, -24f), 94.dp, 12.dp, -24f)
        val hairline = .5.dp.toPx()
        drawRect(ornament.copy(alpha = if (theme.isDark) .26f else .14f), Offset(0f, size.height - hairline), Size(size.width, hairline))
    }
}

/** `CustomTabBar` background: the theme's tab bar gradient, decoration and glow. */
@Composable
internal fun Modifier.tabBarBackground(): Modifier {
    val decor = LocalFausTheme.current.decor
    val accentCapsule = FausCrewColors.systemOrange
    return drawBehind {
        drawRect(decor.tabBarStops.linear())
        drawCornerGlow(decor.tabBarGlow, reach = .7f)
        val ornament = decor.heroOrnament
        val w = size.width
        val h = size.height
        fun at(x: Float, y: Float) = Offset(x, y)
        drawCircle(ornament.copy(alpha = .08f), 52.dp.toPx(), at(w - 24.dp.toPx(), 6.dp.toPx()))
        drawCircle(ornament.copy(alpha = .15f), 38.dp.toPx(), at(w - 24.dp.toPx(), 6.dp.toPx()), style = Stroke(1.dp.toPx()))
        drawCapsule(ornament.copy(alpha = .07f), at(w - 38.dp.toPx(), h - 12.5.dp.toPx()), 112.dp, 15.dp, -24f)
        drawCapsule(accentCapsule.copy(alpha = .2f), at(16.dp.toPx(), 3.dp.toPx()), 88.dp, 12.dp, -24f)
    }
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
