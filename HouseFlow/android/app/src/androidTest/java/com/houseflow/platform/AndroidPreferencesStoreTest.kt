package com.houseflow.platform

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidPreferencesStoreTest {
    private lateinit var context: Context
    private lateinit var file: File
    private lateinit var scope: CoroutineScope
    private lateinit var dataStore: DataStore<Preferences>

    @Before fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        file = File(context.cacheDir, "houseflow-pref-test-${UUID.randomUUID()}.preferences_pb")
        scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        dataStore = PreferenceDataStoreFactory.create(scope = scope, produceFile = { file })
    }

    @After fun tearDown() {
        scope.cancel()
        file.delete()
    }

    @Test fun defaultsWritesAndRemovalMatchIosPreferenceKeys() = runBlocking {
        val store = AndroidPreferencesStore(dataStore)
        assertFalse(store.hasSeenOnboarding())
        assertNull(store.chosenHouse())

        store.setHasSeenOnboarding(true)
        store.setHasSeenOnboarding(true)
        store.setChosenHouse("house-42")
        assertEquals(true, AndroidPreferencesStore(dataStore).hasSeenOnboarding())
        assertEquals("house-42", AndroidPreferencesStore(dataStore).chosenHouse())

        store.setChosenHouse(null)
        assertNull(store.chosenHouse())
        assertEquals(true, store.hasSeenOnboarding())
        assertEquals(setOf("hasSeenOnboarding"), dataStore.data.first().asMap().keys.map { it.name }.toSet())
    }
}
