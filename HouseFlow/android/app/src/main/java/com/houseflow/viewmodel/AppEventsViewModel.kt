package com.houseflow.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.houseflow.platform.AppEventsEffect
import com.houseflow.platform.AppEventsEngine
import com.houseflow.platform.AppEventsNative
import com.houseflow.platform.KeystoreSessionStore
import com.houseflow.platform.OkHttpRealtimeSocketFactory
import com.houseflow.platform.OnlineClock
import com.houseflow.platform.OnlineFailure
import com.houseflow.platform.RealtimeSocket
import com.houseflow.platform.RealtimeSocketFactory
import com.houseflow.platform.RealtimeSocketListener
import com.houseflow.platform.SessionField
import com.houseflow.platform.SessionReadResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal sealed interface AppEventsRequest {
    data class Refresh(val profile: Boolean, val houseId: String?) : AppEventsRequest
    data object SignOut : AppEventsRequest
}

/**
 * Hosts the `/api/v1/events` channel (rules in HouseFlowCore): one socket while the app is
 * in the foreground and signed in. It emits refresh requests that the auth and house view
 * models serve over HTTP; the signals carry no data.
 */
internal class AppEventsViewModel(
    private val engine: AppEventsEngine,
    private val sockets: RealtimeSocketFactory,
    private val token: suspend () -> String?,
    private val clock: () -> Double = OnlineClock::now,
) : ViewModel() {
    private val mutableRequests = Channel<AppEventsRequest>(Channel.UNLIMITED)
    val requests: Flow<AppEventsRequest> = mutableRequests.receiveAsFlow()

    private var socket: RealtimeSocket? = null
    private var socketConnection = -1
    private var tickJob: Job? = null
    private var active = false

    fun update(foreground: Boolean, authenticated: Boolean) {
        perform(engine.event("setActive", clock(), mapOf("foreground" to foreground, "authenticated" to authenticated)))
        active = foreground && authenticated
        if (active && tickJob == null) {
            tickJob = viewModelScope.launch {
                while (isActive) {
                    delay(250)
                    perform(engine.event("tick", clock()))
                }
            }
        } else if (!active) {
            tickJob?.cancel()
            tickJob = null
        }
    }

    fun setSelectedHouse(houseId: String?) {
        perform(engine.event("setSelectedHouse", clock(), mapOf("houseId" to houseId)))
    }

    override fun onCleared() {
        closeSocket()
        engine.close()
    }

    private fun perform(effects: List<AppEventsEffect>) {
        effects.forEach { effect ->
            when (effect) {
                is AppEventsEffect.OpenSocket -> open(effect)
                AppEventsEffect.CloseSocket -> closeSocket()
                is AppEventsEffect.Refresh -> mutableRequests.trySend(AppEventsRequest.Refresh(effect.profile, effect.houseId))
                AppEventsEffect.SignedOut -> mutableRequests.trySend(AppEventsRequest.SignOut)
            }
        }
    }

    private fun open(effect: AppEventsEffect.OpenSocket) {
        closeSocket()
        socketConnection = effect.connection
        viewModelScope.launch {
            val bearer = token()
            if (socketConnection != effect.connection) return@launch
            if (bearer == null) {
                report("connectionFailed", effect.connection, mapOf("status" to 401))
                return@launch
            }
            socket = sockets.open(effect.path, "", bearer, object : RealtimeSocketListener {
                override fun onOpen() = post { report("socketOpened", effect.connection) }
                override fun onText(text: String) = post { report("received", effect.connection, mapOf("text" to text)) }
                override fun onFailure(failure: OnlineFailure) = post {
                    val status = (failure as? OnlineFailure.Http)?.status ?: if (failure == OnlineFailure.Forbidden) 403 else null
                    report("connectionFailed", effect.connection, mapOf("status" to status))
                }
            })
        }
    }

    private fun closeSocket() {
        socket?.close()
        socket = null
        socketConnection = -1
    }

    private fun post(block: () -> Unit) {
        viewModelScope.launch { block() }
    }

    private fun report(type: String, connection: Int, fields: Map<String, Any?> = emptyMap()) {
        if (connection != socketConnection && type != "connectionFailed") return
        perform(engine.event(type, clock(), fields + ("connection" to connection)))
    }

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val appContext = context.applicationContext

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            val store = KeystoreSessionStore(appContext)
            return AppEventsViewModel(
                engine = AppEventsNative.engine(),
                sockets = OkHttpRealtimeSocketFactory(),
                token = { withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value } },
            ) as T
        }
    }
}
