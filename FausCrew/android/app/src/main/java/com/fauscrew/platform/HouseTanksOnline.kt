package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONObject

/** A tank the server seated, normalized to the arena (y up) like [TanksMapPreview]. */
internal data class TanksOnlineSeat(val playerId: String, val x: Double, val y: Double, val rotation: Double, val color: TanksColor)

/** The server's drawn arena from the match countdown on; [map] is null for a map this build lacks. */
internal data class TanksOnlinePreview(val map: TanksMap?, val seats: List<TanksOnlineSeat>)

/** One tank of the in-game bar (up to eight), in seat order. */
internal data class TanksOnlineSeatStatus(
    val playerId: String,
    val name: String,
    val color: TanksColor,
    val armor: Int,
    val roundsWon: Int,
    val isAlive: Boolean,
    /** False while the player has no control (a stationary target), also after leaving. */
    val isConnected: Boolean,
    val hasLeft: Boolean,
    val isLocal: Boolean,
    /** The vote for the next round, shown in `roundReady`. */
    val roundReady: Boolean = false,
)

internal data class TanksOnlineResultPlayer(
    val playerId: String, val rank: Int?, val roundsWon: Int, val name: String?, val color: TanksColor?, val isLocal: Boolean,
    /** From the last seats, before the stored ranks. */
    val isProvisional: Boolean = false,
)

/** The end menu from the match's end; the copy rules are `HouseTanksOnlineCopyKeys` in Core. */
internal data class TanksOnlineResult(
    val phase: String = "idle",
    val titleKey: String = "house_tanks_online_finalizing",
    /** Set when the title is `house_tanks_online_champion` with this player's name. */
    val championId: String? = null,
    val detailKey: String = "house_tanks_online_finalizing_detail",
    val isCompleted: Boolean = false,
    val canRematch: Boolean = false,
    val canRetry: Boolean = false,
    val retryNotBefore: Double = 0.0,
    val sessionId: String? = null,
    val players: List<TanksOnlineResultPlayer> = emptyList(),
) {
    /** Finalizing: the match ended and the stored result is not here yet. */
    val isWaiting: Boolean get() = phase == "waiting" || phase == "idle"
    val isFailed: Boolean get() = phase == "failed"
}

/** The bars and banners over the online arena (`HouseTanksOnlineMatchUI` on iOS). */
internal data class TanksOnlineMatch(
    val phase: String? = null,
    val roundPhase: String? = null,
    val roundNumber: Int = 0,
    /** Whole seconds of the server's round countdown, or null outside one. */
    val countdown: Int? = null,
    val canPress: Boolean = false,
    val isPressed: Boolean = false,
    val isLocalTankDestroyed: Boolean = false,
    /** `HouseTanksOnlineCopyKeys.matchNotice`; [noticeName] fills `{name}`. */
    val noticeTitleKey: String? = null,
    val noticeDetailKey: String? = null,
    val noticeName: String? = null,
    val canRetry: Boolean = false,
    val canReclaim: Boolean = false,
    val isFinished: Boolean = false,
    /** No tank in this match: the banner offers the way out. */
    val isSpectating: Boolean = false,
    val seats: List<TanksOnlineSeatStatus> = emptyList(),
    /** `roundReady`: the panel with the round's winner and the vote for the next one. */
    val showsRoundPanel: Boolean = false,
    val roundTitleKey: String? = null,
    /** `house_tanks_online_round_window` takes `{seconds}` = [roundWindowSeconds]. */
    val roundDetailKey: String? = null,
    val roundWindowSeconds: Int? = null,
    val canVote: Boolean = false,
    val isLocalReady: Boolean = false,
    val isVotePending: Boolean = false,
    val readyCount: Int = 0,
    val voterCount: Int = 0,
    /** The end menu (from the match's end, result or not) replaces every banner, the round
     *  panel and the top-left controls. */
    val showsResult: Boolean = false,
    val result: TanksOnlineResult? = null,
)

/**
 * One drawn frame: the arena in the demo's render contract (null before a snapshot), the bars,
 * and [fps], presentations drawn in the last second for the HUD's chip.
 */
internal data class TanksOnlineFrame(val frame: TanksFrame?, val match: TanksOnlineMatch, val fps: Int? = null)

/** The FauseTanks engine behind JNI: the shared room plus one frame per rendered frame. */
internal interface TanksOnlineEngine : OnlineGameEngine {
    fun frame(now: Double): TanksOnlineFrame
}

internal object HouseTanksOnlineNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(houseId: String, playerId: String, houseOwnerId: String, excludingSessionId: String?): TanksOnlineEngine {
        checked
        return NativeTanksOnlineEngine(
            FausCrewAndroidBridge.houseTanksOnlineCreate(houseId, playerId, houseOwnerId, excludingSessionId.orEmpty()),
        )
    }

    /** `true`/`false` from the server catalog, or `null` when it could not be read. */
    fun catalogAvailability(houseId: String, status: Int, body: String): Boolean? {
        checked
        val root = JSONObject(FausCrewAndroidBridge.houseTanksCatalogResponse(houseId, status, body))
        return if (root.isNull("available")) null else root.getBoolean("available")
    }
}

