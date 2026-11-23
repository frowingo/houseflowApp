package com.fauscrew.push

import android.content.Intent
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.getAndUpdate

/**
 * Hands push data from the system to the UI: the tapped notification's data (kept until taken, so
 * a cold-start tap survives until the UI exists) and messages that arrive while the app is open.
 */
internal object PushInbox {
    private val keys = listOf("notificationId", "type", "houseId", "choreId")

    private val mutablePendingTap = MutableStateFlow<Map<String, String>?>(null)
    val pendingTap: StateFlow<Map<String, String>?> = mutablePendingTap.asStateFlow()

    private val mutableForegroundMessages = MutableSharedFlow<Map<String, String>>(
        extraBufferCapacity = 8, onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val foregroundMessages: SharedFlow<Map<String, String>> = mutableForegroundMessages.asSharedFlow()

    fun offer(data: Map<String, String>) { mutablePendingTap.value = data }

    fun take(): Map<String, String>? = mutablePendingTap.getAndUpdate { null }

    fun publishForeground(data: Map<String, String>) { mutableForegroundMessages.tryEmit(data) }

    /** Known string keys only; null when there is no house to open. */
    fun dataFrom(extras: Map<String, Any?>): Map<String, String>? {
        val data = keys.mapNotNull { key -> (extras[key] as? String)?.let { key to it } }.toMap()
        return if (data["houseId"].isNullOrBlank()) null else data
    }

    fun fromIntent(intent: Intent?): Map<String, String>? {
        val extras = intent?.extras ?: return null
        @Suppress("DEPRECATION")
        return dataFrom(extras.keySet().associateWith { extras.get(it) })
    }
}
