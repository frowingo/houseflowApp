package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import java.util.concurrent.TimeUnit
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject

/** A lobby participant as the online lobby card shows it. */
internal data class OnlineParticipant(val playerId: String, val statusKey: String, val isReady: Boolean, val isLocal: Boolean)

/** Screen-ready lobby state from Core (`HouseRocketsOnlineLobbyState` + copy rules). */
internal data class OnlineLobbyUi(
    val connection: String = "idle",
    val isSynced: Boolean = false,
    val isLobby: Boolean = false,
    val isTerminal: Boolean = false,
    val isLeaving: Boolean = false,
    val isForeground: Boolean = true,
    val controlTransferred: Boolean = false,
    val hasGame: Boolean = false,
    val sessionState: String? = null,
    val statusKey: String = "house_rockets_online_connecting",
    val detailKey: String = "house_rockets_online_connecting_detail",
    val showsProgress: Boolean = true,
    val issueKey: String? = null,
    val connectionTitleKey: String = "house_rockets_recovering",
    val connectionDetailKey: String = "house_rockets_recovering_detail",
    val minimumPlayers: Int = 2,
    /** Host uptime (seconds) before which a retry is not allowed. */
    val retryNotBefore: Double? = null,
    val canRetry: Boolean = false,
    val requiresAuthentication: Boolean = false,
    val canChangeReady: Boolean = false,
    val canCancel: Boolean = false,
    val localReady: Boolean = false,
    val readyCount: Int = 0,
    val participants: List<OnlineParticipant> = emptyList(),
    /** "countdown" or "ready" while a session deadline runs. */
    val deadlineKind: String? = null,
    val deadlineUptime: Double? = null,
    val flightCountdownUptime: Double? = null,
) {
    val isFailed: Boolean get() = connection == "failed"
    val isReconnecting: Boolean get() = connection == "reconnecting"
    val isConnected: Boolean get() = connection == "connected"
    val isSessionLive: Boolean get() = sessionState == "countdown" || sessionState == "running"
}

internal data class OnlineResultPlayer(
    val playerId: String, val rank: Int?, val distance: Double, val name: String?, val color: RocketsColor?, val isLocal: Boolean,
)

internal data class OnlineResultUi(
    val phase: String = "idle",
    val isVisible: Boolean = false,
    val titleKey: String = "house_rockets_online_finalizing",
    /** Set when the title is `house_rockets_lost` with this winner's name. */
    val winnerId: String? = null,
    val detailKey: String = "house_rockets_result_waiting_detail",
    val canRematch: Boolean = false,
    val canRetry: Boolean = false,
    val retryNotBefore: Double = 0.0,
    val sessionId: String? = null,
    val durationSeconds: Double? = null,
    val players: List<OnlineResultPlayer> = emptyList(),
) {
    val isWaiting: Boolean get() = phase == "waiting"
    val isFailed: Boolean get() = phase == "failed"
}

/** Flight extras sampled with each online frame. */
internal data class OnlineFlightUi(
    val canSteer: Boolean,
    val isSyncing: Boolean,
    val statusKey: String,
    val showsConnectionPanel: Boolean,
    val eliminations: List<String>,
)

internal sealed interface OnlineEffect {
    data class EnsureSession(val connection: Int, val path: String, val method: String, val body: String) : OnlineEffect
    data class OpenSocket(val connection: Int, val path: String, val query: String) : OnlineEffect
    data object CloseSocket : OnlineEffect
    data class Send(val connection: Int, val text: String) : OnlineEffect
    data class FetchResult(val request: Int, val path: String, val method: String) : OnlineEffect
    data class Haptic(val success: Boolean) : OnlineEffect
}

internal data class OnlineOutput(
    val effects: List<OnlineEffect>,
    val lobby: OnlineLobbyUi?,
    val result: OnlineResultUi?,
    val closed: Boolean,
    val rematchExcludedSessionId: String?,
)

/** How a host-side failure is reported to the engine. */
internal sealed interface OnlineFailure {
    data object Transport : OnlineFailure
    /** Closed by the server because house membership was revoked. */
    data object Forbidden : OnlineFailure
    data class Http(val status: Int, val retryAfterSeconds: Double?) : OnlineFailure
}

/**
 * The shared online engine (FausCrewCore) behind a handle. Every call returns the effects
 * to perform; `now` is always [OnlineClock.now].
 */
internal interface HouseRocketsOnlineEngine {
    fun event(type: String, now: Double, fields: Map<String, Any?> = emptyMap()): OnlineOutput
    fun receive(text: String, connection: Int, now: Double): OnlineOutput
    fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float)
    fun frame(now: Double): Pair<RocketsFrame, OnlineFlightUi>?
    fun close()
}

