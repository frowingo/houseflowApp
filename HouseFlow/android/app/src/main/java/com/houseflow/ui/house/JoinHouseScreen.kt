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
                            .border(1.dp, HouseFlowColors.indigo.copy(alpha = .10f), CircleShape)
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
                    InviteCodeField(code, { code = InviteCodeBridge.normalize(it) }, strings, isError = state.error != null, submit)
                }
                HelpBox(strings)
                state.error?.let { Text(it, style = HouseFlowType.subheadline, color = HouseFlowColors.errorRed) }
            }
        }
        HouseJourneyButton(strings.get("join_house_submit_button"), valid, HouseJourneyBrushes.joinButton,
            Modifier.padding(start = Spacing.xl, end = Spacing.xl, bottom = Spacing.xxl, top = Spacing.lg),
            height = 56.dp, glow = HouseFlowColors.teal, onClick = submit)
    }
}

@Composable
private fun JoinArt() {
    Box {
        Box(Modifier.size(102.dp).background(HouseFlowColors.teal.copy(alpha = .10f), CircleShape), contentAlignment = Alignment.Center) {
            Box(Modifier.size(78.dp).background(HouseFlowColors.indigo.copy(alpha = .08f), CircleShape))
            // SF `house.and.flag`: a house with a small flag beside it.
            Box(Modifier.size(52.dp)) {
                Icon(HouseFlowIcons.houseFill, null, Modifier.align(Alignment.BottomStart).size(42.dp), tint = HouseFlowColors.indigo)
                Icon(HouseFlowIcons.flag, null, Modifier.align(Alignment.TopEnd).size(20.dp), tint = HouseFlowColors.indigo)
            }
        }
        Box(Modifier.align(Alignment.TopEnd).offset((-2).dp, 8.dp).size(10.dp).background(HouseFlowColors.accentOrange, CircleShape))
    }
}

/** `InviteCodeTextField`: monospaced, centered, upper-case code with focus/error border. */
@Composable
private fun InviteCodeField(value: String, onChange: (String) -> Unit, strings: LocalizedText, isError: Boolean, onSubmit: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val requester = remember { FocusRequester() }
    // iOS focuses the field shortly after the screen appears.
    LaunchedEffect(Unit) { delay(500); runCatching { requester.requestFocus() } }
    val border by animateColorAsState(
        when {
            isError -> HouseFlowColors.error
            focused -> HouseFlowColors.accentOrange
            else -> HouseFlowColors.indigo.copy(alpha = .12f)
        }, Motion.quick(), label = "inviteBorder",
    )
    val shape = RoundedCornerShape(Radius.md)
    val label = strings.get("invite_code_label")
    BasicTextField(
        value = value,
        onValueChange = onChange,
        modifier = Modifier.fillMaxWidth().focusRequester(requester)
            .softShadow(if (focused) HouseFlowColors.accentOrange.copy(alpha = .12f) else Color.Black.copy(alpha = .035f),
                if (focused) 10.dp else 5.dp, y = 3.dp, shape = shape)
            .semantics { contentDescription = label },
        textStyle = HouseFlowType.body.copy(fontFamily = FontFamily.Monospace, fontWeight = FontWeight.SemiBold,
            color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center),
        singleLine = true,
        interactionSource = interaction,
        cursorBrush = SolidColor(HouseFlowColors.primary),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false,
            keyboardType = KeyboardType.Ascii, imeAction = ImeAction.Go),
        keyboardActions = KeyboardActions(onGo = { onSubmit() }),
        decorationBox = { inner ->
            Box(
                Modifier.fillMaxWidth().clip(shape).background(HouseFlowColors.surface)
                    .border(if (focused || isError) 2.dp else 1.dp, border, shape)
                    .padding(Spacing.lg),
                contentAlignment = Alignment.Center,
            ) {
                if (value.isEmpty()) {
                    Text(strings.get("join_house_invite_placeholder"), style = HouseFlowType.body, color = PlaceholderColor,
                        textAlign = TextAlign.Center)
                }
                inner()
            }
        },
    )
}

@Composable
private fun HelpBox(strings: LocalizedText) {
    val shape = RoundedCornerShape(Radius.md)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(HouseFlowColors.teal.copy(alpha = .075f))
            .border(1.dp, HouseFlowColors.teal.copy(alpha = .16f), shape).padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Icon(HouseFlowIcons.infoCircleFill, null, Modifier.size(18.dp), tint = HouseFlowColors.indigo)
            Text(strings.get("join_house_help_title"), style = HouseFlowType.subheadline, color = HouseFlowColors.textPrimary)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            (1..3).forEach { step ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    Box(
                        Modifier.size(20.dp).background(HouseFlowColors.indigo, CircleShape)
                            .border(1.dp, HouseFlowColors.accentOrange.copy(alpha = .55f), CircleShape),
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
