package com.houseflow.platform

import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AndroidHttpAdapterTest {
    private lateinit var server: MockWebServer

    @Before fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After fun tearDown() {
        server.shutdown()
    }

    @Test fun requestAndRawResponseMatchCoreHttpContract() = runBlocking {
        val fixture = contractFixture()
        server.enqueue(MockResponse()
            .setResponseCode(fixture.getValue("responseStatus").toInt())
            .setHeader(fixture.getValue("responseHeaderName"), fixture.getValue("responseHeaderValue"))
            .setBody(fixture.getValue("responseBody")))
        val adapter = adapter()
        val body = fixture.getValue("body").toByteArray()

        val response = adapter.send(PlatformHttpRequest(
            path = fixture.getValue("path"),
            method = fixture.getValue("method"),
            queryItems = listOf(PlatformHttpQueryItem(fixture.getValue("queryName"), fixture.getValue("queryValue"))),
            headers = mapOf("Authorization" to fixture.getValue("authorization"), "Content-Type" to fixture.getValue("contentType")),
            body = body,
        ))

        val recorded = server.takeRequest(2, TimeUnit.SECONDS)
        assertNotNull(recorded)
        assertEquals("/api/v1/house/details?houseId=house%201", recorded!!.path)
        assertEquals(fixture.getValue("method"), recorded.method)
        assertEquals(fixture.getValue("authorization"), recorded.getHeader("Authorization"))
        assertEquals(fixture.getValue("contentType"), recorded.getHeader("Content-Type"))
        assertArrayEquals(body, recorded.body.readByteArray())
        assertEquals(fixture.getValue("responseStatus").toInt(), response.statusCode)
        assertEquals(fixture.getValue("responseHeaderValue"), response.headers["x-request-id"])
        assertEquals(fixture.getValue("responseBody"), response.body.toString(Charsets.UTF_8))
    }

    @Test fun cancellationReturnsWithoutWaitingForNetworkTimeout() = runBlocking {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        val request = async(Dispatchers.IO) { adapter().send(PlatformHttpRequest("auth/isAuth", "GET")) }
        assertNotNull(server.takeRequest(2, TimeUnit.SECONDS))

        request.cancelAndJoin()

        assertTrue(request.isCancelled)
    }

    @Test fun requestTimeoutIsTransportFailure() {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        val shortTimeout = OkHttpClient.Builder().callTimeout(150, TimeUnit.MILLISECONDS).build()
        val adapter = AndroidHttpAdapter.forTesting(server.url("/api/v1/"), shortTimeout)

        assertThrows(IOException::class.java) {
            runBlocking { adapter.send(PlatformHttpRequest("auth/isAuth", "GET")) }
        }
    }

    @Test fun productionRejectsCleartextBaseUrl() {
        assertThrows(IllegalArgumentException::class.java) {
            AndroidHttpAdapter.live("http://example.test/api/v1/")
        }
    }

    private fun adapter() = AndroidHttpAdapter.forTesting(
        server.url("/api/v1/"),
        OkHttpClient.Builder().callTimeout(2, TimeUnit.SECONDS).build(),
    )

    private fun contractFixture(): Map<String, String> =
        requireNotNull(javaClass.classLoader?.getResourceAsStream("platform_http_contract.txt"))
            .bufferedReader().useLines { lines ->
                lines.filter { it.isNotBlank() }.associate { line ->
                    val parts = line.split('=', limit = 2)
                    parts[0] to parts[1]
                }
            }
}
