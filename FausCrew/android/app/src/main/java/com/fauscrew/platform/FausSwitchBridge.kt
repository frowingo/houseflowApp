package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONArray
import org.json.JSONObject

// Faus Switch demo race over the swift-java bridge. Physics, bots, the camera, robot poses
// and every overlay rule live in FausCrewCore; Kotlin only parses what the bridge sends.
// World points are y-up like the iOS scene; `SwitchCamera` maps them to screen points.

/** `FausSwitchMatchPhase`. */
internal enum class SwitchPhase(val raw: String) {
    COUNTDOWN("countdown"), PLAYING("playing"), PAUSED("paused"), ENDED("ended");

    companion object {
        fun from(raw: String) = entries.firstOrNull { it.raw == raw } ?: ENDED
    }
}

/** `FausSwitchColor`; body tones and title keys come from Core ([FausSwitchNative.colors]). */
internal enum class SwitchColor(val raw: String) {
    PLUM("plum"), FOREST("forest"), OCEAN("ocean"), LAVENDER("lavender"),
    OLIVE("olive"), BRONZE("bronze"), GRAPHITE("graphite"), BERRY("berry");

    val titleKey: String get() = "faus_switch_color_$raw"

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

internal enum class SwitchGravity(val raw: String) {
    DOWN("down"), UP("up");

    val opposite: SwitchGravity get() = if (this == DOWN) UP else DOWN

    companion object {
        fun from(raw: String?) = if (raw == UP.raw) UP else DOWN
    }
}

internal enum class SwitchRunnerStatus(val raw: String) {
    RUNNING("running"), FINISHED("finished"), CRASHED("crashed");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

/** `FausSwitchMatchUI.DemoOutcome`. */
internal enum class SwitchDemoOutcome(val raw: String) {
    WON("won"), FINISHED("finished"), CRASHED("crashed"), TIME_UP("timeUp");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw } ?: TIME_UP
    }
}

/** The bridge's answer to a tap: `FausSwitchFlipFeedback`. */
internal enum class SwitchFlip(val raw: String) {
    FLIPPED("flipped"), UNSUPPORTED("unsupported"), IGNORED("ignored");

    companion object {
        fun from(raw: String?) = entries.firstOrNull { it.raw == raw }
    }
}

internal data class SwitchRect(val minX: Double, val minY: Double, val maxX: Double, val maxY: Double) {
    val width: Double get() = maxX - minX
    val height: Double get() = maxY - minY
    val midX: Double get() = (minX + maxX) / 2
    val midY: Double get() = (minY + maxY) / 2
}

/** world → screen (y up): `screen = origin + world * scale`. */
internal data class SwitchCamera(
    val scale: Double,
    val originX: Double,
    val originY: Double,
    val screenWidth: Double,
    val screenHeight: Double,
    val viewportScale: Double,
)

internal data class SwitchRunner(
    val id: String,
    val nameKey: String?,
    val displayName: String?,
    val color: SwitchColor,
    val isLocal: Boolean,
    val isConnected: Boolean,
    val isBoosted: Boolean,
    val rank: Int?,
    val status: SwitchRunnerStatus,
    val gravity: SwitchGravity,
    val scale: Double,
    val crashReason: String?,
    val trackX: Double,
    val trackY: Double,
    /** World pose (y up) and facing in radians. */
    val x: Double,
    val y: Double,
    val angle: Double,
    /** Lost robots far behind the trail are not drawn. */
    val isHidden: Boolean,
) {
    val isRunning: Boolean get() = status == SwitchRunnerStatus.RUNNING
}

/** A start platform in the spawn section's track coordinates. */
internal data class SwitchPlatform(val rect: SwitchRect, val gravity: SwitchGravity, val color: SwitchColor)

/** The dimmed band behind the "left behind" line, in world points: x/y pairs, then the line. */
internal class SwitchLostZone(val polygon: FloatArray, val line: FloatArray)

/** The moving world of one frame. Platforms and the lost zone repeat the last ones sent. */
internal data class SwitchWorld(
    val matchId: String,
    val tick: Long,
    val time: Double,
    val phase: SwitchPhase,
    val countdown: Int?,
    val camera: SwitchCamera,
    val focusX: Double,
    val focusY: Double,
    val cameraFocus: Double,
    val cameraTrail: Double,
    val visibleMaxX: Double,
    val runners: List<SwitchRunner>,
    val platforms: List<SwitchPlatform>,
    val lostZone: SwitchLostZone?,
)

