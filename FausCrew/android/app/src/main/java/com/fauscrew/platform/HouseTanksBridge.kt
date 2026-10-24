package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONArray
import org.json.JSONObject

/** `HouseTanksPhase` from Core. */
internal enum class TanksPhase(val raw: String) {
    COUNTDOWN("countdown"), PLAYING("playing"), PAUSED("paused"), ROUND_ENDED("roundEnded"), MATCH_ENDED("matchEnded"),
}

internal enum class TanksRole(val raw: String) { HUMAN("human"), BOT("bot") }

/** Serialized tank colors from Core; the inks live in the UI palette. */
internal enum class TanksColor(val raw: String) {
    PLUM("plum"), ORANGE("orange"), BLUE("blue"), OLIVE("olive"),
    MUSTARD("mustard"), CRIMSON("crimson"), SKY("sky"), IVORY("ivory"),
}

internal enum class TanksMap(val raw: String) {
    LIVING_ROOM("livingRoom"), CORRIDORS("corridors"), WAREHOUSE("warehouse"), COURTYARD("courtyard"),
    BASEMENT("basement");

    val titleKey: String get() = "house_tanks_map_${raw}_title"
    val detailKey: String get() = "house_tanks_map_${raw}_detail"
}

internal enum class TanksDifficulty(val raw: String) {
    EASY("easy"), NORMAL("normal"), HARD("hard");

    val titleKey: String get() = "house_tanks_difficulty_$raw"
}

internal enum class TanksJoker(val raw: String) {
    ROCKET("rocket"), RAPID_FIRE("rapidFire"), SPREAD_SHOT("spreadShot"), SHIELD("shield"), AIM("aim");

    val titleKey: String get() = "house_tanks_power_$raw"
    val detailKey: String get() = "house_tanks_joker_${raw}_detail"
}

internal enum class TanksObstacleStyle(val raw: String) {
    DIVIDER("divider"), SOFA("sofa"), ROUND_TABLE("roundTable"), CRATE("crate"), BOOKSHELF("bookshelf"),
    PILLAR("pillar"), PLANTER("planter");

    val isRound: Boolean get() = this == ROUND_TABLE || this == PILLAR || this == PLANTER
}

internal enum class TanksTone(val raw: String) {
    NAVY("navy"), TEAL("teal"), ORANGE("orange"), BLUE("blue"), WOOD("wood"), GREEN("green"),
}

internal data class TanksPlayer(
    val id: String,
    val nameKey: String,
    val role: TanksRole,
    val color: TanksColor,
    val armor: Int,
    val roundsWon: Int,
    val isAlive: Boolean,
)

/** A tank in arena dp, SpriteKit's y-up space. */
internal data class TanksTank(
    val id: String,
    val color: TanksColor,
    val role: TanksRole,
    val x: Double,
    val y: Double,
    val rotation: Double,
    val isActive: Boolean,
    val power: TanksJoker?,
    val powerFraction: Double,
    /** The aim joker's sight line length, or null without it. */
    val aimLength: Double?,
)

internal data class TanksObstacle(
    val index: Int,
    val style: TanksObstacleStyle,
    val tone: TanksTone,
    val x: Double,
    val y: Double,
    val width: Double,
    val height: Double,
    val rotation: Double,
    val isMovable: Boolean,
)

internal data class TanksCrate(val index: Int, val x: Double, val y: Double, val isDestroyed: Boolean)

internal data class TanksShot(
    val id: Int, val x: Double, val y: Double, val rotation: Double, val isRocket: Boolean, val color: TanksColor,
)

internal data class TanksToken(val kind: TanksJoker, val x: Double, val y: Double, val fraction: Double)

/** One-off effects; the renderer animates them from the frame they arrive in. */
internal sealed interface TanksEvent {
    data class Fired(val playerId: String) : TanksEvent
    data class Shielded(val playerId: String) : TanksEvent
    data class CrateBroken(val x: Double, val y: Double) : TanksEvent
    data class Explosion(val x: Double, val y: Double) : TanksEvent
    data class Eliminated(val playerId: String, val x: Double, val y: Double) : TanksEvent
}

