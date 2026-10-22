package com.houseflow.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SocialAuthRepositoryTest {
    private val fields = mutableMapOf<SessionField, String>()
    private val requests = mutableListOf<PlatformHttpRequest>()
    private val responses = mutableMapOf<String, PlatformHttpResponse>()
    private val ok = PlatformHttpResponse(200, emptyMap(), byteArrayOf())

    private val authWire = object : AuthWire {
        override fun loginBody(email: String, password: String) = "{}"
        override fun loginResult(status: Int, body: String) = """{"ok":false}"""
        override fun profileResult(status: Int, body: String) = if (status == 200)
            """{"ok":true,"destination":"houseSelection","email":"ada@example.com","firstName":"Ada","lastName":"A","userId":"u","linkedProviders":[4],"hasPassword":false,"signUpProvider":4}"""
            else """{"ok":false,"message":"Unauthorised"}"""
        override fun signupBody(email: String, password: String, firstName: String, lastName: String) = "{}"
        override fun forgotBody(email: String) = "{}"
        override fun resetBody(email: String, code: String, newPassword: String) = "{}"
        override fun verifyBody(code: String) = "{}"
        override fun birthdayBody(birthDay: String) = "{}"
        override fun actionResult(action: String, status: Int, body: String) = """{"ok":true}"""
    }

    /** Stands in for the Swift facade: the response body *is* the facade's JSON result. */
    private val socialWire = object : SocialWire {
        override fun slug(provider: SocialProvider) = provider.slug
        override fun signInBody(credential: SocialCredential, language: String) =
            JSONObject().apply { credential.accessToken?.let { put("accessToken", it) }; put("language", language) }.toString()
        override fun completeCodeBody(pendingToken: String, email: String) = """{"pendingToken":"$pendingToken","email":"$email"}"""
        override fun completeBody(pendingToken: String, email: String, code: String, firstName: String, lastName: String, language: String) =
            """{"pendingToken":"$pendingToken","code":"$code","language":"$language"}"""
        override fun result(action: String, status: Int, body: String) = body
    }

    private val repository = AuthSessionRepository(
        send = { request -> requests += request; responses[request.method + " " + request.path] ?: ok },
        read = { fields[it]?.let(SessionReadResult::Value) ?: SessionReadResult.Missing },
        write = { field, value -> if (value == null) fields.remove(field) else fields[field] = value },
        clear = { fields.clear() },
        wire = authWire,
        socialWire = socialWire,
        language = { "tr" },
    )

    private fun respond(key: String, status: Int, json: String) {
        responses[key] = PlatformHttpResponse(status, emptyMap(), json.toByteArray())
    }

    @Test fun signInStoresOurJwtAndLoadsProfile() = runBlocking {
        respond("POST auth/social/snapchat", 201, """{"ok":true,"status":201,"token":"jwt","isNewUser":true}""")
        val result = repository.socialSignIn(SocialProvider.SNAPCHAT, SocialCredential(accessToken = "snap"))
        result as SocialSignInResult.SignedIn
        assertTrue(result.isNewUser)
        assertEquals(listOf(4), result.profile.linkedProviders)
        assertEquals(false, result.profile.hasPassword)
        assertEquals("jwt", fields[SessionField.AUTH_TOKEN])
        assertEquals("Bearer jwt", requests.last().headers["Authorization"])
        assertEquals("tr", JSONObject(requests.first().body!!.decodeToString()).getString("language"))
    }

    @Test fun needsEmailKeepsNothingOnDisk() = runBlocking {
        respond("POST auth/social/facebook", 200, """{"ok":true,"status":200,"needsEmail":true,"pendingToken":"p"}""")
        val result = repository.socialSignIn(SocialProvider.FACEBOOK, SocialCredential(accessToken = "fb"))
        assertEquals(SocialSignInResult.NeedsEmail("p"), result)
        assertTrue(fields.isEmpty())
    }

    @Test fun conflictCarriesStatusAndMessage() = runBlocking {
        respond("POST auth/social/google", 409, """{"ok":false,"status":409,"message":"Kayıtlı"}""")
        val error = runCatching { repository.socialSignIn(SocialProvider.GOOGLE, SocialCredential(idToken = "g")) }.exceptionOrNull()
        error as SocialAuthException
        assertEquals(409, error.status)
        assertEquals("Kayıtlı", error.serverMessage)
        assertNull(fields[SessionField.AUTH_TOKEN])
    }

    @Test fun completionCreatesTheSession() = runBlocking {
        respond("POST auth/social/complete/code", 200, """{"ok":true,"status":200}""")
        respond("POST auth/social/complete", 201, """{"ok":true,"status":201,"token":"jwt","isNewUser":true}""")
        repository.requestSocialCode("p", " ada@example.com ")
        val profile = repository.completeSocial("p", "ada@example.com", "ABC123", "Ada", "")
        assertEquals("ada@example.com", profile.email)
        assertEquals("jwt", fields[SessionField.AUTH_TOKEN])
        assertEquals(listOf("auth/social/complete/code", "auth/social/complete", "auth/isAuth"), requests.map { it.path })
    }

    @Test fun linkUnlinkUseBearerAndReturnProviders() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "jwt"
        respond("POST auth/social/google/link", 200, """{"ok":true,"status":200,"linkedProviders":[1,4]}""")
        respond("DELETE auth/social/google/link", 200, """{"ok":true,"status":200,"linkedProviders":[4]}""")
        assertEquals(listOf(1, 4), repository.linkSocial(SocialProvider.GOOGLE, SocialCredential(idToken = "g")))
        assertEquals(listOf(4), repository.unlinkSocial(SocialProvider.GOOGLE))
        assertTrue(requests.all { it.headers["Authorization"] == "Bearer jwt" })
    }

    @Test fun onlyMethodCannotBeRemoved() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "jwt"
        respond("DELETE auth/social/snapchat/link", 409, """{"ok":false,"status":409,"message":"Tek yöntem"}""")
        val error = runCatching { repository.unlinkSocial(SocialProvider.SNAPCHAT) }.exceptionOrNull() as SocialAuthException
        assertEquals(409, error.status)
    }

    @Test fun deleteAccountClearsSessionOnlyAfterSuccess() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "jwt"
        respond("DELETE user/me", 500, """{"ok":false,"status":500,"message":"x"}""")
        assertTrue(runCatching { repository.deleteAccount() }.isFailure)
        assertEquals("jwt", fields[SessionField.AUTH_TOKEN])
        respond("DELETE user/me", 204, """{"ok":true,"status":204}""")
        repository.deleteAccount()
        assertTrue(fields.isEmpty())
    }

    @Test fun sessionCheckSeparatesBadSessionFromBadProviderToken() = runBlocking {
        fields[SessionField.AUTH_TOKEN] = "jwt"
        assertEquals(true, repository.isSessionValid())
        respond("GET auth/isAuth", 401, "")
        assertEquals(false, repository.isSessionValid())
        respond("GET auth/isAuth", 503, "")
        assertNull(repository.isSessionValid())
        fields.clear()
        assertFalse(repository.isSessionValid()!!)
    }
}
