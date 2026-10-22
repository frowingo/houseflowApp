package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidLifecycleBridgeTest {
    @Test fun forwardsOnlyIdempotentVisibilityTransitions() {
        val bridge = AndroidLifecycleBridge()
        assertEquals(AppVisibility.BACKGROUND, bridge.visibility.value)

        bridge.onStarted()
        bridge.onStarted()
        assertEquals(AppVisibility.ACTIVE, bridge.visibility.value)

        bridge.onStopped()
        assertEquals(AppVisibility.BACKGROUND, bridge.visibility.value)
    }
}
