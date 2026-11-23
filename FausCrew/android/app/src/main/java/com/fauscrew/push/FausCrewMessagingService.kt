package com.fauscrew.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class FausCrewMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushLog.d("new token ${PushLog.shortToken(token)}")
        PushTokens.publish(token)
    }

    // Only reached for notification messages while the app is in the foreground; in the
    // background the system shows them itself from the manifest defaults.
    override fun onMessageReceived(message: RemoteMessage) {
        message.notification?.let { PushNotifier.show(this, it.title, it.body, message.data) }
        PushInbox.publishForeground(message.data)
    }
}
