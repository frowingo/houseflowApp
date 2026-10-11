package com.houseflow.platform

import android.content.Context
import android.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.KeyStore
import java.util.UUID
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class KeystoreSessionStoreTest {
    private lateinit var context: Context
    private lateinit var preferenceName: String
    private lateinit var keyAlias: String
    private lateinit var store: KeystoreSessionStore

    @Before
    fun setUp() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        val suffix = UUID.randomUUID().toString()
        preferenceName = "houseflow_secure_session_test_$suffix"
        keyAlias = "com.houseflow.session.test.$suffix"
        store = reopen()
    }

    @After
    fun tearDown() {
        store.clearSession()
    }

    @Test
    fun valuesSurviveReopenButAreNotStoredAsPlaintext() {
        store.write(SessionField.AUTH_TOKEN, "secret-token-123")
        store.write(SessionField.USER_EMAIL, "member@example.com")

        val raw = preferences().getString(SessionField.AUTH_TOKEN.storageKey, null)
        assertTrue(raw != null)
        assertNotEquals("secret-token-123", raw)
        assertFalse(requireNotNull(raw).contains("secret-token-123"))
        assertEquals(SessionReadResult.Value("secret-token-123"), reopen().read(SessionField.AUTH_TOKEN))
        assertEquals(SessionReadResult.Value("member@example.com"), reopen().read(SessionField.USER_EMAIL))
    }

    @Test
    fun nullWriteRemovesOnlySelectedField() {
        store.write(SessionField.AUTH_TOKEN, "secret-token-123")
        store.write(SessionField.USER_EMAIL, "member@example.com")

        store.write(SessionField.AUTH_TOKEN, null)

        assertEquals(SessionReadResult.Missing, reopen().read(SessionField.AUTH_TOKEN))
        assertEquals(SessionReadResult.Value("member@example.com"), reopen().read(SessionField.USER_EMAIL))
    }

    @Test
    fun logoutDeletesValuesAndKeystoreKey() {
        store.write(SessionField.AUTH_TOKEN, "secret-token-123")
        store.clearSession()

        assertEquals(SessionReadResult.Missing, reopen().read(SessionField.AUTH_TOKEN))
        assertFalse(keyStore().containsAlias(keyAlias))
    }

    @Test
    fun missingKeyClearsSessionAndRequiresReauthentication() {
        store.write(SessionField.AUTH_TOKEN, "secret-token-123")
        store.write(SessionField.USER_EMAIL, "member@example.com")
        keyStore().deleteEntry(keyAlias)

        assertEquals(SessionReadResult.ReauthenticationRequired, reopen().read(SessionField.AUTH_TOKEN))
        assertEquals(SessionReadResult.Missing, reopen().read(SessionField.USER_EMAIL))
        assertNull(preferences().getString(SessionField.AUTH_TOKEN.storageKey, null))
    }

    @Test
    fun newLoginAfterKeyLossDoesNotRetainUnreadableOldFields() {
        store.write(SessionField.AUTH_TOKEN, "old-token")
        store.write(SessionField.USER_EMAIL, "old@example.com")
        keyStore().deleteEntry(keyAlias)

        store.write(SessionField.AUTH_TOKEN, "new-token")

        assertEquals(SessionReadResult.Value("new-token"), reopen().read(SessionField.AUTH_TOKEN))
        assertEquals(SessionReadResult.Missing, reopen().read(SessionField.USER_EMAIL))
    }

    @Test
    fun tamperedCiphertextClearsSessionAndRequiresReauthentication() {
        store.write(SessionField.AUTH_TOKEN, "secret-token-123")
        store.write(SessionField.USER_EMAIL, "member@example.com")
        val raw = requireNotNull(preferences().getString(SessionField.AUTH_TOKEN.storageKey, null))
        val bytes = Base64.decode(raw, Base64.NO_WRAP)
        bytes[bytes.lastIndex] = (bytes.last().toInt() xor 1).toByte()
        assertTrue(preferences().edit().putString(
            SessionField.AUTH_TOKEN.storageKey,
            Base64.encodeToString(bytes, Base64.NO_WRAP),
        ).commit())

        assertEquals(SessionReadResult.ReauthenticationRequired, reopen().read(SessionField.AUTH_TOKEN))
        assertEquals(SessionReadResult.Missing, reopen().read(SessionField.USER_EMAIL))
    }

    private fun reopen() = KeystoreSessionStore(context, preferenceName, keyAlias)

    private fun preferences() = context.getSharedPreferences(preferenceName, Context.MODE_PRIVATE)

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
}
