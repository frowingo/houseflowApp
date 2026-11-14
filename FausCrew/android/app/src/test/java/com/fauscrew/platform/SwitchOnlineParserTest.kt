package com.fauscrew.platform

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SwitchOnlineParserTest {
    private val match = """
        "phase": "ended", "countdown": null, "roomCountdown": null, "standings": [], "nameTags": [],
        "localStatus": "crashed", "localCrashReason": "leftBehind", "localRank": null, "localTime": null,
        "runnerCount": 2, "canFlip": false, "noticeTitleKey": null, "noticeDetailKey": null,
        "noticeIsBlocking": false, "canRetry": false, "canReclaim": false, "showsResult": true,
        "showsRematchRoom": false, "demoOutcome": null, "demoTitleKey": "faus_switch_time_up",
        "demoDetailKey": "faus_switch_time_up_detail"
    """.trimIndent()

    @Test
    fun roomReadsTheColorsAndTheRematchFlag() {
        val room = SwitchOnlineParser.room(JSONObject("""
            {"isRematchRoom": true, "raceCountdownUptime": 12.5,
             "colors": {"preferred": "ocean", "local": "berry", "localClaim": "berry",
                        "takenByOthers": ["ocean", "plum", "unknown"], "isPreferredTaken": true}}
        """))
        assertEquals(SwitchColor.OCEAN, room.colors.preferred)
        assertEquals(SwitchColor.BERRY, room.colors.local)
        assertEquals(setOf(SwitchColor.OCEAN, SwitchColor.PLUM), room.colors.takenByOthers)
        assertTrue(room.colors.isPreferredTaken)
        assertTrue(room.isRematchRoom)
        assertEquals(12.5, room.raceCountdownUptime!!, 0.0)

        val empty = SwitchOnlineParser.room(JSONObject("""{"raceCountdownUptime": null}"""))
        assertEquals(SwitchLobbyColors(), empty.colors)
        assertFalse(empty.isRematchRoom)
        assertNull(empty.raceCountdownUptime)
    }

    @Test
    fun frameBeforeTheRaceHasOnlyTheOverlays() {
        val frame = SwitchOnlineParser().parse("""{"ok": true, "events": [], "match": {$match}}""")
        assertNull(frame.world)
        assertNull(frame.match.roomCountdown)
        assertNull(frame.match.result)
        assertEquals("leftBehind", frame.match.ui.localCrashReason)
        assertTrue(frame.match.ui.showsResult)
    }

    @Test
    fun resultCarriesTheWinnerAndTheStandings() {
        val frame = SwitchOnlineParser().parse("""
            {"ok": true, "events": [{"type": "humanTeleported"}],
             "match": {$match, "result": {
                "phase": "final", "isWaiting": false, "isFailed": false, "detailKey": "faus_switch_online_final_detail",
                "canRematch": true, "canRetry": false, "retryNotBefore": 0, "sessionId": "s1",
                "winnerId": "u2", "winnerName": null, "titleKey": "faus_switch_online_lost",
                "standings": [{"id": "u2", "nameKey": null, "displayName": "Ada", "color": "plum", "rank": 1,
                               "status": "finished", "crashReason": null, "statusKey": "faus_switch_finished",
                               "out": false, "local": false, "time": 48.5}]}}}
        """)
        val result = frame.match.result!!
        assertEquals("faus_switch_online_lost", result.titleKey)
        assertEquals("u2", result.winnerId)
        assertNull(result.winnerName)
        assertEquals("s1", result.sessionId)
        assertTrue(result.canRematch)
        assertEquals(1, result.standings.size)
        assertEquals("Ada", result.standings[0].displayName)
        assertEquals(listOf(SwitchEventType.HUMAN_TELEPORTED), frame.events.map { it.type })
    }

    @Test(expected = IllegalStateException::class)
    fun aFailedCallThrows() {
        SwitchOnlineParser().parse("""{"ok": false, "message": "Unknown match handle"}""")
    }
}
