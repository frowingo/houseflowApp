package com.houseflow.platform

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first

private val Context.houseflowPreferences by preferencesDataStore(name = "houseflow_preferences")

/** Only non-sensitive preference keys from the existing iOS session flows. */
internal class AndroidPreferencesStore internal constructor(
    private val store: DataStore<Preferences>,
) {
    constructor(context: Context) : this(context.applicationContext.houseflowPreferences)

    suspend fun hasSeenOnboarding(): Boolean = store.data.first()[HAS_SEEN_ONBOARDING] ?: false

    suspend fun setHasSeenOnboarding(value: Boolean) {
        store.edit { it[HAS_SEEN_ONBOARDING] = value }
    }

    suspend fun chosenHouse(): String? = store.data.first()[CHOSEN_HOUSE]

    suspend fun setChosenHouse(value: String?) {
        store.edit { preferences ->
            if (value == null) preferences.remove(CHOSEN_HOUSE)
            else preferences[CHOSEN_HOUSE] = value
        }
    }

    suspend fun selectedLanguage(): String? = store.data.first()[SELECTED_LANGUAGE]

    suspend fun setSelectedLanguage(value: String) {
        store.edit { it[SELECTED_LANGUAGE] = value }
    }

    private companion object {
        val HAS_SEEN_ONBOARDING = booleanPreferencesKey("hasSeenOnboarding")
        val CHOSEN_HOUSE = stringPreferencesKey("chosenHouse")
        val SELECTED_LANGUAGE = stringPreferencesKey("selectedLanguage")
    }
}
