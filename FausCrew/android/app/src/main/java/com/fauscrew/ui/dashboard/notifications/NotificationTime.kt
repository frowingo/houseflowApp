package com.fauscrew.ui.dashboard.notifications

import com.fauscrew.ui.dashboard.parseApiDate
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * "5 min ago" in the app language, never in the future (a fast device clock); older than a week
 * it falls back to the date. Empty when [createdAt] is unreadable.
 */
internal fun relativeNotificationTime(
    createdAt: String, now: Instant, turkish: Boolean, zone: ZoneId = ZoneId.systemDefault(),
): String {
    val created = parseApiDate(createdAt)?.toInstant() ?: return ""
    val age = Duration.between(minOf(created, now), now)
    return when {
        age.toMinutes() < 1 -> if (turkish) "şimdi" else "now"
        age.toMinutes() < 60 -> if (turkish) "${age.toMinutes()} dk. önce" else "${age.toMinutes()} min. ago"
        age.toHours() < 24 -> if (turkish) "${age.toHours()} sa. önce" else "${age.toHours()} hr. ago"
        age.toDays() < 7 -> if (turkish) "${age.toDays()} gün önce" else "${age.toDays()} days ago"
        else -> DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
            .withLocale(Locale.forLanguageTag(if (turkish) "tr" else "en")).format(created.atZone(zone))
    }
}
