package com.fauscrew.platform

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

/** The lobby output's tank colors (`HouseTanksOnlineJSON.lobby` in the bridge). */
class TanksLobbyColorsTest {
    @Test fun readsTheLobbyColors() {
        val lobby = JSONObject(
            """{"colors":{"preferred":"plum","local":"sky","localClaim":"sky","takenByOthers":["plum","olive","neon"],
               "isPreferredTaken":true,"isLocked":true}}""",
        )
        assertEquals(
            TanksLobbyColors(
                preferred = TanksColor.PLUM, local = TanksColor.SKY, localClaim = TanksColor.SKY,
                takenByOthers = setOf(TanksColor.PLUM, TanksColor.OLIVE), isPreferredTaken = true, isLocked = true,
            ),
            TanksLobbyColors.from(lobby),
        )
    }

    @Test fun missingOrEmptyColorsAreNoColors() {
        assertEquals(TanksLobbyColors(), TanksLobbyColors.from(JSONObject("{}")))
        val empty = JSONObject("""{"colors":{"preferred":null,"local":null,"localClaim":null,"takenByOthers":[],
            "isPreferredTaken":false,"isLocked":false}}""")
        assertEquals(TanksLobbyColors(), TanksLobbyColors.from(empty))
    }
}
