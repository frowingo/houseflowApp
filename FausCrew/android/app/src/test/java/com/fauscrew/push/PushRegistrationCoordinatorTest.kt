package com.fauscrew.push

import com.fauscrew.platform.NotificationRepository
import com.fauscrew.platform.NotificationWire
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.PushRegistrationEffect
import com.fauscrew.platform.PushRegistrationEngine
import com.fauscrew.platform.PushRegistrationResult
import com.fauscrew.platform.PushSignOutReason
import java.util.concurrent.ConcurrentLinkedQueue
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/** The host's behaviour with a scripted engine; Core's own rules are tested in FausCrewCore. */
@OptIn(ExperimentalCoroutinesApi::class)
class PushRegistrationCoordinatorTest {
    private val log = ConcurrentLinkedQueue<String>()
    private var jwt: String? = "jwt-1"
    private var freshToken: String? = "fresh"
    private val latest = MutableStateFlow<String?>(null)
    private var jwtGate: CompletableDeferred<Unit>? = null
    private var onDelete: () -> Unit = {}
    private val idle = CompletableDeferred<Unit>()

    /** What the engine answers per event type; anything else answers nothing. */
    private val script = mutableMapOf<String, List<PushRegistrationEffect>>()

    private val engine = object : PushRegistrationEngine {
        override fun event(type: String, fields: Map<String, Any?>): PushRegistrationResult {
            log += when (type) {
                "setToken" -> "setToken ${fields["token"]}"
                "setSession" -> "setSession ${fields["userId"]}"
                "signOut" -> "signOut ${fields["reason"]}"
                else -> type
            }
            if (type == "localTokenDeleted") idle.complete(Unit)
            return PushRegistrationResult(false, script[type].orEmpty())
        }
    }
    private val tokens = object : PushTokenProviding {
        override suspend fun token(): String? = freshToken
        override suspend fun delete() {
            log += "deleteToken"
            onDelete()
        }
    }
    private val wire = object : NotificationWire {
        override fun request(action: String, fieldsJson: String) =
            """{"ok":true,"path":"notification/devices","method":"${if (action == "register") "POST" else "DELETE"}","query":[]}"""
        override fun response(action: String, status: Int, body: String) = """{"ok":true}"""
    }
    private val repository = NotificationRepository(send = { request ->
        log += "${request.method} ${request.headers["Authorization"]}"
        PlatformHttpResponse(200, emptyMap(), ByteArray(0))
    }, wire = wire)

    private fun TestScope.coordinator() = PushRegistrationCoordinator(
        engine, tokens, repository, readJwt = { jwtGate?.await(); jwt.also { log += "readJwt $it" } }, latestTokens = latest, scope = backgroundScope,
    )

    @Test fun launchFetchesTheTokenOnceAndRegistersWithTheStoredJwt() = runTest(UnconfinedTestDispatcher()) {
        script["setToken"] = listOf(PushRegistrationEffect.Register("t1"))
        val host = coordinator()
        host.setSession("u1")
        waitFor("POST Bearer jwt-1")
        assertEquals(1, log.count { it == "setToken fresh" })
        assertEquals(1, log.count { it == "setSession u1" })
        assertEquals(1, log.count { it.startsWith("POST") })
    }

    @Test fun noJwtMeansNoRequest() = runTest(UnconfinedTestDispatcher()) {
        jwt = null
        script["setToken"] = listOf(PushRegistrationEffect.Register("t1"))
        coordinator()
        waitFor("readJwt null")
        assertEquals(0, log.count { it.startsWith("POST") })
    }

    @Test fun tokensIssuedLaterAreForwardedByTheOneCollector() = runTest(UnconfinedTestDispatcher()) {
        coordinator()
        latest.value = "refreshed"
        assertEquals(1, log.count { it == "setToken refreshed" })
    }

    @Test fun userInitiatedSignOutDeletesWithTheJwtFromBeforeTheSessionWasClearedThenFetchesAFreshToken() =
        runTest(UnconfinedTestDispatcher()) {
            script["signOut"] = listOf(PushRegistrationEffect.Unregister("t1"), PushRegistrationEffect.DeleteLocalToken)
            val host = coordinator()
            log.clear()
            host.signOut(PushSignOutReason.UserInitiated)
            jwt = null // the caller clears the session right after signOut returns
            idle.await()
            waitFor("setToken fresh")
            assertEquals(
                listOf("signOut userInitiated", "readJwt jwt-1", "DELETE Bearer jwt-1", "unregisterFinished",
                    "deleteToken", "localTokenDeleted", "setToken fresh"),
                log.toList(),
            )
        }

    @Test fun rejectedSessionAndDeletedAccountSendNoDelete() = runTest(UnconfinedTestDispatcher()) {
        for (reason in listOf(PushSignOutReason.SessionRejected, PushSignOutReason.AccountDeleted)) {
            log.clear()
            script["signOut"] = listOf(PushRegistrationEffect.DeleteLocalToken)
            val host = coordinator()
            log.clear()
            host.signOut(reason)
            waitFor("setToken fresh")
            assertEquals(listOf("signOut ${reason.wire}", "deleteToken", "localTokenDeleted", "setToken fresh"), log.toList())
        }
    }

    @Test fun signOutWithNothingToCleanDoesNothing() = runTest(UnconfinedTestDispatcher()) {
        val host = coordinator()
        log.clear()
        host.signOut(PushSignOutReason.UserInitiated)
        assertEquals(listOf("signOut userInitiated"), log.toList())
    }

    @Test fun theFreshTokenAfterCleanupIsRegisteredOnlyAfterTheLocalTokenWasDeleted() = runTest(UnconfinedTestDispatcher()) {
        script["signOut"] = listOf(PushRegistrationEffect.DeleteLocalToken)
        // From the deletion on, the engine (a user is set again) answers a token with a register.
        onDelete = { script["setToken"] = listOf(PushRegistrationEffect.Register("fresh")) }
        val host = coordinator()
        host.signOut(PushSignOutReason.SessionRejected)
        waitFor("POST Bearer jwt-1")
        assertEquals(1, log.count { it.startsWith("POST") })
        assertEquals(true, log.indexOf("localTokenDeleted") < log.indexOf("POST Bearer jwt-1"))
    }

    @Test fun aSignOutCancelledDuringTheJwtReadStillCleansUpAndALaterTokenRegisters() = runTest(UnconfinedTestDispatcher()) {
        script["signOut"] = listOf(PushRegistrationEffect.Unregister("t1"), PushRegistrationEffect.DeleteLocalToken)
        onDelete = { script["setToken"] = listOf(PushRegistrationEffect.Register("fresh")) }
        val gate = CompletableDeferred<Unit>().also { jwtGate = it }
        val host = coordinator()
        val signOut = launch { host.signOut(PushSignOutReason.UserInitiated) }
        signOut.cancel() // a double logout, or the view model cleared
        jwtGate = null
        gate.complete(Unit)
        idle.await()
        waitFor("POST Bearer jwt-1")
        assertEquals(true, "DELETE Bearer jwt-1" in log)
        assertEquals(true, log.indexOf("localTokenDeleted") < log.indexOf("POST Bearer jwt-1"))
    }

    /** The fake HTTP and token work hop through other threads, so wait for the log line. */
    private suspend fun waitFor(line: String) {
        repeat(500) {
            if (line in log) return
            withContext(Dispatchers.Default) { delay(10) }
        }
        assertEquals("expected log line", line, log.toList().toString())
    }
}
