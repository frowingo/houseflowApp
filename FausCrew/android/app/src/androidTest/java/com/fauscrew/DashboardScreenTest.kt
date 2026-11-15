package com.fauscrew

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.fauscrew.platform.HouseDetails
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.HouseSummary
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.dashboard.DashboardScreen
import com.fauscrew.viewmodel.HouseRoute
import com.fauscrew.viewmodel.HouseUiState
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
        "chore_catalog_open_accessibility" to "Open the chore catalog", "chore_catalog_title" to "Chore Catalog",
        "todays_tasks_empty_add" to "Add from the catalog",
        "new_announcement_action_accessibility_label" to "Create announcement",
        "new_announcement_title" to "New announcement", "new_announcement_subtitle" to "Share an update",
        "new_announcement_title_label" to "Title", "new_announcement_message_label" to "Message",
        "new_announcement_publish_button" to "Publish announcement", "common_cancel" to "Cancel",
        "common_close" to "Close", "tab_home" to "Home", "tab_profile" to "Profile",
        "tab_games" to "Games", "new_chore_title" to "New Chore",
    ))
    private val details = HouseDetails("h", "Ada's home", "u",
        members = listOf(HouseMember("u", "Ada", "A", "")))
    private val state = HouseUiState(route = HouseRoute.DASHBOARD, details = details,
        houses = listOf(HouseSummary("h", "Ada's home", "")), userId = "u", firstName = "Ada")

    @Test fun realEmptyHouseRendersNoDemoChoresAndOpensExistingAnnouncementPopup() {
        var publishes = 0
        compose.setContent { DashboardScreen(state, text, { _, _ -> publishes++ }, {}, { _, _, _ -> }, { _, _ -> }, {}) }
        compose.onNodeWithText("Ada's home").assertExists()
        compose.onNodeWithText("All Done!").assertExists()
        compose.onNode(hasScrollAction()).performScrollToNode(hasText("House Members"))
        compose.onNodeWithText("House Members").assertExists()
        compose.onNode(hasScrollAction()).performScrollToNode(hasContentDescription("Create announcement"))
        compose.onNodeWithContentDescription("Create announcement").performClick()
        compose.onNodeWithText("New announcement").assertExists()
        compose.runOnIdle { assertEquals(0, publishes) }
    }

    @Test fun choreCatalogOpensFromTodaysTasksInsteadOfTheFab() {
        compose.setContent { DashboardScreen(state, text, { _, _ -> }, {}, { _, _, _ -> }, { _, _ -> }, {}) }
        compose.onNodeWithContentDescription("New Chore").assertDoesNotExist()
        compose.onNodeWithText("Chore Catalog").assertDoesNotExist()
        compose.onNode(hasScrollAction()).performScrollToNode(hasContentDescription("Open the chore catalog"))
        compose.onNodeWithContentDescription("Open the chore catalog").performClick()
        compose.onNodeWithText("Chore Catalog").assertExists()
    }

    @Test fun emptyTodaysTasksOffersTheCatalog() {
        compose.setContent { DashboardScreen(state, text, { _, _ -> }, {}, { _, _, _ -> }, { _, _ -> }, {}) }
        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Add from the catalog"))
        compose.onNodeWithText("Add from the catalog").performClick()
        compose.onNodeWithText("Chore Catalog").assertExists()
    }

    @Test fun dashboardReportsPopupAsOverlaySoTheTabBarHides() {
        var overlay = false
        compose.setContent { DashboardScreen(state, text, { _, _ -> }, {}, { _, _, _ -> }, { _, _ -> }, {},
            onOverlayChange = { overlay = it }) }
        compose.onNodeWithContentDescription("Create announcement").performClick()
        compose.runOnIdle { assertEquals(true, overlay) }
    }
}