internal data class SwitchStanding(
    val id: String,
    val nameKey: String?,
    val displayName: String?,
    val color: SwitchColor,
    val rank: Int?,
    val status: SwitchRunnerStatus,
    val crashReason: String?,
    val statusKey: String,
    val isOut: Boolean,
    val isLocal: Boolean,
    val isConnected: Boolean,
    val time: Double?,
)

/** A name beside a robot on its start platform; `x` is the leading edge, `y` the center (screen, y up). */
internal data class SwitchNameTag(
    val id: String,
    val nameKey: String?,
    val displayName: String?,
    val color: SwitchColor,
    val isLocal: Boolean,
    val x: Double,
    val y: Double,
)

/** `FausSwitchMatchUI`: the bars and panels over the race. */
internal data class SwitchMatchUi(
    val phase: SwitchPhase,
    val countdown: Int?,
    val standings: List<SwitchStanding>,
    val nameTags: List<SwitchNameTag>,
    val localStatus: SwitchRunnerStatus?,
    val localCrashReason: String?,
    val localRank: Int?,
    val localTime: Double?,
    val runnerCount: Int,
    val canFlip: Boolean,
    val noticeTitleKey: String?,
    val noticeDetailKey: String?,
    val noticeIsBlocking: Boolean,
    val canRetry: Boolean,
    val canReclaim: Boolean,
    val showsResult: Boolean,
    val showsRematchRoom: Boolean,
    val demoOutcome: SwitchDemoOutcome,
    val demoTitleKey: String,
    val demoDetailKey: String,
)

internal enum class SwitchEventType(val raw: String) {
    COUNTDOWN("countdown"), STARTED("started"), HUMAN_BOOSTED("humanBoosted"), HUMAN_SLOWED("humanSlowed"),
    HUMAN_TELEPORTED("humanTeleported"), HUMAN_CRASHED("humanCrashed"), HUMAN_FINISHED("humanFinished"), ENDED("ended");

    companion object {
        fun from(raw: String) = entries.firstOrNull { it.raw == raw }
    }
}

internal data class SwitchEvent(val type: SwitchEventType, val value: Int? = null, val reason: String? = null)

/** One bridge answer: the frame and overlays once a race started, plus the call's own extras. */
internal data class SwitchUpdate(
    val world: SwitchWorld?,
    val match: SwitchMatchUi?,
    val events: List<SwitchEvent> = emptyList(),
    val changed: Boolean? = null,
    val flip: SwitchFlip? = null,
    val gravity: SwitchGravity? = null,
)

// Static course (read once).

/** A straight section: its point (x, y) is at rotate(angle)·(x − originX, y − centerY) + pose. */
internal data class SwitchSection(
    val startX: Double, val endX: Double, val originX: Double,
    val poseX: Double, val poseY: Double, val angle: Double,
)

/** A bend: both rails as arcs around (centerX, centerY) in world points, drawn in [section]'s colors. */
internal data class SwitchTurn(
    val centerX: Double, val centerY: Double, val startAngle: Double,
    val isLeft: Boolean, val radius: Double, val section: Int,
)

internal data class SwitchRail(val section: Int, val rect: SwitchRect, val isFloor: Boolean)
internal data class SwitchBlock(val id: String, val section: Int, val group: Int, val rect: SwitchRect)
internal data class SwitchGap(val id: String, val minX: Double, val maxX: Double, val rail: SwitchGravity, val section: Int)
internal data class SwitchPad(val id: String, val rect: SwitchRect, val section: Int)
internal data class SwitchPortal(
    val id: String, val x: Double, val rail: SwitchGravity, val section: Int,
    val exitX: Double, val exitGravity: SwitchGravity, val exitSection: Int,
)

internal data class SwitchCourse(
    val version: Int,
    val length: Double,
    val finishX: Double,
    val finishSection: Int,
    val spawnX: Double,
    val spawnSection: Int,
    val worldHeight: Double,
    val viewportWidth: Double,
    val floorSurface: Double,
    val ceilingSurface: Double,
    val railThickness: Double,
    val runnerWidth: Double,
    val runnerHeight: Double,
    val centerY: Double,
    val portalWidth: Double,
    val portalHeight: Double,
    val sections: List<SwitchSection>,
    val turns: List<SwitchTurn>,
    val rails: List<SwitchRail>,
    val blocks: List<SwitchBlock>,
    val gaps: List<SwitchGap>,
    val boosts: List<SwitchPad>,
    val slows: List<SwitchPad>,
    val portals: List<SwitchPortal>,
)

