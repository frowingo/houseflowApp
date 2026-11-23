package com.fauscrew.viewmodel

import com.fauscrew.platform.AuthDestination
import com.fauscrew.platform.AuthProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PushSessionUserTest {
    private fun profile(destination: AuthDestination) = AuthProfile(destination, "a@example.com", null, userId = "u1")
    private fun next(destination: AuthDestination) = AuthRoute.Next(destination, "a@example.com")

    @Test fun aFullySignedInUserIsReturned() {
        for (destination in listOf(AuthDestination.HOUSE_SELECTION, AuthDestination.DASHBOARD)) {
            assertEquals("u1", pushSessionUserId(profile(destination), next(destination)))
        }
    }

    @Test fun anUnverifiedOrIncompleteUserIsNot() {
        for (destination in listOf(AuthDestination.EMAIL_VERIFICATION, AuthDestination.BIRTHDAY_SETUP)) {
            assertNull(pushSessionUserId(profile(destination), next(destination)))
        }
    }

    @Test fun otherRoutesAndNoProfileAreNot() {
        val signedIn = profile(AuthDestination.DASHBOARD)
        for (route in listOf(AuthRoute.SignIn, AuthRoute.Restoring, AuthRoute.RestoreError(null), AuthRoute.Onboarding)) {
            assertNull(pushSessionUserId(signedIn, route))
        }
        assertNull(pushSessionUserId(null, next(AuthDestination.DASHBOARD)))
    }
}
