package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Faus Switch bridge contract (`FausSwitchFrameJSON`) as Kotlin reads it. */
class SwitchFrameParserTest {
    private fun frame(matchId: String = "m1", extras: String = "") = """
        "frame":{"matchId":"$matchId","tick":42,"time":0.35,"phase":"playing","countdown":null,
          "camera":{"scale":0.9,"originX":-120.5,"originY":12,"screenWidth":844,"screenHeight":390,"viewportScale":0.95},
          "focus":{"x":300,"y":160},"cameraFocus":310,"cameraTrail":40,"visibleMaxX":1200,
          "runners":[
            {"id":"h","nameKey":null,"displayName":null,"color":"ocean","local":true,"connected":true,"boosted":true,
             "rank":1,"status":"running","gravity":"up","scale":0.9,"crashReason":null,"finishedAtTick":null,
             "trackX":310,"trackY":200,"x":310,"y":200,"angle":0,"hidden":false},
            {"id":"b1","nameKey":"faus_switch_bot_byte","displayName":null,"color":"berry","local":false,"connected":true,
             "boosted":false,"rank":null,"status":"crashed","gravity":"down","scale":0.9,"crashReason":"leftBehind",
             "finishedAtTick":null,"trackX":20,"trackY":40,"x":20,"y":40,"angle":1.57,"hidden":true}]
          $extras}
    """.trimIndent()

    private val platforms = """,
        "platforms":[{"rect":[10,20,60,28],"gravity":"down","color":"ocean"},{"rect":[10,300,60,308],"gravity":"up","color":"berry"}],
        "lostZone":{"polygon":[[0,0],[10,0],[10,390],[0,390]],"line":[40,0,40,390]}"""

    private val match = """
        "match":{"phase":"playing","countdown":null,
          "standings":[{"id":"h","nameKey":null,"displayName":null,"color":"ocean","rank":1,"status":"finished","crashReason":null,
                        "statusKey":"faus_switch_status_finished","out":false,"local":true,"connected":true,"time":41.25},
                       {"id":"b1","nameKey":"faus_switch_bot_byte","displayName":null,"color":"berry","rank":2,"status":"crashed",
                        "crashReason":"leftBehind","statusKey":"faus_switch_crashed_left_behind_short","out":true,"local":false,
                        "connected":true,"time":null}],
          "nameTags":[{"id":"h","nameKey":null,"displayName":null,"color":"ocean","local":true,"x":96.5,"y":120}],
          "localStatus":"finished","localCrashReason":null,"localRank":1,"localTime":41.25,"runnerCount":2,"canFlip":false,
          "noticeTitleKey":null,"noticeDetailKey":null,"noticeIsBlocking":false,"canRetry":false,"canReclaim":false,
          "showsResult":false,"showsRematchRoom":false,"demoOutcome":"won","demoTitleKey":"faus_switch_won",
          "demoDetailKey":"faus_switch_finished_detail"}
    """.trimIndent()

    @Test
    fun readsTheMovingWorldAndOverlays() {
        val parser = SwitchFrameParser()
        val update = parser.parse("""{"ok":true,${frame(extras = platforms)},$match,
            "events":[{"type":"countdown","value":2},{"type":"humanCrashed","reason":"boundary"},{"type":"later"}]}""")
        assertNotNull(update.world)
        val world = update.world!!
        assertEquals(42L, world.tick)
        assertEquals(SwitchPhase.PLAYING, world.phase)
        assertNull(world.countdown)
        assertEquals(-120.5, world.camera.originX, 0.0)
        assertEquals(0.95, world.camera.viewportScale, 0.0)
        assertEquals(300.0, world.focusX, 0.0)
        val human = world.runners.first()
        assertTrue(human.isLocal && human.isBoosted && human.isRunning)
        assertEquals(SwitchColor.OCEAN, human.color)
        assertEquals(SwitchGravity.UP, human.gravity)
        val bot = world.runners[1]
        assertEquals(SwitchRunnerStatus.CRASHED, bot.status)
        assertEquals("leftBehind", bot.crashReason)
        assertTrue(bot.isHidden)
        assertNull(bot.rank)
        assertEquals(2, world.platforms.size)
        assertEquals(SwitchRect(10.0, 300.0, 60.0, 308.0), world.platforms[1].rect)
        assertEquals(8, world.lostZone!!.polygon.size)
        assertEquals(40f, world.lostZone!!.line[0])

        val ui = update.match!!
        assertEquals(SwitchDemoOutcome.WON, ui.demoOutcome)
        assertEquals(SwitchRunnerStatus.FINISHED, ui.localStatus)
        assertEquals(41.25, ui.localTime!!, 0.0)
        assertEquals(listOf(1, 2), ui.standings.map { it.rank })
        assertTrue(ui.standings[1].isOut)
        assertEquals("faus_switch_crashed_left_behind_short", ui.standings[1].statusKey)
        assertEquals(96.5, ui.nameTags.single().x, 0.0)

        assertEquals(listOf(SwitchEventType.COUNTDOWN, SwitchEventType.HUMAN_CRASHED), update.events.map { it.type })
        assertEquals(2, update.events[0].value)
        assertEquals("boundary", update.events[1].reason)
    }

