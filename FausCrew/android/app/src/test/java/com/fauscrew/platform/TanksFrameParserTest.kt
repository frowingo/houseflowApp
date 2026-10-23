package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TanksFrameParserTest {
    private val withArena = """
        {"ok":true,"started":false,"matchId":"m1","roundKey":"m1-1","revision":2,"phase":"countdown","countdown":3,
         "roundNumber":1,"roundWinnerId":null,"championId":null,"width":844,"height":390,"time":0,
         "players":[
           {"id":"h","nameKey":"house_tanks_you","role":"human","color":"olive","armor":5,"roundsWon":0,"alive":true},
           {"id":"b1","nameKey":"house_tanks_bot_one","role":"bot","color":"plum","armor":4,"roundsWon":1,"alive":true}],
         "tanks":[
           {"id":"h","color":"olive","role":"human","x":84,"y":140,"rotation":0.3,"active":true,"power":"aim",
            "powerFraction":0.5,"aimLength":612.5},
           {"id":"b1","color":"plum","role":"bot","x":740,"y":86,"rotation":2.8,"active":false,"power":null,
            "powerFraction":0,"aimLength":null}],
         "crates":[{"index":4,"x":590,"y":109,"destroyed":false}],
         "projectiles":[{"id":7,"x":120,"y":150,"rotation":0.3,"rocket":true,"color":"olive"}],
         "token":{"kind":"spreadShot","x":420,"y":200,"fraction":0.75},
         "events":[{"type":"fired","playerId":"h","angle":0.3},{"type":"crateBroken","index":2,"x":10,"y":20},
                   {"type":"jokerCollected","playerId":"h","kind":"aim"}],
         "arena":{"mapId":"livingRoom","frame":[16,16,812,358],
           "obstacles":[{"index":0,"style":"divider","tone":"navy","x":422,"y":195,"width":21,"height":39,
                         "rotation":0,"movable":false,"destroyed":false},
                        {"index":4,"style":"crate","tone":"wood","x":590,"y":109,"width":14,"height":14,
                         "rotation":0.26,"movable":true,"destroyed":false}],
           "lines":[[84,195,236,195]],"markers":[[101,78]]}}
    """.trimIndent()

    @Test fun parsesFrameAndKeepsTheArenaForLighterFramesOfTheSameRound() {
        val parser = TanksFrameParser()
        val first = parser.parse(withArena).frame!!
        assertEquals(TanksPhase.COUNTDOWN, first.phase)
        assertEquals(3, first.countdown)
        assertEquals(TanksColor.OLIVE, first.human?.color)
        assertEquals(TanksJoker.AIM, first.tanks[0].power)
        assertEquals(612.5, first.tanks[0].aimLength!!, 0.0)
        assertNull(first.tanks[1].aimLength)
        assertFalse(first.tanks[1].isActive)
        assertTrue(first.projectiles.single().isRocket)
        assertEquals(TanksJoker.SPREAD_SHOT, first.token?.kind)
        assertEquals(2, first.events.size) // jokerCollected has no renderer effect
        assertTrue(first.events[0] is TanksEvent.Fired)
        val arena = first.arena!!
        assertEquals(TanksMap.LIVING_ROOM, arena.map)
        assertTrue(arena.obstacles[1].isMovable)
        assertEquals(TanksObstacleStyle.CRATE, arena.obstacles[1].style)
        assertEquals(812.0, arena.frameWidth, 0.0)

        val lighter = withArena.replace(Regex(""",\s*"arena":\{.*}}$""", RegexOption.DOT_MATCHES_ALL), "}")
            .replace("\"phase\":\"countdown\"", "\"phase\":\"playing\"").replace("\"countdown\":3", "\"countdown\":null")
        val second = parser.parse(lighter).frame!!
        assertEquals(TanksPhase.PLAYING, second.phase)
        assertEquals(arena, second.arena)

        val nextRound = lighter.replace("\"roundKey\":\"m1-1\"", "\"roundKey\":\"m1-2\"")
        assertNull(parser.parse(nextRound).frame!!.arena, "A new round never reuses the old arena")
    }

    @Test fun parsesCallFlagsAndRejectsFailures() {
        val update = TanksFrameParser().parse("""{"ok":true,"started":true,"changed":true}""")
        assertNull(update.frame)
        assertTrue(update.started)
        assertTrue(update.changed)
        val failure = runCatching { TanksFrameParser().parse("""{"ok":false,"message":"Unknown match handle"}""") }
        assertEquals("Unknown match handle", failure.exceptionOrNull()?.message)
    }

    @Test fun parsesMapPreviews() {
        val maps = TanksFrameParser.maps("""
            {"obstacleScale":0.36,"maps":[{"id":"courtyard","spawns":[[0.12,0.36],[0.88,0.64],[0.86,0.22],[0.14,0.7]],
              "obstacles":[{"x":0.5,"y":0.5,"width":0.18,"height":0.18,"rotation":0,"style":"roundTable","tone":"teal"}],
              "lines":[[0.18,0.5,0.38,0.5]],"markers":[[0.18,0.18]]}]}
        """.trimIndent())
        val courtyard = maps.getValue(TanksMap.COURTYARD)
        assertEquals(4, courtyard.spawns.size)
        assertTrue(courtyard.obstacles.single().style.isRound)
        assertEquals(0.36, courtyard.obstacleScale, 0.0)
    }

    private fun assertNull(value: Any?, message: String) = org.junit.Assert.assertNull(message, value)
}