/** `fausSwitchConstants`: the lobby's ranges and every robot color's tone. */
internal data class SwitchConstants(
    val colorHex: Map<SwitchColor, Int>,
    val colors: List<SwitchColor>,
    val minimumBots: Int,
    val maximumBots: Int,
    val defaultBots: Int,
    val botNameKeys: List<String>,
    val humanNameKey: String,
    val countdownSeconds: Int,
    val maximumRunners: Int,
) {
    val botRange: IntRange get() = minimumBots..maximumBots

    /** Demo bots take the colors the player did not pick, in palette order (`FausSwitchColor.free`). */
    fun botColors(excluding: SwitchColor, count: Int): List<SwitchColor> =
        colors.filter { it != excluding }.take(count.coerceAtLeast(0))
}

internal interface FausSwitchEngine {
    fun viewport(width: Double, height: Double): SwitchUpdate
    fun start(color: SwitchColor, botCount: Int): SwitchUpdate
    fun step(deltaSeconds: Double): SwitchUpdate
    fun flip(): SwitchUpdate
    fun pause(): SwitchUpdate
    fun resume(): SwitchUpdate
    fun restart(): SwitchUpdate
    fun close()
}

internal object FausSwitchNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(): FausSwitchEngine {
        checked
        return NativeFausSwitchEngine(FausCrewAndroidBridge.fausSwitchBotCreate())
    }

    private val copies = HashMap<String, Map<String, String>>()

    /** Bundled TR/EN copy from Core, cached per language. */
    @Synchronized
    fun copy(language: String?): Map<String, String> {
        val key = language.orEmpty()
        return copies.getOrPut(key) {
            checked
            JSONObject(FausCrewAndroidBridge.fausSwitchCopy(key)).let { json ->
                json.keys().asSequence().associateWith { json.getString(it) }
            }
        }
    }

    val constants: SwitchConstants by lazy {
        checked
        SwitchFrameParser.constants(FausCrewAndroidBridge.fausSwitchConstants())
    }

    val course: SwitchCourse by lazy {
        checked
        SwitchFrameParser.course(FausCrewAndroidBridge.fausSwitchCourse())
    }
}

private class NativeFausSwitchEngine(private val handle: Int) : FausSwitchEngine {
    private val parser = SwitchFrameParser()

    override fun viewport(width: Double, height: Double) =
        parser.parse(FausCrewAndroidBridge.fausSwitchBotViewport(handle, width, height))
    override fun start(color: SwitchColor, botCount: Int) =
        parser.parse(FausCrewAndroidBridge.fausSwitchBotStart(handle, color.raw, botCount))
    override fun step(deltaSeconds: Double) = parser.parse(FausCrewAndroidBridge.fausSwitchBotStep(handle, deltaSeconds))
    override fun flip() = parser.parse(FausCrewAndroidBridge.fausSwitchBotFlip(handle))
    override fun pause() = parser.parse(FausCrewAndroidBridge.fausSwitchBotPause(handle))
    override fun resume() = parser.parse(FausCrewAndroidBridge.fausSwitchBotResume(handle))
    override fun restart() = parser.parse(FausCrewAndroidBridge.fausSwitchBotRestart(handle))
    override fun close() {
        FausCrewAndroidBridge.fausSwitchBotDestroy(handle)
    }
}

/**
 * Parses the bridge's JSON. Platforms and the lost zone are sent only when they change, so
 * the parser keeps the last ones for the frames in between. One parser per engine.
 */
internal class SwitchFrameParser {
    private var platforms: List<SwitchPlatform> = emptyList()
    private var lostZone: SwitchLostZone? = null
    private var matchId: String? = null

    fun parse(json: String): SwitchUpdate {
        val root = JSONObject(json)
        check(root.optBoolean("ok")) { root.optString("message", "Faus Switch bridge failed") }
        return SwitchUpdate(
            world = root.optJSONObject("frame")?.let(::world),
            match = root.optJSONObject("match")?.let(::matchUi),
            events = root.optJSONArray("events")?.let(::events).orEmpty(),
            changed = if (root.has("changed")) root.getBoolean("changed") else null,
            flip = SwitchFlip.from(root.optNullableString("flip")),
            gravity = root.optNullableString("gravity")?.let(SwitchGravity::from),
        )
    }

