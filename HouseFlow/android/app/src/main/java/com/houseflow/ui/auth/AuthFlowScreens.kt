package com.houseflow.ui.auth

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.FausBadge
import com.houseflow.ui.components.FausButtonGradient
import com.houseflow.ui.components.FausGradientIcon
import com.houseflow.ui.components.FausSpinner
import com.houseflow.ui.components.fausHeroBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.viewmodel.AuthUiState
import com.houseflow.viewmodel.ForgotPhase
import kotlinx.coroutines.delay

private val accentOrange = HouseFlowColors.brandOrange
private val ink = Color(0xFF1C1C1E)
private val muted = Color(0xFF8E8E93)
private val field = Color(0xFFE5E5EA)

@Composable
private fun FlowScaffold(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector,
    onBack: (() -> Unit)?, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().background(Color.White)) {
        Box(Modifier.fillMaxWidth().fausHeroBackground().statusBarsPadding().padding(top = 32.dp, bottom = 64.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                FausBadge(72.dp) { FausGradientIcon(icon, 32.dp) }
                Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
                Text(subtitle, Modifier.padding(horizontal = 32.dp), fontSize = 14.sp,
                    color = Color.White.copy(alpha = .8f), textAlign = TextAlign.Center)
            }
            if (onBack != null) {
                Box(Modifier.padding(start = 24.dp).size(48.dp).clip(CircleShape)
                    .background(Color.White.copy(alpha = .25f)).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White)
                }
            }
        }
        Column(Modifier.fillMaxSize().offset(y = (-32).dp).clip(RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
            .background(Color.White).verticalScroll(rememberScrollState()).navigationBarsPadding()
            .padding(horizontal = 24.dp, vertical = 32.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            content()
        }
    }
}

@Composable
private fun FlowField(label: String, value: String, onValue: (String) -> Unit, placeholder: String,
    readOnly: Boolean = false, password: Boolean = false, keyboard: KeyboardType = KeyboardType.Text,
    showLabel: Boolean = true) {
    var focused by remember { androidx.compose.runtime.mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (showLabel) Text(label, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = ink)
        BasicTextField(value, onValue, Modifier.fillMaxWidth().semantics { contentDescription = label }
            .onFocusChanged { focused = it.isFocused }
            .clip(RoundedCornerShape(12.dp))
            .background(field.copy(alpha = if (readOnly) .6f else 1f))
            .border(2.dp, if (focused && !readOnly) accentOrange else Color.Transparent, RoundedCornerShape(12.dp))
            .padding(16.dp),
            readOnly = readOnly, singleLine = true, textStyle = TextStyle(fontSize = 16.sp, color = ink),
            cursorBrush = SolidColor(accentOrange),
            visualTransformation = if (password) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
            keyboardOptions = KeyboardOptions(keyboardType = keyboard, autoCorrectEnabled = false),
            decorationBox = { inner -> Box { if (value.isEmpty()) Text(placeholder, color = muted, fontSize = 16.sp); inner() } })
    }
}

