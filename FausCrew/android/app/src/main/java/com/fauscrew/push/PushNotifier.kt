package com.fauscrew.push

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.fauscrew.MainActivity
import com.fauscrew.R
import java.util.UUID

/** Shows a push received while the app is open; tapping it opens [MainActivity] with the data. */
internal object PushNotifier {
    fun show(context: Context, title: String?, body: String?, data: Map<String, String>) {
        if (!PushPermission.isGranted(context)) return
        // The tag mirrors the backend's FCM tag, so a repeat of the same notification replaces it.
        // Without one it is random, and so is the request code: extras are never overwritten.
        val tag = data["notificationId"] ?: UUID.randomUUID().toString()
        val open = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        data.forEach { (key, value) -> open.putExtra(key, value) }
        val contentIntent = PendingIntent.getActivity(
            context, tag.hashCode(), open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, DEFAULT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_fauscrew)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()
        NotificationManagerCompat.from(context).notify(tag, 0, notification)
    }
}
