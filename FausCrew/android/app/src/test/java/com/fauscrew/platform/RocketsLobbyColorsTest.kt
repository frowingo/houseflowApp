package com.fauscrew.platform

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The lobby output's rocket colors (`HouseRocketsOnlineJSON.lobby` in the bridge). */
class RocketsLobbyColorsTest {
    @Test fun readsTheLobbyColors() {
        val lobby = JSONObject(
            """{"colors":{"preferred":"teal","local":"blue","localClaim":"blue","takenByOthers":["teal","coral","neon"],
               "isPreferredTaken":true,"isLocked":true}}""",
        )
        assertEquals(
            RocketsLobbyColors(
                preferred = RocketsColor.TEAL, local = RocketsColor.BLUE, localClaim = RocketsColor.BLUE,
                takenByOthers = setOf(RocketsColor.TEAL, RocketsColor.CORAL), isPreferredTaken = true, isLocked = true,
            ),
            RocketsLobbyColors.from(lobby),
        )
    }

    @Test fun missingOrEmptyColorsAreNoColors() {
        assertEquals(RocketsLobbyColors(), RocketsLobbyColors.from(JSONObject("{}")))
        val empty = JSONObject("""{"colors":{"preferred":null,"local":null,"localClaim":null,"takenByOthers":[],
            "isPreferredTaken":false,"isLocked":false}}""")
        assertEquals(RocketsLobbyColors(), RocketsLobbyColors.from(empty))
    }

    @Test fun wireNamesRoundTrip() {
        RocketsColor.entries.forEach { assertEquals(it, RocketsColor.from(it.raw)) }
        assertNull(RocketsColor.from("neon"))
    }
}