@Composable
internal fun OtpField(code: String, onCode: (String) -> Unit, label: String,
    digitsOnly: Boolean, characterCount: Int = 6) {
    var focused by remember { androidx.compose.runtime.mutableStateOf(false) }
    Box(Modifier.fillMaxWidth().height(58.dp), contentAlignment = Alignment.Center) {
        Row(Modifier.fillMaxWidth().widthIn(max = if (characterCount == 8) 360.dp else 326.dp),
            horizontalArrangement = Arrangement.spacedBy(if (characterCount == 8) 5.dp else 10.dp)) {
            repeat(characterCount) { index ->
                val character = code.getOrNull(index)?.toString().orEmpty()
                val active = focused && index == code.length.coerceAtMost(characterCount - 1)
                Box(Modifier.weight(1f).height(58.dp).clip(RoundedCornerShape(12.dp))
                    .background(if (character.isNotEmpty()) accentOrange.copy(alpha = .06f) else Color(0xFFF2F2F7))
                    .border(if (active) 2.dp else 1.dp,
                        if (active) accentOrange else if (character.isNotEmpty()) accentOrange.copy(alpha = .45f) else Color(0xFFD1D1D6),
                        RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                    Text(character, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = ink)
                }
            }
        }
        BasicTextField(code, { typed ->
            onCode(typed.filter { if (digitsOnly) it.isDigit() else it.isLetterOrDigit() }
                .take(characterCount).let { if (digitsOnly) it else it.uppercase() })
        }, Modifier.fillMaxWidth().height(58.dp).onFocusChanged { focused = it.isFocused }
            .semantics { contentDescription = label }, singleLine = true,
            textStyle = TextStyle(color = Color.Transparent), cursorBrush = SolidColor(Color.Transparent),
            visualTransformation = VisualTransformation.None,
            keyboardOptions = KeyboardOptions(keyboardType = if (digitsOnly) KeyboardType.Number else KeyboardType.Ascii,
                autoCorrectEnabled = false))
    }
}

@Composable
private fun FlowButton(label: String, busy: Boolean, enabled: Boolean, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(54.dp)
        .then(if (enabled) Modifier.shadow(10.dp, RoundedCornerShape(18.dp),
            ambientColor = HouseFlowColors.deepBerry, spotColor = HouseFlowColors.deepBerry) else Modifier)
        .clip(RoundedCornerShape(18.dp))
        .background(if (enabled) FausButtonGradient else SolidColor(Color(0xFFD1D1D6)))
        .clickable(enabled = enabled, onClick = onClick), contentAlignment = Alignment.Center) {
        if (busy) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
        else Text(label, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun ErrorText(message: String?, strings: LocalizedText) {
    if (message != null) Text(strings.values[message] ?: message,
        Modifier.fillMaxWidth().background(Color.Red.copy(alpha = .08f), RoundedCornerShape(12.dp)).padding(12.dp),
        color = Color.Red, fontSize = 14.sp)
}

@Composable
internal fun EmailVerificationScreen(state: AuthUiState, strings: LocalizedText, email: String,
    onBack: () -> Unit, onSend: () -> Unit, onCode: (String) -> Unit, onVerify: () -> Unit,
    onDismissSuccess: () -> Unit) {
    BackHandler(onBack = onBack)
    var clock by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(state.resendDeadline) {
        while (state.resendDeadline > System.currentTimeMillis()) { clock = System.currentTimeMillis(); delay(1_000) }
        clock = System.currentTimeMillis()
    }
    val seconds = ((state.resendDeadline - clock).coerceAtLeast(0) / 1_000).toInt()
    FlowScaffold(strings.get("email_verification_title"), strings.get("email_verification_subtitle"), Icons.Filled.Email, onBack) {
        FlowField(strings.get("auth_email_label"), email, {}, strings.get("auth_email_placeholder"), readOnly = true)
        FlowButton(strings.get(if (state.verificationSent) "email_verification_resend_button" else "email_verification_send_button"),
            state.busy, !state.busy && seconds == 0, onSend)
        if (seconds > 0) Text("${strings.get("email_verification_resend_countdown")} %02d:%02d".format(seconds / 60, seconds % 60),
            Modifier.fillMaxWidth(), color = muted, fontSize = 12.sp, textAlign = TextAlign.Center)
        if (state.verificationSent) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(strings.get("email_verification_code_title"), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ink)
                Text(strings.get("email_verification_code_instruction"), fontSize = 14.sp, color = muted, textAlign = TextAlign.Center)
            }
            OtpField(state.code, onCode, strings.get("email_verification_code_title"), false)
            FlowButton(strings.get("email_verification_confirm_button"), state.busy, !state.busy && state.code.length == 6, onVerify)
        }
        ErrorText(state.error, strings)
    }
    if (state.signupSuccess) Dialog(onDismissRequest = onDismissSuccess) {
        Column(Modifier.fillMaxWidth().shadow(24.dp, RoundedCornerShape(24.dp))
            .background(Color.White, RoundedCornerShape(24.dp)).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Box(Modifier.size(88.dp).background(Color(0xFF34C759).copy(alpha = .12f), CircleShape),
                contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.CheckCircle, null, Modifier.size(52.dp), tint = Color(0xFF34C759))
            }
            Text(strings.get("signup_success_title"), color = ink, fontSize = 22.sp, fontWeight = FontWeight.Bold)
            Text(strings.get("signup_success_message"), color = muted, fontSize = 14.sp, textAlign = TextAlign.Center)
            FlowButton(strings.get("common_continue"), false, true, onDismissSuccess)
        }
    }
}

