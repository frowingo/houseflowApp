package com.fauscrew.platform

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.ByteArrayOutputStream
import java.io.InputStream
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.Request

/**
 * Android side of iOS `CachedRemoteImage`: bounded IO download, small decoded bitmap and a
 * shared memory cache. UI code asks for bitmaps; it never touches HTTP directly.
 */
internal object RemoteImageLoader {
    private val cache by lazy {
        object : LruCache<String, Bitmap>(8 * 1024 * 1024) {
            override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount
        }
    }

    fun isLoadable(url: String?): Boolean =
        url != null && (url.startsWith("https://") || url.startsWith("http://"))

    fun cached(url: String): Bitmap? = synchronized(cache) { cache.get(url) }

    suspend fun load(url: String): Bitmap? = withContext(Dispatchers.IO) {
        cached(url)?.let { return@withContext it }
        try {
            val response = download(url, false, SharedHttpClients.images)
            if (response.statusCode !in 200..299 || response.body.isEmpty()) return@withContext null
            val image = decode(response.body, 256) ?: return@withContext null
            synchronized(cache) { cache.put(url, image) }
            image
        } catch (cancel: CancellationException) { throw cancel }
        catch (_: Exception) { null }
    }

    /**
     * Signed review photos: no shared cache, no Authorization header and the raw status
     * so the caller can refresh an expired signature once. The URL is never logged.
     */
    suspend fun fetchUncached(url: String): PlatformHttpResponse = fetchUncached(url, SharedHttpClients.images)

    internal suspend fun fetchUncached(url: String, callFactory: Call.Factory): PlatformHttpResponse =
        download(url, true, callFactory)

    private suspend fun download(url: String, forceNetwork: Boolean, callFactory: Call.Factory): PlatformHttpResponse {
        val request = Request.Builder().url(url).apply {
            if (forceNetwork) cacheControl(okhttp3.CacheControl.FORCE_NETWORK)
        }.build()
        return callFactory.newCall(request).awaitResponse { response ->
            val bytes = if (response.isSuccessful) response.body?.byteStream()?.use(::readLimited) else null
            PlatformHttpResponse(response.code, emptyMap(), bytes ?: byteArrayOf())
        }
    }

    /** Bounded decode for an in-memory photo; nothing is cached. */
    fun decode(bytes: ByteArray, maxDimension: Int = 1024): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var sample = 1
        while (bounds.outWidth / sample > maxDimension || bounds.outHeight / sample > maxDimension) sample *= 2
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    private fun readLimited(stream: InputStream): ByteArray? {
        val output = ByteArrayOutputStream()
        val chunk = ByteArray(8192)
        while (true) {
            val count = stream.read(chunk)
            if (count < 0) break
            if (output.size() + count > 5 * 1024 * 1024) return null
            output.write(chunk, 0, count)
        }
        return output.toByteArray()
    }
}
