package com.fauscrew.push

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log

/** Debug-builds-only push log; callers pass tokens already shortened with [shortToken]. */
internal object PushLog {
    @Volatile private var enabled = false

    fun init(context: Context) {
        enabled = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    }

    /** The only form of an FCM token that may be logged. */
    fun shortToken(token: String): String = token.take(8)

    fun d(message: String) {
        if (enabled) Log.d("FausCrewPush", message)
    }
}
