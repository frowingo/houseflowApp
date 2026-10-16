package com.houseflow.platform

import com.houseflow.androidbridge.HouseFlowAndroidBridge
import org.json.JSONArray
import org.json.JSONObject

internal enum class RocketsPhase { COUNTDOWN, PLAYING, PAUSED, ENDED }

internal enum class RocketsRole { HUMAN, BOT, REMOTE }

internal enum class RocketsEffect { BOOST, SLOW }

/** Serialized player colors from Core; the palette lives in the UI. */
internal enum class RocketsColor { MINT, CORAL, BLUE, GOLD, VIOLET, ORANGE, PINK, TEAL }

internal data class RocketsPlayer(
    val id: String,
    val nameKey: String,
    val role: RocketsRole,
    val color: RocketsColor,
    val isAlive: Boolean,
    val x: Double,
    val y: Double,
    /** Course-relative heading for the rocket sprite. */
    val courseHeading: Double,
    /** Screen heading, as the joystick and accessibility read it. */
    val heading: Double,
    val effect: RocketsEffect?,
)

/** Gate solids in course units relative to `x`; each polygon is flat x,y pairs. */
internal data class RocketsGate(val id: String, val x: Double, val width: Double, val polygons: List<DoubleArray>)

internal data class RocketsField(val id: String, val x: Double, val y: Double, val effect: RocketsEffect)

/** `HouseRocketsProjection` from Core, in dp with SpriteKit's y-up origin. */
internal data class RocketsProjection(
    val angle: Double,
    val scale: Double,
    val originX: Double,
    val originY: Double,
    val visibleLength: Double,
    val isTurning: Boolean,
)

/** An information panel in HUD dp coordinates (y down). */
internal data class RocketsRegion(val x: Float, val y: Float, val width: Float, val height: Float)

internal data class RocketsFrame(
    val matchId: String,
    val revision: Int,
    val phase: RocketsPhase,
    val countdown: Int?,
    val elapsed: Double,
    val cameraX: Double,
    val courseAngle: Double,
    val aliveCount: Int,
    val winnerId: String?,
    val lastEliminatedId: String?,
    /** "Turn" cue target: true = upward, false = right, null = no cue. */
    val turnTargetIsVertical: Boolean?,
    val players: List<RocketsPlayer>,
    val gates: List<RocketsGate>,
    val fields: List<RocketsField>,
    val projection: RocketsProjection?,
    val regions: List<RocketsRegion>,
) {
    val human: RocketsPlayer? get() = players.firstOrNull { it.role == RocketsRole.HUMAN }
    val winner: RocketsPlayer? get() = winnerId?.let { id -> players.firstOrNull { it.id == id } }
}

/** One engine call's outcome: the new frame plus the call-specific flags. */
internal data class RocketsUpdate(
    val frame: RocketsFrame?,
    val started: Boolean = false,
    val changed: Boolean = false,
    val resumed: RocketsPhase? = null,
)

/**
 * The shared House Rockets bot match (HouseFlowCore) behind a handle. Android owns the
 * clock: it steps the countdown and advances physics once per rendered frame.
 */
internal interface HouseRocketsEngine {
    fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float): RocketsUpdate
    fun start(botCount: Int): RocketsUpdate
    fun countdown(): RocketsUpdate
    fun step(deltaSeconds: Double, heading: Double?, sequence: Int): RocketsUpdate
    fun pause(): RocketsUpdate
    fun resume(): RocketsUpdate
    fun restart(): RocketsUpdate
    fun close()
}

internal object HouseRocketsNative {
    private val checked by lazy { check(HouseFlowAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(): HouseRocketsEngine {
        checked
        return NativeHouseRocketsEngine(HouseFlowAndroidBridge.houseRocketsBotCreate())
    }

    /** Bundled TR/EN copy from Core, cached per language. */
    private val copies = HashMap<String, Map<String, String>>()

    @Synchronized
    fun copy(language: String?): Map<String, String> {
        val key = language.orEmpty()
        return copies.getOrPut(key) {
            checked
            JSONObject(HouseFlowAndroidBridge.houseRocketsCopy(key)).toStringMap()
        }
    }

    val countdownStepMillis: Long by lazy {
        checked
        JSONObject(HouseFlowAndroidBridge.houseRocketsConstants()).getLong("countdownStepMillis")
    }
}

private class NativeHouseRocketsEngine(private val handle: Int) : HouseRocketsEngine {
    private val parser = RocketsFrameParser()

    override fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float) = parser.parse(
        HouseFlowAndroidBridge.houseRocketsBotViewport(
            handle, width.toDouble(), height.toDouble(), hudWidth.toDouble(), hudHeight.toDouble(),
        ),
    )

    override fun start(botCount: Int) = parser.parse(HouseFlowAndroidBridge.houseRocketsBotStart(handle, botCount))
    override fun countdown() = parser.parse(HouseFlowAndroidBridge.houseRocketsBotCountdown(handle))
    override fun step(deltaSeconds: Double, heading: Double?, sequence: Int) = parser.parse(
        HouseFlowAndroidBridge.houseRocketsBotStep(handle, deltaSeconds, heading != null, heading ?: 0.0, sequence),
    )
    override fun pause() = parser.parse(HouseFlowAndroidBridge.houseRocketsBotPause(handle))
    override fun resume() = parser.parse(HouseFlowAndroidBridge.houseRocketsBotResume(handle))
    override fun restart() = parser.parse(HouseFlowAndroidBridge.houseRocketsBotRestart(handle))
    override fun close() {
        HouseFlowAndroidBridge.houseRocketsBotDestroy(handle)
    }
}

/**
 * Parses the bridge's frame JSON. Gate geometry arrives only when the course changes,
 * so the parser keeps the last gates and reuses them for lighter frames.
 */
internal class RocketsFrameParser {
    private var gates: List<RocketsGate> = emptyList()

