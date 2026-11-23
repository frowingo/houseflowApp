package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationStringsTest {
    @Test fun builtInTextFollowsTheAppLanguage() {
        assertEquals("Bildirimler", LocalizedText("tr", emptyMap()).notificationText("notifications_title"))
        assertEquals("Notifications", LocalizedText("en", emptyMap()).notificationText("notifications_title"))
        assertEquals("Hatırlatıldı", LocalizedText("tr-TR", emptyMap()).notificationText("chore_detail_reminded"))
        assertEquals("Reminder sent", LocalizedText("en", emptyMap()).notificationText("chore_remind_sent"))
    }

    @Test fun theCatalogWinsOverTheBuiltInText() {
        val text = LocalizedText("tr", mapOf("notifications_title" to "Duyurular"))
        assertEquals("Duyurular", text.notificationText("notifications_title"))
        assertEquals("Eski üye", text.notificationText("notifications_former_member"))
    }

    @Test fun unknownKeysComeBackAsTheKey() {
        assertEquals("nope", LocalizedText("en", emptyMap()).notificationText("nope"))
    }
}
