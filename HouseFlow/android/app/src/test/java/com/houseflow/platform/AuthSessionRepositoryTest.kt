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
    private var profileDestination = "dashboard"
    private val wire = object : AuthWire {
        override fun loginBody(email: String, password: String) = """{"email":"$email","password":"$password"}"""
        override fun loginResult(status: Int, body: String) = if (status == 200) """{"ok":true,"token":"abc"}"""
            else """{"ok":false,"message":"Invalid credentials"}"""
        override fun profileResult(status: Int, body: String) = if (status == 200)
            """{"ok":true,"destination":"$profileDestination","email":"ada@example.com","firstName":"Ada","lastName":"A","language":"tr","userId":"u"}"""
            else """{"ok":false,"message":"Unauthorised"}"""
        override fun signupBody(email: String, password: String, firstName: String, lastName: String) =
            """{"email":"$email","password":"$password","firstName":"$firstName","lastName":"$lastName"}"""
        override fun forgotBody(email: String) = """{"email":"$email"}"""
        override fun resetBody(email: String, code: String, newPassword: String) =
            """{"email":"$email","code":"$code","newPassword":"$newPassword"}"""
        override fun verifyBody(code: String) = """{"code":"$code"}"""
        override fun birthdayBody(birthDay: String) = """{"birthDay":"$birthDay"}"""
        override fun actionResult(action: String, status: Int, body: String) =
            if (status == 200) """{"ok":true}""" else """{"ok":false,"message":"Rejected"}"""
    }
    private val repository = AuthSessionRepository(
        send = { request ->
            requests += request
            if (request.path == "auth/login" || request.path == "auth/signup") loginResponse else profileResponse
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

    @Test fun unverifiedLoginPersistsPendingForProcessRestart() = runBlocking {
        profileDestination = "emailVerification"
        val profile = repository.login("ada@example.com", "secret")
        assertEquals(AuthDestination.EMAIL_VERIFICATION, profile.destination)
        assertEquals(AuthRestoreResult.PendingEmailVerification("ada@example.com"), repository.restore())
    }

    @Test fun signupPersistsPendingVerificationAndRestoreSkipsNetwork() = runBlocking {
        repository.signup("ada@example.com", "secret", "Ada", "A")
        assertEquals("abc", fields[SessionField.AUTH_TOKEN])
        assertEquals("ada@example.com", fields[SessionField.PENDING_EMAIL_VERIFICATION])
        assertEquals(AuthRestoreResult.PendingEmailVerification("ada@example.com"), repository.restore())
        assertEquals(listOf("auth/signup"), requests.map { it.path })
    }

    @Test fun verificationKeepsPendingOnFailureAndClearsAfterProfile() = runBlocking {
        repository.signup("ada@example.com", "secret", "Ada", "A")
        profileResponse = PlatformHttpResponse(400, emptyMap(), byteArrayOf())
        val failure = runCatching { repository.verifyEmail("badbad") }.exceptionOrNull()
        assertTrue(failure is AuthRequestException)
        assertEquals("ada@example.com", fields[SessionField.PENDING_EMAIL_VERIFICATION])
        profileResponse = PlatformHttpResponse(200, emptyMap(), byteArrayOf())
        repository.verifyEmail("ABC123")
        assertNull(fields[SessionField.PENDING_EMAIL_VERIFICATION])
        assertEquals("POST", requests.last { it.path == "auth/validate-email" }.method)
    }

    @Test fun forgotResetAndBirthdayUseIosEndpointsAndQuery() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "abc"
        repository.forgotPassword("ada@example.com")
        repository.resetPassword("ada@example.com", "123456", "new-password")
        repository.sendVerificationCode()
        repository.updateBirthday("2000-01-01T00:00:00Z")
        assertEquals(listOf("auth/forget", "auth/reset", "auth/validate-email", "auth/isAuth", "user/profile/u", "auth/isAuth"),
            requests.map { it.path })
        val birthday = requests.first { it.path == "user/profile/u" }
        assertEquals("PUT", birthday.method)
        assertEquals("u", birthday.queryItems.single().value)
        assertEquals("Bearer abc", birthday.headers["Authorization"])
    }
}
