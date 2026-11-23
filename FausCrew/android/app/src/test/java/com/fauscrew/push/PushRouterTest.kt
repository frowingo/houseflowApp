package com.fauscrew.push

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class PushRouterTest {
    private val target = mapOf("houseId" to "h1", "choreId" to "c1")
    private val context = PushRouteContext(
        isSignedIn = true, houseIds = listOf("h1", "h2"), selectedHouseId = "h2", isSwitchingHouse = false,
        isGameOpen = false, isDashboardShown = true, loadedChoreIds = setOf("c1"),
    )

    private fun router(answer: String, calls: MutableList<Pair<String, String>> = mutableListOf()) =
        PushRouter { targetJson, contextJson -> calls += targetJson to contextJson; answer }

    @Test fun sendsTheTargetAndContextToCoreAsJson() {
        val calls = mutableListOf<Pair<String, String>>()
        router("""{"step":"wait"}""", calls).next(target, context.copy(houseIds = null, loadedChoreIds = null))
        val (targetJson, contextJson) = calls.single()
        assertEquals("h1", JSONObject(targetJson).getString("houseId"))
        assertEquals("c1", JSONObject(targetJson).getString("choreId"))
        val sent = JSONObject(contextJson)
        assertEquals(true, sent.getBoolean("isSignedIn"))
        assertEquals(true, sent.isNull("houseIDs"))
        assertEquals("h2", sent.getString("selectedHouseID"))
        assertEquals(true, sent.isNull("loadedChoreIDs"))
        assertEquals(true, sent.getBoolean("isDashboardShown"))
        val full = JSONObject(context.copy(houseIds = listOf("h1"), loadedChoreIds = setOf("c1")).toJson())
        assertEquals("h1", full.getJSONArray("houseIDs").getString(0))
        assertEquals("c1", full.getJSONArray("loadedChoreIDs").getString(0))
    }

    @Test fun mapsEveryStep() {
        assertEquals(PushRouteStep.Wait, router("""{"step":"wait"}""").next(target, context))
        assertEquals(PushRouteStep.Drop, router("""{"step":"drop"}""").next(target, context))
        assertEquals(PushRouteStep.Finished, router("""{"step":"finished"}""").next(target, context))
        assertEquals(PushRouteStep.OpenChore("c1"), router("""{"step":"openChore","id":"c1"}""").next(target, context))
        assertEquals(PushRouteStep.SwitchHouse("h1"), router("""{"step":"switchHouse","id":"h1"}""").next(target, context))
        assertEquals(PushRouteStep.ShowDashboard, router("""{"step":"showDashboard"}""").next(target, context))
        assertEquals(PushRouteStep.Wait, router("""{"step":"nonsense"}""").next(target, context))
    }

    @Test fun aSwitchOrShowStepIsHandedOutOncePerTargetAndContext() {
        val switch = router("""{"step":"switchHouse","id":"h1"}""")
        assertEquals(PushRouteStep.SwitchHouse("h1"), switch.next(target, context))
        assertEquals(PushRouteStep.Wait, switch.next(target, context))
        val show = router("""{"step":"showDashboard"}""")
        assertEquals(PushRouteStep.ShowDashboard, show.next(target, context))
        assertEquals(PushRouteStep.Wait, show.next(target, context))
    }

    @Test fun aNewTapMayRepeatTheStep() {
        val switch = router("""{"step":"switchHouse","id":"h1"}""")
        assertEquals(PushRouteStep.SwitchHouse("h1"), switch.next(target, context))
        switch.reset()
        assertEquals(PushRouteStep.SwitchHouse("h1"), switch.next(target, context))
    }

    @Test fun terminalStepsAreNeverSuppressed() {
        val open = router("""{"step":"openChore","id":"c1"}""")
        assertEquals(PushRouteStep.OpenChore("c1"), open.next(target, context))
        assertEquals(PushRouteStep.OpenChore("c1"), open.next(target, context))
    }

    @Test fun aSwitchThatLeavesTheHouseUnselectedIsDropped() {
        val switch = router("""{"step":"switchHouse","id":"h1"}""")
        assertEquals(PushRouteStep.SwitchHouse("h1"), switch.next(target, context))
        // Switching started (Core says wait), then it failed and the context is back to the start.
        val waiting = router("""{"step":"wait"}""")
        assertEquals(PushRouteStep.Wait, waiting.next(target, context.copy(isSwitchingHouse = true)))
        assertEquals(PushRouteStep.Wait, switch.next(target, context))
        assertEquals(PushRouteStep.Wait, switch.next(target, context))
        val failed = PushRouter { _, contextJson ->
            if (JSONObject(contextJson).getBoolean("isSwitchingHouse")) """{"step":"wait"}""" else """{"step":"switchHouse","id":"h1"}"""
        }
        assertEquals(PushRouteStep.SwitchHouse("h1"), failed.next(target, context))
        assertEquals(PushRouteStep.Wait, failed.next(target, context.copy(isSwitchingHouse = true)))
        assertEquals(PushRouteStep.Drop, failed.next(target, context))
    }

    @Test fun aContextChangeBeforeTheSwitchStartsIsNotAFailure() {
        val switch = router("""{"step":"switchHouse","id":"h1"}""")
        assertEquals(PushRouteStep.SwitchHouse("h1"), switch.next(target, context))
        // e.g. a popup flag changes before the house view model reports the switch.
        val other = context.copy(isDashboardShown = !context.isDashboardShown)
        assertEquals(PushRouteStep.Wait, switch.next(target, other))
    }

    @Test fun aNewTapForgetsAPerformedSwitch() {
        val failed = PushRouter { _, contextJson ->
            if (JSONObject(contextJson).getBoolean("isSwitchingHouse")) """{"step":"wait"}""" else """{"step":"switchHouse","id":"h1"}"""
        }
        failed.next(target, context)
        failed.next(target, context.copy(isSwitchingHouse = true))
        failed.reset()
        assertEquals(PushRouteStep.SwitchHouse("h1"), failed.next(target, context))
    }
}
