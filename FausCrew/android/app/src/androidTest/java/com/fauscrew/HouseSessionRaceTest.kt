package com.fauscrew

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.AuthDestination
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.DashboardRepository
import com.fauscrew.platform.DashboardWire
import com.fauscrew.platform.HouseSessionRepository
import com.fauscrew.platform.HouseSummary
import com.fauscrew.platform.HouseWire
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.SessionReadResult
import com.fauscrew.viewmodel.HouseRoute
import com.fauscrew.viewmodel.HouseViewModel
import java.io.File
import java.util.UUID
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HouseSessionRaceTest {
    @Test fun lateChoreMutationCannotWriteIntoAnotherHouse() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val file = File(context.cacheDir, "dashboard-race-${UUID.randomUUID()}.preferences_pb")
        val storeJob = SupervisorJob()
        val preferences = AndroidPreferencesStore(PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + storeJob), produceFile = { file }))
        val late = CompletableDeferred<PlatformHttpResponse>()
        val started = CompletableDeferred<Unit>()
        val repository = HouseSessionRepository(
            send = { request -> response(request.queryItems.single().value!!) },
            read = { SessionReadResult.Value("token") },
            wire = object : HouseWire {
                override fun body(action: String, houseId: String, userId: String, name: String,
                    inviteCode: String, type: Int, maxMemberCount: Int, profileImage: String,
                    isChoreReviewPhotoRequired: Boolean) = "{}"
                override fun response(action: String, status: Int, body: String) = body
            },
        )
        val dashboard = DashboardRepository(
            send = { started.complete(Unit); withContext(NonCancellable) { late.await() } },
            read = { SessionReadResult.Value("token") },
            wire = object : DashboardWire {
                override fun body(action: String, houseId: String, choreId: String, assignedTo: String,
                    title: String, description: String, dueDate: String, isRecurring: Boolean, level: Int,
                    recurringInterval: Int, status: Int, isApproved: Boolean) = "{}"
                override fun response(action: String, status: Int, body: String) =
                    """{"ok":true,"data":${org.json.JSONObject.quote(body)}}"""
            },
        )
        val model = HouseViewModel(repository, preferences, dashboard)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        instrumentation.runOnMainSync { model.acceptProfile(profile("u", listOf("a", "b"))) }
        awaitState { model.state.value.details?.id == "a" }
        instrumentation.runOnMainSync {
            model.createAnnouncement("Old note", "Old house only")
        }
        started.await()
        assertEquals(true, model.state.value.mutationBusy)
        instrumentation.runOnMainSync { model.switchHouse("b") }
        awaitState { model.state.value.details?.id == "b" }
        late.complete(PlatformHttpResponse(200, emptyMap(),
            """{"success":true,"data":{"id":"old","houseId":"a","title":"Old note","message":"Old house only","createdOn":"2026-10-12T00:00:00Z"}}""".toByteArray()))
        awaitState { model.state.value.route == HouseRoute.DASHBOARD }
        assertEquals("b", model.state.value.details?.id)
        assertEquals(emptyList<Any>(), model.state.value.details?.announcements)
        storeJob.cancel()
        file.delete()
        Unit
    }

    @Test fun lateOldHouseResponseCannotReplaceNewSession() = runBlocking {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val file = File(context.cacheDir, "house-race-${UUID.randomUUID()}.preferences_pb")
        val storeJob = SupervisorJob()
        val preferences = AndroidPreferencesStore(PreferenceDataStoreFactory.create(
            scope = CoroutineScope(Dispatchers.IO + storeJob), produceFile = { file }))
        preferences.setChosenHouse("b")
        val lateA = CompletableDeferred<PlatformHttpResponse>()
        val repository = HouseSessionRepository(
            send = { request ->
                val id = request.queryItems.single().value!!
                if (id == "a") withContext(NonCancellable) { lateA.await() }
                else response(id)
            },
            read = { SessionReadResult.Value("token") },
            wire = object : HouseWire {
                override fun body(action: String, houseId: String, userId: String, name: String,
                    inviteCode: String, type: Int, maxMemberCount: Int, profileImage: String,
                    isChoreReviewPhotoRequired: Boolean) = "{}"
                override fun response(action: String, status: Int, body: String) = body
            },
        )
        val model = HouseViewModel(repository, preferences)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        instrumentation.runOnMainSync {
            model.acceptProfile(profile("user-1", listOf("a", "b")))
        }
        awaitState { model.state.value.details?.id == "b" }
        instrumentation.runOnMainSync { model.switchHouse("a") }
        awaitState { model.state.value.route == HouseRoute.LOADING }
        instrumentation.runOnMainSync {
            model.resetSession()
            model.acceptProfile(profile("user-2", listOf("c")))
        }
        awaitState { model.state.value.details?.id == "c" }
        lateA.complete(response("a"))
        awaitState { model.state.value.route == HouseRoute.DASHBOARD }
        assertEquals("c", model.state.value.details?.id)
        storeJob.cancel()
        file.delete()
        Unit
    }

    private fun response(id: String) = PlatformHttpResponse(200, emptyMap(),
        """{"success":true,"data":{"id":"$id","name":"House $id"}}""".toByteArray())

    private fun profile(user: String, ids: List<String>) = AuthProfile(
        AuthDestination.DASHBOARD, "$user@example.com", "en", user, "Ada", "A",
        ids.map { HouseSummary(it, "House $it", "") },
    )

    private suspend fun awaitState(condition: () -> Boolean) {
        kotlinx.coroutines.withTimeout(5_000) {
            while (!condition()) kotlinx.coroutines.delay(20)
        }
    }
}
