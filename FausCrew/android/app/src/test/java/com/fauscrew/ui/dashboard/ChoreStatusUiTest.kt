package com.fauscrew.ui.dashboard

import com.fauscrew.platform.ChoreFailureReason
import com.fauscrew.platform.HouseChore
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

    @Test fun failedResponseCarriesTheReasonCoreDecided() {
        val failed = """{"id":"f","houseId":"h","title":"Trash","assignedTo":"u","dueDate":"$due",
            "status":4,"isCompleted":false,"reviewRound":0,"reviewVotes":[]"""
        val chore = JSONObject("""$failed,"failureReason":"dueDatePassed"}""").toHouseChore()
        assertEquals(ChoreStatusUi.FAILED, ChoreStatusUi.of(chore.status))
        assertFalse(chore.isCompleted)
        assertEquals(ChoreFailureReason.DUE_DATE_PASSED, chore.failureReason)
        assertEquals(ChoreFailureReason.UNSPECIFIED, JSONObject("""$failed,"failureReason":"unspecified"}""").toHouseChore().failureReason)
        assertNull(JSONObject("$failed}").toHouseChore().failureReason)
    }

    @Test fun completedBeforeDueStaysCompletedWithoutReason() {
        val chore = chore("c", 3, done = true)
        assertEquals(ChoreStatusUi.COMPLETED, ChoreStatusUi.of(chore.status))
        assertNull(chore.failureReason)
    }

    private fun chore(id: String, status: Int, done: Boolean = false) = HouseChore(
        id = id, houseId = "h", title = id, description = "", assignedTo = "u", dueDate = due,
        status = status, isCompleted = done, isRecurring = false, level = 10, recurringInterval = 0,
        reviewRound = 0, reviewVotes = emptyList(),
    )
}
