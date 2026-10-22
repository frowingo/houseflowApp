package com.fauscrew.platform

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SocialPlaceholderTest {
    @Test fun placeholderIdsKeepProvidersHidden() {
        assertFalse(isConfiguredSocialId("YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"))
        assertFalse(isConfiguredSocialId("fbYOUR_FACEBOOK_APP_ID"))
        assertFalse(isConfiguredSocialId(" "))
        assertTrue(isConfiguredSocialId("1234567890-abc.apps.googleusercontent.com"))
    }

    @Test fun listedButUnconfiguredProvidersStayVisible() {
        val config = SocialAuthConfig(
            listOf(SocialProvider.GOOGLE, SocialProvider.FACEBOOK, SocialProvider.SNAPCHAT),
            setOf(SocialProvider.GOOGLE, SocialProvider.APPLE),
        )
        assertTrue(config.isShown(SocialProvider.FACEBOOK))
        assertFalse(config.isConfigured(SocialProvider.FACEBOOK))
        assertTrue(config.isConfigured(SocialProvider.GOOGLE))
        assertFalse(config.isConfigured(SocialProvider.APPLE))
    }
}
