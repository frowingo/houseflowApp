package com.fauscrew.viewmodel

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.AuthDestination
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.DashboardRepository
import com.fauscrew.platform.DashboardWire
import com.fauscrew.platform.HouseSessionRepository
import com.fauscrew.platform.HouseSummary
import com.fauscrew.platform.HouseWire
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.SessionReadResult
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HouseViewModelRaceTest {
    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun newerRefreshWinsWhenResponsesFinishInReverseOrder() = runBlocking {
        val fixture = fixture()
        val model = fixture.model
        model.refreshDetails("h")
        val firstJob = activeJob(model)
        val first = fixture.nextDetails()
        model.refreshDetails("h")
        val second = fixture.nextDetails()
        second.complete(details("Newer"))
        withTimeout(5_000) { model.state.first { it.details?.name == "Newer" } }
        first.complete(details("Older"))
        withTimeout(5_000) { firstJob.join() }
        awaitJobs(model)
        assertEquals("Newer", model.state.value.details!!.name)
        assertEquals(2, fixture.detailsRequestCount.get())
        assertFalse(fixture.detailsReplies.tryReceive().isSuccess)
        assertFalse(model.viewModelScope.coroutineContext[Job]!!.children.any())
    }

    @Test fun refreshStartedBeforeMutationCannotRemoveCreatedChore() = runBlocking {
        val fixture = fixture()
        val model = fixture.model
        model.refreshDetails("h")
        val refreshJob = activeJob(model)
        val refresh = fixture.nextDetails()
        model.createChore(input)
        fixture.nextMutation().complete(response(chore))
        withTimeout(5_000) { model.state.first { it.mutationSerial == 1L } }
        refresh.complete(details())
        withTimeout(5_000) { refreshJob.join() }
        assertEquals(listOf("c"), model.state.value.details!!.chores.map { it.id })
        val followUp = fixture.nextDetails()
        assertEquals(2, fixture.detailsRequestCount.get())
        followUp.complete(details(announcement = true, withChore = true))
        awaitJobs(model)
        assertEquals(listOf("c"), model.state.value.details!!.chores.map { it.id })
        assertEquals(listOf("a"), model.state.value.details!!.announcements.map { it.id })
        assertEquals(2, fixture.detailsRequestCount.get())
        assertFalse(fixture.detailsReplies.tryReceive().isSuccess)
        assertFalse(model.viewModelScope.coroutineContext[Job]!!.children.any())
    }

    @Test fun mutationMergesIntoDetailsReceivedWhileRequestWasPending() = runBlocking {
        val fixture = fixture()
        val model = fixture.model
        model.createChore(input)
        val mutation = fixture.nextMutation()
        model.refreshDetails("h")
        fixture.nextDetails().complete(details(announcement = true))
        withTimeout(5_000) { model.state.first { it.details?.announcements?.size == 1 } }
        mutation.complete(response(chore))
        withTimeout(5_000) { model.state.first { it.mutationSerial == 1L } }
        assertEquals(listOf("c"), model.state.value.details!!.chores.map { it.id })
        assertEquals(listOf("a"), model.state.value.details!!.announcements.map { it.id })
    }

    @Test fun details401RequestsSignOutBut500DoesNot() = runBlocking {
        for (status in listOf(401, 500)) {
            val fixture = fixture()
            val signals = Channel<Unit>(Channel.UNLIMITED)
            val collector = launch(UnconfinedTestDispatcher(), start = CoroutineStart.UNDISPATCHED) {
                fixture.model.signOutRequests.collect { signals.send(it) }
            }
            try {
                fixture.model.refreshDetails("h")
                val job = activeJob(fixture.model)
                fixture.nextDetails().complete(response("""{"success":false,"error":"Denied"}""", status))
                withTimeout(5_000) { job.join() }
                if (status == 401) assertEquals(Unit, withTimeout(5_000) { signals.receive() })
                else assertFalse(signals.tryReceive().isSuccess)
            } finally { collector.cancel() }
        }
    }

    @Test fun mutation401RequestsSignOutBut500DoesNot() = runBlocking {
        for (status in listOf(401, 500)) {
            val fixture = fixture()
            val signals = Channel<Unit>(Channel.UNLIMITED)
            val collector = launch(UnconfinedTestDispatcher(), start = CoroutineStart.UNDISPATCHED) {
                fixture.model.signOutRequests.collect { signals.send(it) }
            }
            try {
                fixture.model.createChore(input)
                val job = activeJob(fixture.model)
                fixture.nextMutation().complete(response("{}", status))
                withTimeout(5_000) { job.join() }
                if (status == 401) assertEquals(Unit, withTimeout(5_000) { signals.receive() })
                else assertFalse(signals.tryReceive().isSuccess)
                assertFalse(fixture.model.state.value.mutationBusy)
                assertEquals("Denied", fixture.model.state.value.mutationError)
                assertEquals(0L, fixture.model.state.value.mutationSerial)
            } finally { collector.cancel() }
        }
    }

    @Test fun oldHouseResponseCannotChangeNewSessionOrRequestSignOut() = runBlocking {
        val fixture = fixture()
        fixture.model.refreshDetails("h")
        val job = activeJob(fixture.model)
        val refresh = fixture.nextDetails()
        fixture.model.resetSession()
        refresh.complete(response("""{"success":false,"error":"Expired"}""", 401))
        withTimeout(5_000) { job.join() }
        assertEquals(HouseRoute.LOADING, fixture.model.state.value.route)
        val signals = Channel<Unit>(Channel.UNLIMITED)
        val collector = launch(UnconfinedTestDispatcher(), start = CoroutineStart.UNDISPATCHED) {
            fixture.model.signOutRequests.collect { signals.send(it) }
        }
        try { assertFalse(signals.tryReceive().isSuccess) } finally { collector.cancel() }
    }

    private fun activeJob(model: HouseViewModel): Job =
        model.viewModelScope.coroutineContext[Job]!!.children.single()

    private suspend fun awaitJobs(model: HouseViewModel) {
        withTimeout(5_000) { model.viewModelScope.coroutineContext[Job]!!.children.toList().forEach { it.join() } }
    }

    private suspend fun fixture(): Fixture {
        val detailsReplies = Channel<CompletableDeferred<PlatformHttpResponse>>(Channel.UNLIMITED)
        val mutationReplies = Channel<CompletableDeferred<PlatformHttpResponse>>(Channel.UNLIMITED)
        val initial = AtomicBoolean(true)
        val detailsRequestCount = AtomicInteger()
        val houses = HouseSessionRepository(send = {
            if (initial.getAndSet(false)) details() else {
                detailsRequestCount.incrementAndGet()
                val reply = CompletableDeferred<PlatformHttpResponse>()
                detailsReplies.send(reply)
                reply.await()
            }
        }, read = { SessionReadResult.Value("token") }, wire = houseWire)
        val dashboard = DashboardRepository(send = {
            val reply = CompletableDeferred<PlatformHttpResponse>()
            mutationReplies.send(reply)
            reply.await()
        }, read = { SessionReadResult.Value("token") }, wire = dashboardWire)
        val model = HouseViewModel(houses, AndroidPreferencesStore(MemoryDataStore()), dashboard)
        model.acceptProfile(AuthProfile(AuthDestination.DASHBOARD, "ada@example.com", null, userId = "u",
            firstName = "Ada", houses = listOf(HouseSummary("h", "Home", ""))))
        withTimeout(5_000) {
            model.state.first { it.route == HouseRoute.DASHBOARD }
            model.viewModelScope.coroutineContext[Job]!!.children.toList().forEach { it.join() }
        }
        return Fixture(model, detailsReplies, mutationReplies, detailsRequestCount)
    }

    private class Fixture(
        val model: HouseViewModel,
        val detailsReplies: Channel<CompletableDeferred<PlatformHttpResponse>>,
        val mutationReplies: Channel<CompletableDeferred<PlatformHttpResponse>>,
        val detailsRequestCount: AtomicInteger,
    ) {
        suspend fun nextDetails() = withTimeout(5_000) { detailsReplies.receive() }
        suspend fun nextMutation() = withTimeout(5_000) { mutationReplies.receive() }
    }

    private fun response(body: String, status: Int = 200) = PlatformHttpResponse(status, emptyMap(), body.toByteArray())
    private fun details(name: String = "Home", announcement: Boolean = false, withChore: Boolean = false): PlatformHttpResponse = response(
        """{"success":true,"data":{"id":"h","name":"$name","members":[{"id":"u","firstName":"Ada"}],"chores":${if (withChore) "[$chore]" else "[]"},"announcements":${if (announcement) """[{"id":"a","houseId":"h","title":"News","description":"Hello"}]""" else "[]"}}}""",
    )
    private val input = ChoreInput("h", "u", "Dishes", "", "2026-11-15T00:00:00Z", false, 10, 0)
    private val chore = """{"id":"c","houseId":"h","title":"Dishes","assignedTo":"u"}"""
    private val houseWire = object : HouseWire {
        override fun body(action: String, houseId: String, userId: String, name: String, inviteCode: String,
            type: Int, maxMemberCount: Int, profileImage: String, isChoreReviewPhotoRequired: Boolean) = "{}"
        override fun response(action: String, status: Int, body: String) = body
    }
    private val dashboardWire = object : DashboardWire {
        override fun body(action: String, houseId: String, choreId: String, assignedTo: String, title: String,
            description: String, dueDate: String, isRecurring: Boolean, level: Int, recurringInterval: Int,
            status: Int, isApproved: Boolean, category: Int) = "{}"
        override fun response(action: String, status: Int, body: String): String =
            if (status >= 400) """{"ok":false,"message":"Denied"}"""
            else JSONObject().put("ok", true).put("data", body).toString()
    }
    private class MemoryDataStore : DataStore<Preferences> {
        private val state = MutableStateFlow(emptyPreferences())
        override val data: Flow<Preferences> = state
        override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences =
            transform(state.value).also { state.value = it }
    }
}