/** The static arena of a round: furniture, crate shapes and floor plan, in arena dp. */
internal data class TanksArena(
    val map: TanksMap,
    /** Crowded-match maps draw every actor smaller. */
    val scale: Double,
    val frameX: Double,
    val frameY: Double,
    val frameWidth: Double,
    val frameHeight: Double,
    val obstacles: List<TanksObstacle>,
    val lines: List<DoubleArray>,
    val markers: List<DoubleArray>,
)

internal data class TanksFrame(
    val matchId: String,
    /** Changes with every round; a new key means a freshly built arena. */
    val roundKey: String,
    val revision: Int,
    val phase: TanksPhase,
    val countdown: Int?,
    val roundNumber: Int,
    val roundWinnerId: String?,
    val championId: String?,
    val players: List<TanksPlayer>,
    val width: Double,
    val height: Double,
    val time: Double,
    val tanks: List<TanksTank>,
    val crates: List<TanksCrate>,
    val projectiles: List<TanksShot>,
    val token: TanksToken?,
    val events: List<TanksEvent>,
    val arena: TanksArena?,
) {
    val human: TanksPlayer? get() = players.firstOrNull { it.role == TanksRole.HUMAN }
    val roundWinner: TanksPlayer? get() = roundWinnerId?.let { id -> players.firstOrNull { it.id == id } }
    val champion: TanksPlayer? get() = championId?.let { id -> players.firstOrNull { it.id == id } }
}

internal data class TanksUpdate(val frame: TanksFrame?, val started: Boolean = false, val changed: Boolean = false)

/** A map as authored (normalized, y up) for lobby previews. */
internal data class TanksMapPreview(
    val map: TanksMap,
    val spawns: List<DoubleArray>,
    val obstacles: List<TanksObstacle>,
    val lines: List<DoubleArray>,
    val markers: List<DoubleArray>,
    /** `obstacleBaseScale × gameplayScale`: rendered size = arena size × normalized size × scale × map scale. */
    val obstacleScale: Double,
    val scale: Double,
    val minPlayers: Int,
    val maxPlayers: Int,
) {
    val playerCounts: IntRange get() = minPlayers..maxPlayers
    /** A map that lets the player choose how many tanks take part. */
    val hasPlayerChoice: Boolean get() = minPlayers != maxPlayers
}

/**
 * The shared FauseTanks demo match (FausCrewCore) behind a handle. Android owns the clock:
 * it steps the countdown and advances the arena once per rendered frame.
 */
internal interface HouseTanksEngine {
    fun viewport(width: Float, height: Float): TanksUpdate
    /** `playerCount` includes the human; Core clamps it to the map's player range. */
    fun start(difficulty: TanksDifficulty, color: TanksColor, map: TanksMap, playerCount: Int): TanksUpdate
    fun countdown(): TanksUpdate
    fun step(deltaSeconds: Double): TanksUpdate
    fun press(pressed: Boolean): TanksUpdate
    fun nextRound(): TanksUpdate
    fun restart(): TanksUpdate
    fun pause(): TanksUpdate
    fun resume(): TanksUpdate
    fun close()
}

internal object HouseTanksNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(): HouseTanksEngine {
        checked
        return NativeHouseTanksEngine(FausCrewAndroidBridge.houseTanksBotCreate())
    }

    private val copies = HashMap<String, Map<String, String>>()

    /** Bundled TR/EN copy from Core, cached per language. */
    @Synchronized
    fun copy(language: String?): Map<String, String> {
        val key = language.orEmpty()
        return copies.getOrPut(key) {
            checked
            JSONObject(FausCrewAndroidBridge.houseTanksCopy(key)).let { json ->
                json.keys().asSequence().associateWith { json.getString(it) }
            }
        }
    }

    val maps: Map<TanksMap, TanksMapPreview> by lazy {
        checked
        TanksFrameParser.maps(FausCrewAndroidBridge.houseTanksMaps())
    }

    val countdownStepMillis: Long by lazy {
        checked
        JSONObject(FausCrewAndroidBridge.houseTanksConstants()).getLong("countdownStepMillis")
    }
}

