package com.fauscrew

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.house.CreateHouseScreen
import com.fauscrew.ui.house.HouseSelectionScreen
import com.fauscrew.ui.house.JoinHouseScreen
import com.fauscrew.viewmodel.HouseRoute
import com.fauscrew.viewmodel.HouseUiState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HouseScreensTest {
    @get:Rule val compose = createComposeRule()
    private val strings = LocalizedText("en", mapOf(
        "house_selection_title" to "Your home", "house_selection_subtitle" to "Choose an option",
        "house_selection_create_title" to "Create a home", "house_selection_create_subtitle" to "Start fresh",
        "house_selection_join_title" to "Join a home", "house_selection_join_subtitle" to "Use a code",
        "create_house_title" to "Create home", "create_house_subtitle" to "Your place",
        "create_house_name_label" to "Home name", "create_house_name_placeholder" to "Enter name",
        "create_house_type_label" to "Home type", "create_house_type_student" to "Student",
        "create_house_type_shared" to "Shared", "create_house_type_dorm" to "Dorm",
        "create_house_member_count_label" to "Members", "create_house_submit_button" to "Create",
        "house_summary_title" to "Summary", "house_summary_subtitle" to "Confirm",
        "house_summary_name_label" to "Name", "house_summary_type_label" to "Type",
        "house_summary_person_count_label" to "People", "house_summary_create_button" to "Confirm create",
        "join_house_title" to "Join home", "join_house_subtitle" to "Enter code",
        "invite_code_label" to "Invite code", "join_house_invite_placeholder" to "AB12CD34",
        "join_house_submit_button" to "Join", "join_house_help_title" to "How it works",
    ))

    @Test fun selectionKeepsExistingTwoChoices() {
        var create = 0
        var join = 0
        compose.setContent { HouseSelectionScreen(strings, { create++ }, { join++ }) }
        compose.onNodeWithText("Create a home").performClick()
        compose.onNodeWithText("Join a home").performClick()
        compose.runOnIdle { assertEquals(1, create); assertEquals(1, join) }
    }

    @Test fun createRequiresNameAndShowsIosSummaryBeforeRequest() {
        var creates = 0
        compose.setContent { CreateHouseScreen(HouseUiState(route = HouseRoute.CREATE), strings, {}, { _, _, _ -> creates++ }) }
        compose.onNodeWithContentDescription("Home name").performTextInput("Ada's place")
        compose.onNodeWithText("Create").performClick()
        compose.onNodeWithText("Summary").assertExists()
        compose.runOnIdle { assertEquals(0, creates) }
        compose.onNodeWithText("Confirm create").performClick()
        compose.runOnIdle { assertEquals(1, creates) }
    }

    @Test fun joinNormalizesEightCharacterCodeBeforeRequest() {
        var code = ""
        compose.setContent { JoinHouseScreen(HouseUiState(route = HouseRoute.JOIN), strings, {}, { code = it }) }
        compose.onNodeWithContentDescription("Invite code").performTextInput("ab-12 cd34")
        compose.onNodeWithText("Join").performClick()
        compose.runOnIdle { assertEquals("AB12CD34", code) }
    }
}
