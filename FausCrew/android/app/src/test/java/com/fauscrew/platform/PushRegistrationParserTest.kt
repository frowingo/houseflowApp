package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PushRegistrationParserTest {
    @Test fun parsesEveryEffectAndTheCleanupFlag() {
        val result = PushRegistrationParser.parse("""{"ok":true,"cleaningUp":true,"effects":[
            {"type":"register","token":"t1"},{"type":"unregister","token":"t2"},{"type":"deleteLocalToken"}]}""")
        assertEquals(true, result.cleaningUp)
        assertEquals(
            listOf(PushRegistrationEffect.Register("t1"), PushRegistrationEffect.Unregister("t2"), PushRegistrationEffect.DeleteLocalToken),
            result.effects,
        )
    }

    @Test fun noEffects() {
        assertEquals(PushRegistrationResult(false, emptyList()), PushRegistrationParser.parse("""{"ok":true,"cleaningUp":false,"effects":[]}"""))
    }

    @Test fun failuresAndUnknownEffectsAreErrors() {
        assertEquals("Unsupported event", assertThrows(IllegalStateException::class.java) {
            PushRegistrationParser.parse("""{"ok":false,"message":"Unsupported event"}""")
        }.message)
        assertThrows(IllegalStateException::class.java) {
            PushRegistrationParser.parse("""{"ok":true,"cleaningUp":false,"effects":[{"type":"other"}]}""")
        }
    }

    @Test fun signOutReasonsUseCoresWireValues() {
        assertEquals(listOf("userInitiated", "sessionRejected", "accountDeleted"), PushSignOutReason.entries.map { it.wire })
    }
}
