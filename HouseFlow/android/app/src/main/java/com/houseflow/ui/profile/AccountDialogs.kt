package com.houseflow.ui.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.AuthProfile
import com.houseflow.platform.LocalizedText
import com.houseflow.platform.SocialProvider
import com.houseflow.ui.auth.OtpField
import com.houseflow.ui.auth.social
import com.houseflow.ui.components.HouseFlowPopup
import com.houseflow.ui.components.PopupError
import com.houseflow.ui.components.PopupFooter
import com.houseflow.ui.components.PopupPrimaryButton
import com.houseflow.ui.components.PopupSecondaryButton
import com.houseflow.ui.components.PopupTextField
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.viewmodel.AccountUiState

/** Settings → sign-in methods: link/unlink providers and, for password-less accounts, set a password. */
@Composable
internal fun LoginMethodsDialog(
    user: AuthProfile, account: AccountUiState, enabled: List<SocialProvider>, strings: LocalizedText,
    onDismiss: () -> Unit, onLink: (SocialProvider) -> Unit, onUnlink: (SocialProvider) -> Unit,
    onRequestPasswordCode: () -> Unit, onSetPassword: (String, String) -> Unit,
) {
    val linked = user.linkedProviders.orEmpty().mapNotNull(SocialProvider::of).toSet()
    // Linked providers stay visible (so they can be removed) even if this build no longer offers them.
    val rows = SocialProvider.entries.filter { it in linked || it in enabled }
    val working = account.busyProvider != null || account.passwordBusy
    HouseFlowPopup(
        onDismiss = onDismiss, dismissEnabled = !working, bodySpacing = Spacing.lg,
        header = {
            ProfilePopupHeader(strings.social("profile_login_methods_label", "Giriş yöntemleri", "Sign-in methods"), user.email,
                HouseFlowIcons.lockShieldFill, !working, strings.profileValue("common_close"), onDismiss)
        },
        footer = {
            PopupFooter { PopupSecondaryButton(strings.profileValue("common_close"), !working, onDismiss, Modifier.fillMaxWidth()) }
        },
    ) {
        if (rows.isEmpty()) {
            Text(strings.social("login_methods_none", "Bu sürümde bağlanabilecek bir giriş yöntemi yok.",
                "No sign-in methods can be linked in this version."), style = HouseFlowType.subheadline,
                color = HouseFlowColors.textSecondary)
        }
        rows.forEach { provider ->
            val isLinked = provider in linked
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(provider.displayName, style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
                    Text(if (isLinked) strings.social("login_methods_linked", "Bağlı", "Linked")
                        else strings.social("login_methods_not_linked", "Bağlı değil", "Not linked"),
                        fontSize = 12.sp, color = HouseFlowColors.textSecondary)
                }
                when {
                    account.busyProvider == provider -> CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    isLinked -> ActionText(strings.social("login_methods_unlink", "Kaldır", "Remove"),
                        HouseFlowColors.error, !working) { onUnlink(provider) }
                    else -> ActionText(strings.social("login_methods_link", "Bağla", "Link"),
                        HouseFlowColors.accentOrange, !working) { onLink(provider) }
                }
            }
        }
        if (user.hasPassword == false) PasswordSetup(account, strings, onRequestPasswordCode, onSetPassword)
        if (account.passwordSaved) {
            Text(strings.social("login_methods_password_saved", "Şifren belirlendi.", "Your password is set."),
                style = HouseFlowType.subheadline, color = HouseFlowColors.success)
        }
        if (account.messageIsInfo) {
            account.message?.let { Text(it, style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary) }
        } else {
            PopupError(account.message)
        }
    }
}

