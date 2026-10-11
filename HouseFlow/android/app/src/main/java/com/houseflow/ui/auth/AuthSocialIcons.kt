package com.houseflow.ui.auth

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.unit.dp

internal enum class SocialKind { Google, Apple, Snapchat }

/** Native vector equivalents of the three marks already drawn by iOS AuthView. */
@Composable
internal fun SocialIcon(kind: SocialKind, tint: Color) {
    Canvas(Modifier.size(22.dp)) {
        val x = size.width / 20f
        val y = size.height / 20f
        scale(x, y, pivot = Offset.Zero) {
            when (kind) {
                SocialKind.Google -> {
                    val ring = Size(15.6f, 15.6f)
                    val topLeft = Offset(2.2f, 2.2f)
                    val stroke = Stroke(width = 4.4f, cap = StrokeCap.Butt)
                    drawArc(Color(0xFFEA4335), 200f, 95f, false, topLeft, ring, style = stroke)
                    drawArc(Color(0xFFFBBC05), 135f, 65f, false, topLeft, ring, style = stroke)
                    drawArc(Color(0xFF34A853), 45f, 90f, false, topLeft, ring, style = stroke)
                    drawArc(Color(0xFF4285F4), -45f, 90f, false, topLeft, ring, style = stroke)
                    drawLine(Color(0xFF4285F4), Offset(10f, 10f), Offset(19f, 10f), strokeWidth = 4.4f)
                }
                SocialKind.Apple -> {
                    val fruit = Path().apply {
                        moveTo(10f, 5.2f)
                        cubicTo(8f, 3.7f, 5.2f, 4.7f, 3.7f, 6.5f)
                        cubicTo(1.8f, 8.9f, 2.4f, 13.1f, 4.2f, 16.2f)
                        cubicTo(5.4f, 18.5f, 6.8f, 19.6f, 8.5f, 18.8f)
                        cubicTo(9.5f, 18.3f, 10.5f, 18.3f, 11.5f, 18.8f)
                        cubicTo(13.5f, 19.7f, 14.8f, 18.1f, 16.1f, 15.9f)
                        cubicTo(14.8f, 15.1f, 14f, 13.8f, 14f, 12.2f)
                        cubicTo(14f, 10.5f, 15f, 9.1f, 16.5f, 8.4f)
                        cubicTo(15.4f, 5.7f, 13.1f, 4.1f, 10f, 5.2f)
                        close()
                    }
                    val leaf = Path().apply {
                        moveTo(10f, 4.4f)
                        cubicTo(10.1f, 2.5f, 11.4f, 1f, 14f, .5f)
                        cubicTo(14f, 2.4f, 12.8f, 4.1f, 10f, 4.4f)
                        close()
                    }
                    drawPath(fruit, tint)
                    drawPath(leaf, tint)
                }
                SocialKind.Snapchat -> {
                    val ghost = Path().apply {
                        moveTo(10f, 16.6f)
                        cubicTo(11.4f, 15.6f, 13.4f, 19.4f, 14.8f, 18.6f)
                        cubicTo(17.4f, 17.2f, 19f, 14.4f, 17.6f, 11.2f)
                        cubicTo(18.4f, 7.6f, 19f, 4f, 15.2f, 4f)
                        cubicTo(13f, 1.6f, 11.6f, .8f, 10f, 1.4f)
                        cubicTo(8.4f, .8f, 7f, 1.6f, 4.8f, 4f)
                        cubicTo(1f, 4f, 1.6f, 7.6f, 2.4f, 11.2f)
                        cubicTo(1f, 14.4f, 2.6f, 17.2f, 5.2f, 18.6f)
                        cubicTo(6.6f, 19.4f, 8.6f, 15.6f, 10f, 16.6f)
                        close()
                    }
                    drawPath(ghost, tint)
                }
            }
        }
    }
}
