package com.fauscrew.platform

import java.util.Locale

/**
 * The `tr` / `en` code sent as `Accept-Language` on every request and as a new social
 * account's `language`. Kept in step with the selected localization prefix.
 */
internal object ApiLanguage {
    @Volatile var code: String = resolve(Locale.getDefault().language)
        private set

    fun update(prefix: String?) { if (!prefix.isNullOrBlank()) code = resolve(prefix) }

    private fun resolve(prefix: String?): String =
        if (prefix?.lowercase(Locale.ROOT)?.startsWith("tr") == true) "tr" else "en"
}
