package com.fauscrew.platform

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * The game socket offers `permessage-deflate` (an 8-player FauseTanks frame shrinks
 * from ~12 KB to ~3 KB) and still reads compressed text frames once the server
 * accepts it.
 */
class RealtimeCompressionTest {
    private lateinit var server: MockWebServer

    @Before fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After fun tearDown() {
        server.shutdown()
    }

    @Test fun socketOffersAndUsesPerMessageDeflate() {
        val frame = "{\"type\":\"houseTanks.snapshot\",\"payload\":\"" + "tank".repeat(2_000) + "\"}"
        server.enqueue(MockResponse()
            .setHeader("Sec-WebSocket-Extensions", "permessage-deflate")
            .withWebSocketUpgrade(object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    webSocket.send(frame)
                }
            }))
        val received = CountDownLatch(1)
        val firstFrame = AtomicReference<String>()
        val factory = OkHttpRealtimeSocketFactory(baseUrl = server.url("/api/v1/"))
        val socket = factory.open("game/sessions/s1/realtime", "protocolVersion=2", "token", object : RealtimeSocketListener {
            override fun onOpen() = Unit
            override fun onText(text: String) {
                if (firstFrame.compareAndSet(null, text)) received.countDown()
            }
            override fun onFailure(failure: OnlineFailure) = Unit
        })
        val request = server.takeRequest(5, TimeUnit.SECONDS)!!
        assertTrue(request.getHeader("Sec-WebSocket-Extensions").orEmpty().contains("permessage-deflate"))
        assertEquals("Bearer token", request.getHeader("Authorization"))
        assertTrue(received.await(5, TimeUnit.SECONDS))
        assertEquals(frame, firstFrame.get())
        socket.close()
    }
}
