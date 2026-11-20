package com.fauscrew.viewmodel

import android.content.Context
import android.content.pm.ApplicationInfo
import com.fauscrew.platform.DebugCrashReport
import com.fauscrew.platform.OnlineClock
import com.fauscrew.platform.OnlineEffect
import com.fauscrew.platform.OnlineFailure
import com.fauscrew.platform.OnlineGameEngine
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.OnlineResultUi
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocket
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.RealtimeSocketListener
import com.fauscrew.platform.retryAfterSeconds
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** Debug builds only: decided at runtime so release builds need no BuildConfig. */
internal fun Context.isDebuggable(): Boolean = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

/**
 * The Android host of a FausCrewCore online engine for one match (iOS: `GameOnlineHost`):
 * it performs the engine's effects (HTTP, WebSocket, haptics), reports every outcome with
 * its tag and ticks the engine every 25 ms. It decides nothing about lobby, reconnect or
 * control. All engine calls happen on [scope]'s (main) thread.
 *
 * A non-null [debugLog] (debug builds) asks the engine for its netcode numbers: the final ones
 * go to [debugLog] once when the result appears; nothing is drawn on screen.
 *
 * An engine call that throws (a bridge `ok: false`, unreadable JSON) ends this match, not the
 * app: the session disposes itself, [failed] and [closed] turn true and [onFailure] gets the error.
 */
