package com.houseflow.platform

import android.content.Context
import com.houseflow.R
import com.houseflow.androidbridge.HouseFlowAndroidBridge
import java.io.IOException

/** API provider numbers. Apple has no Android flow on the backend, so it is never offered here. */
internal enum class SocialProvider(val number: Int, val slug: String, val displayName: String) {
    GOOGLE(1, "google", "Google"),
    APPLE(2, "apple", "Apple"),
    FACEBOOK(3, "facebook", "Facebook"),
    SNAPCHAT(4, "snapchat", "Snapchat");

    companion object {
        fun of(number: Int): SocialProvider? = entries.firstOrNull { it.number == number }
        /** Providers that may ever show a button on Android. */
        val androidProviders = listOf(GOOGLE, FACEBOOK, SNAPCHAT)
    }
}

/** What a provider SDK produced for one attempt. Never logged, persisted or sent elsewhere. */
internal data class SocialCredential(
    val idToken: String? = null,
    val accessToken: String? = null,
    val nonce: String? = null,
    val authorizationCode: String? = null,
    val firstName: String? = null,
    val lastName: String? = null,
) {
    override fun toString() = "SocialCredential(<redacted>)"
}

/** Non-2xx backend answer. Branch on [status]; [serverMessage] is localized display text. */
internal class SocialAuthException(val status: Int?, val serverMessage: String?) :
    IOException(serverMessage ?: "Social sign-in failed")

internal sealed class SocialSignInException : Exception() {
    /** The user closed the provider sheet. */
    class Cancelled : SocialSignInException()
    /** No SDK/config for this provider in this build. */
    class Unavailable(val provider: SocialProvider) : SocialSignInException()
    class Provider(override val message: String?) : SocialSignInException()
}

/** Gets a fresh provider credential per attempt; one adapter per provider SDK. */
internal interface SocialCredentialProvider {
    suspend fun credential(provider: SocialProvider): SocialCredential
    /** Closes every provider SDK session (logout, account deletion, a rejected token). */
    fun signOutAll()
}

internal class SocialCredentialRouter(
    private val adapters: Map<SocialProvider, SocialCredentialProvider>,
) : SocialCredentialProvider {
    override suspend fun credential(provider: SocialProvider): SocialCredential =
        adapters[provider]?.credential(provider) ?: throw SocialSignInException.Unavailable(provider)

    override fun signOutAll() = adapters.values.forEach { it.signOutAll() }
}

/**
 * Every provider in `R.array.houseflow_social_providers` gets a button (Apple never does on Android).
 * One whose ID is still a `YOUR_…` placeholder is shown but not configured: tapping it explains
 * that instead of opening the SDK.
 */
internal data class SocialAuthConfig(
    val shown: List<SocialProvider>,
    val configured: Set<SocialProvider> = shown.toSet(),
) {
    fun isShown(provider: SocialProvider) = provider in shown
    fun isConfigured(provider: SocialProvider) = provider in shown && provider in configured

    companion object {
        fun load(context: Context): SocialAuthConfig {
            val names = context.resources.getStringArray(R.array.houseflow_social_providers).toSet()
            val ids = mapOf(
                SocialProvider.GOOGLE to R.string.google_web_client_id,
                SocialProvider.FACEBOOK to R.string.facebook_app_id,
                SocialProvider.SNAPCHAT to R.string.snap_client_id,
            )
            val shown = SocialProvider.androidProviders.filter { it.slug in names }
            val configured = shown.filter { provider ->
                ids[provider]?.let { isConfiguredSocialId(context.getString(it)) } == true
            }
            return SocialAuthConfig(shown, configured.toSet())
        }
    }
}

/** Core's social wire contract behind the JNI bridge; replaced by a fake in unit tests. */
internal interface SocialWire {
    fun slug(provider: SocialProvider): String
    fun signInBody(credential: SocialCredential, language: String): String
    fun completeCodeBody(pendingToken: String, email: String): String
    fun completeBody(pendingToken: String, email: String, code: String, firstName: String, lastName: String, language: String): String
    /** action: signIn, accepted, linked. */
    fun result(action: String, status: Int, body: String): String
}

internal object NativeSocialWire : SocialWire {
    private val checked by lazy { check(HouseFlowAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun slug(provider: SocialProvider): String {
        checked
        return HouseFlowAndroidBridge.socialProviderSlug(provider.number)
    }

    override fun signInBody(credential: SocialCredential, language: String): String {
        checked
        return HouseFlowAndroidBridge.socialSignInRequestBody(
            credential.idToken.orEmpty(), credential.accessToken.orEmpty(), credential.nonce.orEmpty(),
            credential.authorizationCode.orEmpty(), credential.firstName.orEmpty(), credential.lastName.orEmpty(), language,
        )
    }

    override fun completeCodeBody(pendingToken: String, email: String): String {
        checked
        return HouseFlowAndroidBridge.socialCompleteCodeRequestBody(pendingToken, email)
    }

    override fun completeBody(pendingToken: String, email: String, code: String, firstName: String, lastName: String, language: String): String {
        checked
        return HouseFlowAndroidBridge.socialCompleteRequestBody(pendingToken, email, code, firstName, lastName, language)
    }

    override fun result(action: String, status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.socialResponse(action, status, body)
    }
}
