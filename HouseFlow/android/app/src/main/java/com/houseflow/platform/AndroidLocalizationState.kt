package com.houseflow.platform

import android.content.Context
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext

internal data class LocalizedText(val prefix: String?, val values: Map<String, String>) {
    fun get(key: String): String = values[key] ?: key
}

/** Cache-first state, then iOS's device/default/first-active language order. */
internal class AndroidLocalizationState(
    private val repository: AndroidLocalizationRepository,
    private val cache: AndroidLocalizationCache,
    private val preferences: AndroidPreferencesStore,
    private val deviceLanguage: () -> String = { Locale.getDefault().toLanguageTag() },
) {
    private val mutableText = MutableStateFlow(LocalizedText(null, emptyMap()))
    val text: StateFlow<LocalizedText> = mutableText.asStateFlow()
    @Volatile private var desiredPrefix: String? = null

    suspend fun start() {
        val persisted = preferences.selectedLanguage()
        val cached = withContext(Dispatchers.IO) { cache.loadMostRecent() }
        val initial = persisted ?: cached?.first
        if (initial != null && desiredPrefix == null && mutableText.value.prefix == null) {
            mutableText.value = LocalizedText(initial, withContext(Dispatchers.IO) { cache.load(initial) })
        }
        val languages = try { repository.fetchLanguages() } catch (cancel: CancellationException) {
            throw cancel
        } catch (_: Exception) { emptyList() }
        val active = languages.filter { it.isActive }
        val chosen = desiredPrefix ?: mutableText.value.prefix ?: persisted ?: cached?.first
            ?: chooseInitial(active, deviceLanguage()) ?: return
        select(chosen)
    }

    suspend fun select(prefix: String, forceRefresh: Boolean = false) {
        val normalized = AndroidLocalizationCache.normalizePrefix(prefix) ?: return
        desiredPrefix = normalized
        val cached = withContext(Dispatchers.IO) { cache.load(normalized) }
        if (desiredPrefix != normalized) return
        mutableText.value = LocalizedText(normalized, cached)
        preferences.setSelectedLanguage(normalized)
        val fresh = repository.values(normalized, forceRefresh)
        if (desiredPrefix == normalized) mutableText.value = LocalizedText(normalized, fresh)
    }

    suspend fun applyProfileLanguage(prefix: String?) {
        if (!prefix.isNullOrBlank() && prefix != mutableText.value.prefix) select(prefix)
    }

    suspend fun availableLanguages(): List<PlatformLanguage> = repository.fetchLanguages()

    companion object {
        fun chooseInitial(active: List<PlatformLanguage>, device: String): String? {
            val normalized = device.lowercase(Locale.ROOT).replace('_', '-')
            return active.firstOrNull { it.prefix.lowercase(Locale.ROOT).replace('_', '-') == normalized }?.prefix
                ?: active.firstOrNull { it.prefix.substringBefore('-').substringBefore('_').lowercase(Locale.ROOT) == normalized.substringBefore('-') }?.prefix
                ?: active.firstOrNull { it.isDefault }?.prefix
                ?: active.firstOrNull()?.prefix
        }

        fun live(context: Context, http: AndroidHttpAdapter): AndroidLocalizationState {
            val cache = AndroidLocalizationCache(context)
            return AndroidLocalizationState(AndroidLocalizationRepository(http::send, cache), cache, AndroidPreferencesStore(context))
        }
    }
}