    fun world(json: JSONObject): SwitchWorld {
        val id = json.getString("matchId")
        if (id != matchId) {
            // A new race never reuses the last race's pieces.
            matchId = id
            platforms = emptyList()
            lostZone = null
        }
        json.optJSONArray("platforms")?.let { array ->
            platforms = array.objects { SwitchPlatform(rect(it.getJSONArray("rect")), SwitchGravity.from(it.getString("gravity")),
                color(it.getString("color"))) }
        }
        json.optJSONObject("lostZone")?.let { zone ->
            val polygon = zone.getJSONArray("polygon")
            val points = FloatArray(polygon.length() * 2)
            for (index in 0 until polygon.length()) {
                val point = polygon.getJSONArray(index)
                points[index * 2] = point.getDouble(0).toFloat()
                points[index * 2 + 1] = point.getDouble(1).toFloat()
            }
            val line = zone.getJSONArray("line")
            lostZone = SwitchLostZone(points, FloatArray(4) { line.getDouble(it).toFloat() })
        }
        val camera = json.getJSONObject("camera")
        val focus = json.getJSONObject("focus")
        return SwitchWorld(
            matchId = id,
            tick = json.getLong("tick"),
            time = json.getDouble("time"),
            phase = SwitchPhase.from(json.getString("phase")),
            countdown = json.optNullableInt("countdown"),
            camera = SwitchCamera(camera.getDouble("scale"), camera.getDouble("originX"), camera.getDouble("originY"),
                camera.getDouble("screenWidth"), camera.getDouble("screenHeight"), camera.getDouble("viewportScale")),
            focusX = focus.getDouble("x"),
            focusY = focus.getDouble("y"),
            cameraFocus = json.getDouble("cameraFocus"),
            cameraTrail = json.getDouble("cameraTrail"),
            visibleMaxX = json.getDouble("visibleMaxX"),
            runners = json.getJSONArray("runners").objects(::runner),
            platforms = platforms,
            lostZone = lostZone,
        )
    }

    private fun runner(json: JSONObject) = SwitchRunner(
        id = json.getString("id"),
        nameKey = json.optNullableString("nameKey"),
        displayName = json.optNullableString("displayName"),
        color = color(json.getString("color")),
        isLocal = json.getBoolean("local"),
        isConnected = json.getBoolean("connected"),
        isBoosted = json.getBoolean("boosted"),
        rank = json.optNullableInt("rank"),
        status = SwitchRunnerStatus.from(json.getString("status")) ?: SwitchRunnerStatus.RUNNING,
        gravity = SwitchGravity.from(json.getString("gravity")),
        scale = json.getDouble("scale"),
        crashReason = json.optNullableString("crashReason"),
        trackX = json.getDouble("trackX"),
        trackY = json.getDouble("trackY"),
        x = json.getDouble("x"),
        y = json.getDouble("y"),
        angle = json.getDouble("angle"),
        isHidden = json.optBoolean("hidden"),
    )

