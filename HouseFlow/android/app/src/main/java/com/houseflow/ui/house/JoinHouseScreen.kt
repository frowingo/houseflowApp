package com.houseflow.ui.house

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.InviteCodeBridge
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.auth.OtpField
import com.houseflow.ui.components.FausButtonGradient
import com.houseflow.ui.components.FausHouseIcon
import com.houseflow.ui.components.FausIconGradient
import com.houseflow.ui.components.PlaceholderColor
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow
import com.houseflow.viewmodel.HouseUiState
import kotlinx.coroutines.delay

private const val INVITE_CODE_LENGTH = 8

/** `JoinHouseView`: header art, invite code field, the three-step help box and Join. */
@Composable
internal fun JoinHouseScreen(state: HouseUiState, strings: LocalizedText, onBack: () -> Unit, onJoin: (String) -> Unit) {
    val focus = LocalFocusManager.current
    var code by rememberSaveable { mutableStateOf("") }
    val valid = code.length == INVITE_CODE_LENGTH
    val submit = { if (valid) { focus.clearFocus(); onJoin(code) } }
    Column(Modifier.fillMaxSize().mainScreenBackground().statusBarsPadding().navigationBarsPadding()) {
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.padding(top = Spacing.xl, bottom = Spacing.xxxl), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.xl)) {
                    Box(
                        Modifier.size(40.dp).clip(CircleShape).background(HouseFlowColors.surface)
                            .border(1.dp, HouseFlowColors.brandOrange.copy(alpha = .20f), CircleShape)
                            .clickable(role = Role.Button, onClick = onBack)
                            .semantics { contentDescription = strings.get("common_back", "Back") },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(HouseFlowIcons.arrowLeft, null, Modifier.size(22.dp), tint = HouseFlowColors.accentOrangeInk)
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    JoinArt()
                    Text(strings.get("join_house_title"), fontSize = 34.sp, fontWeight = FontWeight.Bold,
                        color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center)
                    Text(strings.get("join_house_subtitle"), Modifier.padding(horizontal = Spacing.xxxl),
                        style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
                }
            }
            Column(Modifier.padding(horizontal = Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.xxl)) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                    Text(strings.get("invite_code_label"), Modifier.fillMaxWidth(), style = HouseFlowType.headline,
                        color = HouseFlowColors.textPrimary)
                    OtpField(code, { code = InviteCodeBridge.normalize(it) }, strings.get("invite_code_label"), false, INVITE_CODE_LENGTH)
                }
                HelpBox(strings)
                state.error?.let { Text(it, style = HouseFlowType.subheadline, color = HouseFlowColors.errorRed) }
            }
        }
        HouseJourneyButton(strings.get("join_house_submit_button"), valid, FausButtonGradient,
            Modifier.padding(start = Spacing.xl, end = Spacing.xl, bottom = Spacing.xxl, top = Spacing.lg),
            height = 56.dp, glow = HouseFlowColors.deepBerry, onClick = submit)
    }
}

@Composable
private fun JoinArt() {
    Box {
        Box(
            Modifier.size(96.dp).background(HouseFlowColors.background, CircleShape)
                .border(1.5.dp, HouseFlowColors.brandOrange.copy(alpha = .55f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            FausHouseIcon(48.dp)
        }
        // Key badge: the invite code.
        Box(
            Modifier.align(Alignment.BottomEnd).offset(2.dp, (-2).dp).size(30.dp)
                .softShadow(HouseFlowColors.deepBerry.copy(alpha = .3f), 4.dp, y = 3.dp, shape = CircleShape)
                .background(FausIconGradient, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(HouseFlowIcons.keyFill, null, Modifier.size(15.dp), tint = Color.White)
        }
    }
}

@Composable
private fun HelpBox(strings: LocalizedText) {
    val shape = RoundedCornerShape(Radius.md)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(HouseFlowColors.deepBerry.copy(alpha = .05f))
            .border(1.dp, HouseFlowColors.deepBerry.copy(alpha = .12f), shape).padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Icon(HouseFlowIcons.infoCircleFill, null, Modifier.size(18.dp), tint = HouseFlowColors.accentOrangeInk)
            Text(strings.get("join_house_help_title"), style = HouseFlowType.subheadline, color = HouseFlowColors.textPrimary)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            (1..3).forEach { step ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    Box(
                        Modifier.size(20.dp).background(FausIconGradient, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(step.toString(), style = HouseFlowType.caption, color = Color.White)
                    }
                    Text(strings.get("join_house_step_$step"), Modifier.weight(1f), style = HouseFlowType.caption,
                        color = HouseFlowColors.textSecondary)
                }
            }
        }
    }
}
