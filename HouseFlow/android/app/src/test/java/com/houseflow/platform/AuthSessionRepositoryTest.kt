package com.houseflow.platform

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthSessionRepositoryTest {
    private val fields = mutableMapOf<SessionField, String>()
    private val requests = mutableListOf<PlatformHttpRequest>()
    private var loginResponse = PlatformHttpResponse(200, emptyMap(), "token".toByteArray())
    private var profileResponse = PlatformHttpResponse(200, emptyMap(), "profile".toByteArray())
    private val wire = object : AuthWire {
        override fun loginBody(email: String, password: String) = """{"email":"$email","password":"$password"}"""
        override fun loginResult(status: Int, body: String) = if (status == 200) """{"ok":true,"token":"abc"}"""
            else """{"ok":false,"message":"Invalid credentials"}"""
        override fun profileResult(status: Int, body: String) = if (status == 200)
            """{"ok":true,"destination":"dashboard","email":"ada@example.com","firstName":"Ada","lastName":"A","language":"tr"}"""
            else """{"ok":false,"message":"Unauthorised"}"""
    }
    private val repository = AuthSessionRepository(
        send = { request ->
            requests += request
            if (request.path == "auth/login") loginResponse else profileResponse
        },
        read = { fields[it]?.let(SessionReadResult::Value) ?: SessionReadResult.Missing },
        write = { field, value -> if (value == null) fields.remove(field) else fields[field] = value },
        clear = { fields.clear() },
        wire = wire,
    )

    @Test fun loginPersistsSessionAndRoutesThroughProfile() = runBlocking {
        fields[SessionField.PENDING_EMAIL_VERIFICATION] = "old@example.com"
        val profile = repository.login("ada@example.com", "password")
        assertEquals(AuthDestination.DASHBOARD, profile.destination)
        assertEquals("tr", profile.language)
        assertEquals(listOf("auth/login", "auth/isAuth"), requests.map { it.path })
        assertEquals("Bearer abc", requests.last().headers["Authorization"])
        assertEquals("abc", fields[SessionField.AUTH_TOKEN])
        assertEquals("Ada", fields[SessionField.USER_FIRST_NAME])
        assertNull(fields[SessionField.PENDING_EMAIL_VERIFICATION])
        assertEquals("password", org.json.JSONObject(requests.first().body!!.decodeToString()).getString("password"))
    }

    @Test fun failureDoesNotPersistToken() = runBlocking {
        loginResponse = PlatformHttpResponse(401, emptyMap(), byteArrayOf())
        val error = runCatching { repository.login("ada@example.com", "wrong") }.exceptionOrNull()
        assertEquals("Invalid credentials", (error as AuthRequestException).serverMessage)
        assertNull(fields[SessionField.AUTH_TOKEN])
    }

    @Test fun restoreKeepsTokenOnServerFailureAndLogoutClearsIt() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "abc"
        profileResponse = PlatformHttpResponse(503, emptyMap(), byteArrayOf())
        assertTrue(repository.restore() is AuthRestoreResult.Error)
        assertEquals("abc", fields[SessionField.AUTH_TOKEN])
        profileResponse = PlatformHttpResponse(200, emptyMap(), "profile".toByteArray())
        assertTrue(repository.restore() is AuthRestoreResult.SignedIn)
        repository.logout()
        assertEquals(AuthRestoreResult.SignedOut, repository.restore())
    }

    @Test fun pendingVerificationTakesPriorityWithoutNetworkCall() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "abc"
        fields[SessionField.PENDING_EMAIL_VERIFICATION] = "ada@example.com"
        assertEquals(AuthRestoreResult.PendingEmailVerification("ada@example.com"), repository.restore())
        assertTrue(requests.isEmpty())
    }

    @Test fun profileFailureAfterLoginKeepsTokenForRetryRoute() = runBlocking {
        profileResponse = PlatformHttpResponse(503, emptyMap(), byteArrayOf())
        val error = runCatching { repository.login("ada@example.com", "password") }.exceptionOrNull()
        assertEquals("Unauthorised", (error as AuthProfileException).serverMessage)
        assertEquals("abc", fields[SessionField.AUTH_TOKEN])
    }
}