private class NativeHouseTanksEngine(private val handle: Int) : HouseTanksEngine {
    private val parser = TanksFrameParser()

    override fun viewport(width: Float, height: Float) =
        parser.parse(FausCrewAndroidBridge.houseTanksBotViewport(handle, width.toDouble(), height.toDouble()))
    override fun start(difficulty: TanksDifficulty, color: TanksColor, map: TanksMap, playerCount: Int) =
        parser.parse(FausCrewAndroidBridge.houseTanksBotStart(handle, difficulty.raw, color.raw, map.raw, playerCount))
    override fun countdown() = parser.parse(FausCrewAndroidBridge.houseTanksBotCountdown(handle))
    override fun step(deltaSeconds: Double) = parser.parse(FausCrewAndroidBridge.houseTanksBotStep(handle, deltaSeconds))
    override fun press(pressed: Boolean) = parser.parse(FausCrewAndroidBridge.houseTanksBotPress(handle, pressed))
    override fun nextRound() = parser.parse(FausCrewAndroidBridge.houseTanksBotNextRound(handle))
    override fun restart() = parser.parse(FausCrewAndroidBridge.houseTanksBotRestart(handle))
    override fun pause() = parser.parse(FausCrewAndroidBridge.houseTanksBotPause(handle))
    override fun resume() = parser.parse(FausCrewAndroidBridge.houseTanksBotResume(handle))
    override fun close() {
        FausCrewAndroidBridge.houseTanksBotDestroy(handle)
    }
}

/**
 * Parses the bridge's frame JSON. The static arena arrives only when a round starts or the
 * viewport changes, so the parser keeps the last one for lighter frames of the same round.
 */
internal class TanksFrameParser {
    private var arena: TanksArena? = null
    private var arenaRoundKey: String? = null