internal open class GameOnlineSession(
    private val scope: CoroutineScope,
    private val engine: OnlineGameEngine,
    private val http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val token: suspend () -> String?,
    private val sockets: RealtimeSocketFactory,
    private val onHaptic: (success: Boolean) -> Unit,
    private val clock: () -> Double = OnlineClock::now,
    private val tickMillis: Long = 25,
    private val debugLog: ((String) -> Unit)? = null,
    /** Null: the debug crash report (a no-op in release builds). */
    private val onFailure: ((Throwable) -> Unit)? = null,
) {
    private val mutableLobby = MutableStateFlow(OnlineLobbyUi())
    val lobby: StateFlow<OnlineLobbyUi> = mutableLobby.asStateFlow()
    private val mutableResult = MutableStateFlow(OnlineResultUi())
    val result: StateFlow<OnlineResultUi> = mutableResult.asStateFlow()
    private val mutableClosed = MutableStateFlow(false)
    /** The engine finished `leave`/cleanup; the screen may close. */
    val closed: StateFlow<Boolean> = mutableClosed.asStateFlow()
    private val mutableFps = MutableStateFlow<Int?>(null)
    /** Frames drawn in the last second, for the HUD's chip: null until a frame reports it, refreshed twice a second at most. */
    val fps: StateFlow<Int?> = mutableFps.asStateFlow()
    private var lastFpsAt = Double.NEGATIVE_INFINITY
    private var loggedFinalDiagnostics = false
    private val mutableFailed = MutableStateFlow(false)
    /** An engine call failed and this match was closed instead of the app. */
    val failed: StateFlow<Boolean> = mutableFailed.asStateFlow()

    var rematchExcludedSessionId: String? = null
        private set

    private var socket: RealtimeSocket? = null
    private var socketConnection = -1
    private val work = SupervisorJob(scope.coroutineContext[Job])
    protected var isDisposed = false
        private set

    fun start(isForeground: Boolean, isLandscape: Boolean) {
        send("start", mapOf("foreground" to isForeground, "landscape" to isLandscape))
        if (debugLog != null) send("setDiagnostics", mapOf("enabled" to true))
        scope.launch(work) {
            while (isActive) {
                delay(tickMillis)
                if (isDisposed) return@launch
                send("tick")
            }
        }
    }

    /** A user intent: setReady, setLandscape, setForeground, retry, retryResult, cancel, reclaim, leave, and the game's own. */
    fun intent(type: String, fields: Map<String, Any?> = emptyMap()) {
        send(type, fields)
    }

    /** Cleanup without a business leave (screen closed, rematch). */
    fun dispose() {
        if (isDisposed) return
        isDisposed = true
        work.cancel()
        socket?.close()
        socket = null
        // A failed engine may fail again here; the native handle is still released.
        runCatching { engine.event("disconnect", clock()) }
        runCatching { engine.close() }
    }

    /** One engine event and its output; a failing engine closes this match (see the class doc). */
    private fun send(type: String, fields: Map<String, Any?> = emptyMap()) {
        if (isDisposed) return
        guarded(Unit) { apply(engine.event(type, clock(), fields)) }
    }

    /** Runs one engine call; a failure ends this match and returns [fallback]. */
    protected fun <T> guarded(fallback: T, call: () -> T): T = try {
        call()
    } catch (cancel: CancellationException) {
        throw cancel
    } catch (error: Exception) {
        fail(error)
        fallback
    }

    private fun fail(error: Exception) {
        if (isDisposed) return
        val report = onFailure
        if (report != null) report(error) else DebugCrashReport.recordHandled("Online match closed after an engine error", error)
        dispose()
        mutableFailed.value = true
        mutableClosed.value = true
    }

    private fun apply(output: OnlineOutput) {
        if (isDisposed) return
        output.lobby?.let { mutableLobby.value = it }
        output.result?.let {
            mutableResult.value = it
            if (it.isVisible) logFinalDiagnostics()
        }
        rematchExcludedSessionId = output.rematchExcludedSessionId
        output.effects.forEach(::perform)
        if (output.closed) mutableClosed.value = true
        applied(output)
    }

    /** Game-specific models carried by [output], after the shared ones. */
    protected open fun applied(output: OnlineOutput) = Unit

    protected fun now(): Double = clock()

    /** Called after each sampled frame with the rate it reported; [fps] only follows it every half second. */
    protected fun sampleFps(reported: Int?) {
        if (reported == null) return
        val at = clock()
        if (at - lastFpsAt < FpsRefreshSeconds) return
        lastFpsAt = at
        mutableFps.value = reported
    }

    /** Frames keep sampling during the result phase, so the lines are current within half a second. */
    private fun logFinalDiagnostics() {
        val log = debugLog ?: return
        if (loggedFinalDiagnostics || engine.diagnostics.isEmpty()) return
        loggedFinalDiagnostics = true
        log(engine.diagnostics.joinToString("\n"))
    }

    private fun perform(effect: OnlineEffect) {
        when (effect) {
            is OnlineEffect.EnsureSession -> scope.launch(work) {
                try {
                    val bearer = token() ?: return@launch report("connectionFailed",
                        mapOf("failure" to "authenticationRequired", "connection" to effect.connection))
                    val response = http(PlatformHttpRequest(
                        path = effect.path, method = effect.method,
                        headers = mapOf("Authorization" to "Bearer $bearer", "Content-Type" to "application/json",
                            "Accept" to "application/json"),
                        body = effect.body.toByteArray(Charsets.UTF_8),
                    ))
                    report("sessionResponse", mapOf("status" to response.statusCode, "body" to response.body.decodeToString(),
                        "retryAfter" to retryAfterSeconds(response.headers["retry-after"]), "connection" to effect.connection))
                } catch (cancel: CancellationException) {
                    throw cancel
                } catch (_: Exception) {
                    report("connectionFailed", mapOf("failure" to "transport", "connection" to effect.connection))
                }
            }
            is OnlineEffect.OpenSocket -> {
                socket?.close()
                socket = null
                socketConnection = effect.connection
                scope.launch(work) {
                    try {
                        val bearer = token()
                        if (isDisposed || socketConnection != effect.connection) return@launch
                        if (bearer == null) {
                            report("connectionFailed", mapOf("failure" to "authenticationRequired", "connection" to effect.connection))
                            return@launch
                        }
                        socket = sockets.open(effect.path, effect.query, bearer, listener(effect.connection))
                    } catch (cancel: CancellationException) {
                        throw cancel
                    } catch (_: Exception) {
                        report("connectionFailed", mapOf("failure" to "transport", "connection" to effect.connection))
                    }
                }
            }
            OnlineEffect.CloseSocket -> {
                socket?.close()
                socket = null
                socketConnection = -1
            }
            is OnlineEffect.Send -> {
                val sent = effect.connection == socketConnection && socket?.send(effect.text) == true
                if (!sent) report("sendFailed", mapOf("failure" to "notConnected", "connection" to effect.connection))
            }
            is OnlineEffect.FetchResult -> scope.launch(work) {
                try {
                    val bearer = token() ?: return@launch report("resultFailed", mapOf("request" to effect.request))
                    val response = http(PlatformHttpRequest(path = effect.path, method = effect.method,
                        headers = mapOf("Authorization" to "Bearer $bearer", "Accept" to "application/json")))
                    report("resultResponse", mapOf("status" to response.statusCode, "body" to response.body.decodeToString(),
                        "retryAfter" to retryAfterSeconds(response.headers["retry-after"]), "request" to effect.request))
                } catch (cancel: CancellationException) {
                    throw cancel
                } catch (_: Exception) {
                    report("resultFailed", mapOf("request" to effect.request))
                }
            }
            is OnlineEffect.Haptic -> onHaptic(effect.success)
        }
    }

    private fun listener(connection: Int) = object : RealtimeSocketListener {
        override fun onOpen() = post { report("socketOpened", mapOf("connection" to connection)) }
        override fun onText(text: String) = post { guarded(Unit) { apply(engine.receive(text, connection, clock())) } }
        override fun onFailure(failure: OnlineFailure) = post {
            val fields = when (failure) {
                OnlineFailure.Transport -> mapOf("failure" to "transport")
                OnlineFailure.Forbidden -> mapOf("failure" to "forbidden")
                is OnlineFailure.Http -> mapOf("failure" to "http", "status" to failure.status,
                    "retryAfter" to failure.retryAfterSeconds)
            }
            report("connectionFailed", fields + ("connection" to connection))
        }
    }

    private fun post(block: () -> Unit) {
        scope.launch(work) { if (!isDisposed) block() }
    }

    private fun report(type: String, fields: Map<String, Any?>) = send(type, fields)
}

private const val FpsRefreshSeconds = 0.5
