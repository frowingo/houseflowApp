package com.fauscrew.platform

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewPhotoTest {
    @Test fun acceptsSupportedFormatsBySignature() {
        assertEquals("image/jpeg", ReviewPhoto.from(jpeg).mimeType)
        assertEquals("image/png", ReviewPhoto.from(png).mimeType)
        assertEquals("image/webp", ReviewPhoto.from(webp).mimeType)
        assertEquals("review-photo.webp", ReviewPhoto.from(webp).fileName)
    }

    @Test fun rejectsMissingUnsupportedAndOversizedBeforeAnyRequest() {
        assertEquals(ReviewPhotoException.Reason.MISSING, reason(null))
        assertEquals(ReviewPhotoException.Reason.MISSING, reason(byteArrayOf()))
        assertEquals(ReviewPhotoException.Reason.UNSUPPORTED, reason("GIF89a".toByteArray()))
        assertEquals(ReviewPhotoException.Reason.TOO_LARGE, reason(jpeg + ByteArray(ReviewPhoto.MAX_BYTES)))
        assertEquals(ReviewPhoto.MAX_BYTES, ReviewPhoto.from(jpeg + ByteArray(ReviewPhoto.MAX_BYTES - jpeg.size)).bytes.size)
    }

    @Test fun signedUrlExpiryUsesLeeway() {
        val signed = SignedReviewPhotoUrl("https://signed.example", "2026-10-29T10:20:00.500Z")
        val expiry = Instant.parse(signed.expiresAt).toEpochMilli()
        assertFalse(signed.isExpired(expiry - 60_000))
        assertTrue(signed.isExpired(expiry - 2_000))
        assertTrue(signed.isExpired(expiry + 1_000))
        assertFalse(SignedReviewPhotoUrl("", "soon").isExpired(System.currentTimeMillis()))
    }

    private fun reason(bytes: ByteArray?) =
        (runCatching { ReviewPhoto.from(bytes) }.exceptionOrNull() as ReviewPhotoException).reason

    companion object {
        val jpeg = byteArrayOf(0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01)
        val png = byteArrayOf(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D)
        val webp = byteArrayOf(0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50)

        private fun byteArrayOf(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }
    }
}
