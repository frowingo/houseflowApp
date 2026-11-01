package com.fauscrew.viewmodel

import com.fauscrew.platform.HouseRocketsOnlineEngine
import com.fauscrew.platform.OnlineClock
import com.fauscrew.platform.OnlineFlightUi
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.RocketsFrame
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** House Rockets' online match: the shared host plus the interpolated flight. */
internal class HouseRocketsOnlineSession(
    scope: CoroutineScope,
    private val engine: HouseRocketsOnlineEngine,
    http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    token: suspend () -> String?,
    sockets: RealtimeSocketFactory,
    onHaptic: (success: Boolean) -> Unit,
    clock: () -> Double = OnlineClock::now,
    tickMillis: Long = 25,
) : GameOnlineSession(scope, engine, http, token, sockets, onHaptic, clock, tickMillis) {
    private val mutableFrame = MutableStateFlow<RocketsFrame?>(null)
    /** The interpolated flight; refreshed once per rendered frame by [sampleFrame]. */
    val frame: StateFlow<RocketsFrame?> = mutableFrame.asStateFlow()
    private val mutableFlight = MutableStateFlow<OnlineFlightUi?>(null)
    val flight: StateFlow<OnlineFlightUi?> = mutableFlight.asStateFlow()

    fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float) {
        if (!isDisposed) engine.viewport(width, height, hudWidth, hudHeight)
    }

    fun sampleFrame() {
        if (isDisposed) return
        val sampled = engine.frame(now())
        mutableFrame.value = sampled?.first
        if (mutableFlight.value != sampled?.second) mutableFlight.value = sampled?.second
    }

    override fun applied(output: OnlineOutput) {
        if (!lobby.value.hasGame && mutableFrame.value != null) sampleFrame()
    }
}
