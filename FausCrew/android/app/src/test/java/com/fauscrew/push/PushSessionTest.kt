package com.fauscrew.push

import com.fauscrew.viewmodel.AuthRoute
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PushSessionTest {
    @Test fun aSessionRestoreBlipKeepsTheTap() {
        assertFalse(isRealSignOut(hadSession = true, profileUserId = null, route = AuthRoute.Restoring))
        assertFalse(isRealSignOut(hadSession = true, profileUserId = null, route = AuthRoute.RestoreError("x")))
        assertFalse(isRealSignOut(hadSession = true, profileUserId = "u1", route = AuthRoute.Restoring))
    }

    @Test fun aRealSignOutClearsTheTap() {
        assertTrue(isRealSignOut(hadSession = true, profileUserId = null, route = AuthRoute.SignIn))
        assertTrue(isRealSignOut(hadSession = true, profileUserId = null, route = AuthRoute.Onboarding))
    }

    @Test fun aColdStartTapSurvivesAndSigningInKeepsIt() {
        assertFalse(isRealSignOut(hadSession = false, profileUserId = null, route = AuthRoute.SignIn))
        assertFalse(isRealSignOut(hadSession = false, profileUserId = "u2", route = AuthRoute.Restoring))
    }

    @Test fun theNotificationUserIsHeldThroughARestore() {
        assertEquals("u1", notificationUserId("u1", null, AuthRoute.Restoring))
        assertEquals("u1", notificationUserId("u1", null, AuthRoute.RestoreError(null)))
        assertNull(notificationUserId("u1", null, AuthRoute.SignIn))
        assertEquals("u2", notificationUserId("u1", "u2", AuthRoute.SignIn))
        assertNull(notificationUserId(null, null, AuthRoute.Restoring))
    }
}