    fun parse(json: String): TanksUpdate {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "FauseTanks bridge failed") }
        val frame = if (root.has("matchId")) frame(root) else null
        return TanksUpdate(frame, started = root.optBoolean("started", false), changed = root.optBoolean("changed", false))
    }

    fun frame(root: JSONObject): TanksFrame {
        val roundKey = root.getString("roundKey")
        root.optJSONObject("arena")?.let { json ->
            val frame = json.getJSONArray("frame")
            arena = TanksArena(
                map = map(json.getString("mapId")),
                scale = json.optDouble("scale", 1.0),
                frameX = frame.getDouble(0), frameY = frame.getDouble(1),
                frameWidth = frame.getDouble(2), frameHeight = frame.getDouble(3),
                obstacles = json.getJSONArray("obstacles").objects { obstacle(it) },
                lines = json.getJSONArray("lines").doubleArrays(),
                markers = json.getJSONArray("markers").doubleArrays(),
            )
            arenaRoundKey = roundKey
        }
        return TanksFrame(
            matchId = root.getString("matchId"),
            roundKey = roundKey,
            revision = root.getInt("revision"),
            phase = TanksPhase.entries.first { it.raw == root.getString("phase") },
            countdown = if (root.isNull("countdown")) null else root.getInt("countdown"),
            roundNumber = root.getInt("roundNumber"),
            roundWinnerId = root.optNullableString("roundWinnerId"),
            championId = root.optNullableString("championId"),
            players = root.getJSONArray("players").objects { player ->
                TanksPlayer(
                    id = player.getString("id"), nameKey = player.getString("nameKey"),
                    role = role(player.getString("role")), color = color(player.getString("color")),
                    armor = player.getInt("armor"), roundsWon = player.getInt("roundsWon"),
                    isAlive = player.getBoolean("alive"),
                )
            },
            width = root.getDouble("width"),
            height = root.getDouble("height"),
            time = root.getDouble("time"),
            tanks = root.getJSONArray("tanks").objects { tank ->
                TanksTank(
                    id = tank.getString("id"), color = color(tank.getString("color")), role = role(tank.getString("role")),
                    x = tank.getDouble("x"), y = tank.getDouble("y"), rotation = tank.getDouble("rotation"),
                    isActive = tank.getBoolean("active"),
                    power = tank.optNullableString("power")?.let(::joker),
                    powerFraction = tank.getDouble("powerFraction"),
                    aimLength = if (tank.isNull("aimLength")) null else tank.getDouble("aimLength"),
                )
            },
            crates = root.getJSONArray("crates").objects { crate ->
                TanksCrate(crate.getInt("index"), crate.getDouble("x"), crate.getDouble("y"), crate.getBoolean("destroyed"))
            },
            projectiles = root.getJSONArray("projectiles").objects { shot ->
                TanksShot(shot.getInt("id"), shot.getDouble("x"), shot.getDouble("y"), shot.getDouble("rotation"),
                    shot.getBoolean("rocket"), color(shot.getString("color")))
            },
            token = root.optJSONObject("token")?.let { token ->
                TanksToken(joker(token.getString("kind")), token.getDouble("x"), token.getDouble("y"),
                    token.getDouble("fraction"))
            },
            events = root.getJSONArray("events").objects { event(it) }.filterNotNull(),
            arena = arena.takeIf { arenaRoundKey == roundKey },
        )
    }

    companion object {
        fun maps(json: String): Map<TanksMap, TanksMapPreview> {
            val root = JSONObject(json)
            val scale = root.getDouble("obstacleScale")
            return root.getJSONArray("maps").objects { map ->
                TanksMapPreview(
                    map = map(map.getString("id")),
                    spawns = map.getJSONArray("spawns").doubleArrays(),
                    obstacles = map.getJSONArray("obstacles").objects { obstacle(it, index = 0) },
                    lines = map.getJSONArray("lines").doubleArrays(),
                    markers = map.getJSONArray("markers").doubleArrays(),
                    obstacleScale = scale,
                    scale = map.optDouble("scale", 1.0),
                    minPlayers = map.optInt("minPlayers", 4),
                    maxPlayers = map.optInt("maxPlayers", 4),
                )
            }.associateBy { it.map }
        }

        private fun obstacle(json: JSONObject, index: Int = json.optInt("index")) = TanksObstacle(
            index = index,
            style = TanksObstacleStyle.entries.first { it.raw == json.getString("style") },
            tone = TanksTone.entries.first { it.raw == json.getString("tone") },
            x = json.getDouble("x"), y = json.getDouble("y"),
            width = json.getDouble("width"), height = json.getDouble("height"),
            rotation = json.getDouble("rotation"),
            isMovable = json.optBoolean("movable", json.getString("style") == "crate"),
        )

        private fun event(json: JSONObject): TanksEvent? = when (json.getString("type")) {
            "fired" -> TanksEvent.Fired(json.getString("playerId"))
            "shielded" -> TanksEvent.Shielded(json.getString("playerId"))
            "crateBroken" -> TanksEvent.CrateBroken(json.getDouble("x"), json.getDouble("y"))
            "explosion" -> TanksEvent.Explosion(json.getDouble("x"), json.getDouble("y"))
            "eliminated" -> TanksEvent.Eliminated(json.getString("playerId"), json.getDouble("x"), json.getDouble("y"))
            else -> null
        }

        private fun map(raw: String) = TanksMap.entries.first { it.raw == raw }
        private fun role(raw: String) = TanksRole.entries.first { it.raw == raw }
        private fun color(raw: String) = TanksColor.entries.first { it.raw == raw }
        private fun joker(raw: String) = TanksJoker.entries.first { it.raw == raw }
    }
}

private fun <T> JSONArray.objects(transform: (JSONObject) -> T): List<T> = List(length()) { transform(getJSONObject(it)) }

private fun JSONArray.doubleArrays(): List<DoubleArray> = List(length()) { index ->
    val values = getJSONArray(index)
    DoubleArray(values.length()) { values.getDouble(it) }
}
