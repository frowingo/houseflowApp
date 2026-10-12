package com.houseflow

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.auth.AuthScreen
import com.houseflow.viewmodel.AuthRoute
import com.houseflow.viewmodel.AuthUiState
import com.houseflow.viewmodel.AuthMode
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AuthScreenTest {
    @get:Rule val compose = createComposeRule()

    @Test fun iOSCopyValidationAndSubmitSemantics() {
        var state by mutableStateOf(AuthUiState(route = AuthRoute.SignIn))
        var submissions = 0
        compose.setContent {
            AuthScreen(state, LocalizedText("en", mapOf(
                "app_name" to "HouseFlow", "auth_tagline" to "Your home, in sync",
                "auth_sign_in_tab" to "Sign In", "auth_sign_up_tab" to "Sign Up",
                "auth_email_label" to "Email Address", "auth_email_placeholder" to "your@email.com",
                "auth_password_label" to "Password", "auth_password_placeholder" to "Enter your password",
                "auth_sign_in_button" to "Sign In", "auth_create_account_button" to "Create Account",
                "auth_first_name_label" to "First Name", "auth_last_name_label" to "Last Name",
                "auth_first_name_placeholder" to "First Name", "auth_last_name_placeholder" to "Last Name",
                "auth_forgot_password_button" to "Forgot Password?",
                "auth_divider_or" to "or", "auth_google_button" to "Google",
                "auth_apple_button" to "Apple", "auth_snapchat_button" to "Snapchat",
            )), { state = state.copy(email = it) }, { state = state.copy(password = it) },
                { state = state.copy(firstName = it) }, { state = state.copy(lastName = it) },
                { state = state.copy(mode = it, email = "", password = "", firstName = "", lastName = "") },
                {}, { submissions++ })
        }
        compose.onNodeWithText("Your home, in sync").assertExists()
        compose.onNodeWithText("Sign Up").assertExists()
        compose.onNodeWithContentDescription("Sign In").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Email Address").performTextInput("ada@example.com")
        compose.onNodeWithContentDescription("Password").performTextInput("secret")
        compose.onNodeWithContentDescription("Sign In").performClick()
        compose.runOnIdle { assertEquals(1, submissions) }
        compose.onNodeWithText("Sign Up").performClick()
        compose.onNodeWithContentDescription("Create Account").assertIsNotEnabled()
        compose.onNodeWithContentDescription("First Name").performTextInput("Ada")
        compose.onNodeWithContentDescription("Last Name").performTextInput("A")
        compose.onNodeWithContentDescription("Email Address").performTextInput("ada@example.com")
        compose.onNodeWithContentDescription("Password").performTextInput("secret")
        compose.onNodeWithContentDescription("Create Account").performClick()
        compose.runOnIdle { assertEquals(AuthMode.SIGN_UP, state.mode); assertEquals(2, submissions) }
    }
}
