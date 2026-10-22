package com.fauscrew.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HouseSessionRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private var response = ""
    private val wire = object : HouseWire {
        override fun body(action: String, houseId: String, userId: String, name: String, inviteCode: String,
            type: Int, maxMemberCount: Int, profileImage: String): String =
            JSONObject().put("action", action).put("houseId", houseId).put("userId", userId)
                .put("name", name).put("inviteCode", inviteCode).put("type", type)
                .put("maxMemberCount", maxMemberCount).put("profileImage", profileImage).toString()
        override fun response(action: String, status: Int, body: String): String = body
    }
    private val repo = HouseSessionRepository(
        send = { request -> requests += request; PlatformHttpResponse(200, emptyMap(), response.toByteArray()) },
        read = { SessionReadResult.Value("token") }, wire = wire,
    )

    @Test fun createAndJoinUseIosPathsAndBodies() = runBlocking {
        response = """{"success":true,"data":{"id":"h","name":"Home","profileImage":""}}"""
        assertEquals("h", repo.create("Home", 2, 5).id)
        assertEquals("h", repo.join("AB12CD34").id)
        assertEquals(listOf("house/create", "house/join"), requests.map { it.path })
        assertEquals("Bearer token", requests.first().headers["Authorization"])
        assertEquals(5, JSONObject(requests.first().body!!.decodeToString()).getInt("maxMemberCount"))
        assertEquals("AB12CD34", JSONObject(requests.last().body!!.decodeToString()).getString("inviteCode"))
    }

    @Test fun detailsUseHouseIdQueryAndRejectOtherHouse() = runBlocking {
        response = """{"success":true,"data":{"id":"h","name":"Home","members":[{"id":"u","firstName":"Ada","lastName":"A"}],"chores":[{"id":"c","houseId":"h","title":"Dishes"}],"announcements":[]}}"""
        val details = repo.details("h")
        assertEquals(listOf("Ada A"), details.members.map { it.name })
        assertEquals(listOf("Dishes"), details.chores.map { it.title })
        assertEquals("house/details", requests.single().path)
        assertEquals("houseId", requests.single().queryItems.single().name)
        response = """{"success":true,"data":{"id":"other","name":"Wrong"}}"""
        assertTrue(runCatching { repo.details("h") }.exceptionOrNull() is HouseRequestException)
    }

    @Test fun infoInviteExitAndProfileUseExistingEndpoints() = runBlocking {
        response = """{"success":true,"data":{"houseName":"Home","houseProfileImage":"","houseType":1,"houseMemberCount":1,"houseMemberCountLimit":4,"houseMembers":[{"userId":"u","name":"Ada","profileImage":"","isOwner":true}]}}"""
        assertEquals("Home", JSONObject(repo.info("h").payload).getString("houseName"))
        repo.updateProfile("h", "New", 1, 4, "image")
        response = """{"success":true,"data":{"inviteCode":"AB12CD34","expiresInSeconds":3600}}"""
        assertEquals("AB12CD34", repo.invite("h").code)
        response = """{"success":true}"""
        repo.exit("h", "u")
        assertEquals(listOf("house/infos", "house/profile", "house/inviteCode", "house/exit"), requests.map { it.path })
        assertEquals("PUT", requests[1].method)
        assertEquals("u", JSONObject(requests.last().body!!.decodeToString()).getString("userId"))
    }

    @Test fun serverFailureDoesNotBecomeHouseDetails() = runBlocking {
        response = """{"success":false,"error":"Denied"}"""
        val failure = runCatching { repo.details("h") }.exceptionOrNull() as HouseRequestException
        assertEquals("Denied", failure.serverMessage)
    }
}
