package com.fauscrew.platform

import java.io.IOException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import okio.BufferedSource
import okio.ForwardingSource
import okio.Timeout
import okio.buffer
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RemoteImageLoaderTest {
    @Test fun cancellationCancelsTheUnderlyingCallAndClosesALateResponse() = runTest {
        val calls = PendingCalls()
        val download = async { RemoteImageLoader.fetchUncached("https://signed.example/photo", calls) }
        runCurrent()
        assertTrue(calls.call.isExecuted())
        assertFalse(calls.call.isCanceled())

        download.cancelAndJoin()

        assertTrue(download.isCancelled)
        assertTrue(calls.call.isCanceled())
        calls.call.callback.onFailure(calls.call, IOException("canceled"))
        var closed = false
        val source = object : ForwardingSource(Buffer().writeUtf8("late photo")) {
            override fun close() { closed = true; super.close() }
        }.buffer()
        val body = object : ResponseBody() {
            override fun contentType(): MediaType? = null
            override fun contentLength(): Long = 10
            override fun source(): BufferedSource = source
        }
        calls.call.respond(200, body)
        assertTrue(closed)
    }

    @Test fun signedPhotoKeepsForceNetworkNoAuthorizationAndRawStatus() = runTest {
        val calls = PendingCalls()
        val download = async { RemoteImageLoader.fetchUncached("https://signed.example/photo", calls) }
        runCurrent()

        assertTrue(calls.call.request().cacheControl.noCache)
        assertNull(calls.call.request().header("Authorization"))
        calls.call.respond(403, "expired".toResponseBody())

        val response = download.await()
        assertEquals(403, response.statusCode)
        assertTrue(response.body.isEmpty())
    }

    @Test fun downloadAcceptsFiveMegabytesAndDropsLargerBodies() = runTest {
        val limit = 5 * 1024 * 1024
        for (size in listOf(limit, limit + 1)) {
            val calls = PendingCalls()
            val bytes = ByteArray(size) { 1 }
            val download = async { RemoteImageLoader.fetchUncached("https://signed.example/photo", calls) }
            runCurrent()
            calls.call.respond(200, bytes.toResponseBody())

            val response = download.await()
            assertEquals(200, response.statusCode)
            assertArrayEquals(if (size == limit) bytes else byteArrayOf(), response.body)
        }
    }

    @Test fun adapterAlsoCancelsItsCallThroughTheSharedHelper() = runTest {
        val calls = PendingCalls()
        val adapter = AndroidHttpAdapter.forTesting(
            okhttp3.HttpUrl.Builder().scheme("https").host("example.test").build(), calls,
        )
        val request = async { adapter.send(PlatformHttpRequest("photo", "GET")) }
        runCurrent()

        request.cancelAndJoin()

        assertTrue(request.isCancelled)
        assertTrue(calls.call.isCanceled())
    }

    private class PendingCalls : Call.Factory {
        lateinit var call: PendingCall
        override fun newCall(request: Request): Call = PendingCall(request).also { call = it }
    }

    private class PendingCall(private val input: Request) : Call {
        lateinit var callback: Callback
        private var canceled = false
        private var executed = false
        override fun request(): Request = input
        override fun execute(): Response = error("Only asynchronous calls are supported")
        override fun enqueue(responseCallback: Callback) {
            executed = true
            callback = responseCallback
        }
        override fun cancel() { canceled = true }
        override fun isExecuted(): Boolean = executed
        override fun isCanceled(): Boolean = canceled
        override fun timeout(): Timeout = Timeout()
        override fun clone(): Call = PendingCall(input)

        fun respond(status: Int, body: ResponseBody) {
            callback.onResponse(this, Response.Builder().request(input).protocol(Protocol.HTTP_1_1)
                .code(status).message("response").body(body).build())
        }
    }
}
