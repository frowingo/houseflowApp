package com.houseflow

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeLeft
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.onboarding.OnboardingScreen
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OnboardingScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test fun continuePagesForwardAndFinalPageCompletes() {
        var completions = 0
        compose.setContent {
            OnboardingScreen(
                LocalizedText("en", mapOf(
                    "onboarding_page_1_title" to "First",
                    "onboarding_page_1_subtitle" to "First description",
                    "onboarding_page_2_title" to "Second",
                    "onboarding_page_2_subtitle" to "Second description",
                    "onboarding_page_3_title" to "Third",
                    "onboarding_page_3_subtitle" to "Third description",
                    "onboarding_get_started_button" to "Get Started",
                )), false,
            ) { completions++ }
        }

        compose.onNodeWithText("First").assertExists()
        compose.onNodeWithContentDescription("Get Started").assertDoesNotExist()
        compose.onNodeWithContentDescription("Continue").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Second").assertExists()
        compose.onNodeWithTag("onboarding_pager").performTouchInput { swipeLeft() }
        compose.waitForIdle()
        // Games page falls back to built-in copy until the backend ships its keys.
        compose.onNodeWithText("Play together").assertExists()
        compose.onNodeWithContentDescription("Continue").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Third").assertExists()
        compose.runOnIdle { assertEquals(0, completions) }
        compose.onNodeWithContentDescription("Get Started").performClick()
        compose.runOnIdle { assertEquals(1, completions) }
    }
}
