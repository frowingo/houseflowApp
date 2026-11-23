package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONArray

/** Core's unread/seen rules for the notification panel. */
internal interface NotificationRules {
    fun unreadCount(items: List<NotificationItem>, markerJson: String?): Int

    /** The marker to save when the panel opens; null when there are no items. */
    fun seenMarker(items: List<NotificationItem>): String?
}

internal object NativeNotificationRules : NotificationRules {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun unreadCount(items: List<NotificationItem>, markerJson: String?): Int {
        checked
        return FausCrewAndroidBridge.notificationUnreadCount(itemsJson(items), markerJson.orEmpty())
    }

    override fun seenMarker(items: List<NotificationItem>): String? {
        checked
        return FausCrewAndroidBridge.notificationSeenMarker(itemsJson(items)).ifEmpty { null }
    }

    private fun itemsJson(items: List<NotificationItem>) = JSONArray(items.map { it.toJson() }).toString()
}

/** `ChoreReminderRules.canRemind`: Core decides when the Remind button shows. */
internal object ChoreReminder {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun canRemind(chore: HouseChore, currentUserId: String, nowMillis: Long = System.currentTimeMillis()): Boolean {
        checked
        return FausCrewAndroidBridge.choreCanRemind(
            chore.assignedTo, currentUserId, chore.status, chore.dueDate, nowMillis / 1000.0)
    }
}
