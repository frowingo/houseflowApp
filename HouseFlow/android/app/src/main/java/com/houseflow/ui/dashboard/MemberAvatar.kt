package com.houseflow.ui.dashboard

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.ByteArrayOutputStream
import java.io.InputStream
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.foundation.Image
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.HouseMember
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request

/** Same remote-image-or-initials behavior as iOS; decode only a small avatar bitmap. */
@Composable
internal fun MemberAvatar(member: HouseMember?, size: Dp) {
    var bitmap by remember(member?.imageUrl) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(member?.imageUrl) {
        bitmap = member?.imageUrl?.takeIf { it.startsWith("https://") || it.startsWith("http://") }
            ?.let { AvatarImages.load(it) }
    }
    Box(Modifier.size(size).clip(CircleShape).background(Color(0xFF45579E)), contentAlignment = Alignment.Center) {
        val current = bitmap
        if (current != null) Image(current.asImageBitmap(), contentDescription = member?.name,
            modifier = Modifier.size(size), contentScale = ContentScale.Crop)
        else Text((member?.firstName?.take(1).orEmpty() + member?.lastName?.take(1).orEmpty()).ifBlank { "?" },
            color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
    }
}

internal object AvatarImages {
    private val client = OkHttpClient()
    private val cache = object : LruCache<String, Bitmap>(8 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap): Int = value.byteCount
    }

    suspend fun load(url: String): Bitmap? = withContext(Dispatchers.IO) {
        synchronized(cache) { cache.get(url) }?.let { return@withContext it }
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
