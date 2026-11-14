package com.fauscrew.viewmodel

import com.fauscrew.platform.OnlineClock
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchFlip
import com.fauscrew.platform.SwitchOnlineEngine
import com.fauscrew.platform.SwitchOnlineFrame
import com.fauscrew.platform.SwitchRoom
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The Faus Switch online room and race: the shared host, the robot colors, the flip and the drawn frame. */
internal class FausSwitchOnlineSession(
    scope: CoroutineScope,
    private val engine: SwitchOnlineEngine,
    http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    token: suspend () -> String?,
    sockets: RealtimeSocketFactory,
    onHaptic: (success: Boolean) -> Unit,
    clock: () -> Double = OnlineClock::now,
    tickMillis: Long = 25,
) : GameOnlineSession(scope, engine, http, token, sockets, onHaptic, clock, tickMillis) {
    private val mutableRoom = MutableStateFlow(SwitchRoom())
    /** Faus Switch's lobby keys (colors, rematch room, race countdown). */
    val room: StateFlow<SwitchRoom> = mutableRoom.asStateFlow()

    /** The host's uptime, for the deadlines the lobby model carries. */
    fun uptime(): Double = now()

    /** The tap; the answer says whether the robot flipped. Null after dispose. */
    fun flip(): SwitchFlip? {
        if (isDisposed) return null
        intent("flip")
        return engine.lastFlip
    }

    fun selectColor(color: SwitchColor) = intent("selectColor", mapOf("color" to color.raw))

    fun setReduceMotion(enabled: Boolean) = intent("setReduceMotion", mapOf("enabled" to enabled))

    fun viewport(width: Double, height: Double) {
        if (!isDisposed) engine.viewport(width, height)
    }

    /** One frame per rendered frame: each race event is in exactly one. Null after dispose. */
    fun frame(): SwitchOnlineFrame? = if (isDisposed) null else engine.frame(now())

    override fun applied(output: OnlineOutput) {
        if (output.lobby != null) mutableRoom.value = engine.room
    }
}
