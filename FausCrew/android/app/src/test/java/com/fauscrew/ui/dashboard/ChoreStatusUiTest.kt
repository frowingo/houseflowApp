package com.fauscrew.ui.dashboard

import com.fauscrew.platform.ChoreFailureReason
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.HouseStatusHistory
import com.fauscrew.platform.HouseVote
import com.fauscrew.platform.toHouseChore
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChoreStatusUiTest {
    private val due = "2026-10-12T18:30:00Z"

    @Test fun rawValuesMapAndUnknownFallsBack() {
        assertEquals(ChoreStatusUi.DRAFT, ChoreStatusUi.of(0))
        assertEquals(ChoreStatusUi.PROGRESS, ChoreStatusUi.of(1))
        assertEquals(ChoreStatusUi.IN_TEST, ChoreStatusUi.of(2))
        assertEquals(ChoreStatusUi.COMPLETED, ChoreStatusUi.of(3))
        assertEquals(ChoreStatusUi.FAILED, ChoreStatusUi.of(4))
        assertEquals(ChoreStatusUi.UNKNOWN, ChoreStatusUi.of(99))
        assertEquals(ChoreStatusUi.UNKNOWN, ChoreStatusUi.of(-1))
    }

    @Test fun failedAndUnknownAreTerminalAndNeverAdvance() {
        assertEquals(ChoreStatusUi.PROGRESS, ChoreStatusUi.DRAFT.next)
        assertEquals(ChoreStatusUi.IN_TEST, ChoreStatusUi.PROGRESS.next)
        listOf(ChoreStatusUi.IN_TEST, ChoreStatusUi.COMPLETED, ChoreStatusUi.FAILED, ChoreStatusUi.UNKNOWN)
            .forEach { assertNull(it.name, it.next) }
        assertTrue(ChoreStatusUi.IN_TEST.acceptsActions)
        assertFalse(ChoreStatusUi.COMPLETED.acceptsActions)
        assertFalse(ChoreStatusUi.FAILED.acceptsActions)
        assertFalse(ChoreStatusUi.UNKNOWN.acceptsActions)
        assertFalse(ChoreStatusUi.FAILED in ChoreStatusUi.PIPELINE)
    }

    @Test fun badgeUsesFailedKeyAndFallbacks() {
        val failed = ChoreStatusUi.FAILED
        assertEquals("chore_status_failed", failed.key)
        assertEquals("Başarısız", failed.tr)
        assertEquals("Failed", failed.en)
        assertEquals(ChoreListGroup.FAILED, failed.group)
        assertTrue(failed.group.isHistory)
    }

    @Test fun listsSplitByStatusNotIsCompleted() {
        val chores = listOf(chore("a", 1), chore("b", 4), chore("c", 3, done = true), chore("d", 0), chore("e", 99))
        val (active, history) = chores.splitByHistory()
        assertEquals(listOf("a", "d"), active.map { it.id })
        assertEquals(listOf("b", "c", "e"), history.map { it.id })
    }

    @Test fun failedResponseParsesWithHistory() {
        val chore = JSONObject("""
            {"id":"f","houseId":"h","title":"Trash","assignedTo":"u","dueDate":"$due",
             "status":4,"isCompleted":false,"completedAt":"0001-01-01T00:00:00Z","completedBy":"",
             "statusHistories":[
               {"status":1,"updater":"u","dateTime":"2026-10-11T09:00:00Z"},
               {"status":4,"updater":"system","dateTime":"2026-10-12T18:30:05Z"}],
             "reviewRound":0,"reviewVotes":[]}
        """.trimIndent()).toHouseChore()
        assertEquals(ChoreStatusUi.FAILED, ChoreStatusUi.of(chore.status))
        assertFalse(chore.isCompleted)
        assertEquals(HouseStatusHistory(4, "system", "2026-10-12T18:30:05Z"), chore.statusHistories.last())
        assertEquals(ChoreFailureReason.DUE_DATE_PASSED, chore.failureReason)
    }

    @Test fun completedBeforeDueStaysCompletedWithoutReason() {
        val chore = chore("c", 3, done = true)
        assertEquals(ChoreStatusUi.COMPLETED, ChoreStatusUi.of(chore.status))
        assertNull(chore.failureReason)
    }

    @Test fun failureReasonIsConservative() {
        assertEquals(ChoreFailureReason.DUE_DATE_PASSED, reason("system", "2026-10-12T18:30:00Z"))
        assertEquals(ChoreFailureReason.DUE_DATE_PASSED, reason(" System ", "2026-10-13T00:00:00Z"))
        assertEquals(ChoreFailureReason.UNSPECIFIED, reason("user-1", "2026-10-13T00:00:00Z"))
        assertEquals(ChoreFailureReason.UNSPECIFIED, reason("system", "2026-10-12T10:00:00Z"))
        assertEquals(ChoreFailureReason.UNSPECIFIED, reason("system", "not a date"))
        assertEquals(ChoreFailureReason.UNSPECIFIED, reason("system", "2026-10-13T00:00:00Z", round = 3, rejectedIn = 3))
        assertEquals(ChoreFailureReason.DUE_DATE_PASSED, reason("system", "2026-10-13T00:00:00Z", round = 2, rejectedIn = 1))
        assertEquals(ChoreFailureReason.UNSPECIFIED, ChoreFailureReason.of(emptyList(), due, 0, emptyList()))
    }

    private fun reason(updater: String, failedAt: String, round: Int = 1, rejectedIn: Int? = null) =
        ChoreFailureReason.of(
            listOf(HouseStatusHistory(1, "u", "2026-10-11T09:00:00Z"), HouseStatusHistory(4, updater, failedAt)),
            due, round, listOfNotNull(rejectedIn?.let { HouseVote(it, "r", false) }),
        )

    private fun chore(id: String, status: Int, done: Boolean = false) = HouseChore(
        id = id, houseId = "h", title = id, description = "", assignedTo = "u", dueDate = due,
        status = status, isCompleted = done, isRecurring = false, level = 10, recurringInterval = 0,
        reviewRound = 0, reviewVotes = emptyList(),
    )
}
