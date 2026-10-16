package com.houseflow.ui.games.rockets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.ScreenRotation
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.NorthEast
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.PhoneIphone
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.RocketsColor
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.scaleButton
import com.houseflow.ui.theme.softShadow
import com.houseflow.viewmodel.HouseRocketsUiState
import com.houseflow.viewmodel.RocketsMode
import com.houseflow.viewmodel.RocketsOnlineBlocker

private val PlayerOrder = RocketsColor.entries
private val BotNameKeys = listOf("house_rockets_bot_one", "house_rockets_bot_two", "house_rockets_bot_three")
private val NavigationBarHeight = 44.dp
private val ButtonHeightLarge = 56.dp

/** `HouseRocketsView.lobby`: header, mode choice or setup, the flight guide and Start. */
@Composable
internal fun HouseRocketsLobby(
    state: HouseRocketsUiState,
    copy: RocketsCopy,
    isWaitingForLandscape: Boolean,
    orientationFailed: Boolean,
    onBack: () -> Unit,
    onSelectMode: (RocketsMode) -> Unit,
    onChangeMode: () -> Unit,
    onBotCount: (Int) -> Unit,
    onStart: () -> Unit,
) {
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        // The inline navigation bar of the Games stack: an empty title and a back chevron.
        Box(Modifier.fillMaxWidth().height(NavigationBarHeight)) {
            Box(
                Modifier.padding(start = Spacing.sm).size(NavigationBarHeight)
                    .clickable(role = Role.Button, onClick = onBack)
                    .semantics { contentDescription = copy("house_rockets_exit") },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBackIos, null, Modifier.size(20.dp), tint = HouseFlowColors.primary)
            }
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.widthIn(max = 620.dp).fillMaxWidth().padding(Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                LobbyHeader(copy, state.selectedMode)
                val mode = state.selectedMode
                if (mode != null) {
                    SelectedModeHeader(mode, copy, enabled = !isWaitingForLandscape, onChangeMode)
                    if (mode == RocketsMode.LOCAL_BOTS) {
                        BotLobby(state.botCount, copy, enabled = !isWaitingForLandscape, onBotCount)
                    } else {
                        OnlineBlocker(state.onlineBlocker, copy)
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        RocketsMode.entries.forEach { ModeButton(it, copy) { onSelectMode(it) } }
                    }
                }
                FlightGuide(copy)
                if (mode == RocketsMode.LOCAL_BOTS || (orientationFailed && mode == null)) {
                    RocketsLabel(
                        Icons.Outlined.ScreenRotation,
                        copy(if (orientationFailed) "house_rockets_landscape_error" else "house_rockets_landscape"),
                        HouseFlowType.subheadline,
                        if (orientationFailed) HouseRocketsPreparationTheme.danger else HouseRocketsPreparationTheme.muted,
                    )
                }
            }
        }
        if (state.selectedMode == RocketsMode.LOCAL_BOTS) {
            StartButton(copy, isWaitingForLandscape, onStart)
        }
    }
}

@Composable
private fun LobbyHeader(copy: RocketsCopy, mode: RocketsMode?) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Box(
            Modifier.size(88.dp).background(HouseRocketsPalette.navy, RoundedCornerShape(24.dp)),
            contentAlignment = Alignment.Center,
        ) { HouseRocketsRocketMark(Modifier.size(68.dp)) }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(copy("house_rockets_title"), style = HouseFlowType.largeTitle.copy(fontWeight = FontWeight.Black),
                color = HouseRocketsPreparationTheme.ink)
            Text(copy(if (mode == RocketsMode.LOCAL_BOTS) "house_rockets_subtitle" else "house_rockets_mode_prompt"),
                style = HouseFlowType.subheadline, color = HouseRocketsPreparationTheme.muted)
        }
    }
}

