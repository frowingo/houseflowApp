package com.fauscrew.platform

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.io.IOException
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

internal data class PlatformLanguage(
    val image: String,
    val isActive: Boolean,
    val isDefault: Boolean,
    val name: String,
    val nativeName: String,
    val prefix: String,
)

/** Cache file shape and key match the existing iOS localization cache contract. */
internal class AndroidLocalizationCache(
    context: Context,
    private val directory: File = File(context.applicationContext.filesDir, "Localization"),
) {
    fun load(languagePrefix: String): Map<String, String> {
        val prefix = normalizePrefix(languagePrefix) ?: return emptyMap()
        val payload = fileFor(prefix)?.let(::read)
        return if (payload?.first == prefix) payload.second else emptyMap()
    }

    fun loadMostRecent(): Pair<String, Map<String, String>>? =
        directory.listFiles()
            ?.asSequence()
            ?.filter { it.name.startsWith("plaintext_") && it.extension == "json" }
            ?.sortedByDescending { it.lastModified() }
            ?.mapNotNull(::read)
            ?.firstOrNull { it.first.isNotEmpty() && it.second.isNotEmpty() }

    /** Cache writes are best-effort; the fetched in-memory result remains valid. */
    fun save(languagePrefix: String, values: Map<String, String>): Boolean {
        val target = fileFor(languagePrefix) ?: return false
        if (!directory.exists() && !directory.mkdirs()) return false
        val payload = JSONObject()
            .put("language", requireNotNull(normalizePrefix(languagePrefix)))
            .put("updatedAt", System.currentTimeMillis() / 1000.0)
            .put("values", JSONObject(values))
            .toString()
            .toByteArray(Charsets.UTF_8)
        val atomicFile = AtomicFile(target)
        val stream = try { atomicFile.startWrite() } catch (_: IOException) { return false }
        return try {
            stream.write(payload)
            atomicFile.finishWrite(stream)
            true
        } catch (_: IOException) {
            atomicFile.failWrite(stream)
            false
        }
    }

    private fun read(file: File): Pair<String, Map<String, String>>? = try {
        val payload = JSONObject(String(AtomicFile(file).readFully(), Charsets.UTF_8))
        val language = payload.getString("language")
        val values = payload.getJSONObject("values")
        val result = values.keys().asSequence().associateWith { values.getString(it) }
        language to result
    } catch (_: IOException) {
        null
    } catch (_: JSONException) {
        null
    }

    private fun fileFor(prefix: String): File? = normalizePrefix(prefix)?.let {
        File(directory, "plaintext_$it.json")
    }

    companion object {
        fun normalizePrefix(value: String): String? =
            value.trim().lowercase(Locale.ROOT).takeIf { it.matches(Regex("[a-z0-9_-]{1,35}")) }
    }
}

/** Remote localization with cache-first load, explicit refresh and key fallback. */
internal class AndroidLocalizationRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val cache: AndroidLocalizationCache,
) {
    suspend fun fetchLanguages(): List<PlatformLanguage> = withContext(Dispatchers.IO) {
        val data = fetchData("localization/languages")
        List(data.length()) { index ->
            val item = data.getJSONObject(index)
            PlatformLanguage(
                image = item.getString("image"),
                isActive = item.getBoolean("isActive"),
                isDefault = item.getBoolean("isDefault"),
                name = item.getString("name"),
                nativeName = item.getString("nativeName"),
                prefix = item.getString("prefix"),
            )
        }
    }

    suspend fun values(languagePrefix: String, forceRefresh: Boolean = false): Map<String, String> =
        withContext(Dispatchers.IO) {
            val prefix = requireNotNull(AndroidLocalizationCache.normalizePrefix(languagePrefix)) {
                "Invalid localization language prefix"
            }
            val cached = cache.load(prefix)
            if (cached.isNotEmpty() && !forceRefresh) return@withContext cached
            try {
                val data = fetchData("localization/plaintext/$prefix")
                val fresh = buildMap {
                    repeat(data.length()) { index ->
                        val item = data.getJSONObject(index)
                        item.getString("language") // Keep iOS's required wire-field validation.
                        put(item.getString("key"), item.getString("value"))
                    }
                }
                if (!cache.save(prefix, fresh)) {
                    AppLogger.record(AppLogger.Event.LOCALIZATION_CACHE_WRITE_FAILED)
                }
                fresh
            } catch (error: CancellationException) {
                throw error
            } catch (_: IOException) {
                cached
            } catch (_: JSONException) {
                cached
            } catch (_: LocalizationFetchException) {
                cached
            }
        }

    fun value(forKey: String, values: Map<String, String>, fallback: String = forKey): String =
        values[forKey] ?: fallback

    private suspend fun fetchData(path: String): org.json.JSONArray {
        val response = send(PlatformHttpRequest(path, "GET"))
        if (response.statusCode !in 200..399) throw LocalizationFetchException()
        val envelope = JSONObject(String(response.body, Charsets.UTF_8))
        if (!envelope.getBoolean("success")) throw LocalizationFetchException()
        return envelope.getJSONArray("data")
    }

    private class LocalizationFetchException : Exception()
}