@Composable
private fun PasswordSetup(account: AccountUiState, strings: LocalizedText,
    onRequestCode: () -> Unit, onSetPassword: (String, String) -> Unit) {
    var code by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Text(strings.social("login_methods_set_password", "Şifre belirle", "Set a password"),
            style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
        Text(strings.social("login_methods_set_password_hint", "Emailine bir kod göndeririz; şifreni o kodla belirlersin.",
            "We'll email you a code that lets you choose a password."), fontSize = 13.sp, color = HouseFlowColors.textSecondary)
        if (!account.passwordCodeSent) {
            PopupPrimaryButton(strings.social("social_email_send", "Kod gönder", "Send code"), !account.passwordBusy,
                onRequestCode, Modifier.fillMaxWidth(), icon = HouseFlowIcons.envelopeFill, busy = account.passwordBusy)
        } else {
            OtpField(code, { code = it }, strings.social("social_code_label", "Doğrulama kodu", "Verification code"), false)
            PopupTextField(password, { password = it },
                strings.get("forgot_password_new_password_placeholder"),
                Modifier.fillMaxWidth().semantics { contentDescription = "new-password" },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrectEnabled = false))
            PopupPrimaryButton(strings.get("forgot_password_reset_button"),
                !account.passwordBusy && code.length == 6 && password.isNotEmpty(),
                { onSetPassword(code, password) }, Modifier.fillMaxWidth(), busy = account.passwordBusy)
        }
    }
}

@Composable
private fun ActionText(text: String, color: androidx.compose.ui.graphics.Color, enabled: Boolean, onClick: () -> Unit) {
    Text(text, Modifier.clip(RoundedCornerShape(Radius.sm)).clickable(enabled = enabled, onClick = onClick)
        .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        color = if (enabled) color else HouseFlowColors.textTertiary, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
}

/** In-app account deletion with explicit confirmation of what is removed. */
@Composable
internal fun DeleteAccountDialog(account: AccountUiState, strings: LocalizedText, onDismiss: () -> Unit, onConfirm: () -> Unit) {
    var confirming by remember { mutableStateOf(false) }
    HouseFlowPopup(
        onDismiss = onDismiss, dismissEnabled = !account.deleting, bodySpacing = Spacing.lg,
        header = {
            ProfilePopupHeader(strings.social("delete_account_title", "Hesabı sil", "Delete account"), null,
                HouseFlowIcons.exclamationmarkTriangleFill, !account.deleting, strings.profileValue("common_close"), onDismiss)
        },
        footer = {
            PopupFooter {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    PopupSecondaryButton(strings.get("common_cancel"), !account.deleting, onDismiss, Modifier.weight(1f))
                    PopupPrimaryButton(
                        if (confirming) strings.social("delete_account_confirm_button", "Evet, kalıcı olarak sil", "Yes, delete permanently")
                        else strings.social("delete_account_button", "Hesabı sil", "Delete account"),
                        !account.deleting, { if (confirming) onConfirm() else confirming = true }, Modifier.weight(1f),
                        icon = HouseFlowIcons.exclamationmarkTriangleFill, busy = account.deleting,
                        brush = Brush.horizontalGradient(listOf(HouseFlowColors.error, HouseFlowColors.error)),
                    )
                }
            }
        },
    ) {
        listOf(
            strings.social("delete_account_permanent", "Hesabın kalıcı olarak silinir.", "Your account is deleted permanently."),
            strings.social("delete_account_sole_member",
                "Tek üyesi olduğun evler; tüm görevleri, duyuruları ve geçmişiyle birlikte silinir.",
                "Houses where you are the only member are deleted with all their chores, announcements and history."),
            strings.social("delete_account_shared", "Paylaşılan evler kalan ilk üyeye geçer.",
                "Shared houses pass to the first remaining member."),
        ).forEach { line ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text("•", color = HouseFlowColors.error)
                Text(line, style = HouseFlowType.subheadline, color = HouseFlowColors.textPrimary)
            }
        }
        if (confirming) {
            Text(strings.social("delete_account_confirm_message", "Bu işlem geri alınamaz.", "This cannot be undone."),
                Modifier.fillMaxWidth().background(HouseFlowColors.error.copy(alpha = .08f), RoundedCornerShape(Radius.md))
                    .padding(Spacing.md),
                style = HouseFlowType.subheadline, color = HouseFlowColors.error, fontWeight = FontWeight.SemiBold)
        }
        PopupError(account.deleteError)
    }
}