/** Monotonic seconds shared by the engine, deadlines and frames. */
internal object OnlineClock {
    fun now(): Double = android.os.SystemClock.elapsedRealtimeNanos() / 1_000_000_000.0
}

internal object HouseRocketsOnlineNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(houseId: String, playerId: String, houseOwnerId: String, excludingSessionId: String?): HouseRocketsOnlineEngine {
        checked
        return NativeOnlineEngine(
            FausCrewAndroidBridge.houseRocketsOnlineCreate(houseId, playerId, houseOwnerId, excludingSessionId.orEmpty()),
        )
    }

    /** `true`/`false` from the server catalog, or `null` when it could not be read. */
    fun catalogAvailability(houseId: String, status: Int, body: String): Boolean? {
        checked
        val root = JSONObject(FausCrewAndroidBridge.gameCatalogResponse(houseId, status, body))
        return if (root.isNull("available")) null else root.getBoolean("available")
    }
}

private class NativeOnlineEngine(private val handle: Int) : HouseRocketsOnlineEngine {
    private val frames = RocketsFrameParser()

    override fun event(type: String, now: Double, fields: Map<String, Any?>): OnlineOutput {
        val json = JSONObject().put("type", type).put("now", now)
        fields.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
        return OnlineOutputParser.parse(FausCrewAndroidBridge.houseRocketsOnlineEvent(handle, json.toString()))
    }

    override fun receive(text: String, connection: Int, now: Double): OnlineOutput =
        OnlineOutputParser.parse(FausCrewAndroidBridge.houseRocketsOnlineReceive(handle, text, connection, now))

    override fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float) {
        FausCrewAndroidBridge.houseRocketsOnlineViewport(handle, width.toDouble(), height.toDouble(),
            hudWidth.toDouble(), hudHeight.toDouble())
    }

    override fun frame(now: Double): Pair<RocketsFrame, OnlineFlightUi>? =
        OnlineOutputParser.frame(frames, FausCrewAndroidBridge.houseRocketsOnlineFrame(handle, now))

    override fun close() {
        FausCrewAndroidBridge.houseRocketsOnlineDestroy(handle)
    }
}

/** JSON → Kotlin for the online bridge; JVM-testable. */
internal object OnlineOutputParser {
    fun parse(json: String): OnlineOutput {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "House Rockets online bridge failed") }
        return OnlineOutput(
            effects = root.optJSONArray("effects").objects().map(::effect),
            lobby = root.optJSONObject("lobby")?.let(::lobby),
            result = root.optJSONObject("result")?.let(::result),
            closed = root.optBoolean("closed", false),
            rematchExcludedSessionId = root.optNullableString("rematchExcludedSessionId"),
        )
    }

    fun frame(parser: RocketsFrameParser, json: String): Pair<RocketsFrame, OnlineFlightUi>? {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "House Rockets online bridge failed") }
        if (!root.has("matchId")) return null
        val eliminations = root.optJSONArray("eliminations")
        return parser.frame(root) to OnlineFlightUi(
            canSteer = root.optBoolean("canSteer"),
            isSyncing = root.optBoolean("isSyncing"),
            statusKey = root.optString("statusKey"),
            showsConnectionPanel = root.optBoolean("showsConnectionPanel"),
            eliminations = List(eliminations?.length() ?: 0) { eliminations!!.getString(it) },
        )
    }

    private fun effect(json: JSONObject): OnlineEffect = when (val type = json.getString("type")) {
        "ensureSession" -> OnlineEffect.EnsureSession(json.getInt("connection"), json.getString("path"),
            json.getString("method"), json.getString("body"))
        "openSocket" -> OnlineEffect.OpenSocket(json.getInt("connection"), json.getString("path"), json.getString("query"))
        "closeSocket" -> OnlineEffect.CloseSocket
        "send" -> OnlineEffect.Send(json.getInt("connection"), json.getString("text"))
        "fetchResult" -> OnlineEffect.FetchResult(json.getInt("request"), json.getString("path"), json.getString("method"))
        "haptic" -> OnlineEffect.Haptic(json.getString("haptic") == "success")
        else -> error("Unknown online effect $type")
    }

    private fun lobby(json: JSONObject) = OnlineLobbyUi(
        connection = json.getString("connection"),
        isSynced = json.getBoolean("isSynced"),
        isLobby = json.getBoolean("isLobby"),
        isTerminal = json.getBoolean("isTerminal"),
        isLeaving = json.getBoolean("isLeaving"),
        isForeground = json.getBoolean("isForeground"),
        controlTransferred = json.getBoolean("controlTransferred"),
        hasGame = json.getBoolean("hasGame"),
        sessionState = json.optNullableString("sessionState"),
        statusKey = json.getString("statusKey"),
        detailKey = json.getString("detailKey"),
        showsProgress = json.getBoolean("showsProgress"),
        issueKey = json.optNullableString("issueKey"),
        connectionTitleKey = json.getString("connectionTitleKey"),
        connectionDetailKey = json.getString("connectionDetailKey"),
        minimumPlayers = json.getInt("minimumPlayers"),
        retryNotBefore = json.optNullableDouble("retryNotBefore"),
        canRetry = json.getBoolean("canRetry"),
        requiresAuthentication = json.getBoolean("requiresAuthentication"),
        canChangeReady = json.getBoolean("canChangeReady"),
        canCancel = json.getBoolean("canCancel"),
        localReady = json.getBoolean("localReady"),
        readyCount = json.getInt("readyCount"),
        participants = json.optJSONArray("participants").objects().map {
            OnlineParticipant(it.getString("playerId"), it.getString("statusKey"), it.getBoolean("ready"), it.getBoolean("isLocal"))
        },
        deadlineKind = json.optNullableString("deadlineKind"),
        deadlineUptime = json.optNullableDouble("deadlineUptime"),
        flightCountdownUptime = json.optNullableDouble("flightCountdownUptime"),
    )

    private fun result(json: JSONObject) = OnlineResultUi(
        phase = json.getString("phase"),
        isVisible = json.getBoolean("visible"),
        titleKey = json.getString("titleKey"),
        winnerId = json.optNullableString("winnerId"),
        detailKey = json.getString("detailKey"),
        canRematch = json.getBoolean("canRematch"),
        canRetry = json.getBoolean("canRetry"),
        retryNotBefore = json.optDouble("retryNotBefore", 0.0),
        sessionId = json.optNullableString("sessionId"),
        durationSeconds = json.optNullableDouble("durationSeconds"),
        players = json.optJSONArray("players").objects().map {
            OnlineResultPlayer(
                playerId = it.getString("playerId"),
                rank = if (it.isNull("rank")) null else it.getInt("rank"),
                distance = it.getDouble("distance"),
                name = it.optNullableString("name"),
                color = it.optNullableString("color")?.let { color -> RocketsColor.valueOf(color.uppercase()) },
                isLocal = it.getBoolean("isLocal"),
            )
        },
    )

    private fun JSONArray?.objects(): List<JSONObject> = if (this == null) emptyList() else List(length()) { getJSONObject(it) }
    private fun JSONObject.optNullableDouble(key: String): Double? = if (isNull(key)) null else getDouble(key)
}

