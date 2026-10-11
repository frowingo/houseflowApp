package com.houseflow.platform

import android.content.Context
import android.content.SharedPreferences
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.io.IOException
import java.security.InvalidKeyException
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Matches the five persisted fields in Core's SecureSessionStore port. */
internal enum class SessionField(val storageKey: String) {
    AUTH_TOKEN("authToken"),
    USER_EMAIL("userEmail"),
    USER_FIRST_NAME("userFirstName"),
    USER_LAST_NAME("userLastName"),
    PENDING_EMAIL_VERIFICATION("pendingEmailVerification"),
}

internal sealed interface SessionReadResult {
    data class Value(val value: String) : SessionReadResult
    data object Missing : SessionReadResult
    data object ReauthenticationRequired : SessionReadResult
}

/**
 * App-private ciphertext backed by a non-exportable Android Keystore AES key.
 * Calls perform disk/Keystore I/O and must run off the main thread. The Swift
 * port is deliberately not bound until an async JNI ownership contract exists.
 */
internal class KeystoreSessionStore(
    context: Context,
    preferenceName: String = PREFERENCE_NAME,
    private val keyAlias: String = KEY_ALIAS,
) {
    private val applicationContext = context.applicationContext
    private val preferences: SharedPreferences by lazy {
        applicationContext.getSharedPreferences(preferenceName, Context.MODE_PRIVATE)
    }

    @Synchronized
    fun read(field: SessionField): SessionReadResult {
        requireBackgroundThread()
        val encoded = try {
            preferences.getString(field.storageKey, null)
        } catch (_: ClassCastException) {
            return invalidateSession()
        } ?: return SessionReadResult.Missing

        val key = try {
            keyStore().getKey(keyAlias, null) as? SecretKey
        } catch (_: UnrecoverableKeyException) {
            return invalidateSession()
        }
        if (key == null) return invalidateSession()

        val payload = try {
            Base64.decode(encoded, Base64.NO_WRAP)
        } catch (_: IllegalArgumentException) {
            return invalidateSession()
        }
        if (payload.size < HEADER_SIZE + GCM_TAG_BYTES || payload[0] != FORMAT_VERSION) {
            return invalidateSession()
        }

        return try {
            val iv = payload.copyOfRange(1, HEADER_SIZE)
            val ciphertext = payload.copyOfRange(HEADER_SIZE, payload.size)
            val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(GCM_TAG_BITS, iv))
            cipher.updateAAD(field.storageKey.toByteArray(Charsets.UTF_8))
            SessionReadResult.Value(String(cipher.doFinal(ciphertext), Charsets.UTF_8))
        } catch (_: AEADBadTagException) {
            invalidateSession()
        } catch (_: InvalidKeyException) {
            invalidateSession()
        }
    }

    @Synchronized
    fun write(field: SessionField, value: String?) {
        requireBackgroundThread()
        if (value == null) {
            commit(preferences.edit().remove(field.storageKey))
            return
        }

        val payload = try {
            encrypt(keyForWrite(), field, value)
        } catch (_: InvalidKeyException) {
            clearSession()
            encrypt(createKey(), field, value)
        }
        commit(preferences.edit().putString(field.storageKey, Base64.encodeToString(payload, Base64.NO_WRAP)))
    }

    private fun keyForWrite(): SecretKey {
        val existing = try {
            keyStore().getKey(keyAlias, null) as? SecretKey
        } catch (_: UnrecoverableKeyException) {
            clearSession()
            null
        }
        if (existing != null) return existing
        // A restored ciphertext file without its Keystore key cannot be reused.
        if (preferences.all.isNotEmpty()) clearSession()
        return createKey()
    }

    private fun encrypt(key: SecretKey, field: SessionField, value: String): ByteArray {
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(field.storageKey.toByteArray(Charsets.UTF_8))
        val iv = cipher.iv
        check(iv.size == GCM_IV_BYTES) { "Unexpected AES-GCM IV size" }
        return byteArrayOf(FORMAT_VERSION) + iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
    }

    /** Logout removes every session value and its encryption key before returning. */
    @Synchronized
    fun clearSession() {
        requireBackgroundThread()
        commit(preferences.edit().clear())
        keyStore().deleteEntry(keyAlias)
    }

    private fun invalidateSession(): SessionReadResult {
        clearSession()
        AppLogger.record(AppLogger.Event.SESSION_REAUTH_REQUIRED)
        return SessionReadResult.ReauthenticationRequired
    }

    private fun createKey(): SecretKey {
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER)
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    private fun requireBackgroundThread() {
        check(Looper.myLooper() != Looper.getMainLooper()) {
            "Secure session I/O must run off the main thread"
        }
    }

    private fun commit(editor: SharedPreferences.Editor) {
        if (!editor.commit()) throw IOException("Secure session write failed")
    }

    private companion object {
        const val PREFERENCE_NAME = "houseflow_secure_session_v1"
        const val KEY_ALIAS = "com.houseflow.session.v1"
        const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_IV_BYTES = 12
        const val GCM_TAG_BYTES = 16
        const val GCM_TAG_BITS = 128
        const val HEADER_SIZE = 1 + GCM_IV_BYTES
        const val FORMAT_VERSION: Byte = 1
    }
}
