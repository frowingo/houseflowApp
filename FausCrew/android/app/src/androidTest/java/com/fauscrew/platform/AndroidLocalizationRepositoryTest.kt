package com.fauscrew.platform

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.IOException
import java.util.UUID
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidLocalizationRepositoryTest {
    private lateinit var context: Context
    private lateinit var directory: File
    private lateinit var cache: AndroidLocalizationCache

    @Before fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        directory = File(context.cacheDir, "Localization-test-${UUID.randomUUID()}")
        cache = AndroidLocalizationCache(context, directory)
    }

    @After fun tearDown() {
        directory.deleteRecursively()
    }

    @Test fun existingIosShapeLoadsAndUnknownKeyFallsBack() {
        assertTrue(directory.mkdirs())
        File(directory, "plaintext_en.json").writeText(
            """{"language":"en","updatedAt":0,"values":{"known.key":"Cached value"}}"""
        )
        val repository = AndroidLocalizationRepository({ error("Offline") }, cache)

        assertEquals("Cached value", repository.value("known.key", cache.load("en")))
        assertEquals("Fallback", repository.value("missing.key", cache.load("en"), "Fallback"))
        assertEquals("en", cache.loadMostRecent()?.first)
    }

    @Test fun explicitRefreshReplacesCacheAndOfflineKeepsLatestValues() = runBlocking {
        val requests = mutableListOf<PlatformHttpRequest>()
        val repository = AndroidLocalizationRepository({ request ->
            requests += request
            PlatformHttpResponse(
                200,
                emptyMap(),
                """{"success":true,"data":[{"key":"greeting","language":"tr","value":"Merhaba"}]}"""
                    .toByteArray(),
            )
        }, cache)

        assertEquals(mapOf("greeting" to "Merhaba"), repository.values(" TR ", forceRefresh = true))
        assertEquals("localization/plaintext/tr", requests.single().path)
        assertEquals(mapOf("greeting" to "Merhaba"), cache.load("tr"))

        val offline = AndroidLocalizationRepository({ throw IOException("offline") }, cache)
        assertEquals(mapOf("greeting" to "Merhaba"), offline.values("tr", forceRefresh = true))
        assertEquals("Merhaba", offline.value("greeting", cache.load("tr")))
    }

    @Test fun languageEndpointMatchesExistingWireFields() = runBlocking {
        val repository = AndroidLocalizationRepository({ request ->
            assertEquals("localization/languages", request.path)
            PlatformHttpResponse(200, emptyMap(),
                """{"success":true,"data":[{"image":"flag","isActive":true,"isDefault":false,"name":"Turkish","nativeName":"Türkçe","prefix":"tr"}]}"""
                    .toByteArray())
        }, cache)

        val language = repository.fetchLanguages().single()
        assertEquals("tr", language.prefix)
        assertTrue(language.isActive)
        assertFalse(language.isDefault)
    }

    @Test fun corruptedOrCrossLanguageCacheDoesNotEscapeItsKey() {
        assertTrue(directory.mkdirs())
        File(directory, "plaintext_en.json").writeText("invalid json")
        assertTrue(cache.load("en").isEmpty())
        File(directory, "plaintext_en.json").writeText(
            """{"language":"tr","updatedAt":0,"values":{"key":"wrong"}}""")
        assertTrue(cache.load("en").isEmpty())
        assertFalse(cache.save("../escape", mapOf("key" to "bad")))
    }
}