    companion object {
        fun matchUi(json: JSONObject) = SwitchMatchUi(
            phase = SwitchPhase.from(json.getString("phase")),
            countdown = json.optNullableInt("countdown"),
            standings = json.getJSONArray("standings").objects(::standing),
            nameTags = json.getJSONArray("nameTags").objects { tag ->
                SwitchNameTag(tag.getString("id"), tag.optNullableString("nameKey"), tag.optNullableString("displayName"),
                    color(tag.getString("color")), tag.getBoolean("local"), tag.getDouble("x"), tag.getDouble("y"))
            },
            localStatus = SwitchRunnerStatus.from(json.optNullableString("localStatus")),
            localCrashReason = json.optNullableString("localCrashReason"),
            localRank = json.optNullableInt("localRank"),
            localTime = json.optNullableDouble("localTime"),
            runnerCount = json.getInt("runnerCount"),
            canFlip = json.getBoolean("canFlip"),
            noticeTitleKey = json.optNullableString("noticeTitleKey"),
            noticeDetailKey = json.optNullableString("noticeDetailKey"),
            noticeIsBlocking = json.optBoolean("noticeIsBlocking"),
            canRetry = json.optBoolean("canRetry"),
            canReclaim = json.optBoolean("canReclaim"),
            showsResult = json.optBoolean("showsResult"),
            showsRematchRoom = json.optBoolean("showsRematchRoom"),
            demoOutcome = SwitchDemoOutcome.from(json.optNullableString("demoOutcome")),
            demoTitleKey = json.getString("demoTitleKey"),
            demoDetailKey = json.getString("demoDetailKey"),
        )

        fun standing(json: JSONObject) = SwitchStanding(
            id = json.getString("id"),
            nameKey = json.optNullableString("nameKey"),
            displayName = json.optNullableString("displayName"),
            color = color(json.getString("color")),
            rank = json.optNullableInt("rank"),
            status = SwitchRunnerStatus.from(json.getString("status")) ?: SwitchRunnerStatus.RUNNING,
            crashReason = json.optNullableString("crashReason"),
            statusKey = json.getString("statusKey"),
            isOut = json.getBoolean("out"),
            isLocal = json.getBoolean("local"),
            isConnected = json.optBoolean("connected", true),
            time = json.optNullableDouble("time"),
        )

        fun events(array: JSONArray): List<SwitchEvent> = array.objects { event ->
            SwitchEventType.from(event.getString("type"))?.let {
                SwitchEvent(it, event.optNullableInt("value"), event.optNullableString("reason"))
            }
        }.filterNotNull()

        fun constants(json: String): SwitchConstants {
            val root = JSONObject(json)
            val colors = root.getJSONArray("colors").objects { it }
            val names = root.getJSONArray("botNameKeys")
            return SwitchConstants(
                colorHex = colors.associate { color(it.getString("id")) to it.getInt("hex") },
                colors = colors.map { color(it.getString("id")) },
                minimumBots = root.getInt("minimumBots"),
                maximumBots = root.getInt("maximumBots"),
                defaultBots = root.getInt("defaultBots"),
                botNameKeys = List(names.length()) { names.getString(it) },
                humanNameKey = root.getString("humanNameKey"),
                countdownSeconds = root.getInt("countdownSeconds"),
                maximumRunners = root.getInt("maximumRunners"),
            )
        }

        fun course(json: String): SwitchCourse {
            val root = JSONObject(json)
            return SwitchCourse(
                version = root.getInt("version"),
                length = root.getDouble("length"),
                finishX = root.getDouble("finishX"),
                finishSection = root.getInt("finishSection"),
                spawnX = root.getDouble("spawnX"),
                spawnSection = root.getInt("spawnSection"),
                worldHeight = root.getDouble("worldHeight"),
                viewportWidth = root.getDouble("viewportWidth"),
                floorSurface = root.getDouble("floorSurface"),
                ceilingSurface = root.getDouble("ceilingSurface"),
                railThickness = root.getDouble("railThickness"),
                runnerWidth = root.getDouble("runnerWidth"),
                runnerHeight = root.getDouble("runnerHeight"),
                centerY = root.getDouble("centerY"),
                portalWidth = root.getDouble("portalWidth"),
                portalHeight = root.getDouble("portalHeight"),
                sections = root.getJSONArray("sections").objects {
                    SwitchSection(it.getDouble("startX"), it.getDouble("endX"), it.getDouble("originX"),
                        it.getDouble("poseX"), it.getDouble("poseY"), it.getDouble("angle"))
                },
                turns = root.getJSONArray("turns").objects {
                    SwitchTurn(it.getDouble("centerX"), it.getDouble("centerY"), it.getDouble("startAngle"),
                        it.getBoolean("isLeft"), it.getDouble("radius"), it.getInt("section"))
                },
                rails = root.getJSONArray("rails").objects {
                    SwitchRail(it.getInt("section"), rect(it.getJSONArray("rect")), it.getBoolean("floor"))
                },
                blocks = root.getJSONArray("blocks").objects {
                    SwitchBlock(it.getString("id"), it.getInt("section"), it.getInt("group"), rect(it.getJSONArray("rect")))
                },
                gaps = root.getJSONArray("gaps").objects {
                    SwitchGap(it.getString("id"), it.getDouble("minX"), it.getDouble("maxX"),
                        SwitchGravity.from(it.getString("rail")), it.getInt("section"))
                },
                boosts = root.getJSONArray("boosts").objects(::pad),
                slows = root.getJSONArray("slows").objects(::pad),
                portals = root.getJSONArray("portals").objects {
                    SwitchPortal(it.getString("id"), it.getDouble("x"), SwitchGravity.from(it.getString("rail")),
                        it.getInt("section"), it.getDouble("exitX"), SwitchGravity.from(it.getString("exitGravity")),
                        it.getInt("exitSection"))
                },
            )
        }

        private fun pad(json: JSONObject) = SwitchPad(json.getString("id"), rect(json.getJSONArray("rect")), json.getInt("section"))

        private fun rect(array: JSONArray) =
            SwitchRect(array.getDouble(0), array.getDouble(1), array.getDouble(2), array.getDouble(3))

        private fun color(raw: String) = SwitchColor.from(raw) ?: SwitchColor.LAVENDER
    }
}

private fun <T> JSONArray.objects(transform: (JSONObject) -> T): List<T> = List(length()) { transform(getJSONObject(it)) }

private fun JSONObject.optNullableInt(key: String): Int? = if (isNull(key)) null else getInt(key)

private fun JSONObject.optNullableDouble(key: String): Double? = if (isNull(key)) null else getDouble(key)
