package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONArray
import org.json.JSONObject

// The Faus Switch online room over the swift-java bridge (`FausSwitchOnlineBridge`). The
// engine in FausCrewCore decides every lobby, color, reconnect, control and result rule;
// the shared `GameOnlineSession` performs its effects. Faus Switch adds the room's robot
// colors to the shared lobby output and draws the race in the demo's render contract.

/** `FausSwitchLobbyColors` as the room draws it: who holds which robot color. */
internal data class SwitchLobbyColors(
    /** The remembered pick asked for when seated. */
    val preferred: SwitchColor? = null,
    /** The local robot's color: the pick while it is free, else the server's claim. */
    val local: SwitchColor? = null,
    val localClaim: SwitchColor? = null,
    val takenByOthers: Set<SwitchColor> = emptySet(),
    /** The pick is held by someone else, so the server gave another color. */
    val isPreferredTaken: Boolean = false,
    /** The local player is ready: the color is fixed until they take the ready back. */
    val isLocked: Boolean = false,
)

/** Faus Switch's own lobby keys next to the shared [OnlineLobbyUi]. */
internal data class SwitchRoom(
    val colors: SwitchLobbyColors = SwitchLobbyColors(),
    /** A rematch's new session before its first snapshot. */
    val isRematchRoom: Boolean = false,
    val raceCountdownUptime: Double? = null,
)

/** The result panel (`FausSwitchOnlineResultState` with Core's copy rules and standings). */
internal data class SwitchOnlineResult(
    val phase: String,
    val isWaiting: Boolean,
    val isFailed: Boolean,
    val titleKey: String,
    val detailKey: String,
    val canRematch: Boolean,
    val canRetry: Boolean,
    val retryNotBefore: Double,
    val sessionId: String?,
    /** Set when the title is `faus_switch_online_lost`: [winnerName] (or the house's name) fills `{name}`. */
    val winnerId: String?,
    val winnerName: String?,
    val standings: List<SwitchStanding>,
)

/** The bars and panels over the online race. */
internal data class SwitchOnlineMatch(
    val ui: SwitchMatchUi,
    /** Whole seconds of the room's ready window or start countdown, or null. */
    val roomCountdown: Int?,
    val result: SwitchOnlineResult?,
)

/** One drawn frame: the race (null before the first snapshot), its local events and the overlays. */
internal data class SwitchOnlineFrame(val world: SwitchWorld?, val match: SwitchOnlineMatch, val events: List<SwitchEvent>)

/** The Faus Switch engine behind JNI: the shared room, its colors, the flip and one frame per rendered frame. */
internal interface SwitchOnlineEngine : OnlineGameEngine {
    /** Faus Switch's lobby keys from the last output that carried a lobby. */
    val room: SwitchRoom
    /** The answer to the last `flip` event. */
    val lastFlip: SwitchFlip?
    fun viewport(width: Double, height: Double)
    fun frame(now: Double): SwitchOnlineFrame
}

internal object FausSwitchOnlineNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(houseId: String, playerId: String, houseOwnerId: String, excludingSessionId: String?,
               preferredColor: SwitchColor?): SwitchOnlineEngine {
        checked
        return NativeSwitchOnlineEngine(FausCrewAndroidBridge.fausSwitchOnlineCreate(
            houseId, playerId, houseOwnerId, excludingSessionId.orEmpty(), preferredColor?.raw.orEmpty()))
    }

    /** `true`/`false` from the server catalog, or `null` when it could not be read. */
    fun catalogAvailability(houseId: String, status: Int, body: String): Boolean? {
        checked
        val root = JSONObject(FausCrewAndroidBridge.fausSwitchCatalogResponse(houseId, status, body))
        return if (root.isNull("available")) null else root.getBoolean("available")
    }
}

private class NativeSwitchOnlineEngine(private val handle: Int) : SwitchOnlineEngine {
    private val frames = SwitchOnlineParser()

    override var room = SwitchRoom()
        private set
    override var lastFlip: SwitchFlip? = null
        private set

