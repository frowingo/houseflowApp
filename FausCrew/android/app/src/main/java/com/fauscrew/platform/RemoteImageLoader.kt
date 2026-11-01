package com.fauscrew.platform

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.ByteArrayOutputStream
import java.io.InputStream
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Android side of iOS `CachedRemoteImage`: bounded IO download, small decoded bitmap and a
 * shared memory cache. UI code asks for bitmaps; it never touches HTTP directly.
 */
internal object RemoteImageLoader {
    private val client = OkHttpClient()
    private val cache = object : LruCache<String, Bitmap>(8 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount
    }

    fun isLoadable(url: String?): Boolean =
        url != null && (url.startsWith("https://") || url.startsWith("http://"))

    fun cached(url: String): Bitmap? = synchronized(cache) { cache.get(url) }

    suspend fun load(url: String): Bitmap? = withContext(Dispatchers.IO) {
        cached(url)?.let { return@withContext it }
        val request = runCatching { Request.Builder().url(url).build() }.getOrNull() ?: return@withContext null
        try {
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                val bytes = response.body?.byteStream()?.use(::readLimited) ?: return@withContext null
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                var sample = 1
                while (bounds.outWidth / sample > 256 || bounds.outHeight / sample > 256) sample *= 2
                val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                    BitmapFactory.Options().apply { inSampleSize = sample }) ?: return@withContext null
                synchronized(cache) { cache.put(url, image) }
                image
            }
        } catch (cancel: CancellationException) { throw cancel }
        catch (_: Exception) { null }
    }

    /**
     * Signed review photos: no shared cache, no Authorization header and the raw status
     * so the caller can refresh an expired signature once. The URL is never logged.
     */
    suspend fun fetchUncached(url: String): PlatformHttpResponse = withContext(Dispatchers.IO) {
        val request = Request.Builder().url(url).cacheControl(okhttp3.CacheControl.FORCE_NETWORK).build()
        client.newCall(request).execute().use { response ->
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
