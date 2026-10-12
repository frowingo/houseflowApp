package com.houseflow

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.platform.HouseDetails
import com.houseflow.platform.HouseMember
import com.houseflow.platform.HouseSummary
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.dashboard.DashboardScreen
import com.houseflow.viewmodel.HouseRoute
import com.houseflow.viewmodel.HouseUiState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DashboardScreenTest {
    @get:Rule val compose = createComposeRule()
    private val text = LocalizedText("en", mapOf(
        "dashboard_greeting_template" to "Hi, {first_name}", "announcement_title" to "Announcements",
        "announcement_empty_title" to "There are no active announcements.",
        "todays_tasks_title" to "Today's Tasks", "todays_tasks_empty_title" to "All Done!",
        "todays_tasks_empty_subtitle" to "You've completed all tasks for today",
        "house_members_title" to "House Members", "floating_new_chore_button" to "New Chore",
        "new_announcement_action_accessibility_label" to "Create announcement",
        "new_announcement_title" to "New announcement", "new_announcement_subtitle" to "Share an update",
        "new_announcement_title_label" to "Title", "new_announcement_message_label" to "Message",
        "new_announcement_publish_button" to "Publish announcement", "common_cancel" to "Cancel",
        "common_close" to "Close", "tab_home" to "Home", "tab_profile" to "Profile",
        "tab_games" to "Games", "new_chore_title" to "New Chore",
    ))
    private val details = HouseDetails("h", "Ada's home", "{}", "u",
        members = listOf(HouseMember("u", "Ada", "A", "")))
    private val state = HouseUiState(route = HouseRoute.DASHBOARD, details = details,
        houses = listOf(HouseSummary("h", "Ada's home", "")), userId = "u", firstName = "Ada")

    @Test fun realEmptyHouseRendersNoDemoChoresAndOpensExistingAnnouncementPopup() {
        var publishes = 0
        compose.setContent { DashboardScreen(state, text, {}, { _, _ -> publishes++ }, {}, { _, _ -> }, { _, _ -> }, {}) }
        compose.onNodeWithText("Ada's home").assertExists()
        compose.onNodeWithText("All Done!").assertExists()
        compose.onNodeWithText("House Members").assertExists()
        compose.onNodeWithContentDescription("Create announcement").performClick()
        compose.onNodeWithText("New announcement").assertExists()
        compose.runOnIdle { assertEquals(0, publishes) }
    }

    @Test fun fabKeepsIosTwoTapFlow() {
        compose.setContent { DashboardScreen(state, text, {}, { _, _ -> }, {}, { _, _ -> }, { _, _ -> }, {}) }
        compose.onNodeWithText("New Chore").assertDoesNotExist()
        compose.onNodeWithContentDescription("New Chore").performClick()
        compose.onNodeWithText("New Chore").assertExists()
    }
}