@Composable
private fun SelectedModeHeader(mode: RocketsMode, copy: RocketsCopy, enabled: Boolean, onChangeMode: () -> Unit) {
    val bots = mode == RocketsMode.LOCAL_BOTS
    Row(
        Modifier.fillMaxWidth()
            .drawBehind {
                drawRect(HouseRocketsPreparationTheme.hairline, topLeft = Offset(0f, size.height - 1.dp.toPx()),
                    size = Size(size.width, 1.dp.toPx()))
            }
            .padding(bottom = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        RocketsLabel(
            if (bots) Icons.Outlined.SportsEsports else Icons.Outlined.People,
            copy(if (bots) "house_rockets_mode_bots" else "house_rockets_mode_housemates"),
            HouseFlowType.title3.copy(fontWeight = FontWeight.Bold), HouseRocketsPreparationTheme.ink,
            Modifier.weight(1f),
        )
        Box(
            Modifier.heightIn(min = 44.dp).clickable(enabled = enabled, role = Role.Button, onClick = onChangeMode),
            contentAlignment = Alignment.Center,
        ) {
            Text(copy("house_rockets_change_mode"), style = HouseFlowType.subheadline, fontWeight = FontWeight.SemiBold,
                color = HouseRocketsPreparationTheme.accent.copy(alpha = if (enabled) 1f else .45f))
        }
    }
}

@Composable
private fun ModeButton(mode: RocketsMode, copy: RocketsCopy, onClick: () -> Unit) {
    val bots = mode == RocketsMode.LOCAL_BOTS
    val cream = HouseRocketsPalette.cream
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        Modifier.fillMaxWidth().heightIn(min = 104.dp)
            .scaleButton(onClick = onClick)
            .background(if (bots) HouseRocketsPalette.navy else HouseRocketsPalette.burgundy, shape)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(Modifier.size(44.dp).background(cream.copy(alpha = .12f), RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center) {
                Icon(if (bots) Icons.Rounded.SportsEsports else Icons.Rounded.People, null, Modifier.size(24.dp),
                    tint = if (bots) HouseRocketsPalette.ice else cream)
            }
            Text(copy(if (bots) "house_rockets_mode_bots" else "house_rockets_mode_housemates"),
                Modifier.weight(1f), style = HouseFlowType.headline.copy(fontWeight = FontWeight.Bold), color = cream)
            Icon(Icons.Rounded.NorthEast, null, Modifier.size(18.dp), tint = cream)
        }
        Text(copy(if (bots) "house_rockets_mode_bots_detail" else "house_rockets_mode_housemates_detail"),
            style = HouseFlowType.subheadline, color = cream.copy(alpha = .84f))
    }
}

@Composable
private fun BotLobby(botCount: Int, copy: RocketsCopy, enabled: Boolean, onBotCount: (Int) -> Unit) {
    Column(Modifier.padding(vertical = Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        RocketsLabel(Icons.Rounded.PhoneIphone, copy("house_rockets_offline"), HouseFlowType.subheadline,
            HouseRocketsPreparationTheme.muted)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            for (index in 0..botCount.coerceIn(1, 3)) {
                Box(
                    Modifier.size(24.dp).clip(CircleShape).background(HouseRocketsPalette.player(PlayerOrder[index]))
                        .then(if (index == 0) Modifier.border(2.dp, HouseRocketsPreparationTheme.ink, CircleShape) else Modifier)
                        .semantics {
                            contentDescription = copy(if (index == 0) "house_rockets_you" else BotNameKeys[index - 1])
                        },
                )
            }
        }
        Text(copy("house_rockets_bot_count"), style = HouseFlowType.subheadline, fontWeight = FontWeight.SemiBold,
            color = HouseRocketsPreparationTheme.ink)
        CapsuleSegmentedControl(listOf("1", "2", "3"), botCount.coerceIn(1, 3) - 1, enabled) { onBotCount(it + 1) }
    }
}

/** The iOS 26 segmented `Picker`: a capsule track with a raised white capsule. */
@Composable
private fun CapsuleSegmentedControl(options: List<String>, selectedIndex: Int, enabled: Boolean, onSelect: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth().height(32.dp).clip(CircleShape).background(Color(0x1F767680)).padding(2.dp),
    ) {
        options.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            Box(
                Modifier.weight(1f).fillMaxSize()
                    .then(if (selected) Modifier.softShadow(Color.Black.copy(alpha = .10f), 4.dp, y = 1.dp, shape = CircleShape)
                        .background(Color.White, CircleShape) else Modifier)
                    .clip(CircleShape)
                    .clickable(enabled = enabled, role = Role.Tab) { onSelect(index) }
                    .semantics { this.selected = selected },
                contentAlignment = Alignment.Center,
            ) {
                Text(label, fontSize = 14.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                    color = Color.Black.copy(alpha = if (enabled) 1f else .45f), maxLines = 1)
            }
        }
    }
}