private class NativeTanksOnlineEngine(private val handle: Int) : TanksOnlineEngine {
    private val frames = TanksOnlineFrameParser()

    override fun event(type: String, now: Double, fields: Map<String, Any?>): OnlineOutput {
        val json = JSONObject().put("type", type).put("now", now)
        fields.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
        return OnlineOutputParser.parse(FausCrewAndroidBridge.houseTanksOnlineEvent(handle, json.toString()))
    }

    override fun receive(text: String, connection: Int, now: Double): OnlineOutput =
        OnlineOutputParser.parse(FausCrewAndroidBridge.houseTanksOnlineReceive(handle, text, connection, now))

    override fun frame(now: Double): TanksOnlineFrame = frames.parse(FausCrewAndroidBridge.houseTanksOnlineFrame(handle, now))

    override fun close() {
        FausCrewAndroidBridge.houseTanksOnlineDestroy(handle)
    }
}

/** `houseTanksOnlineFrame` output. Keeps one [TanksFrameParser] so a round's arena is read once. */
internal class TanksOnlineFrameParser {
    private val frames = TanksFrameParser()

    fun parse(json: String): TanksOnlineFrame {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "FauseTanks online bridge failed") }
        val fps = root.optInt("fps", -1).takeIf { it >= 0 }
        return TanksOnlineFrame(root.optJSONObject("frame")?.let(frames::frame), match(root.getJSONObject("match")), fps)
    }

    private fun match(json: JSONObject) = TanksOnlineMatch(
        phase = json.text("phase"),
        roundPhase = json.text("roundPhase"),
        roundNumber = json.getInt("roundNumber"),
        countdown = if (json.isNull("countdown")) null else json.getInt("countdown"),
        canPress = json.getBoolean("canPress"),
        isPressed = json.getBoolean("isPressed"),
        isLocalTankDestroyed = json.getBoolean("isLocalTankDestroyed"),
        noticeTitleKey = json.text("noticeTitleKey"),
        noticeDetailKey = json.text("noticeDetailKey"),
        noticeName = json.text("noticeName"),
        canRetry = json.getBoolean("canRetry"),
        canReclaim = json.getBoolean("canReclaim"),
        isFinished = json.getBoolean("isFinished"),
        isSpectating = json.optBoolean("isSpectating"),
        showsRoundPanel = json.optBoolean("showsRoundPanel"),
        roundTitleKey = json.text("roundTitleKey"),
        roundDetailKey = json.text("roundDetailKey"),
        roundWindowSeconds = if (json.isNull("roundWindowSeconds")) null else json.getInt("roundWindowSeconds"),
        canVote = json.optBoolean("canVote"),
        isLocalReady = json.optBoolean("isLocalReady"),
        isVotePending = json.optBoolean("isVotePending"),
        readyCount = json.optInt("readyCount"),
        voterCount = json.optInt("voterCount"),
        showsResult = json.optBoolean("showsResult"),
        result = json.optJSONObject("result")?.let(::result),
        seats = json.getJSONArray("seats").let { seats ->
            List(seats.length()) { index -> seats.getJSONObject(index) }.mapNotNull { seat ->
                val color = TanksColor.entries.firstOrNull { it.raw == seat.getString("color") } ?: return@mapNotNull null
                TanksOnlineSeatStatus(
                    playerId = seat.getString("playerId"), name = seat.getString("name"), color = color,
                    armor = seat.getInt("armor"), roundsWon = seat.getInt("roundsWon"), isAlive = seat.getBoolean("alive"),
                    isConnected = seat.getBoolean("connected"), hasLeft = seat.getBoolean("left"),
                    isLocal = seat.getBoolean("local"), roundReady = seat.optBoolean("roundReady"),
                )
            }
        },
    )

    private fun result(json: JSONObject) = TanksOnlineResult(
        phase = json.getString("phase"),
        titleKey = json.getString("titleKey"),
        championId = json.text("championId"),
        detailKey = json.getString("detailKey"),
        isCompleted = json.optBoolean("completed"),
        canRematch = json.getBoolean("canRematch"),
        canRetry = json.getBoolean("canRetry"),
        retryNotBefore = json.optDouble("retryNotBefore", 0.0),
        sessionId = json.text("sessionId"),
        players = json.optJSONArray("players")?.let { players ->
            List(players.length()) { index -> players.getJSONObject(index) }.map { player ->
                TanksOnlineResultPlayer(
                    playerId = player.getString("playerId"),
                    rank = if (player.isNull("rank")) null else player.getInt("rank"),
                    roundsWon = player.getInt("roundsWon"),
                    name = player.text("name"),
                    color = player.text("color")?.let { raw -> TanksColor.entries.firstOrNull { it.raw == raw } },
                    isLocal = player.getBoolean("isLocal"),
                    isProvisional = player.optBoolean("provisional"),
                )
            }
        }.orEmpty(),
    )

    private fun JSONObject.text(key: String): String? = if (isNull(key)) null else getString(key)
}
