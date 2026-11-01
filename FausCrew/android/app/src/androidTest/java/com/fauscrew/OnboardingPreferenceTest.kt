package com.fauscrew

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.fauscrew.platform.AndroidPreferencesStore
import java.io.File
import java.util.UUID
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OnboardingPreferenceTest {
    @Test fun completionIsStoredInNonSensitivePreferences() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val file = File(context.cacheDir, "onboarding-${UUID.randomUUID()}.preferences_pb")
        val preferences = AndroidPreferencesStore(PreferenceDataStoreFactory.create(produceFile = { file }))

        assertFalse(preferences.hasSeenOnboarding())
        preferences.setHasSeenOnboarding(true)
        assertTrue(preferences.hasSeenOnboarding())
    }
}
