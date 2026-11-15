package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class SharedHttpClientsTest {
    @Test fun clientsReuseThePoolAndDispatcher() {
        val api = SharedHttpClients.api
        for (client in listOf(SharedHttpClients.realtime, SharedHttpClients.images)) {
            assertSame(api.connectionPool, client.connectionPool)
            assertSame(api.dispatcher, client.dispatcher)
        }
        assertSame(api, SharedHttpClients.api)
    }

    @Test fun timeoutsStaySpecificToEachClientWithoutAuthInterceptors() {
        val api = SharedHttpClients.api
        assertEquals(0, api.callTimeoutMillis)
        assertEquals(15_000, api.connectTimeoutMillis)
        assertEquals(30_000, api.readTimeoutMillis)
        assertEquals(60_000, api.writeTimeoutMillis)

        val realtime = SharedHttpClients.realtime
        assertEquals(15_000, realtime.connectTimeoutMillis)
        assertEquals(0, realtime.readTimeoutMillis)
        assertEquals(10_000, realtime.writeTimeoutMillis)

        val images = SharedHttpClients.images
        assertEquals(0, images.callTimeoutMillis)
        assertEquals(10_000, images.connectTimeoutMillis)
        assertEquals(10_000, images.readTimeoutMillis)
        assertEquals(10_000, images.writeTimeoutMillis)
        for (client in listOf(api, realtime, images)) {
            assertTrue(client.interceptors.isEmpty())
            assertTrue(client.networkInterceptors.isEmpty())
        }
    }
}
