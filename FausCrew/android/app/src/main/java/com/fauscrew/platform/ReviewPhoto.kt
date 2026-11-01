package com.fauscrew.platform

import android.graphics.Bitmap
import android.graphics.ImageDecoder
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

/**
 * A validated chore review photo for the multipart `file` field. Mirrors Core
 * `ChoreReviewPhotoUpload`: photo bytes never cross the JNI bridge.
 */
internal class ReviewPhoto private constructor(val bytes: ByteArray, val mimeType: String) {
    val fileName: String
        get() = when (mimeType) {
            "image/png" -> "review-photo.png"
            "image/webp" -> "review-photo.webp"
            else -> "review-photo.jpg"
        }

    companion object {
        /** Backend limit: 3 MB, as in Core `ChoreReviewPhotoRules.maxByteCount`. */
        const val MAX_BYTES = 3 * 1024 * 1024

        /** Format from magic bytes so a renamed file cannot pass. */
        fun mimeType(bytes: ByteArray): String? = when {
            bytes.startsWith(0xFF, 0xD8, 0xFF) -> "image/jpeg"
            bytes.startsWith(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A) -> "image/png"
            bytes.size >= 12 && bytes.startsWith(0x52, 0x49, 0x46, 0x46) &&
                bytes.copyOfRange(8, 12).contentEquals(byteArrayOf(0x57, 0x45, 0x42, 0x50)) -> "image/webp"
            else -> null
        }

        fun from(bytes: ByteArray?): ReviewPhoto {
            if (bytes == null || bytes.isEmpty()) throw ReviewPhotoException(ReviewPhotoException.Reason.MISSING)
            val mimeType = mimeType(bytes) ?: throw ReviewPhotoException(ReviewPhotoException.Reason.UNSUPPORTED)
            if (bytes.size > MAX_BYTES) throw ReviewPhotoException(ReviewPhotoException.Reason.TOO_LARGE)
            return ReviewPhoto(bytes, mimeType)
        }

        private fun ByteArray.startsWith(vararg prefix: Int): Boolean =
            size >= prefix.size && prefix.indices.all { this[it] == prefix[it].toByte() }
    }
}

internal class ReviewPhotoException(val reason: Reason) : IllegalArgumentException(reason.name) {
    enum class Reason(val key: String, val fallback: String) {
        MISSING("chore_review_photo_missing", "Add a photo before sending the chore to review."),
        UNSUPPORTED("chore_review_photo_unsupported", "Only JPEG, PNG or WebP photos can be uploaded."),
        TOO_LARGE("chore_review_photo_too_large", "The photo must be 3 MB or smaller."),
    }
}

/**
 * Cache files the camera app writes review photos into. Only a photo taken now is
 * accepted, so the gallery is never offered; each file is deleted once it is read.
 */
internal object ReviewPhotoCapture {
    fun newTarget(context: android.content.Context): Pair<java.io.File, android.net.Uri> {
        val directory = java.io.File(context.cacheDir, "review-photos").apply { mkdirs() }
        directory.listFiles()?.forEach { it.delete() }
        val file = java.io.File.createTempFile("capture-", ".jpg", directory)
        val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.reviewphoto", file)
        return file to uri
    }
}

/** A signed storage URL; it lives only inside one load and is never stored or logged. */
internal data class SignedReviewPhotoUrl(val url: String, val expiresAt: String) {
    fun isExpired(nowMillis: Long, leewayMillis: Long = 5_000): Boolean {
        val expiry = runCatching { java.time.Instant.parse(expiresAt).toEpochMilli() }.getOrNull() ?: return false
        return nowMillis + leewayMillis >= expiry
    }
}

/**
 * Re-encodes a picked photo (often HEIC) as JPEG under the 3 MB limit with the platform
 * decoder, which also applies EXIF rotation. Undecodable input is returned unchanged so
 * [ReviewPhoto.from] reports the precise error.
 */
internal object ReviewPhotoEncoder {
    private const val MAX_DIMENSION = 2048
    private val qualities = listOf(80, 65, 50, 35)

    fun prepared(bytes: ByteArray): ByteArray {
        val bitmap = runCatching {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(ByteBuffer.wrap(bytes))) { decoder, info, _ ->
                val longest = maxOf(info.size.width, info.size.height)
                if (longest > MAX_DIMENSION) {
                    val ratio = MAX_DIMENSION.toFloat() / longest
                    decoder.setTargetSize((info.size.width * ratio).toInt().coerceAtLeast(1),
                        (info.size.height * ratio).toInt().coerceAtLeast(1))
                }
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }.getOrNull() ?: return bytes
        try {
            for (quality in qualities) {
                val output = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
                if (output.size() <= ReviewPhoto.MAX_BYTES) return output.toByteArray()
            }
            return bytes
        } finally {
            bitmap.recycle()
        }
    }
}
