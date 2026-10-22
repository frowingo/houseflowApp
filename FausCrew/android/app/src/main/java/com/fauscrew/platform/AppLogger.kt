package com.fauscrew.platform

import android.util.Log

/** Fixed-code events only: callers cannot pass tokens, headers, email or payloads. */
internal object AppLogger {
    enum class Event(val code: String) {
        SESSION_REAUTH_REQUIRED("session_reauth_required"),
        LOCALIZATION_CACHE_WRITE_FAILED("localization_cache_write_failed"),
    }

    fun record(event: Event) {
        Log.i("FausCrew", "event=${event.code}")
    }
}
