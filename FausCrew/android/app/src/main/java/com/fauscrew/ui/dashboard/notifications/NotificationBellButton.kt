package com.fauscrew.ui.dashboard.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.notificationText
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.Sizes

/** The dashboard hero's bell: the megaphone's 40dp circle plus the unread badge (1-9, then "9+"). */
@Composable
internal fun NotificationBellButton(unread: Int, strings: LocalizedText, onClick: () -> Unit) {
    val label = strings.notificationText("notifications_open_accessibility_label")
    val unreadText = strings.notificationText("notifications_unread_badge_accessibility")
        .replace("%d", unread.toString()).replace("{count}", unread.toString())
    Box(Modifier.size(40.dp)) {
        Box(
            Modifier.size(40.dp).clip(CircleShape).background(LocalFausTheme.current.decor.heroOrnament.copy(alpha = .18f))
                .clickable(role = Role.Button, onClick = onClick)
                .semantics { contentDescription = if (unread > 0) "$label, $unreadText" else label },
            contentAlignment = Alignment.Center,
        ) {
            Icon(FausCrewIcons.bellFill, null, Modifier.size(Sizes.iconMedium + 2.dp), tint = FausCrewColors.onHero.copy(alpha = .9f))
        }
        if (unread > 0) {
            Text(
                if (unread > 9) "9+" else unread.toString(),
                Modifier.align(Alignment.TopEnd).offset(x = 5.dp, y = (-5).dp).defaultMinSize(minWidth = 18.dp, minHeight = 18.dp)
                    .background(FausCrewColors.accentOrange, CircleShape).border(1.5.dp, Color.White.copy(alpha = .85f), CircleShape)
                    .padding(horizontal = 4.dp).clearAndSetSemantics {},
                color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold, maxLines = 1,
                textAlign = TextAlign.Center,
            )
        }
    }
}
