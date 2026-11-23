package com.fauscrew.push

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PushInboxTest {
    @Test fun keepsOnlyKnownStringKeys() {
        val data = PushInbox.dataFrom(mapOf(
            "notificationId" to "n1", "type" to "chore_reminder", "houseId" to "h1", "choreId" to "c1",
            "google.message_id" to "x", "title" to "t",
        ))
        assertEquals(mapOf("notificationId" to "n1", "type" to "chore_reminder", "houseId" to "h1", "choreId" to "c1"), data)
    }

    @Test fun dropsNonStringValues() {
        val data = PushInbox.dataFrom(mapOf("houseId" to "h1", "choreId" to 7, "type" to null))
        assertEquals(mapOf("houseId" to "h1"), data)
    }

    @Test fun missingOrBlankHouseIdIsNull() {
        assertNull(PushInbox.dataFrom(mapOf("type" to "announcement")))
        assertNull(PushInbox.dataFrom(mapOf("houseId" to " ", "type" to "announcement")))
        assertNull(PushInbox.dataFrom(mapOf("houseId" to 5)))
    }
}
