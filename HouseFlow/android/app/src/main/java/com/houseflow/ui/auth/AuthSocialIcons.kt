package com.houseflow.ui.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.houseflow.R

internal enum class SocialKind { Google, Facebook, Snapchat }

/**
 * The providers' own marks, never redrawn: Google's "G" from Play Services
 * (`googleg_standard_color_18`), Facebook's "f" from the Facebook SDK (`com_facebook_button_icon`),
 * and Snapchat's ghost copied from Snap Login Kit, whose resources are private.
 */
@Composable
internal fun SocialIcon(kind: SocialKind) {
    when (kind) {
        // Google's guidelines size the mark at 18dp inside the button.
        SocialKind.Google -> Box(Modifier.size(22.dp), contentAlignment = Alignment.Center) {
            Image(painterResource(com.google.android.gms.base.R.drawable.googleg_standard_color_18), null, Modifier.size(18.dp))
        }
        SocialKind.Facebook -> Image(painterResource(com.facebook.common.R.drawable.com_facebook_button_icon), null,
            Modifier.size(22.dp))
        SocialKind.Snapchat -> Image(painterResource(R.drawable.snapchat_ghost), null, Modifier.size(22.dp))
    }
}
