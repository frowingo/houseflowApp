package com.fauscrew.platform

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Base64
import androidx.activity.ComponentActivity
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.FacebookSdk
import com.facebook.Profile
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.fauscrew.R
import com.snap.loginkit.AccessTokenResultCallback
import com.snap.loginkit.LoginResultCallback
import com.snap.loginkit.SnapLogin
import com.snap.loginkit.SnapLoginProvider
import com.snap.loginkit.UserDataQuery
import com.snap.loginkit.UserDataResultCallback
import com.snap.loginkit.exceptions.AccessTokenException
import com.snap.loginkit.exceptions.LoginException
import com.snap.loginkit.exceptions.UserDataException
import com.snap.loginkit.models.UserDataResult
import java.lang.ref.WeakReference
import java.security.SecureRandom
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine

/** The foreground activity provider SDKs present from. MainActivity attaches/detaches itself. */
internal object SocialActivityHolder {
    @Volatile private var reference: WeakReference<ComponentActivity>? = null
    val current: ComponentActivity? get() = reference?.get()

    fun attach(activity: ComponentActivity) { reference = WeakReference(activity) }
    fun detach(activity: ComponentActivity) { if (reference?.get() === activity) reference = null }
}

/** IDs ship as `YOUR_…` placeholders; such a provider stays unavailable. */
internal fun isConfiguredSocialId(value: String): Boolean = value.isNotBlank() && !value.contains("YOUR_")

internal object SocialNonce {
    private val random = SecureRandom()

    /** URL-safe, whitespace-free, fresh per attempt. */
    fun create(): String = ByteArray(32).also(random::nextBytes)
        .let { Base64.encodeToString(it, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING) }
}

/**
 * Google via Credential Manager. `setServerClientId` takes the *web* client ID; the ID token goes to
 * the backend as `idToken`, and the raw nonce given to the SDK is sent unchanged as `nonce`.
 */
internal class GoogleCredentialAdapter(
    private val appContext: Context,
    private val activity: () -> ComponentActivity?,
) : SocialCredentialProvider {
    private val manager by lazy { CredentialManager.create(appContext) }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override suspend fun credential(provider: SocialProvider): SocialCredential {
        val webClientId = appContext.getString(R.string.google_web_client_id)
        if (provider != SocialProvider.GOOGLE || !isConfiguredSocialId(webClientId)) throw SocialSignInException.Unavailable(provider)
        val host = activity() ?: throw SocialSignInException.Provider(null)
        val nonce = SocialNonce.create()
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(GetSignInWithGoogleOption.Builder(webClientId).setNonce(nonce).build())
            .build()
        val response = try {
            manager.getCredential(host, request)
        } catch (_: GetCredentialCancellationException) {
            throw SocialSignInException.Cancelled()
        } catch (error: GetCredentialException) {
            throw SocialSignInException.Provider(error.message)
        }
        val credential = response.credential
        if (credential !is CustomCredential || credential.type !in GOOGLE_TYPES) throw SocialSignInException.Provider(null)
        val google = try { GoogleIdTokenCredential.createFrom(credential.data) } catch (error: Exception) {
            throw SocialSignInException.Provider(error.message)
        }
        return SocialCredential(idToken = google.idToken, nonce = nonce, firstName = google.givenName, lastName = google.familyName)
    }

    /** Also makes the next sign-in show the account chooser again. */
    override fun signOutAll() {
        if (!isConfiguredSocialId(appContext.getString(R.string.google_web_client_id))) return
        scope.launch { runCatching { manager.clearCredentialState(ClearCredentialStateRequest()) } }
    }

    private companion object {
        val GOOGLE_TYPES = setOf(
            GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL,
            GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL,
        )
    }
}

