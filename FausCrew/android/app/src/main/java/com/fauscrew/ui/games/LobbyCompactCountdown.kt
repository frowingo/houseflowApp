package com.fauscrew.ui.games

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.dp
import com.fauscrew.ui.theme.FausCrewType
import androidx.compose.ui.text.font.FontWeight

/**
 * Reports whether at least [threshold] of this element's height is on screen (iOS:
 * `onScrollVisibilityChange`); a scrolled-away card reports false.
 */
internal fun Modifier.reportsOnScreen(threshold: Float = .3f, onChange: (Boolean) -> Unit): Modifier =
    onGloballyPositioned { coordinates ->
        val height = coordinates.size.height
        if (height > 0) onChange(coordinates.boundsInWindow().height / height >= threshold)
    }

/** A lobby countdown's seconds for the top bar, shown while its large card is scrolled away. */
@Composable
internal fun CompactCountdown(seconds: Int, ink: Color, danger: Color, description: String, modifier: Modifier = Modifier) {
    val tint = if (seconds <= 5) danger else ink
    Row(
        modifier.padding(horizontal = 12.dp).clearAndSetSemantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.Timer, null, Modifier.size(18.dp), tint = tint)
        Text("$seconds", style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Black, fontFeatureSettings = "tnum"),
            color = tint)
    }
}
