package com.fauscrew.ui.dashboard.notifications

import java.time.Instant
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationTimeTest {
    private val now = Instant.parse("2026-11-21T12:00:00Z")

    private fun text(createdAt: String, turkish: Boolean = false) =
        relativeNotificationTime(createdAt, now, turkish, ZoneOffset.UTC)

    @Test fun shortAgesAreRelative() {
        assertEquals("now", text("2026-11-21T11:59:40Z"))
        assertEquals("5 min. ago", text("2026-11-21T11:55:00Z"))
        assertEquals("3 hr. ago", text("2026-11-21T09:00:00Z"))
        assertEquals("2 days ago", text("2026-11-19T12:00:00Z"))
    }

    @Test fun turkishCopy() {
        assertEquals("5 dk. önce", text("2026-11-21T11:55:00Z", turkish = true))
        assertEquals("3 sa. önce", text("2026-11-21T09:00:00Z", turkish = true))
        assertEquals("2 gün önce", text("2026-11-19T12:00:00Z", turkish = true))
    }

    @Test fun aFutureTimeNeverReadsAsFuture() {
        assertEquals("now", text("2026-11-21T12:30:00Z"))
    }

    @Test fun unreadableTimeIsEmptyAndOldItemsShowTheDate() {
        assertEquals("", text("nope"))
        assertEquals(true, text("2026-10-01T12:00:00Z").contains("2026"))
    }
}
