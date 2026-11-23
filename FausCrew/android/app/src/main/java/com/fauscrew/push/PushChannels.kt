package com.fauscrew.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import com.fauscrew.platform.ApiLanguage

/** Must match `default_notification_channel_id` in the manifest. */
internal const val DEFAULT_CHANNEL_ID = "fauscrew_default"

internal object PushChannels {
    /**
     * Creates the default channel unless it exists. A background wake-up must not rename it to the
     * device language; the app-language rename is [ensureDefault]'s.
     */
    fun createIfMissing(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(DEFAULT_CHANNEL_ID) == null) ensureDefault(context)
    }

    /** Creates the default channel, or renames it when the app language changed (same id). */
    fun ensureDefault(context: Context, languageCode: String = ApiLanguage.code) {
        val (name, description) = defaultChannelText(languageCode)
        val channel = NotificationChannel(DEFAULT_CHANNEL_ID, name, NotificationManager.IMPORTANCE_HIGH)
        channel.description = description
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun defaultChannelText(languageCode: String): Pair<String, String> =
        if (languageCode == "tr") "Genel bildirimler" to "Duyurular ve görev hatırlatmaları"
        else "General notifications" to "Announcements and chore reminders"
}
