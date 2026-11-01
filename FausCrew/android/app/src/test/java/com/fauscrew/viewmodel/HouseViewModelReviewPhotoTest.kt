package com.fauscrew.viewmodel

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.AuthDestination
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.DashboardRepository
import com.fauscrew.platform.DashboardWire
import com.fauscrew.platform.HouseSessionRepository
import com.fauscrew.platform.HouseSummary
import com.fauscrew.platform.HouseWire
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.ReviewPhoto
import com.fauscrew.platform.ReviewPhotoTest
import com.fauscrew.platform.SessionReadResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HouseViewModelReviewPhotoTest {
    private val statusRequests = mutableListOf<PlatformHttpRequest>()

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun jsonStatusIsKeptWhenHouseDoesNotRequirePhoto() = runBlocking {
        val model = dashboardModel(isChoreReviewPhotoRequired = false)

        model.updateChoreStatus("c", 2)
        awaitMutation(model)

        val request = statusRequests.single()
        assertNull(request.multipart)
        assertEquals("application/json", request.headers["Content-Type"])
        assertEquals("status", JSONObject(request.body!!.decodeToString()).getString("action"))
    }

    @Test fun requiredPhotoBlocksJsonAndSendsMultipart() = runBlocking {
        val model = dashboardModel(isChoreReviewPhotoRequired = true)

        model.updateChoreStatus("c", 2)
        assertTrue(statusRequests.isEmpty())
        assertEquals(false, model.state.value.mutationBusy)

        model.updateChoreStatus("c", 2, ReviewPhoto.from(ReviewPhotoTest.jpeg))
        awaitMutation(model)

        assertNotNull(statusRequests.single().multipart)
        val chore = model.state.value.details!!.chores.single()
        assertEquals(2, chore.status)
        assertEquals(listOf(1), chore.reviewPhotoRounds)
    }

    private suspend fun awaitMutation(model: HouseViewModel) {
        withTimeout(5_000) { model.state.first { it.mutationSerial > 0 || it.mutationError != null } }
    }

    private suspend fun dashboardModel(isChoreReviewPhotoRequired: Boolean): HouseViewModel {
        val chore = JSONObject().put("id", "c").put("houseId", "h").put("title", "Dishes").put("assignedTo", "u")
            .put("status", 1).put("reviewRound", 0)
        val details = JSONObject().put("success", true).put("data", JSONObject().put("id", "h").put("name", "Home")
            .put("isChoreReviewPhotoRequired", isChoreReviewPhotoRequired)
            .put("chores", JSONArray().put(chore))).toString()
        val houses = HouseSessionRepository(
            send = { PlatformHttpResponse(200, emptyMap(), details.toByteArray()) },
            read = { SessionReadResult.Value("token") }, wire = passthroughHouseWire,
        )
        val updated = JSONArray().put(JSONObject(chore.toString()).put("status", 2).put("reviewRound", 1)
            .put("reviewPhotoRounds", JSONArray().put(1))).toString()
        val dashboard = DashboardRepository(
            send = { request -> statusRequests += request; PlatformHttpResponse(200, emptyMap(), updated.toByteArray()) },
            read = { SessionReadResult.Value("token") }, wire = passthroughDashboardWire,
        )
        val model = HouseViewModel(houses, AndroidPreferencesStore(MemoryDataStore()), dashboard)
        model.acceptProfile(AuthProfile(AuthDestination.DASHBOARD, "ada@example.com", "en", userId = "u",
            firstName = "Ada", houses = listOf(HouseSummary("h", "Home", ""))))
        withTimeout(5_000) { model.state.first { it.route == HouseRoute.DASHBOARD } }
        return model
    }

    private val passthroughHouseWire = object : HouseWire {
        override fun body(action: String, houseId: String, userId: String, name: String, inviteCode: String,
            type: Int, maxMemberCount: Int, profileImage: String, isChoreReviewPhotoRequired: Boolean) = "{}"
        override fun response(action: String, status: Int, body: String) = body
    }

    private val passthroughDashboardWire = object : DashboardWire {
        override fun body(action: String, houseId: String, choreId: String, assignedTo: String, title: String,
            description: String, dueDate: String, isRecurring: Boolean, level: Int, recurringInterval: Int,
            status: Int, isApproved: Boolean): String = JSONObject().put("action", action).toString()
        override fun response(action: String, status: Int, body: String): String =
            JSONObject().put("ok", true).put("data", body).toString()
    }

    private class MemoryDataStore : DataStore<Preferences> {
        private val state = MutableStateFlow(emptyPreferences())
        override val data: Flow<Preferences> = state
        override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences =
            transform(state.value).also { state.value = it }
    }
}