/** Facebook classic login (Android has no Limited Login): the access token goes as `accessToken`. */
internal class FacebookCredentialAdapter(
    private val appContext: Context,
    private val activity: () -> ComponentActivity?,
) : SocialCredentialProvider {
    private val configured get() = isConfiguredSocialId(appContext.getString(R.string.facebook_app_id))

    override suspend fun credential(provider: SocialProvider): SocialCredential {
        if (provider != SocialProvider.FACEBOOK || !configured) throw SocialSignInException.Unavailable(provider)
        val host = activity() ?: throw SocialSignInException.Provider(null)
        ensureInitialized()
        val manager = LoginManager.getInstance()
        // Each attempt starts from a clean SDK session so the token is fresh.
        manager.logOut()
        val callbacks = CallbackManager.Factory.create()
        val result = try {
            suspendCancellableCoroutine { continuation ->
                manager.registerCallback(callbacks, object : FacebookCallback<LoginResult> {
                    override fun onSuccess(result: LoginResult) { if (continuation.isActive) continuation.resume(result) }
                    override fun onCancel() {
                        if (continuation.isActive) continuation.resumeWithException(SocialSignInException.Cancelled())
                    }
                    override fun onError(error: FacebookException) {
                        if (continuation.isActive) continuation.resumeWithException(SocialSignInException.Provider(error.message))
                    }
                })
                manager.logIn(host, callbacks, listOf("public_profile", "email"))
            }
        } finally {
            manager.unregisterCallback(callbacks)
        }
        val profile = Profile.getCurrentProfile()
        return SocialCredential(accessToken = result.accessToken.token, firstName = profile?.firstName, lastName = profile?.lastName)
    }

    override fun signOutAll() {
        if (!configured) return
        ensureInitialized()
        LoginManager.getInstance().logOut()
    }

    @Suppress("DEPRECATION")
    private fun ensureInitialized() {
        if (!FacebookSdk.isInitialized()) FacebookSdk.sdkInitialize(appContext)
    }
}

/**
 * Snap Login Kit (display name + external ID). The access token goes as `accessToken`. Snapchat never
 * shares an email, so a new user always continues with `needsEmail`; the display name pre-fills it.
 */
internal class SnapchatCredentialAdapter(
    private val appContext: Context,
    private val activity: () -> ComponentActivity?,
) : SocialCredentialProvider {
    private val configured get() = isConfiguredSocialId(appContext.getString(R.string.snap_client_id))

    override suspend fun credential(provider: SocialProvider): SocialCredential {
        if (provider != SocialProvider.SNAPCHAT || !configured) throw SocialSignInException.Unavailable(provider)
        val host = activity() ?: throw SocialSignInException.Provider(null)
        val login = SnapLoginProvider.get(host)
        // Clearing first forces a fresh grant instead of reusing a stored token.
        login.clearToken()
        grant(host, login)
        val token = suspendCancellableCoroutine { continuation ->
            login.fetchAccessToken(object : AccessTokenResultCallback {
                override fun onSuccess(accessToken: String) { if (continuation.isActive) continuation.resume(accessToken) }
                override fun onFailure(exception: AccessTokenException) {
                    if (continuation.isActive) continuation.resumeWithException(SocialSignInException.Provider(exception.message))
                }
            })
        }
        return SocialCredential(accessToken = token, firstName = displayName(login))
    }

    override fun signOutAll() {
        if (configured) SnapLoginProvider.get(appContext).clearToken()
    }

    /**
     * Login Kit never reports a user who leaves Snapchat without approving. If the app comes back to
     * the foreground and no result follows shortly, the attempt counts as cancelled.
     */
    private suspend fun grant(host: ComponentActivity, login: SnapLogin) = suspendCancellableCoroutine { continuation ->
        val finished = AtomicBoolean(false)
        val main = Handler(Looper.getMainLooper())
        var observer: LifecycleEventObserver? = null
        fun finish(error: Throwable?) {
            if (!finished.compareAndSet(false, true)) return
            main.post { observer?.let(host.lifecycle::removeObserver) }
            if (!continuation.isActive) return
            if (error == null) continuation.resume(Unit) else continuation.resumeWithException(error)
        }
        var leftApp = false
        observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> leftApp = true
                Lifecycle.Event.ON_RESUME -> if (leftApp) main.postDelayed({ finish(SocialSignInException.Cancelled()) }, RETURN_GRACE_MS)
                else -> Unit
            }
        }
        main.post { observer?.let(host.lifecycle::addObserver) }
        continuation.invokeOnCancellation { finished.set(true); main.post { observer?.let(host.lifecycle::removeObserver) } }
        login.startTokenGrant(object : LoginResultCallback {
            override fun onStart() = Unit
            override fun onSuccess(accessToken: String) = finish(null)
            override fun onFailure(exception: LoginException) = finish(SocialSignInException.Provider(exception.message))
        })
    }

    /** Best effort: a missing display name only leaves the name fields empty. */
    private suspend fun displayName(login: SnapLogin): String? = suspendCancellableCoroutine { continuation ->
        login.fetchUserData(UserDataQuery.newBuilder().withDisplayName().build(), object : UserDataResultCallback {
            override fun onSuccess(result: UserDataResult) {
                if (continuation.isActive) continuation.resume(result.data?.meData?.displayName)
            }
            override fun onFailure(exception: UserDataException) { if (continuation.isActive) continuation.resume(null) }
        })
    }

    private companion object {
        const val RETURN_GRACE_MS = 2_000L
    }
}
