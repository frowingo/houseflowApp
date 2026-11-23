package com.fauscrew.push

import android.content.Context
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.NotificationRepository
import com.fauscrew.platform.PushRegistrationEffect
import com.fauscrew.platform.PushRegistrationEngine
import com.fauscrew.platform.PushRegistrationResult
import com.fauscrew.platform.PushRegistrationNative
import com.fauscrew.platform.PushSignOutReason
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Performs what Core's push registration rules decide: registers the FCM token with the backend,
 * and on sign-out unregisters and deletes it. Everything here runs on [scope]'s (main) dispatcher,
 * because the engine is not thread-safe; only the HTTP and session reads hop off it.
 * Failures are logged and never shown or retried (Core already decided).
 */
internal class PushRegistrationCoordinator(
    private val engine: PushRegistrationEngine,
    private val tokens: PushTokenProviding,
    private val repository: NotificationRepository,
    private val readJwt: suspend () -> String?,
    latestTokens: Flow<String?>,
    private val scope: CoroutineScope,
) {
    private var signOuts = 0

    init {
        // One long-lived collector: tokens FCM issues later (refreshes, the one after a deletion).
        scope.launch { latestTokens.filterNotNull().collect(::setToken) }
        scope.launch {
            val before = signOuts
            val token = tokens.token()
            // A token fetched before a sign-out may be the one that was just deleted.
            if (signOuts == before) setToken(token)
        }
    }

    /** The fully signed-in user, or null. */
    fun setSession(userId: String?) {
        handle(engine.event("setSession", mapOf("userId" to userId)))
    }

    /**
     * Call BEFORE the stored JWT is cleared: it is read here, before this returns, for the DELETE
     * that runs afterwards in the background. Never fails the sign-out.
     */
    suspend fun signOut(reason: PushSignOutReason) {
        val effects = engine.event("signOut", mapOf("reason" to reason.wire)).effects
        if (effects.isEmpty()) return
        signOuts += 1
        val unregister = effects.filterIsInstance<PushRegistrationEffect.Unregister>().firstOrNull()
        // The engine is cleaning up now and only `cleanUp` ends that, so a cancelled caller
        // (double logout, cleared view model) must not stop here.
        withContext(NonCancellable) {
            val jwt = if (unregister != null) jwtOrNull() else null
            scope.launch { cleanUp(unregister?.token, jwt) }
        }
    }

    private fun setToken(token: String?) {
        handle(engine.event("setToken", mapOf("token" to token)))
    }

    private fun handle(result: PushRegistrationResult) {
        result.effects.filterIsInstance<PushRegistrationEffect.Register>().forEach { register(it.token) }
    }

    private fun register(token: String) {
        scope.launch {
            val jwt = jwtOrNull() ?: return@launch
            attempt("register") { repository.registerDevice(token, jwt) }
        }
    }

    /** DELETE first, then the local token; a fresh token is then fetched so a following login can register. */
    private suspend fun cleanUp(unregisteredToken: String?, jwt: String?) {
        if (unregisteredToken != null) {
            if (jwt != null) attempt("unregister") { repository.unregisterDevice(unregisteredToken, jwt) }
            engine.event("unregisterFinished")
        }
        attempt("delete token") { tokens.delete() }
        engine.event("localTokenDeleted")
        setToken(tokens.token())
    }

    /** A session that cannot be read counts as signed out here. */
    private suspend fun jwtOrNull(): String? = try {
        readJwt()
    } catch (cancel: CancellationException) {
        throw cancel
    } catch (error: Exception) {
        PushLog.d("session read failed: ${error.javaClass.simpleName}")
        null
    }

    private suspend fun attempt(what: String, block: suspend () -> Unit) {
        try {
            block()
        } catch (cancel: CancellationException) {
            throw cancel
        } catch (error: Exception) {
            PushLog.d("$what failed: ${error.javaClass.simpleName}")
        }
    }
}

/** The process-wide instance, started from `FausCrewApplication`. Calls before [init] are ignored. */
internal object PushRegistrationHost {
    @Volatile private var coordinator: PushRegistrationCoordinator? = null

    fun init(context: Context) {
        if (coordinator != null) return
        val store = KeystoreSessionStore(context)
        coordinator = PushRegistrationCoordinator(
            engine = PushRegistrationNative.engine(),
            tokens = FirebasePushTokenProvider(),
            repository = NotificationRepository.live(AndroidHttpAdapter.live()),
            readJwt = { withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value } },
            latestTokens = PushTokens.latest,
            scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
        )
    }

    fun setSession(userId: String?) {
        coordinator?.setSession(userId)
    }

    suspend fun signOut(reason: PushSignOutReason) {
        coordinator?.signOut(reason)
    }
}
