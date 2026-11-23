package com.fauscrew.platform

private val builtIn: Map<String, Pair<String, String>> = mapOf(
    "notifications_title" to ("Bildirimler" to "Notifications"),
    "notifications_empty" to ("Son 30 günde bildirim yok" to "No notifications in the last 30 days"),
    "notifications_error_retry" to ("Bildirimler yüklenemedi. Tekrar dene" to "Couldn't load notifications. Try again"),
    "notifications_open_accessibility_label" to ("Bildirimleri aç" to "Open notifications"),
    "notifications_unread_badge_accessibility" to ("%d okunmamış" to "%d unread"),
    "notifications_former_member" to ("Eski üye" to "Former member"),
    "chore_detail_remind_action" to ("Hatırlat" to "Remind"),
    "chore_detail_reminded" to ("Hatırlatıldı" to "Reminded"),
    "chore_remind_sent" to ("Hatırlatma gönderildi" to "Reminder sent"),
)

/** Built-in tr/en copy for [key] in the app language, for keys the remote catalog does not ship yet. */
internal fun LocalizedText.builtInText(key: String): String {
    val texts = builtIn[key] ?: return key
    return if ((prefix ?: ApiLanguage.code).startsWith("tr", ignoreCase = true)) texts.first else texts.second
}

/** The catalog's text when it has one, else the built-in tr/en text. */
internal fun LocalizedText.notificationText(key: String): String = values[key] ?: builtInText(key)
