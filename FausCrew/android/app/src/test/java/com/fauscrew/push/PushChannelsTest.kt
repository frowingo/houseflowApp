package com.fauscrew.push

import org.junit.Assert.assertEquals
import org.junit.Test

class PushChannelsTest {
    @Test fun turkishText() {
        assertEquals("Genel bildirimler" to "Duyurular ve görev hatırlatmaları", PushChannels.defaultChannelText("tr"))
    }

    @Test fun otherLanguagesFallBackToEnglish() {
        val english = "General notifications" to "Announcements and chore reminders"
        assertEquals(english, PushChannels.defaultChannelText("en"))
        assertEquals(english, PushChannels.defaultChannelText("de"))
    }
}
