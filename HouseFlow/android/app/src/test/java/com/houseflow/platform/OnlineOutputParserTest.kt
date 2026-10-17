package com.houseflow.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OnlineOutputParserTest {
    @Test fun parsesEffectsLobbyAndResult() {
        val output = OnlineOutputParser.parse("""
            {"ok":true,"closed":false,"rematchExcludedSessionId":null,
             "effects":[
               {"type":"ensureSession","connection":1,"path":"game/houseRockets/session","method":"PUT","body":"{\"houseId\":\"h\"}"},
               {"type":"closeSocket"},
               {"type":"openSocket","connection":2,"path":"game/sessions/s/realtime","query":"protocolVersion=2"},
               {"type":"send","connection":2,"text":"{}"},
               {"type":"fetchResult","request":3,"path":"game/sessions/s/result","method":"GET"},
               {"type":"haptic","haptic":"success"}],
             "lobby":{"connection":"connected","isSynced":true,"isLobby":true,"isTerminal":false,"isLeaving":false,
               "isForeground":true,"controlTransferred":false,"hasGame":false,"sessionState":"lobby",
               "statusKey":"house_rockets_online_lobby","detailKey":"house_rockets_online_lobby_detail","showsProgress":false,
               "issueKey":null,"connectionTitleKey":"house_rockets_recovering","connectionDetailKey":"house_rockets_recovering_detail",
               "minimumPlayers":2,"retryNotBefore":null,"canRetry":true,"requiresAuthentication":false,"canChangeReady":true,
               "canCancel":true,"localReady":false,"readyCount":1,
               "participants":[{"playerId":"u","statusKey":"house_rockets_waiting","ready":false,"isLocal":true}],
               "deadlineKind":"ready","deadlineUptime":42.5,"flightCountdownUptime":null},
             "result":{"phase":"available","visible":true,"detailKey":"house_rockets_result_detail","canRematch":true,
               "canRetry":false,"retryNotBefore":0,"sessionId":"s","titleKey":"house_rockets_lost","winnerId":"w",
               "durationSeconds":12.25,
               "players":[{"playerId":"w","rank":1,"distance":900,"name":"Ada","color":"coral","isLocal":false},
                          {"playerId":"u","rank":null,"distance":10,"name":null,"color":null,"isLocal":true}]}}
        """.trimIndent())
        assertEquals(6, output.effects.size)
        assertEquals(OnlineEffect.EnsureSession(1, "game/houseRockets/session", "PUT", """{"houseId":"h"}"""), output.effects[0])
        assertEquals(OnlineEffect.CloseSocket, output.effects[1])
        assertEquals(OnlineEffect.Haptic(true), output.effects[5])
        val lobby = output.lobby!!
        assertTrue(lobby.isConnected)
        assertEquals("ready", lobby.deadlineKind)
        assertEquals(42.5, lobby.deadlineUptime!!, 0.0)
        assertEquals(listOf(OnlineParticipant("u", "house_rockets_waiting", false, true)), lobby.participants)
        val result = output.result!!
        assertEquals("w", result.winnerId)
        assertEquals(RocketsColor.CORAL, result.players.first().color)
        assertNull(result.players.last().rank)
    }

    @Test fun parsesOnlineFrameWithNamesAndServerPhases() {
        val (frame, flight) = OnlineOutputParser.frame(RocketsFrameParser(), """
            {"ok":true,"matchId":"s","revision":1,"phase":"recovering","countdown":null,"elapsed":1.5,"cameraX":10,
             "courseAngle":0,"aliveCount":1,"winnerId":null,"lastEliminatedId":null,"direction":null,
             "players":[{"id":"u","nameKey":"","name":"Ada","role":"human","color":"mint","alive":true,"x":1,"y":2,
               "courseHeading":0,"heading":0,"effect":null,"effectRemaining":0}],
             "fields":[],"gates":[],"canSteer":false,"isSyncing":true,"statusKey":"house_rockets_online_syncing_flight",
             "showsConnectionPanel":true,"eliminations":["Bo"]}
        """.trimIndent())!!
        assertEquals(RocketsPhase.RECOVERING, frame.phase)
        assertEquals("Ada", frame.human?.name)
        assertTrue(flight.isSyncing && flight.showsConnectionPanel)
        assertEquals(listOf("Bo"), flight.eliminations)
        assertNull(OnlineOutputParser.frame(RocketsFrameParser(), """{"ok":true}"""))
    }

    @Test fun retryAfterAcceptsSecondsAndHttpDates() {
        assertEquals(3.0, retryAfterSeconds("3")!!, 0.0)
        assertNull(retryAfterSeconds("-1"))
        assertNull(retryAfterSeconds(null))
        assertEquals(10.0, retryAfterSeconds("Thu, 01 Jan 1970 00:00:10 GMT", nowMillis = 0)!!, 0.0)
    }
}