    override fun event(type: String, now: Double, fields: Map<String, Any?>): OnlineOutput {
        val json = JSONObject().put("type", type).put("now", now)
        fields.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
        return read(FausCrewAndroidBridge.fausSwitchOnlineEvent(handle, json.toString()))
    }

    override fun receive(text: String, connection: Int, now: Double): OnlineOutput =
        read(FausCrewAndroidBridge.fausSwitchOnlineReceive(handle, text, connection, now))

    private fun read(json: String): OnlineOutput {
        val output = OnlineOutputParser.parse(json)
        val root = JSONObject(json)
        root.optJSONObject("lobby")?.let { room = SwitchOnlineParser.room(it) }
        lastFlip = SwitchFlip.from(if (root.isNull("flip")) null else root.getString("flip"))
        return output
    }

    override fun viewport(width: Double, height: Double) {
        FausCrewAndroidBridge.fausSwitchOnlineViewport(handle, width, height)
    }

    override fun frame(now: Double): SwitchOnlineFrame = frames.parse(FausCrewAndroidBridge.fausSwitchOnlineFrame(handle, now))

    override fun close() {
        FausCrewAndroidBridge.fausSwitchOnlineDestroy(handle)
    }
}

/** `fausSwitchOnlineFrame` output. Keeps one [SwitchFrameParser] so platforms and the lost zone carry over. */
internal class SwitchOnlineParser {
    private val frames = SwitchFrameParser()

    fun parse(json: String): SwitchOnlineFrame {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "Faus Switch online bridge failed") }
        val match = root.getJSONObject("match")
        return SwitchOnlineFrame(
            world = root.optJSONObject("frame")?.let(frames::world),
            match = SwitchOnlineMatch(
                ui = SwitchFrameParser.matchUi(match),
                roomCountdown = if (match.isNull("roomCountdown")) null else match.getInt("roomCountdown"),
                result = match.optJSONObject("result")?.let(::result),
            ),
            events = root.optJSONArray("events")?.let(SwitchFrameParser::events).orEmpty(),
        )
    }

    companion object {
        fun room(lobby: JSONObject): SwitchRoom {
            val colors = lobby.optJSONObject("colors")
            return SwitchRoom(
                colors = colors?.let {
                    SwitchLobbyColors(
                        preferred = SwitchColor.from(it.text("preferred")),
                        local = SwitchColor.from(it.text("local")),
                        localClaim = SwitchColor.from(it.text("localClaim")),
                        takenByOthers = it.optJSONArray("takenByOthers").strings().mapNotNull(SwitchColor::from).toSet(),
                        isPreferredTaken = it.optBoolean("isPreferredTaken"),
                        isLocked = it.optBoolean("isLocked"),
                    )
                } ?: SwitchLobbyColors(),
                isRematchRoom = lobby.optBoolean("isRematchRoom"),
                raceCountdownUptime = if (lobby.isNull("raceCountdownUptime")) null else lobby.getDouble("raceCountdownUptime"),
            )
        }

        fun result(json: JSONObject) = SwitchOnlineResult(
            phase = json.getString("phase"),
            isWaiting = json.getBoolean("isWaiting"),
            isFailed = json.getBoolean("isFailed"),
            titleKey = json.getString("titleKey"),
            detailKey = json.getString("detailKey"),
            canRematch = json.getBoolean("canRematch"),
            canRetry = json.getBoolean("canRetry"),
            retryNotBefore = json.optDouble("retryNotBefore", 0.0),
            sessionId = json.text("sessionId"),
            winnerId = json.text("winnerId"),
            winnerName = json.text("winnerName"),
            standings = json.optJSONArray("standings")?.let { array ->
                List(array.length()) { SwitchFrameParser.standing(array.getJSONObject(it)) }
            }.orEmpty(),
        )

        private fun JSONObject.text(key: String): String? = if (isNull(key)) null else getString(key)

        private fun JSONArray?.strings(): List<String> = if (this == null) emptyList() else List(length()) { getString(it) }
    }
}
