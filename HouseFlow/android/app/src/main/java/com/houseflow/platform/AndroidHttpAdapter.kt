package com.houseflow.platform

import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.HttpUrl.Companion.toHttpUrl

/** Kotlin-side mirror of Core's raw HTTP port; status/body interpretation stays in Core. */
internal data class PlatformHttpQueryItem(val name: String, val value: String?)

internal data class PlatformHttpRequest(
    val path: String,
    val method: String,
    val queryItems: List<PlatformHttpQueryItem> = emptyList(),
    val headers: Map<String, String> = emptyMap(),
    val body: ByteArray? = null,
)

internal data class PlatformHttpResponse(
    val statusCode: Int,
    val headers: Map<String, String>,
    val body: ByteArray,
)

/** One pooled client per app graph. No body/header logging and no custom TLS trust manager. */
internal class AndroidHttpAdapter private constructor(
    private val baseUrl: HttpUrl,
    private val callFactory: Call.Factory,
) {
    suspend fun send(request: PlatformHttpRequest): PlatformHttpResponse {
        val call = callFactory.newCall(makeRequest(request))
        return suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, error: IOException) {
                    if (continuation.isActive) continuation.resumeWithException(error)
                }

                override fun onResponse(call: Call, response: Response) {
                    try {
                        response.use {
                            val headers = it.headers.names().associate { name ->
                                name.lowercase() to it.header(name).orEmpty()
                            }
                            val result = PlatformHttpResponse(
                                statusCode = it.code,
                                headers = headers,
                                body = it.body?.bytes() ?: byteArrayOf(),
                            )
                            if (continuation.isActive) continuation.resume(result)
                        }
                    } catch (error: IOException) {
                        if (continuation.isActive) continuation.resumeWithException(error)
                    }
                }
            })
        }
    }

    private fun makeRequest(input: PlatformHttpRequest): Request {
        val segments = input.path.split('/')
        require(segments.isNotEmpty() && segments.all { it.isNotEmpty() && it != "." && it != ".." }) {
            "HTTP path must contain only relative segments"
        }
        val url = baseUrl.newBuilder().apply {
            segments.forEach(::addPathSegment)
            input.queryItems.forEach { addQueryParameter(it.name, it.value) }
        }.build()

        val contentType = input.headers.entries.firstOrNull {
            it.key.equals("Content-Type", ignoreCase = true)
        }?.value?.toMediaType()
        val body = input.body?.toRequestBody(contentType)
            ?: if (input.method.uppercase() in setOf("POST", "PUT", "PATCH")) {
                byteArrayOf().toRequestBody(contentType)
            } else null
        return Request.Builder().url(url).method(input.method, body).apply {
            input.headers.forEach { (name, value) -> header(name, value) }
        }.build()
    }

    companion object {
        const val LIVE_BASE_URL = "https://houseflowapi.fly.dev/api/v1/"

        fun live(baseUrl: String = LIVE_BASE_URL): AndroidHttpAdapter {
            val parsed = baseUrl.toHttpUrl()
            require(parsed.isHttps) { "Production HTTP endpoint must use HTTPS" }
            val client = OkHttpClient.Builder()
                .callTimeout(30, TimeUnit.SECONDS)
                .build()
            return AndroidHttpAdapter(parsed, client)
        }

        /** Loopback/fake transport for deterministic contract tests only. */
        internal fun forTesting(baseUrl: HttpUrl, callFactory: Call.Factory): AndroidHttpAdapter =
            AndroidHttpAdapter(baseUrl, callFactory)
    }
}

/** `Retry-After` as seconds from now: delta-seconds or an HTTP-date, like iOS. */
internal fun retryAfterSeconds(value: String?, nowMillis: Long = System.currentTimeMillis()): Double? {
    val text = value?.trim()?.takeIf(String::isNotEmpty) ?: return null
    text.toDoubleOrNull()?.let { return if (it.isFinite() && it >= 0) it else null }
    val format = java.text.SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", java.util.Locale.US)
        .apply { timeZone = java.util.TimeZone.getTimeZone("GMT") }
    val date = runCatching { format.parse(text) }.getOrNull() ?: return null
    return maxOf(0.0, (date.time - nowMillis) / 1000.0)
}
