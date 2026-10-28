package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class InviteCodeBridgeTest {
    @Test fun versionIsExplicit() {
        assertEquals(14, InviteCodeBridge.API_VERSION)
    }

    @Test fun nullIsRejectedBeforeNativeCall() {
        assertThrows(IllegalArgumentException::class.java) {
            InviteCodeBridge.normalize(null)
        }
    }

    @Test fun oversizedInputIsRejectedBeforeNativeCall() {
        assertThrows(IllegalArgumentException::class.java) {
            InviteCodeBridge.normalize("x".repeat(65))
        }
    }
}
