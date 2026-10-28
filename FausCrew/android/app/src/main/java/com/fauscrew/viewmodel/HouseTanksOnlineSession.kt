package com.fauscrew.viewmodel

import com.fauscrew.platform.OnlineClock
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.TanksOnlineEngine
import com.fauscrew.platform.TanksOnlineFrame
import com.fauscrew.platform.TanksOnlinePreview
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The FauseTanks online room and match: the shared host, the drawn arena and the button. */
internal class HouseTanksOnlineSession(
    scope: CoroutineScope,
    private val engine: TanksOnlineEngine,
    http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    token: suspend () -> String?,
    sockets: RealtimeSocketFactory,
    onHaptic: (success: Boolean) -> Unit,
    clock: () -> Double = OnlineClock::now,
    tickMillis: Long = 25,
) : GameOnlineSession(scope, engine, http, token, sockets, onHaptic, clock, tickMillis) {
    private val mutablePreview = MutableStateFlow<TanksOnlinePreview?>(null)
    /** The map and seated tanks from the match countdown on; null before. */
    val preview: StateFlow<TanksOnlinePreview?> = mutablePreview.asStateFlow()

    /** The host's uptime, for the deadlines the lobby model carries. */
    fun uptime(): Double = now()

    /** The single button; the engine sends only changes it is allowed to send. */
    fun press() = intent("press")
    fun release() = intent("release")

    /** The vote for the next round from the in-game panel. */
    fun setRoundReady(ready: Boolean) = intent("setRoundReady", mapOf("ready" to ready))

    /** One frame per rendered frame: each server event is in exactly one. Null after dispose. */
    fun frame(): TanksOnlineFrame? = if (isDisposed) null else engine.frame(now())

    override fun applied(output: OnlineOutput) {
        if (output.previewChanged) mutablePreview.value = output.preview
    }
}
