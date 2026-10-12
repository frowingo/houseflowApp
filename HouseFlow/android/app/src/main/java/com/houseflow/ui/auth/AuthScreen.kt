package com.houseflow.ui.auth

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.LocalizedText
import com.houseflow.viewmodel.AuthUiState
import com.houseflow.viewmodel.AuthMode

private val orange = Color(0xFFFFA500)
private val primary = Color(0xFF007AFF)
private val gray6 = Color(0xFFF2F2F7)
private val secondary = Color(0xFF8E8E93)
private val ink = Color(0xFF1C1C1E)
private val hero = Brush.linearGradient(listOf(orange, Color(0xFFFFC060)))

/** Dimensions and hierarchy follow iOS AuthView. */
@Composable
internal fun AuthScreen(
    state: AuthUiState,
    strings: LocalizedText,
    onEmail: (String) -> Unit,
    onPassword: (String) -> Unit,
    onFirstName: (String) -> Unit,
    onLastName: (String) -> Unit,
    onMode: (AuthMode) -> Unit,
    onForgot: () -> Unit,
    onSubmit: () -> Unit,
) {
    val focus = LocalFocusManager.current
    Column(Modifier.fillMaxSize().background(Color.White)) {
        Column(
            Modifier.fillMaxWidth().background(hero).statusBarsPadding().padding(top = 32.dp, bottom = 72.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.size(104.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(104.dp).background(Color.White.copy(alpha = .10f), CircleShape))
                Box(Modifier.size(84.dp).background(Color.White.copy(alpha = .18f), CircleShape))
                Icon(Icons.Filled.Home, null, Modifier.size(36.dp), tint = Color.White)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(strings.get("app_name"), fontSize = 30.sp, fontWeight = FontWeight.Bold, color = Color.White)
                Text(strings.get("auth_tagline"), fontSize = 15.sp, color = Color.White.copy(alpha = .72f))
            }
        }
        Column(
            Modifier.fillMaxSize().offset(y = (-32).dp).clip(RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp))
                .background(Color.White).verticalScroll(rememberScrollState()).navigationBarsPadding()
                .padding(horizontal = 24.dp).padding(top = 32.dp, bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(gray6).padding(4.dp)) {
                AuthTab(strings.get("auth_sign_in_tab"), state.mode == AuthMode.SIGN_IN, Modifier.weight(1f)) { onMode(AuthMode.SIGN_IN) }
                AuthTab(strings.get("auth_sign_up_tab"), state.mode == AuthMode.SIGN_UP, Modifier.weight(1f)) { onMode(AuthMode.SIGN_UP) }
            }
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                if (state.mode == AuthMode.SIGN_UP) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.weight(1f)) {
                            AuthField(strings.get("auth_first_name_label"), strings.get("auth_first_name_placeholder"),
                                state.firstName, onFirstName, Icons.Filled.Person, false, KeyboardType.Text, ImeAction.Next)
                        }
                        Box(Modifier.weight(1f)) {
                            AuthField(strings.get("auth_last_name_label"), strings.get("auth_last_name_placeholder"),
                                state.lastName, onLastName, Icons.Filled.Person, false, KeyboardType.Text, ImeAction.Next)
                        }
                    }
                }
                AuthField(strings.get("auth_email_label"), strings.get("auth_email_placeholder"), state.email,
                    onEmail, Icons.Filled.Email, false, KeyboardType.Email, ImeAction.Next)
                AuthField(strings.get("auth_password_label"), strings.get("auth_password_placeholder"), state.password,
                    onPassword, Icons.Filled.Lock, true, KeyboardType.Password, ImeAction.Done) {
                    focus.clearFocus(); onSubmit()
                }
                if (state.mode == AuthMode.SIGN_IN) {
                    Text(strings.get("auth_forgot_password_button"), Modifier.fillMaxWidth().clickable(onClick = onForgot), color = primary,
                        fontSize = 14.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.End)
                }
            }
            if (state.error != null) {
                Text(strings.values[state.error] ?: state.error,
                    Modifier.fillMaxWidth().background(Color.Red.copy(alpha = .08f), RoundedCornerShape(12.dp)).padding(12.dp),
                    color = Color.Red, fontSize = 15.sp)
            }
            val buttonBrush = if (state.canSubmit) hero else Brush.linearGradient(listOf(Color(0xFFD1D1D6), Color(0xFFD1D1D6)))
            Row(
                Modifier.fillMaxWidth().height(54.dp).clip(RoundedCornerShape(20.dp)).background(buttonBrush)
                    .clickable(enabled = state.canSubmit) { focus.clearFocus(); onSubmit() }
                    .semantics { contentDescription = strings.get(if (state.mode == AuthMode.SIGN_UP) "auth_create_account_button" else "auth_sign_in_button") },
                horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
            ) {
                if (state.busy) CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
                else {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, null, Modifier.size(18.dp), tint = Color.White)
                    Spacer(Modifier.width(8.dp))
                    Text(strings.get(if (state.mode == AuthMode.SIGN_UP) "auth_create_account_button" else "auth_sign_in_button"),
                        color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                }
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.weight(1f).height(1.dp).background(Color(0xFFE5E5EA)))
                Text(strings.get("auth_divider_or"), color = secondary, fontSize = 12.sp)
                Box(Modifier.weight(1f).height(1.dp).background(Color(0xFFE5E5EA)))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                SocialButton(strings.get("auth_google_button"), SocialKind.Google, Color.White, ink, Modifier.weight(1f).border(1.dp, Color(0xFFD1D1D6), RoundedCornerShape(12.dp)))
                SocialButton(strings.get("auth_apple_button"), SocialKind.Apple, Color.Black, Color.White, Modifier.weight(1f))
                SocialButton(strings.get("auth_snapchat_button"), SocialKind.Snapchat, Color.Yellow, Color.Black, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun AuthTab(label: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(modifier.height(36.dp).clip(RoundedCornerShape(12.dp))
        .then(if (selected) Modifier.shadow(6.dp, RoundedCornerShape(12.dp)).background(Color.White) else Modifier)
        .clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(label, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
            color = if (selected) primary else secondary)
    }
}

@Composable
private fun AuthField(label: String, placeholder: String, value: String, onValue: (String) -> Unit,
    icon: ImageVector, secure: Boolean, keyboard: KeyboardType, ime: ImeAction, onDone: () -> Unit = {}) {
    var focused by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, color = ink, fontSize = 15.sp)
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(gray6)
                .border(2.dp, if (focused) primary else Color.Transparent, RoundedCornerShape(12.dp))
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(icon, null, Modifier.size(20.dp), tint = if (focused) primary else secondary)
            BasicTextField(value, onValue,
                Modifier.weight(1f).onFocusChanged { focused = it.isFocused }.semantics { contentDescription = label },
                singleLine = true, textStyle = TextStyle(fontSize = 16.sp, color = ink), cursorBrush = SolidColor(primary),
                visualTransformation = if (secure) PasswordVisualTransformation() else VisualTransformation.None,
                keyboardOptions = KeyboardOptions(keyboardType = keyboard, imeAction = ime, autoCorrectEnabled = false),
                keyboardActions = KeyboardActions(onDone = { onDone() }),
                decorationBox = { inner -> Box { if (value.isEmpty()) Text(placeholder, color = secondary, fontSize = 16.sp); inner() } },
            )
        }
    }
}

@Composable
private fun SocialButton(label: String, kind: SocialKind, background: Color, foreground: Color, modifier: Modifier) {
    Column(modifier.height(60.dp).clip(RoundedCornerShape(12.dp)).background(background),
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        SocialIcon(kind, foreground)
        Text(label, color = foreground, fontSize = 12.sp)
    }
}
