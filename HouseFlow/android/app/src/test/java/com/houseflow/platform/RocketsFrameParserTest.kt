package com.houseflow.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RocketsFrameParserTest {
    private val withCourse = """
        {"ok":true,"started":false,"matchId":"m1","revision":3,"phase":"countdown","countdown":2,
         "elapsed":0,"cameraX":0,"courseAngle":0,"aliveCount":2,"winnerId":null,"lastEliminatedId":null,
         "direction":null,
         "players":[
           {"id":"p1","nameKey":"house_rockets_you","role":"human","color":"mint","alive":true,"x":250,"y":105,
            "courseHeading":0,"heading":0,"effect":null,"effectRemaining":0},
           {"id":"p2","nameKey":"house_rockets_bot_one","role":"bot","color":"coral","alive":true,"x":250,"y":255,
            "courseHeading":0.1,"heading":0.1,"effect":"boost","effectRemaining":1.2}],
         "fields":[{"id":"f1","x":1220,"y":180,"effect":"slow"}],
         "gates":[{"id":"g1","x":900,"width":92,"polygons":[[-46,0,46,0,46,85,-46,85]]}],
         "projection":{"angle":0,"scale":0.79,"originX":10,"originY":-3,"visibleLength":1068,"turning":false},
         "regions":[[180,8,440,44],[180,317,440,44]]}
    """.trimIndent()

    @Test fun parsesFrameAndKeepsGatesForLighterFrames() {
        val parser = RocketsFrameParser()
        val first = parser.parse(withCourse).frame!!
        assertEquals(RocketsPhase.COUNTDOWN, first.phase)
        assertEquals(2, first.countdown)
        assertEquals(RocketsRole.HUMAN, first.human?.role)
        assertEquals(RocketsColor.CORAL, first.players[1].color)
        assertEquals(RocketsEffect.BOOST, first.players[1].effect)
        assertEquals(RocketsEffect.SLOW, first.fields.single().effect)
        assertEquals(8, first.gates.single().polygons.single().size)
        assertEquals(RocketsRegion(180f, 8f, 440f, 44f), first.regions.first())
        assertFalse(first.projection!!.isTurning)
        assertNull(first.turnTargetIsVertical)

        val lighter = withCourse.replace(Regex(""","gates":\[.*?]}]"""), "")
            .replace("\"countdown\":2", "\"countdown\":null").replace("\"phase\":\"countdown\"", "\"phase\":\"playing\"")
            .replace("\"direction\":null", "\"direction\":\"vertical\"").replace("\"started\":false", "\"started\":true")
        val update = parser.parse(lighter)
        assertTrue(update.started)
        assertEquals(listOf("g1"), update.frame!!.gates.map { it.id })
        assertNull(update.frame!!.countdown)
        assertEquals(true, update.frame!!.turnTargetIsVertical)
    }

    @Test fun readsFlagsAndFailures() {
        val parser = RocketsFrameParser()
        assertEquals(RocketsPhase.COUNTDOWN,
            parser.parse(withCourse.replace("\"ok\":true", "\"ok\":true,\"resumed\":\"countdown\"")).resumed)
        assertTrue(parser.parse("""{"ok":true,"changed":true}""").changed)
        assertNull(parser.parse("""{"ok":true}""").frame)
        val failure = runCatching { parser.parse("""{"ok":false,"message":"Unknown match handle"}""") }
        assertEquals("Unknown match handle", failure.exceptionOrNull()?.message)
    }
}
