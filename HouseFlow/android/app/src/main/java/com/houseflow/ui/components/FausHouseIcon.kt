package com.houseflow.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import com.houseflow.ui.theme.HouseFlowColors
import kotlin.math.min

/**
 * FausCrew's own house glyph on a 24-unit grid: roof, chimney, rounded walls and an arched door.
 * iOS draws the same coordinates (`FausHouseIcon.swift`), so both platforms render it identically.
 */
internal fun DrawScope.drawFausHouse(brush: Brush) {
    val unit = min(size.width, size.height) / 24f
    val origin = Offset(center.x - 12f * unit, center.y - 12f * unit)
    fun x(v: Float) = origin.x + v * unit
    fun y(v: Float) = origin.y + v * unit
    val path = Path().apply {
        // Roof
        moveTo(x(2.75f), y(11.25f)); lineTo(x(12f), y(3.5f)); lineTo(x(21.25f), y(11.25f))
        // Chimney
        moveTo(x(16.25f), y(6.9f)); lineTo(x(16.25f), y(4.75f))
        // Walls
        moveTo(x(5.25f), y(9.4f)); lineTo(x(5.25f), y(18.5f))
        quadraticTo(x(5.25f), y(20.5f), x(7.25f), y(20.5f))
        lineTo(x(16.75f), y(20.5f))
        quadraticTo(x(18.75f), y(20.5f), x(18.75f), y(18.5f))
        lineTo(x(18.75f), y(9.4f))
        // Door
        moveTo(x(9.75f), y(20.5f)); lineTo(x(9.75f), y(16.25f))
        quadraticTo(x(9.75f), y(14f), x(12f), y(14f))
        quadraticTo(x(14.25f), y(14f), x(14.25f), y(16.25f))
        lineTo(x(14.25f), y(20.5f))
    }
    drawPath(path, brush, style = Stroke(width = 2.1f * unit, cap = StrokeCap.Round, join = StrokeJoin.Round))
}

/** House glyph stroke gradient, laid out on the icon's 24-unit grid. */
internal fun fausHouseBrush(unit: Float) = Brush.linearGradient(
    0f to HouseFlowColors.brandLight,
    .4f to HouseFlowColors.brandOrange,
    1f to Color(0xFF8A2440),
    start = Offset(3f * unit, 3f * unit),
    end = Offset(21f * unit, 21f * unit),
)

/** `FausHouseIcon`: brand-gradient house by default, or a flat [color]. */
@Composable
internal fun FausHouseIcon(size: Dp, modifier: Modifier = Modifier, color: Color? = null) {
    Canvas(modifier.size(size)) {
        drawFausHouse(color?.let { androidx.compose.ui.graphics.SolidColor(it) } ?: fausHouseBrush(this.size.minDimension / 24f))
    }
}