/** Socket events, delivered on OkHttp's thread; the session hops to the main thread. */
internal interface RealtimeSocketListener {
    fun onOpen()
    fun onText(text: String)
    fun onFailure(failure: OnlineFailure)
}

internal interface RealtimeSocket {
    fun send(text: String): Boolean
    fun close()
}

/** Opens the game WebSocket. Tests substitute a fake. */
internal fun interface RealtimeSocketFactory {
    fun open(path: String, query: String, token: String, listener: RealtimeSocketListener): RealtimeSocket
}

/**
 * OkHttp WebSocket transport (`URLSessionWebSocketTask` on iOS). OkHttp negotiates
 * `permessage-deflate` on its own. Only JSON text frames are accepted; the engine owns
 * size limits, heartbeat and reconnect.
 */
internal class OkHttpRealtimeSocketFactory(
    private val baseUrl: HttpUrl = AndroidHttpAdapter.LIVE_BASE_URL.toHttpUrl(),
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS)
        .build(),
) : RealtimeSocketFactory {
    override fun open(path: String, query: String, token: String, listener: RealtimeSocketListener): RealtimeSocket {
        val url = baseUrl.newBuilder().apply {
            path.split('/').forEach(::addPathSegment)
            query.split('&').filter(String::isNotEmpty).forEach { pair ->
                addQueryParameter(pair.substringBefore('='), pair.substringAfter('=', ""))
            }
        }.build()
        val request = Request.Builder().url(url).header("Authorization", "Bearer $token").build()
        val socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) = listener.onOpen()
            override fun onMessage(webSocket: WebSocket, text: String) = listener.onText(text)
            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
                listener.onFailure(if (code == 1008 && reason == "house membership revoked") OnlineFailure.Forbidden
                    else OnlineFailure.Transport)
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                val failure = response?.takeIf { it.code >= 400 }?.let {
                    OnlineFailure.Http(it.code, retryAfterSeconds(it.header("Retry-After")))
                } ?: OnlineFailure.Transport
                response?.close()
                listener.onFailure(failure)
            }
        })
        return object : RealtimeSocket {
            override fun send(text: String): Boolean = socket.send(text)
            override fun close() = socket.cancel()
        }
    }
}
