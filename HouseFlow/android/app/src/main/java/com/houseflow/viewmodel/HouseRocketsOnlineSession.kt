package com.houseflow.viewmodel

import com.houseflow.platform.HouseRocketsOnlineEngine
import com.houseflow.platform.OnlineClock
import com.houseflow.platform.OnlineEffect
import com.houseflow.platform.OnlineFailure
import com.houseflow.platform.OnlineFlightUi
import com.houseflow.platform.OnlineLobbyUi
import com.houseflow.platform.OnlineOutput
import com.houseflow.platform.OnlineResultUi
import com.houseflow.platform.PlatformHttpRequest
import com.houseflow.platform.PlatformHttpResponse
import com.houseflow.platform.RealtimeSocket
import com.houseflow.platform.RealtimeSocketFactory
import com.houseflow.platform.RealtimeSocketListener
import com.houseflow.platform.RocketsFrame
import com.houseflow.platform.retryAfterSeconds
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * The Android host of HouseFlowCore's online engine for one match: it performs the
 * engine's effects (HTTP, WebSocket, haptics), reports every outcome with its tag and
 * ticks the engine every 25 ms. It decides nothing about lobby, reconnect or control.
 * All engine calls happen on [scope]'s (main) thread.
 */
internal class HouseRocketsOnlineSession(
    private val scope: CoroutineScope,
    private val engine: HouseRocketsOnlineEngine,
    private val http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val token: suspend () -> String?,
    private val sockets: RealtimeSocketFactory,
    private val onHaptic: (success: Boolean) -> Unit,
    private val clock: () -> Double = OnlineClock::now,
    private val tickMillis: Long = 25,
) {
    private val mutableLobby = MutableStateFlow(OnlineLobbyUi())
    val lobby: StateFlow<OnlineLobbyUi> = mutableLobby.asStateFlow()
    private val mutableResult = MutableStateFlow(OnlineResultUi())
    val result: StateFlow<OnlineResultUi> = mutableResult.asStateFlow()
    private val mutableFrame = MutableStateFlow<RocketsFrame?>(null)
    /** The interpolated flight; refreshed once per rendered frame by [sampleFrame]. */
    val frame: StateFlow<RocketsFrame?> = mutableFrame.asStateFlow()
    private val mutableFlight = MutableStateFlow<OnlineFlightUi?>(null)
    val flight: StateFlow<OnlineFlightUi?> = mutableFlight.asStateFlow()
    private val mutableClosed = MutableStateFlow(false)
    /** The engine finished `leave`/cleanup; the screen may close. */
    val closed: StateFlow<Boolean> = mutableClosed.asStateFlow()

    var rematchExcludedSessionId: String? = null
        private set

    private var socket: RealtimeSocket? = null
    private var socketConnection = -1
    private var tickJob: Job? = null
    private var isDisposed = false

    fun start(isForeground: Boolean, isLandscape: Boolean) {
        apply(engine.event("start", clock(), mapOf("foreground" to isForeground, "landscape" to isLandscape)))
        tickJob = scope.launch {
            while (isActive) {
                delay(tickMillis)
                if (isDisposed) return@launch
                apply(engine.event("tick", clock()))
            }
        }
    }

    /** A user intent: setReady, setLandscape, setForeground, retry, retryResult, cancel, reclaim, leave, steer, endSteering, adjust, reduceMotion. */
    fun intent(type: String, fields: Map<String, Any?> = emptyMap()) {
        if (isDisposed) return
        apply(engine.event(type, clock(), fields))
    }

    fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float) {
        if (!isDisposed) engine.viewport(width, height, hudWidth, hudHeight)
    }

    fun sampleFrame() {
        if (isDisposed) return
        val sampled = engine.frame(clock())
        mutableFrame.value = sampled?.first
        if (mutableFlight.value != sampled?.second) mutableFlight.value = sampled?.second
    }

    /** Cleanup without a business leave (screen closed, rematch). */
    fun dispose() {
        if (isDisposed) return
        isDisposed = true
        tickJob?.cancel()
        socket?.close()
        socket = null
        engine.event("disconnect", clock())
        engine.close()
    }

    private fun apply(output: OnlineOutput) {
        if (isDisposed) return
        output.lobby?.let { mutableLobby.value = it }
        output.result?.let { mutableResult.value = it }
        rematchExcludedSessionId = output.rematchExcludedSessionId
        output.effects.forEach(::perform)
        if (output.closed) mutableClosed.value = true
        if (!mutableLobby.value.hasGame && mutableFrame.value != null) sampleFrame()
    }

    private fun perform(effect: OnlineEffect) {
        when (effect) {
            is OnlineEffect.EnsureSession -> scope.launch {
                val bearer = token() ?: return@launch report("connectionFailed",
                    mapOf("failure" to "authenticationRequired", "connection" to effect.connection))
                try {
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
                scope.launch {
                    val bearer = token()
                    if (isDisposed || socketConnection != effect.connection) return@launch
                    if (bearer == null) {
                        report("connectionFailed", mapOf("failure" to "authenticationRequired", "connection" to effect.connection))
                        return@launch
                    }
                    socket = sockets.open(effect.path, effect.query, bearer, listener(effect.connection))
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
            is OnlineEffect.FetchResult -> scope.launch {
                val bearer = token() ?: return@launch report("resultFailed", mapOf("request" to effect.request))
                try {
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
        override fun onText(text: String) = post { apply(engine.receive(text, connection, clock())) }
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
        scope.launch { if (!isDisposed) block() }
    }

    private fun report(type: String, fields: Map<String, Any?>) {
        if (isDisposed) return
        apply(engine.event(type, clock(), fields))
    }
}