@Composable
internal fun ForgotPasswordScreen(state: AuthUiState, strings: LocalizedText, onBack: () -> Unit,
    onEmail: (String) -> Unit, onSend: () -> Unit, onCode: (String) -> Unit,
    onPassword: (String) -> Unit, onReset: () -> Unit) {
    BackHandler(onBack = onBack)
    val validEmail = Regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$").matches(state.forgotEmail)
    FlowScaffold(strings.get("forgot_password_title"), strings.get("forgot_password_subtitle"), Icons.Filled.Lock, onBack) {
        FlowField(strings.get("auth_email_label"), state.forgotEmail, onEmail, strings.get("auth_email_placeholder"),
            readOnly = state.busy || state.forgotPhase == ForgotPhase.CODE_ENTRY || state.forgotPhase == ForgotPhase.COMPLETE,
            keyboard = KeyboardType.Email)
        FlowButton(strings.get("forgot_password_send_button"), state.busy,
            validEmail && !state.busy && state.forgotPhase != ForgotPhase.CODE_ENTRY && state.forgotPhase != ForgotPhase.COMPLETE,
            onSend)
        if (state.forgotPhase != ForgotPhase.IDLE || state.busy) {
            Box(Modifier.fillMaxWidth().height(80.dp), contentAlignment = Alignment.Center) {
                when {
                    state.busy && state.forgotPhase == ForgotPhase.IDLE -> FausSpinner(56.dp)
                    state.forgotPhase == ForgotPhase.FAILED -> Icon(Icons.Filled.Close, null, Modifier.size(44.dp), tint = Color.Red)
                    else -> Icon(Icons.Filled.CheckCircle, null, Modifier.size(44.dp), tint = Color(0xFF34C759))
                }
            }
        }
        if (state.forgotPhase == ForgotPhase.CODE_ENTRY || state.forgotPhase == ForgotPhase.COMPLETE) {
            Text(strings.get("forgot_password_check_inbox_title"), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ink)
            Text(strings.get("forgot_password_code_instruction_template").replace("{email}", state.forgotEmail),
                fontSize = 14.sp, color = muted)
            OtpField(state.code, onCode, strings.get("forgot_password_check_inbox_title"), false)
            FlowField(strings.get("forgot_password_new_password_label"), state.newPassword, onPassword,
                strings.get("forgot_password_new_password_placeholder"), password = true, keyboard = KeyboardType.Password)
            FlowButton(strings.get("forgot_password_reset_button"), state.busy,
                !state.busy && state.code.length == 6 && state.newPassword.isNotEmpty(), onReset)
        }
        if (state.forgotPhase == ForgotPhase.COMPLETE) Text(strings.get("forgot_password_success_toast"), color = Color(0xFF34C759))
        ErrorText(state.error, strings)
    }
}

/** Copy for keys the remote catalog does not ship yet, in the API language. */
internal fun LocalizedText.social(key: String, tr: String, en: String): String =
    values[key] ?: if (com.houseflow.platform.ApiLanguage.code == "tr") tr else en

/**
 * `needsEmail`: the provider (Snapchat, Facebook without email) gave no address. The account
 * is created only after the user verifies one with the emailed 6-character code.
 */
@Composable
internal fun SocialEmailScreen(state: AuthUiState, strings: LocalizedText, onCancel: () -> Unit,
    onEmail: (String) -> Unit, onSend: () -> Unit, onCode: (String) -> Unit,
    onFirstName: (String) -> Unit, onLastName: (String) -> Unit, onComplete: () -> Unit) {
    BackHandler(onBack = onCancel)
    val pending = state.socialPending ?: return
    val codeStep = pending.step == com.houseflow.viewmodel.SocialEmailStep.CODE
    FlowScaffold(
        strings.social("social_email_title", "Emailini doğrula", "Verify your email"),
        if (codeStep) strings.social("social_code_subtitle", "${pending.email} adresine gönderilen 6 karakterlik kodu gir.",
            "Enter the 6-character code sent to ${pending.email}.")
        else strings.social("social_email_subtitle", "Hesabını açmak için bir email adresine ihtiyacımız var. Sana bir kod göndereceğiz.",
            "We need an email address to create your account. We'll send you a code."),
        Icons.Filled.Email, onCancel,
    ) {
        FlowField(strings.get("auth_email_label"), pending.email, onEmail, strings.get("auth_email_placeholder"),
            readOnly = state.busy || codeStep, keyboard = KeyboardType.Email)
        if (!codeStep) {
            FlowButton(strings.social("social_email_send", "Kod gönder", "Send code"), state.busy,
                !state.busy && pending.canSubmit, onSend)
        } else {
            OtpField(pending.code, onCode, strings.social("social_code_label", "Doğrulama kodu", "Verification code"), false)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.weight(1f)) {
                    FlowField(strings.get("auth_first_name_label"), pending.firstName, onFirstName, strings.get("auth_first_name_placeholder"))
                }
                Box(Modifier.weight(1f)) {
                    FlowField(strings.get("auth_last_name_label"), pending.lastName, onLastName, strings.get("auth_last_name_placeholder"))
                }
            }
            FlowButton(strings.social("social_code_confirm", "Hesabı oluştur", "Create account"), state.busy,
                !state.busy && pending.canSubmit, onComplete)
            Text(strings.social("social_code_resend", "Tekrar gönder", "Resend code"),
                Modifier.fillMaxWidth().clickable(enabled = !state.busy, onClick = onSend),
                color = HouseFlowColors.accentOrangeInk, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
        }
        ErrorText(state.error, strings)
        Text(strings.get("common_cancel"), Modifier.fillMaxWidth().clickable(onClick = onCancel),
            color = muted, fontSize = 15.sp, textAlign = TextAlign.Center)
    }
}
