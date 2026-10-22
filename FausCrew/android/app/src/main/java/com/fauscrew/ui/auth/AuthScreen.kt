package com.fauscrew.ui.auth

import androidx.compose.foundation.Canvas
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
import androidx.compose.material.icons.filled.Info
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.SocialProvider
import com.fauscrew.ui.components.FausButtonGradient
import com.fauscrew.ui.components.FausBadge
import com.fauscrew.ui.components.fausHeroBackground
import com.fauscrew.ui.components.drawFausMark
import com.fauscrew.ui.components.fausMarkBrush
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.viewmodel.AuthUiState
import com.fauscrew.viewmodel.AuthMode

private val accent = FausCrewColors.brandOrange
private val gray6 = Color(0xFFF2F2F7)
private val secondary = Color(0xFF8E8E93)
private val ink = Color(0xFF1C1C1E)

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
    onSocial: (SocialProvider) -> Unit = {},
) {
    val focus = LocalFocusManager.current
    Column(Modifier.fillMaxSize().background(Color.White)) {
        Column(
            Modifier.fillMaxWidth().fausHeroBackground()
                .statusBarsPadding().padding(top = 32.dp, bottom = 72.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            FausBadge(88.dp) {
                Canvas(Modifier.size(88.dp)) { drawFausMark(fausMarkBrush(size.minDimension / 1024f)) }
            }
            // Brand wordmark and motto stay fixed across languages.
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    buildAnnotatedString {
                        withStyle(SpanStyle(fontWeight = FontWeight.ExtraBold)) { append("Faus") }
                        withStyle(SpanStyle(fontWeight = FontWeight.Normal, color = Color.White.copy(alpha = .88f))) { append("Crew") }
                    },
                    fontSize = 30.sp, color = Color.White,
                )
                Text("Make living together fun", fontSize = 15.sp, color = Color.White.copy(alpha = .8f))
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
                    Text(strings.get("auth_forgot_password_button"), Modifier.fillMaxWidth().clickable(onClick = onForgot), color = FausCrewColors.accentOrangeInk,
                        fontSize = 14.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.End)
                }
            }
            if (state.error != null) {
                Text(strings.values[state.error] ?: state.error,
                    Modifier.fillMaxWidth().background(Color.Red.copy(alpha = .08f), RoundedCornerShape(12.dp)).padding(12.dp),
                    color = Color.Red, fontSize = 15.sp)
            }
            if (state.info != null) {
                Row(Modifier.fillMaxWidth().background(Color(0xFF007AFF).copy(alpha = .10f), RoundedCornerShape(12.dp)).padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                    Icon(Icons.Filled.Info, null, Modifier.size(18.dp), tint = Color(0xFF007AFF))
                    Text(state.info, color = ink, fontSize = 15.sp)
                }
            }
            if (state.notice != null) {
                Text(state.notice,
                    Modifier.fillMaxWidth().background(Color(0xFF34C759).copy(alpha = .10f), RoundedCornerShape(12.dp)).padding(12.dp),
                    color = Color(0xFF237548), fontSize = 15.sp)
            }
            val buttonBrush = if (state.canSubmit) FausButtonGradient else SolidColor(Color(0xFFD1D1D6))
            Row(
                Modifier.fillMaxWidth().height(54.dp)
                    .then(if (state.canSubmit) Modifier.shadow(10.dp, RoundedCornerShape(20.dp),
                        ambientColor = FausCrewColors.deepBerry, spotColor = FausCrewColors.deepBerry) else Modifier)
                    .clip(RoundedCornerShape(20.dp)).background(buttonBrush)
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
            // Only providers this build enabled; Apple has no Android flow and is never listed.
            if (state.socialProviders.isNotEmpty()) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.weight(1f).height(1.dp).background(Color(0xFFE5E5EA)))
                    Text(strings.get("auth_divider_or"), color = secondary, fontSize = 12.sp)
                    Box(Modifier.weight(1f).height(1.dp).background(Color(0xFFE5E5EA)))
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    state.socialProviders.forEach { provider ->
                        val onClick = { focus.clearFocus(); onSocial(provider) }
                        when (provider) {
                            SocialProvider.GOOGLE -> SocialButton(strings.get("auth_google_button"), SocialKind.Google, Color.White, ink,
                                Modifier.weight(1f).border(1.dp, Color(0xFFD1D1D6), RoundedCornerShape(12.dp)), !state.busy, onClick)
                            SocialProvider.FACEBOOK -> SocialButton("Facebook", SocialKind.Facebook, Color(0xFF1877F2), Color.White,
                                Modifier.weight(1f), !state.busy, onClick)
                            SocialProvider.SNAPCHAT -> SocialButton(strings.get("auth_snapchat_button"), SocialKind.Snapchat, Color(0xFFFFFC00),
                                Color.Black, Modifier.weight(1f), !state.busy, onClick)
                            SocialProvider.APPLE -> Unit
                        }
                    }
                }
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
            color = if (selected) accent else secondary)
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
                .border(2.dp, if (focused) accent else Color.Transparent, RoundedCornerShape(12.dp))
                .padding(horizontal = 16.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(icon, null, Modifier.size(20.dp), tint = if (focused) accent else secondary)
            BasicTextField(value, onValue,
                Modifier.weight(1f).onFocusChanged { focused = it.isFocused }.semantics { contentDescription = label },
                singleLine = true, textStyle = TextStyle(fontSize = 16.sp, color = ink), cursorBrush = SolidColor(accent),
                visualTransformation = if (secure) PasswordVisualTransformation() else VisualTransformation.None,
                keyboardOptions = KeyboardOptions(keyboardType = keyboard, imeAction = ime, autoCorrectEnabled = false),
                keyboardActions = KeyboardActions(onDone = { onDone() }),
                decorationBox = { inner -> Box { if (value.isEmpty()) Text(placeholder, color = secondary, fontSize = 16.sp); inner() } },
            )
        }
    }
}

@Composable
private fun SocialButton(label: String, kind: SocialKind, background: Color, foreground: Color, modifier: Modifier,
    enabled: Boolean, onClick: () -> Unit) {
    Column(modifier.height(60.dp).clip(RoundedCornerShape(12.dp)).background(background)
        .clickable(enabled = enabled, onClick = onClick).semantics { contentDescription = label },
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        SocialIcon(kind)
        Text(label, color = foreground, fontSize = 12.sp)
    }
}