    fun parse(json: String): RocketsUpdate {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "House Rockets bridge failed") }
        val frame = if (root.has("matchId")) frame(root) else null
        return RocketsUpdate(
            frame = frame,
            started = root.optBoolean("started", false),
            changed = root.optBoolean("changed", false),
            resumed = root.optNullableString("resumed")?.let(::phase),
        )
    }

    private fun frame(root: JSONObject): RocketsFrame {
        root.optJSONArray("gates")?.let { array ->
            gates = array.objects { gate ->
                RocketsGate(
                    gate.getString("id"), gate.getDouble("x"), gate.getDouble("width"),
                    gate.getJSONArray("polygons").let { polygons ->
                        List(polygons.length()) { index -> polygons.getJSONArray(index).doubles() }
                    },
                )
            }
        }
        return RocketsFrame(
            matchId = root.getString("matchId"),
            revision = root.getInt("revision"),
            phase = phase(root.getString("phase")),
            countdown = if (root.isNull("countdown")) null else root.getInt("countdown"),
            elapsed = root.getDouble("elapsed"),
            cameraX = root.getDouble("cameraX"),
            courseAngle = root.getDouble("courseAngle"),
            aliveCount = root.getInt("aliveCount"),
            winnerId = root.optNullableString("winnerId"),
            lastEliminatedId = root.optNullableString("lastEliminatedId"),
            turnTargetIsVertical = root.optNullableString("direction")?.let { it == "vertical" },
            players = root.getJSONArray("players").objects { player ->
                RocketsPlayer(
                    id = player.getString("id"),
                    nameKey = player.getString("nameKey"),
                    role = RocketsRole.valueOf(player.getString("role").uppercase()),
                    color = RocketsColor.valueOf(player.getString("color").uppercase()),
                    isAlive = player.getBoolean("alive"),
                    x = player.getDouble("x"),
                    y = player.getDouble("y"),
                    courseHeading = player.getDouble("courseHeading"),
                    heading = player.getDouble("heading"),
                    effect = player.optNullableString("effect")?.let(::effect),
                )
            },
            gates = gates,
            fields = root.getJSONArray("fields").objects { field ->
                RocketsField(field.getString("id"), field.getDouble("x"), field.getDouble("y"),
                    effect(field.getString("effect")))
            },
            projection = root.optJSONObject("projection")?.let {
                RocketsProjection(it.getDouble("angle"), it.getDouble("scale"), it.getDouble("originX"),
                    it.getDouble("originY"), it.getDouble("visibleLength"), it.getBoolean("turning"))
            },
            regions = root.optJSONArray("regions")?.let { array ->
                List(array.length()) { index ->
                    val rect = array.getJSONArray(index)
                    RocketsRegion(rect.getDouble(0).toFloat(), rect.getDouble(1).toFloat(),
                        rect.getDouble(2).toFloat(), rect.getDouble(3).toFloat())
                }
            } ?: emptyList(),
        )
    }

    private fun phase(value: String) = RocketsPhase.valueOf(value.uppercase())
    private fun effect(value: String) = RocketsEffect.valueOf(value.uppercase())
}

private fun JSONObject.optNullableString(key: String): String? = if (isNull(key)) null else optString(key)

private fun <T> JSONArray.objects(transform: (JSONObject) -> T): List<T> =
    List(length()) { transform(getJSONObject(it)) }

private fun JSONArray.doubles(): DoubleArray = DoubleArray(length()) { getDouble(it) }

private fun JSONObject.toStringMap(): Map<String, String> =
    keys().asSequence().associateWith { getString(it) }
