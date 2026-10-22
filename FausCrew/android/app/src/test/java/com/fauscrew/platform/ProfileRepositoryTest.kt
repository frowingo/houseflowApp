package com.fauscrew.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProfileRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private var response = ""
    private val wire = object : ProfileWire {
        override fun body(change: ProfileChange): String = JSONObject()
            .put("firstName", change.firstName).put("language", change.language).toString()
        override fun update(status: Int, body: String): String = body
        override fun images(status: Int, body: String): String = body
    }
    private val repo = ProfileRepository(
        send = { request -> requests += request; PlatformHttpResponse(200, emptyMap(), response.toByteArray()) },
        read = { SessionReadResult.Value("secret") }, wire = wire,
    )

    @Test fun updateAndImagesUseExistingAuthenticatedEndpoints() = runBlocking {
        response = """{"ok":true,"firstName":"Ada","lastName":"A","imageUrl":"","birthDay":"","phoneNumber":"","language":"tr"}"""
        assertEquals("tr", repo.update("u", ProfileChange(firstName = "Ada", language = "tr")).language)
        assertEquals("user/profile/u", requests[0].path)
        assertEquals("PUT", requests[0].method)
        assertEquals("u", requests[0].queryItems.single().value)
        assertEquals("Bearer secret", requests[0].headers["Authorization"])
        assertEquals("Ada", JSONObject(requests[0].body!!.decodeToString()).getString("firstName"))

        response = """{"ok":true,"images":[{"url":"https://example.com/a.png","publicId":"a"}]}"""
        assertEquals("a", repo.images("profile/superhero").single().publicId)
        assertEquals("user/getImages", requests[1].path)
        assertEquals("profile/superhero", requests[1].queryItems.single().value)
    }

    @Test fun rejectedUpdateDoesNotProduceAProfile() = runBlocking {
        response = """{"ok":false,"message":"Denied"}"""
        val failure = runCatching { repo.update("u", ProfileChange(language = "tr")) }.exceptionOrNull()
        assertTrue(failure is AuthRequestException)
        assertEquals("Denied", (failure as AuthRequestException).serverMessage)
    }
}
