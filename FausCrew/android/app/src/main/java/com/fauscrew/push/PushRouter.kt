package com.fauscrew.push

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import com.fauscrew.platform.InviteCodeBridge
import org.json.JSONArray
import org.json.JSONObject

/** What the UI shows right now; null collections mean "still loading" (Core's `PushRouteContext`). */
internal data class PushRouteContext(
    val isSignedIn: Boolean,
    val houseIds: List<String>?,
    val selectedHouseId: String?,
    val isSwitchingHouse: Boolean,
    val isGameOpen: Boolean,
    val isDashboardShown: Boolean,
    val loadedChoreIds: Set<String>?,
) {
    fun toJson(): String = JSONObject()
        .put("isSignedIn", isSignedIn)
        .put("houseIDs", houseIds?.let(::JSONArray) ?: JSONObject.NULL)
        .put("selectedHouseID", selectedHouseId ?: JSONObject.NULL)
        .put("isSwitchingHouse", isSwitchingHouse)
        .put("isGameOpen", isGameOpen)
        .put("isDashboardShown", isDashboardShown)
        .put("loadedChoreIDs", loadedChoreIds?.let(::JSONArray) ?: JSONObject.NULL)
        .toString()
}

internal sealed interface PushRouteStep {
    /** Keep the target and evaluate again when the context changes. */
    data object Wait : PushRouteStep
    /** The house is not the user's: forget the target. */
    data object Drop : PushRouteStep
    data class SwitchHouse(val houseId: String) : PushRouteStep
    /** Close popups and select the home tab. */
    data object ShowDashboard : PushRouteStep
    data class OpenChore(val choreId: String) : PushRouteStep
    data object Finished : PushRouteStep
}

private fun nativeRoute(targetJson: String, contextJson: String): String {
    check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION)
    return FausCrewAndroidBridge.notificationPushRoute(targetJson, contextJson)
}

/**
 * Asks Core for the next step of a tapped push. A switch is handed out once per tap and a show
 * step once per target and context, so an action that changes nothing cannot loop; the caller clears the target
 * on [PushRouteStep.Drop], [PushRouteStep.OpenChore] and [PushRouteStep.Finished]. A switch that
 * ran but left the house unselected (it failed) ends as a drop.
 */
internal class PushRouter(private val route: (String, String) -> String = ::nativeRoute) {
    private var lastPerformed: Triple<Map<String, String>, PushRouteContext, PushRouteStep>? = null
    /** The target a switch was handed out for; a switch is requested at most once per tap. */
    private var switchedFor: Map<String, String>? = null
    /** The performed switch was seen running; an unrelated context change before it starts is not a failure. */
    private var switchSeenRunning = false

    /** A newer tap starts fresh, even when it equals the previous one. */
    fun reset() {
        lastPerformed = null
        switchedFor = null
        switchSeenRunning = false
    }

    fun next(target: Map<String, String>, context: PushRouteContext): PushRouteStep {
        val result = JSONObject(route(JSONObject(target).toString(), context.toJson()))
        val id = result.optString("id")
        val step = when (result.optString("step")) {
            "switchHouse" -> PushRouteStep.SwitchHouse(id)
            "showDashboard" -> PushRouteStep.ShowDashboard
            "openChore" -> PushRouteStep.OpenChore(id)
            "finished" -> PushRouteStep.Finished
            "drop" -> PushRouteStep.Drop
            else -> PushRouteStep.Wait
        }
        val switched = switchedFor == target
        if (switched && context.isSwitchingHouse) switchSeenRunning = true
        if (step is PushRouteStep.SwitchHouse && switched) {
            // It ran and the context came back still asking for it: it failed, give up. Before it
            // starts, an unrelated change must not request a second switch.
            return if (switchSeenRunning) PushRouteStep.Drop else PushRouteStep.Wait
        }
        if (step is PushRouteStep.SwitchHouse) switchedFor = target
        if (step is PushRouteStep.SwitchHouse || step is PushRouteStep.ShowDashboard) {
            val performed = Triple(target, context, step)
            if (performed == lastPerformed) return PushRouteStep.Wait
            lastPerformed = performed
        }
        return step
    }
}