    @Test
    fun keepsPlatformsAndTheLostZoneUntilTheyChangeOrTheRaceDoes() {
        val parser = SwitchFrameParser()
        val first = parser.parse("""{"ok":true,${frame(extras = platforms)}}""").world!!
        val second = parser.parse("""{"ok":true,${frame()}}""").world!!
        assertSame(first.platforms, second.platforms)
        assertSame(first.lostZone, second.lostZone)
        val next = parser.parse("""{"ok":true,${frame(matchId = "m2")}}""").world!!
        assertTrue(next.platforms.isEmpty())
        assertNull(next.lostZone)
    }

    @Test
    fun readsCallExtrasWithoutAFrameBeforeTheRace() {
        val parser = SwitchFrameParser()
        val viewport = parser.parse("""{"ok":true,"changed":true}""")
        assertNull(viewport.world)
        assertNull(viewport.match)
        assertEquals(true, viewport.changed)
        val flip = parser.parse("""{"ok":true,"flip":"unsupported","gravity":null}""")
        assertEquals(SwitchFlip.UNSUPPORTED, flip.flip)
        assertNull(flip.gravity)
        assertEquals(SwitchGravity.DOWN, parser.parse("""{"ok":true,"flip":"flipped","gravity":"down"}""").gravity)
    }

    @Test(expected = IllegalStateException::class)
    fun rejectsAFailedCall() {
        SwitchFrameParser().parse("""{"ok":false,"message":"Unknown match handle"}""")
    }

    @Test
    fun readsConstantsAndTheBotColors() {
        val constants = SwitchFrameParser.constants("""
            {"colors":[{"id":"plum","hex":3146271,"titleKey":"faus_switch_color_plum"},
                       {"id":"forest","hex":4032877,"titleKey":"faus_switch_color_forest"},
                       {"id":"ocean","hex":1,"titleKey":"faus_switch_color_ocean"}],
             "minimumBots":1,"maximumBots":3,"defaultBots":3,"botNameKeys":["faus_switch_bot_byte","faus_switch_bot_pixel"],
             "humanNameKey":"faus_switch_you","countdownSeconds":3,"physicsRate":120,"maximumRunners":8}
        """.trimIndent())
        assertEquals(1..3, constants.botRange)
        assertEquals(3146271, constants.colorHex[SwitchColor.PLUM])
        assertEquals(listOf(SwitchColor.PLUM, SwitchColor.OCEAN), constants.botColors(SwitchColor.FOREST, 2))
        assertEquals(listOf(SwitchColor.FOREST, SwitchColor.OCEAN), constants.botColors(SwitchColor.PLUM, 5))
        assertEquals(8, constants.maximumRunners)
    }

    @Test
    fun readsTheCourse() {
        val course = SwitchFrameParser.course("""
            {"version":7,"length":9000,"finishX":8800,"finishSection":2,"spawnX":120,"spawnSection":0,"worldHeight":390,
             "viewportWidth":844,"floorSurface":30,"ceilingSurface":360,"railThickness":30,"runnerWidth":27.2,"runnerHeight":33.6,
             "centerY":195,"portalWidth":22,"portalHeight":44,
             "sections":[{"startX":0,"endX":3000,"originX":0,"poseX":0,"poseY":195,"angle":0}],
             "turns":[{"centerX":3000,"centerY":600,"startAngle":-1.57,"isLeft":true,"radius":400,"section":1}],
             "rails":[{"section":0,"rect":[0,0,3000,30],"floor":true}],
             "blocks":[{"id":"b1","section":0,"group":2,"rect":[400,30,430,90]}],
             "gaps":[{"id":"g1","minX":700,"maxX":760,"rail":"up","section":0}],
             "boosts":[{"id":"p1","rect":[900,150,960,170],"section":0}],
             "slows":[],
             "portals":[{"id":"o1","x":1200,"rail":"down","section":0,"exitX":1000,"exitGravity":"up","exitSection":0}]}
        """.trimIndent())
        assertEquals(7, course.version)
        assertEquals(195.0, course.centerY, 0.0)
        assertTrue(course.turns.single().isLeft)
        assertEquals(1, course.turns.single().section)
        assertTrue(course.rails.single().isFloor)
        assertEquals(2, course.blocks.single().group)
        assertEquals(SwitchGravity.UP, course.gaps.single().rail)
        assertTrue(course.slows.isEmpty())
        assertEquals(SwitchGravity.UP, course.portals.single().exitGravity)
        assertFalse(course.boosts.isEmpty())
    }
}
