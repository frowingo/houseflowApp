package com.fauscrew.ui.components

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.RemoteImageLoader
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons

/**
 * `CachedRemoteImage`: shows [placeholder] until the bitmap arrives (or when the URL is
 * missing/unloadable). Transparent artwork keeps whatever is behind it, like on iOS.
 */
@Composable
internal fun RemoteImage(
    url: String?,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    placeholder: @Composable () -> Unit,
) {
    val source = url?.trim()?.takeIf(RemoteImageLoader::isLoadable)
    var bitmap by remember(source) { mutableStateOf<Bitmap?>(source?.let(RemoteImageLoader::cached)) }
    LaunchedEffect(source) {
        if (source != null && bitmap == null) bitmap = RemoteImageLoader.load(source)
    }
    Box(modifier, contentAlignment = Alignment.Center) {
        val current = bitmap
        if (current != null) {
            Image(current.asImageBitmap(), contentDescription, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        } else {
            placeholder()
        }
    }
}

/** `UserAvatar`: remote image clipped to a circle, initials on the system blue otherwise. */
@Composable
internal fun UserAvatar(member: HouseMember?, size: Dp, modifier: Modifier = Modifier) {
    val initials = member?.let { it.firstName.take(1) + it.lastName.take(1) }.orEmpty()
    RemoteImage(member?.imageUrl, modifier.size(size).clip(CircleShape), member?.name) {
        Box(Modifier.fillMaxSize().background(FausCrewColors.primary), contentAlignment = Alignment.Center) {
            Text(initials, color = androidx.compose.ui.graphics.Color.White,
                fontSize = (size.value * .4f).sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
        }
    }
}

/** `HouseProfileThumbnail` / `HouseSwitcherIcon`: house artwork with an indigo house fallback. */
@Composable
internal fun HouseThumbnail(url: String?, size: Dp, shape: Shape = RoundedCornerShape(13.dp)) {
    RemoteImage(url, Modifier.size(size).clip(shape)) {
        Box(Modifier.fillMaxSize().background(FausCrewColors.indigo.copy(alpha = .11f)),
            contentAlignment = Alignment.Center) {
            Icon(FausCrewIcons.houseFill, null, Modifier.size(size * .45f), tint = FausCrewColors.indigo)
        }
    }
}

/** Circle variant used by the house switcher rows. */
@Composable
internal fun HouseSwitcherIcon(url: String?) = HouseThumbnail(url, 42.dp, CircleShape)