@Composable
private fun OnlineBlocker(blocker: RocketsOnlineBlocker, copy: RocketsCopy) {
    Column(
        Modifier.fillMaxWidth().background(HouseRocketsPreparationTheme.surface, RoundedCornerShape(Radius.xl))
            .padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        RocketsLabel(Icons.Rounded.WifiOff, copy("house_rockets_online_unavailable"), HouseFlowType.headline,
            HouseRocketsPreparationTheme.ink)
        Text(
            copy(when (blocker) {
                RocketsOnlineBlocker.SIGN_IN_REQUIRED -> "house_rockets_online_sign_in"
                RocketsOnlineBlocker.HOUSE_REQUIRED -> "house_rockets_online_house_required"
                RocketsOnlineBlocker.SERVICE_UNAVAILABLE -> "house_rockets_online_unavailable_detail"
            }),
            style = HouseFlowType.subheadline, color = HouseRocketsPreparationTheme.muted,
        )
    }
}

@Composable
private fun FlightGuide(copy: RocketsCopy) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Text(copy("house_rockets_how_to_play"), style = HouseFlowType.title2, color = HouseRocketsPreparationTheme.ink)
        Column {
            GuideStep(copy, "house_rockets_step_steer", "house_rockets_rule_aim", Icons.Rounded.TouchApp,
                HouseRocketsPalette.navy, HouseRocketsPalette.cream)
            GuideStep(copy, "house_rockets_step_thrust", "house_rockets_rule_drive", Icons.Rounded.NorthEast,
                HouseRocketsPalette.burgundy, HouseRocketsPalette.cream)
            GuideStep(copy, "house_rockets_step_fields", "house_rockets_rule_fields", Icons.Rounded.Bolt,
                HouseRocketsPalette.blue, HouseRocketsPalette.navy)
            GuideStep(copy, "house_rockets_step_survive", "house_rockets_rule_survive", Icons.Rounded.Shield,
                HouseRocketsPalette.red, HouseRocketsPalette.cream, isLast = true)
        }
    }
}

@Composable
private fun GuideStep(
    copy: RocketsCopy, title: String, detail: String, icon: ImageVector,
    tint: Color, symbolInk: Color, isLast: Boolean = false,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(44.dp).background(tint, CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, null, Modifier.size(20.dp), tint = symbolInk)
            }
            if (!isLast) Box(Modifier.width(2.dp).height(38.dp).background(HouseRocketsPreparationTheme.hairline))
        }
        Column(
            Modifier.padding(top = 2.dp, bottom = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Text(copy(title), style = HouseFlowType.headline, color = HouseRocketsPreparationTheme.ink)
            Text(copy(detail), style = HouseFlowType.subheadline, color = HouseRocketsPreparationTheme.muted)
        }
    }
}

@Composable
private fun StartButton(copy: RocketsCopy, isWaiting: Boolean, onStart: () -> Unit) {
    val surface = HouseRocketsPreparationTheme.surface
    Row(
        Modifier.padding(horizontal = Spacing.xl, vertical = Spacing.lg).fillMaxWidth().height(ButtonHeightLarge)
            .scaleButton(enabled = !isWaiting, onClick = onStart)
            .background(HouseRocketsPreparationTheme.accent.copy(alpha = if (isWaiting) .6f else 1f),
                RoundedCornerShape(Radius.lg)),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isWaiting) CircularProgressIndicator(Modifier.size(18.dp), color = surface, strokeWidth = 2.dp)
        Icon(Icons.Rounded.NorthEast, null, Modifier.size(18.dp), tint = surface)
        Text(copy(if (isWaiting) "house_rockets_rotating" else "house_rockets_start"),
            style = HouseFlowType.headline, color = surface)
    }
}

/** SwiftUI `Label`: an SF Symbol sized to the text, then the title. */
@Composable
internal fun RocketsLabel(
    icon: ImageVector,
    text: String,
    style: TextStyle,
    color: Color,
    modifier: Modifier = Modifier,
    iconSize: Dp = (style.fontSize.value + 3).dp,
    spacing: Dp = Spacing.sm,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(spacing)) {
        Icon(icon, null, Modifier.size(iconSize), tint = color)
        Text(text, style = style, color = color)
    }
}
