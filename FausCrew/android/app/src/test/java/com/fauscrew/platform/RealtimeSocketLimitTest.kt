package com.fauscrew.platform

import java.io.IOException
import okhttp3.Request
import okhttp3.WebSocket
import okio.ByteString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RealtimeSocketLimitTest {
    @Test fun byteLimitIsInclusiveForAsciiAndMultibyteText() {
        val limit = REALTIME_MAXIMUM_INCOMING_BYTES
        assertFalse(exceedsRealtimeMessageLimit(""))
        for (character in listOf("a", "é", "€", "🚀")) {
            val size = character.toByteArray(Charsets.UTF_8).size
            val text = character.repeat(limit / size) + "a".repeat(limit % size)
            assertFalse(exceedsRealtimeMessageLimit(text))
            assertTrue(exceedsRealtimeMessageLimit(text + "a"))
        }
        assertFalse(exceedsRealtimeMessageLimit("€".repeat(limit / 3)))
    }

    @Test fun oversizedTextClosesWithoutForwardingAndReportsOnlyOnce() {
        val events = RecordingListener()
        val listener = OkHttpRealtimeSocketListener(events)
        val socket = FakeSocket()

        listener.onMessage(socket, "a".repeat(REALTIME_MAXIMUM_INCOMING_BYTES + 1))
        listener.onMessage(socket, "late frame")
        listener.onClosing(socket, 1009, "Message too large")
        listener.onFailure(socket, IOException("closed"), null)

        assertEquals(listOf(1009 to "Message too large"), socket.closes)
        assertTrue(events.texts.isEmpty())
        assertEquals(listOf(OnlineFailure.Transport), events.failures)
    }

    @Test fun acceptedTextIsForwardedAndBinaryFramesStayIgnored() {
        val events = RecordingListener()
        val listener = OkHttpRealtimeSocketListener(events)
        val socket = FakeSocket()
        val text = "a".repeat(REALTIME_MAXIMUM_INCOMING_BYTES)

        listener.onMessage(socket, ByteString.EMPTY)
        listener.onMessage(socket, text)

        assertEquals(listOf(text), events.texts)
        assertTrue(events.failures.isEmpty())
        assertTrue(socket.closes.isEmpty())
    }

    @Test fun membershipRevocationKeepsItsFailureKindAndIsReportedOnce() {
        val events = RecordingListener()
        val listener = OkHttpRealtimeSocketListener(events)
        val socket = FakeSocket()

        listener.onClosing(socket, 1008, "house membership revoked")
        listener.onFailure(socket, IOException("closed"), null)

        assertEquals(listOf(1000 to null), socket.closes)
        assertEquals(listOf(OnlineFailure.Forbidden), events.failures)
    }

    private class RecordingListener : RealtimeSocketListener {
        val texts = mutableListOf<String>()
        val failures = mutableListOf<OnlineFailure>()
        override fun onOpen() = Unit
        override fun onText(text: String) { texts += text }
        override fun onFailure(failure: OnlineFailure) { failures += failure }
    }

    private class FakeSocket : WebSocket {
        val closes = mutableListOf<Pair<Int, String?>>()
        override fun request(): Request = Request.Builder().url("https://example.test/").build()
        override fun queueSize(): Long = 0
        override fun send(text: String): Boolean = true
        override fun send(bytes: ByteString): Boolean = true
        override fun close(code: Int, reason: String?): Boolean {
            closes += code to reason
            return true
        }
        override fun cancel() = Unit
    }
}
