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
import com.houseflow.ui.auth.BirthdaySetupScreen
import com.houseflow.ui.auth.EmailVerificationScreen
import com.houseflow.ui.auth.ForgotPasswordScreen
import com.houseflow.viewmodel.AuthRoute
import com.houseflow.viewmodel.AuthUiState
import com.houseflow.viewmodel.ForgotPhase
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AuthFlowScreensTest {
    @get:Rule val compose = createComposeRule()

    private val strings = LocalizedText("en", mapOf(
        "auth_email_label" to "Email Address", "auth_email_placeholder" to "your@email.com",
        "email_verification_title" to "Verify your email", "email_verification_subtitle" to "Check your inbox",
        "email_verification_send_button" to "Send verification email",
        "email_verification_resend_button" to "Resend email", "email_verification_code_title" to "Verification code",
        "email_verification_code_instruction" to "Enter code", "email_verification_confirm_button" to "Verify email",
        "signup_success_title" to "Registration complete", "signup_success_message" to "Welcome",
        "common_continue" to "Continue", "forgot_password_title" to "Forgot password",
        "forgot_password_subtitle" to "Reset your password", "forgot_password_send_button" to "Send code",
        "forgot_password_check_inbox_title" to "Check inbox",
        "forgot_password_code_instruction_template" to "Code sent to {email}",
        "forgot_password_new_password_label" to "New password",
        "forgot_password_new_password_placeholder" to "Enter new password",
        "forgot_password_reset_button" to "Reset password",
        "birthday_setup_title" to "When is your birthday?",
        "birthday_setup_subtitle" to "Complete your profile",
        "birthday_setup_date_label" to "Date of birth",
        "birthday_setup_privacy_note" to "Saved securely",
        "birthday_setup_continue_button" to "Save and continue",
    ))

    @Test fun verificationRequiresSixCharactersAndResendCooldown() {
        var state by mutableStateOf(AuthUiState(route = AuthRoute.SignIn, verificationSent = true,
            resendDeadline = System.currentTimeMillis() + 180_000))
        var verifies = 0
        compose.setContent { EmailVerificationScreen(state, strings, "ada@example.com", {}, {},
            { state = state.copy(code = it) }, { verifies++ }, {}) }
        compose.onNodeWithText("Resend email").assertIsNotEnabled()
        compose.onNodeWithText("Verify email").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Verification code").performTextInput("ABC123")
        compose.onNodeWithText("Verify email").performClick()
        compose.runOnIdle { assertEquals(1, verifies) }
    }

    @Test fun forgotPasswordShowsCodePhaseOnlyAfterSend() {
        var state by mutableStateOf(AuthUiState(route = AuthRoute.ForgotPassword))
        var sends = 0
        compose.setContent { ForgotPasswordScreen(state, strings, {}, { state = state.copy(forgotEmail = it) },
            { sends++; state = state.copy(forgotPhase = ForgotPhase.CODE_ENTRY) },
            { state = state.copy(code = it) }, { state = state.copy(newPassword = it) }, {}) }
        compose.onNodeWithText("Send code").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Email Address").performTextInput("ada@example.com")
        compose.onNodeWithText("Send code").performClick()
        compose.onNodeWithText("Check inbox").assertExists()
        compose.onNodeWithContentDescription("Check inbox").performTextInput("a1b2c3")
        compose.runOnIdle {
            assertEquals(1, sends)
            assertEquals("A1B2C3", state.code)
        }
    }

    @Test fun birthdayScreenKeepsExistingHeadingAndSaveAction() {
        var saves = 0
        compose.setContent { BirthdaySetupScreen(AuthUiState(route = AuthRoute.SignIn), strings, {}, { saves++ }) }
        compose.onNodeWithText("When is your birthday?").assertExists()
        compose.onNodeWithText("Save and continue").performClick()
        compose.runOnIdle { assertEquals(1, saves) }
    }
}
