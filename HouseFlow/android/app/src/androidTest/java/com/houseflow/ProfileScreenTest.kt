package com.houseflow

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.platform.AuthDestination
import com.houseflow.platform.AuthProfile
import com.houseflow.platform.HouseSummary
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.profile.ProfileScreen
import com.houseflow.viewmodel.HouseRoute
import com.houseflow.viewmodel.HouseUiState
import com.houseflow.viewmodel.ProfileUiState
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ProfileScreenTest {
    @get:Rule val compose = createComposeRule()
    private val strings = LocalizedText("en", mapOf(
        "profile_account_information_title" to "Account Information",
        "profile_house_information_title" to "House Information",
        "profile_personal_info_title" to "Personal Information",
        "profile_settings_title" to "Settings",
        "profile_house_information_view_button" to "View",
        "profile_house_join_title" to "Join a house",
        "profile_house_join_row_subtitle" to "Enter invite code",
        "profile_edit_button" to "Edit",
        "profile_first_name_label" to "First name",
        "profile_last_name_label" to "Last name",
        "profile_birthdate_label" to "Birth date",
        "profile_email_label" to "Email",
        "profile_phone_label" to "Phone",
        "profile_member_since_label" to "Member since",
        "profile_language_settings_label" to "Language settings",
        "profile_about_label" to "About",
        "profile_logout_label" to "Log out",
        "tab_profile" to "Profile", "tab_home" to "Home", "tab_games" to "Games",
        "common_cancel" to "Cancel", "common_close" to "Close",
    ))
    private val user = AuthProfile(AuthDestination.DASHBOARD, "ada@example.com", "en", "u", "Ada", "A",
        listOf(HouseSummary("h", "Ada's home", "")))
    private val house = HouseUiState(route = HouseRoute.DASHBOARD,
        houses = listOf(HouseSummary("h", "Ada's home", "")), userId = "u")

    @Test fun profileShowsExistingCardsAndOpensEdit() {
        var homeCalls = 0
        compose.setContent { ProfileScreen(user, house, ProfileUiState(), strings,
            onHome = { homeCalls++ }, onLogout = {}, onUpdateProfile = {}, onLoadImages = {},
            onLoadLanguages = {}, onSaveLanguage = {}, onClearProfileError = {}, onJoin = {},
            onOpenHouse = {}, onCloseHouse = {}, onInvite = {}, onUpdateHouse = { _, _, _, _ -> },
            onRemoveMember = { _, _ -> }, onLeave = {}, onClearHouseError = {}) }
        compose.onNodeWithText("Ada A").assertExists()
        compose.onNodeWithText("ada@example.com").assertExists()
        compose.onNodeWithText("Ada's home").assertExists()
        compose.onNodeWithText("Edit").performClick()
        compose.onNodeWithText("First name").assertExists()
        compose.onNodeWithText("Cancel").performClick()
        compose.onNodeWithText("Home").performClick()
        compose.runOnIdle { assertEquals(1, homeCalls) }
    }
}
