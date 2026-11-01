package com.fauscrew.viewmodel

import com.fauscrew.platform.ApiLanguage
import com.fauscrew.platform.AuthProfileException
import com.fauscrew.platform.AuthRequestException
import com.fauscrew.platform.SocialAuthException
import com.fauscrew.platform.SocialSignInException
import java.io.IOException

/**
 * Display text for social-auth failures. Backend `error` text is shown as is (it already
 * follows `Accept-Language`); only locally produced failures get built-in copy.
 */
internal object SocialMessages {
    private fun pick(tr: String, en: String) = if (ApiLanguage.code == "tr") tr else en

    fun unavailable() = pick("Bu giriş yöntemi şu anda kullanılamıyor.", "This sign-in method is not available right now.")
    fun notConfigured(provider: com.fauscrew.platform.SocialProvider) = pick(
        "${provider.displayName} ile giriş henüz yapılandırılmadı. Şimdilik başka bir yöntemle devam edebilirsin.",
        "Sign in with ${provider.displayName} isn't set up yet. Please use another method for now.",
    )
    fun generic() = pick("İşlem tamamlanamadı. Lütfen tekrar deneyin.", "Something went wrong. Please try again.")
    fun offline() = pick("Bağlantı kurulamadı. Daha sonra tekrar deneyin.", "Could not connect. Please try again later.")
    fun onlyMethodHint() = pick("Önce şifre belirle ya da başka bir yöntem bağla.", "Set a password or link another method first.")

    fun of(error: Throwable): String = when (error) {
        is SocialAuthException -> error.serverMessage ?: generic()
        is SocialSignInException.Unavailable -> unavailable()
        is SocialSignInException.Provider -> error.message ?: generic()
        is AuthRequestException -> error.serverMessage ?: generic()
        is AuthProfileException -> error.serverMessage ?: generic()
        is IOException -> offline()
        else -> generic()
    }
}
