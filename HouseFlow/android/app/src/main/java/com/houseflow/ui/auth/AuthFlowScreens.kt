package com.houseflow.ui.auth

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
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
import com.houseflow.viewmodel.AuthUiState
import com.houseflow.viewmodel.ForgotPhase
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.delay

private val orange = Color(0xFFFFA500)
private val accentOrange = Color(0xFFFF7A26)
private val ink = Color(0xFF1C1C1E)
private val muted = Color(0xFF8E8E93)
private val field = Color(0xFFE5E5EA)
private val hero = Brush.linearGradient(listOf(orange, Color(0xFFFFC060)))

@Composable
private fun FlowScaffold(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector,
    onBack: (() -> Unit)?, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().background(Color.White)) {
        Box(Modifier.fillMaxWidth().background(hero).statusBarsPadding().padding(top = 24.dp, bottom = 60.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(88.dp).background(Color.White.copy(alpha = .10f), CircleShape), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(70.dp).background(Color.White.copy(alpha = .18f), CircleShape), contentAlignment = Alignment.Center) {
                        Icon(icon, null, Modifier.size(28.dp), tint = Color.White)
                    }
                }
                Text(title, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
                Text(subtitle, Modifier.padding(horizontal = 32.dp), fontSize = 14.sp,
                    color = Color.White.copy(alpha = .76f), textAlign = TextAlign.Center)
            }
            if (onBack != null) {
                Box(Modifier.padding(start = 24.dp).size(48.dp).clip(CircleShape)
                    .background(Color.White.copy(alpha = .25f)).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White)
                }
            }
        }
        Column(Modifier.fillMaxSize().clip(RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
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
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (showLabel) Text(label, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = ink)
        BasicTextField(value, onValue, Modifier.fillMaxWidth().semantics { contentDescription = label }
            .clip(RoundedCornerShape(12.dp))
            .background(field.copy(alpha = if (readOnly) .6f else 1f)).padding(16.dp),
            readOnly = readOnly, singleLine = true, textStyle = TextStyle(fontSize = 16.sp, color = ink),
            cursorBrush = SolidColor(Color(0xFF007AFF)),
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
                    .background(Color(0xFFF2F2F7))
                    .border(if (active) 2.dp else 1.dp,
                        if (active) Color(0xFF007AFF) else if (character.isNotEmpty()) Color(0x66007AFF) else Color(0xFFD1D1D6),
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
    Box(Modifier.fillMaxWidth().height(54.dp).clip(RoundedCornerShape(18.dp))
        .background(if (enabled) hero else Brush.linearGradient(listOf(Color(0xFFD1D1D6), Color(0xFFD1D1D6))))
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
                    state.busy && state.forgotPhase == ForgotPhase.IDLE -> CircularProgressIndicator(color = orange)
                    state.forgotPhase == ForgotPhase.FAILED -> Icon(Icons.Filled.Close, null, Modifier.size(44.dp), tint = Color.Red)
                    else -> Icon(Icons.Filled.CheckCircle, null, Modifier.size(44.dp), tint = Color(0xFF34C759))
                }
            }
        }
        if (state.forgotPhase == ForgotPhase.CODE_ENTRY || state.forgotPhase == ForgotPhase.COMPLETE) {
            Text(strings.get("forgot_password_check_inbox_title"), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ink)
            Text(strings.get("forgot_password_code_instruction_template").replace("{email}", state.forgotEmail),
                fontSize = 14.sp, color = muted)
            OtpField(state.code, onCode, strings.get("forgot_password_check_inbox_title"), true)
            FlowField(strings.get("forgot_password_new_password_label"), state.newPassword, onPassword,
                strings.get("forgot_password_new_password_placeholder"), password = true, keyboard = KeyboardType.Password)
            FlowButton(strings.get("forgot_password_reset_button"), state.busy,
                !state.busy && state.code.length == 6 && state.newPassword.isNotEmpty(), onReset)
        }
        if (state.forgotPhase == ForgotPhase.COMPLETE) Text(strings.get("forgot_password_success_toast"), color = Color(0xFF34C759))
        ErrorText(state.error, strings)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun BirthdaySetupScreen(state: AuthUiState, strings: LocalizedText, onDate: (LocalDate) -> Unit, onSave: () -> Unit) {
    val today = remember { LocalDate.now() }
    val earliest = remember(today) { today.minusYears(120) }
    val picker = rememberDatePickerState(
        initialSelectedDateMillis = state.birthday.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
        yearRange = earliest.year..today.year,
        selectableDates = object : androidx.compose.material3.SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                val date = Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate()
                return !date.isBefore(earliest) && !date.isAfter(today)
            }
        },
    )
    LaunchedEffect(picker.selectedDateMillis) {
        picker.selectedDateMillis?.let { onDate(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
    }
    Column(Modifier.fillMaxSize().background(Color(0xFFF2F2F7)).verticalScroll(rememberScrollState()).navigationBarsPadding()) {
        Box(Modifier.fillMaxWidth().background(Brush.linearGradient(listOf(accentOrange, Color(0xFFFFA338))))
            .statusBarsPadding().height(280.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.align(Alignment.TopStart).padding(start = 45.dp, top = 46.dp).size(12.dp)
                .background(Color.White.copy(alpha = .32f), CircleShape))
            Box(Modifier.align(Alignment.TopEnd).padding(end = 55.dp, top = 36.dp).size(7.dp)
                .background(Color.White.copy(alpha = .42f), CircleShape))
            Box(Modifier.align(Alignment.BottomEnd).padding(end = 28.dp, bottom = 80.dp).size(16.dp)
                .background(Color.White.copy(alpha = .18f), CircleShape))
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(Modifier.size(112.dp).background(Color.White.copy(alpha = .15f), CircleShape), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(88.dp).background(Color.White.copy(alpha = .20f), CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.DateRange, null, Modifier.size(42.dp), tint = Color.White)
                    }
                }
                Text(strings.get("birthday_setup_title"), Modifier.padding(horizontal = 20.dp),
                    fontSize = 27.sp, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
                Text(strings.get("birthday_setup_subtitle"), Modifier.padding(horizontal = 40.dp),
                    fontSize = 15.sp, color = Color.White.copy(alpha = .82f), textAlign = TextAlign.Center)
            }
        }
        Column(Modifier.fillMaxWidth().offset(y = (-28).dp).padding(horizontal = 20.dp)
            .shadow(10.dp, RoundedCornerShape(28.dp)).background(Color.White, RoundedCornerShape(28.dp))
            .padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Text(strings.get("birthday_setup_date_label"), fontSize = 17.sp,
                fontWeight = FontWeight.Bold, color = ink, textAlign = TextAlign.Center)
            val locale = remember(strings.prefix) { Locale.forLanguageTag(strings.prefix ?: Locale.getDefault().toLanguageTag()) }
            Text(state.birthday.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = accentOrange, textAlign = TextAlign.Center)
            DatePicker(state = picker, modifier = Modifier.fillMaxWidth(), title = null, headline = null,
                showModeToggle = false, colors = DatePickerDefaults.colors(
                    selectedDayContainerColor = accentOrange, todayDateBorderColor = accentOrange, todayContentColor = accentOrange))
            Text(strings.get("birthday_setup_privacy_note"), Modifier.fillMaxWidth()
                .background(accentOrange.copy(alpha = .08f), RoundedCornerShape(12.dp)).padding(12.dp),
                color = muted, fontSize = 12.sp)
            ErrorText(state.error, strings)
            FlowButton(strings.get("birthday_setup_continue_button"), state.busy, !state.busy, onSave)
        }
    }
}
