package com.houseflow.viewmodel

import org.junit.Assert.assertEquals
import org.junit.Test

class InitialRouteTest {
    @Test fun signedOutFirstLaunchShowsOnboarding() {
        assertEquals(AuthRoute.Onboarding, signedOutRoute(false))
    }

    @Test fun signedOutReturningUserShowsSignIn() {
        assertEquals(AuthRoute.SignIn, signedOutRoute(true))
    }
}
