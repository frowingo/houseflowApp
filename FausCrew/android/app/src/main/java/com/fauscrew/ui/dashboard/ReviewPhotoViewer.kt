package com.fauscrew.ui.dashboard

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Bitmap
import android.os.Build
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.SecureFlagPolicy
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.Spacing

/**
 * Full-screen review photo, the only place a review photo is shown. The window is
 * FLAG_SECURE so screenshots and recordings never contain the photo; on Android 14+ a
 * screenshot attempt also reports [onCaptureAttempt] so the caller can close the viewer.
 */
@Composable
internal fun ReviewPhotoViewer(
    photo: Bitmap,
    closeLabel: String,
    onClose: () -> Unit,
    onCaptureAttempt: () -> Unit,
) {
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(
            usePlatformDefaultWidth = false,
            decorFitsSystemWindows = false,
            securePolicy = SecureFlagPolicy.SecureOn,
        ),
    ) {
        val activity = LocalContext.current.findActivity()
        val captureAttempt by rememberUpdatedState(onCaptureAttempt)
        DisposableEffect(activity) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE || activity == null) {
                return@DisposableEffect onDispose {}
            }
            val callback = Activity.ScreenCaptureCallback { captureAttempt() }
            activity.registerScreenCaptureCallback(activity.mainExecutor, callback)
            onDispose { activity.unregisterScreenCaptureCallback(callback) }
        }
        Box(Modifier.fillMaxSize().background(Color.Black).systemBarsPadding()) {
            Image(photo.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
            Box(
                Modifier.align(Alignment.TopEnd).padding(Spacing.lg).size(36.dp).clip(CircleShape)
                    .background(Color.White.copy(alpha = .2f)).clickable(onClick = onClose)
                    .semantics { contentDescription = closeLabel },
                contentAlignment = Alignment.Center,
            ) {
                Icon(FausCrewIcons.xmark, null, Modifier.size(18.dp), tint = Color.White)
            }
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
