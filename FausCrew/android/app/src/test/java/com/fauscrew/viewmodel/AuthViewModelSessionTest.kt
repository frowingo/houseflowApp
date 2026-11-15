package com.fauscrew.viewmodel

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidLocalizationCache
import com.fauscrew.platform.AndroidLocalizationRepository
import com.fauscrew.platform.AndroidLocalizationState
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.AuthSessionRepository
import com.fauscrew.platform.AuthWire
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import com.fauscrew.platform.SocialCredential
import com.fauscrew.platform.SocialCredentialProvider
import com.fauscrew.platform.SocialProvider
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelSessionTest {
    @get:Rule val temporaryFolder = TemporaryFolder()
    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun lateRefreshAfterLogoutAndLoginCannotOverwriteNewAccount() = runBlocking {
        val fields = ConcurrentHashMap<SessionField, String>().apply { put(SessionField.AUTH_TOKEN, "a") }
        val refreshStarted = CompletableDeferred<Unit>()
        val refreshReply = CompletableDeferred<PlatformHttpResponse>()
        val aRequests = AtomicInteger()
        val session = AuthSessionRepository(
            send = { request ->
                when {
                    request.path == "auth/login" -> response("""{"ok":true,"token":"b"}""")
                    request.headers["Authorization"] == "Bearer b" -> response(profile("b", "Bea"))
                    aRequests.incrementAndGet() == 1 -> response(profile("a", "Ada"))
                    else -> {
                        refreshStarted.complete(Unit)
                        // Complete even after cancellation, as an already-delivered transport response can.
                        withContext(NonCancellable) { refreshReply.await() }
                    }
                }
            },
            read = { fields[it]?.let(SessionReadResult::Value) ?: SessionReadResult.Missing },
            write = { field, value -> if (value == null) fields.remove(field) else fields[field] = value },
            clear = { fields.clear() }, wire = wire,
        )
        val model = model(session)
        awaitProfile(model, "a")
        awaitJobs(model)
        model.refreshProfile()
        val refreshJob = model.viewModelScope.coroutineContext[Job]!!.children.single()
        withTimeout(5_000) { refreshStarted.await() }
        model.logout()
        withTimeout(5_000) { model.state.first { it.route == AuthRoute.Onboarding && !it.busy } }
        assertTrue(refreshJob.isCancelled)
        model.setEmail("b@example.com")
        model.setPassword("secret")
        model.login()
        awaitProfile(model, "b")
        refreshReply.complete(response(profile("a", "Old Ada")))
        withTimeout(5_000) { refreshJob.join() }
        assertEquals("b", model.state.value.profile!!.userId)
        assertEquals("Bea", model.state.value.profile!!.firstName)
        assertEquals("b", fields[SessionField.AUTH_TOKEN])
        assertEquals("b@example.com", fields[SessionField.USER_EMAIL])
        assertEquals("Bea", fields[SessionField.USER_FIRST_NAME])
        assertNull(fields[SessionField.PENDING_EMAIL_VERIFICATION])
    }

    @Test fun restoreSignedOutClearsPreviousProfileAndFormState() = runBlocking {
        val fields = ConcurrentHashMap<SessionField, String>().apply { put(SessionField.AUTH_TOKEN, "a") }
        val session = AuthSessionRepository(
            send = { response(profile("a", "Ada")) },
            read = { fields[it]?.let(SessionReadResult::Value) ?: SessionReadResult.Missing },
            write = { field, value -> if (value == null) fields.remove(field) else fields[field] = value },
            clear = { fields.clear() }, wire = wire,
        )
        val social = RecordingSocialCredentials()
        val model = model(session, social)
        awaitProfile(model, "a")
        awaitJobs(model)
        model.setEmail("private@example.com")
        model.setPassword("secret")
        model.setFirstName("Private")
        model.loadLanguages()
        withTimeout(5_000) { model.profileState.first { it.error != null } }
        model.requestPasswordSetup()
        withTimeout(5_000) { model.accountState.first { it.passwordCodeSent } }
        fields.clear()
        model.restore()
        withTimeout(5_000) { model.state.first { it.route == AuthRoute.Onboarding && !it.busy } }
        assertNull(model.state.value.profile)
        assertEquals("", model.state.value.email)
        assertEquals("", model.state.value.password)
        assertEquals("", model.state.value.firstName)
        assertEquals(ProfileUiState(), model.profileState.value)
        assertEquals(AccountUiState(), model.accountState.value)
        assertFalse(model.state.value.busy)
        assertEquals(1, social.signOutCount)
    }

    @Test fun signedOutColdStartDoesNotSignOutSocialProviders() = runBlocking {
        val session = AuthSessionRepository(
            send = { error("must not send") }, read = { SessionReadResult.Missing },
            write = { _, _ -> }, clear = {}, wire = wire,
        )
        val social = RecordingSocialCredentials()
        val model = model(session, social)
        withTimeout(5_000) { model.state.first { it.route == AuthRoute.Onboarding && !it.busy } }
        awaitJobs(model)
        assertEquals(0, social.signOutCount)
    }

    private fun model(session: AuthSessionRepository, social: RecordingSocialCredentials = RecordingSocialCredentials()): AuthViewModel {
        val preferences = AndroidPreferencesStore(MemoryDataStore())
        val cache = AndroidLocalizationCache(temporaryFolder.newFolder())
        val repository = AndroidLocalizationRepository(send = { throw IOException("offline") }, cache = cache)
        return AuthViewModel(session, AndroidLocalizationState(repository, cache, preferences), preferences,
            socialCredentials = social)
    }

    private suspend fun awaitProfile(model: AuthViewModel, userId: String) {
        withTimeout(5_000) { model.state.first { it.profile?.userId == userId && !it.busy } }
    }
    private suspend fun awaitJobs(model: AuthViewModel) {
        withTimeout(5_000) { model.viewModelScope.coroutineContext[Job]!!.children.toList().forEach { it.join() } }
    }
    private fun response(body: String) = PlatformHttpResponse(200, emptyMap(), body.toByteArray())
    private fun profile(id: String, firstName: String) =
        """{"ok":true,"destination":"dashboard","email":"$id@example.com","firstName":"$firstName","lastName":"Test","userId":"$id"}"""
    private val wire = object : AuthWire {
        override fun loginBody(email: String, password: String) = JSONObject().put("email", email).toString()
        override fun loginResult(status: Int, body: String) = body
        override fun profileResult(status: Int, body: String) = body
        override fun signupBody(email: String, password: String, firstName: String, lastName: String) = "{}"
        override fun forgotBody(email: String) = "{}"
        override fun resetBody(email: String, code: String, newPassword: String) = "{}"
        override fun verifyBody(code: String) = "{}"
        override fun birthdayBody(birthDay: String) = "{}"
        override fun actionResult(action: String, status: Int, body: String) = body
    }
    private class RecordingSocialCredentials : SocialCredentialProvider {
        var signOutCount = 0
        override suspend fun credential(provider: SocialProvider): SocialCredential = error("must not request credentials")
        override fun signOutAll() { signOutCount++ }
    }
    private class MemoryDataStore : DataStore<Preferences> {
        private val state = MutableStateFlow(emptyPreferences())
        override val data: Flow<Preferences> = state
        override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences =
            transform(state.value).also { state.value = it }
    }
}
