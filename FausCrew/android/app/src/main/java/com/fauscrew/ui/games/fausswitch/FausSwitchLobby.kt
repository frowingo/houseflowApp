package com.fauscrew.ui.games.fausswitch

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.HighlightOff
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Memory
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.ScreenRotation
import androidx.compose.material.icons.rounded.Sensors
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchConstants
import com.fauscrew.platform.SwitchRoom
import com.fauscrew.ui.games.CompactCountdown
import com.fauscrew.ui.games.reportsOnScreen
import com.fauscrew.ui.games.tanks.rememberSecondsUntil
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton
import com.fauscrew.viewmodel.FausSwitchUiState
import com.fauscrew.viewmodel.SwitchMode
import java.util.Locale

private val ButtonHeightLarge = 56.dp

/** The online room as the lobby draws it; [lobby] is null until a session exists. */
internal class SwitchOnlineRoomUi(
    val lobby: OnlineLobbyUi?,
    val room: SwitchRoom,
    /** House members' names by user id. */
    val members: Map<String, String>,
    val uptime: () -> Double,
    val onReady: (Boolean) -> Unit,
    val onCancel: () -> Unit,
    val onRetry: () -> Unit,
)

/**
 * `FausSwitchLobbyView`: in portrait, pick demo or online, then the robot color and either
 * the bots (demo) or the house room (online). Orientation and the race stay with
 * [FausSwitchScreen].
 */
@Composable
internal fun FausSwitchLobby(
    state: FausSwitchUiState,
    copy: SwitchCopy,
    constants: SwitchConstants,
    reduceMotion: Boolean,
    userId: String?,
    houseId: String?,
    isLandscapeLayout: Boolean,
    isWaitingForLandscape: Boolean,
    orientationFailed: Boolean,
    online: SwitchOnlineRoomUi,
    onBack: () -> Unit,
    onSelectMode: (SwitchMode) -> Unit,
    onChangeMode: () -> Unit,
    onSelectColor: (SwitchColor) -> Unit,
    onSelectBotCount: (Int) -> Unit,
    onStart: () -> Unit,
) {
    // While the start countdown card is scrolled away, the top bar carries its seconds.
    var isStartCardVisible by remember { mutableStateOf(true) }
    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.sm), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clip(CircleShape).scaleButton(onClick = onBack)
                    .semantics { contentDescription = copy("faus_switch_exit") },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.AutoMirrored.Rounded.ArrowBack, null, tint = FausSwitchPalette.ink) }
            Spacer(Modifier.weight(1f))
            val lobby = online.lobby
            val seconds = rememberSecondsUntil(
                lobby?.deadlineUptime?.takeIf { state.selectedMode == SwitchMode.ONLINE && lobby.deadlineKind != null },
                online.uptime)
            if (seconds != null && !isStartCardVisible) {
                CompactCountdown(seconds, FausSwitchPalette.ink, FausSwitchPalette.danger,
                    copy.template("faus_switch_online_seconds", "seconds" to "$seconds"))
            }
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.widthIn(max = 620.dp).fillMaxWidth()
                    .padding(start = Spacing.xl, end = Spacing.xl, top = Spacing.sm, bottom = Spacing.xxl),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                Header(state, copy)
                val mode = state.selectedMode
                if (mode != null) {
                    ModeBar(mode, copy, onChangeMode)
                    if (mode == SwitchMode.DEMO) {
                        DemoSetup(state, copy, constants, onSelectColor, onSelectBotCount)
                    } else {
                        OnlineRoom(state, copy, constants, userId, houseId, online, onSelectColor) { isStartCardVisible = it }
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        SwitchMode.entries.forEach { ModeCard(it, copy) { onSelectMode(it) } }
                    }
                }
                Rules(state.color, copy, reduceMotion)
                if (mode == SwitchMode.DEMO || orientationFailed) {
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        val color = if (orientationFailed) FausSwitchPalette.danger else FausSwitchPalette.secondaryInk
                        Icon(Icons.Rounded.ScreenRotation, null, Modifier.size(18.dp), tint = color)
                        Text(copy(if (orientationFailed) "faus_switch_landscape_error" else "faus_switch_landscape_detail"),
                            style = FausCrewType.subheadline, color = color)
                    }
                }
            }
        }
        if (state.selectedMode == SwitchMode.DEMO) {
            BottomBar {
                StartButton(copy, isLandscapeLayout, isWaitingForLandscape, onStart)
            }
        }
    }
}

@Composable
private fun Header(state: FausSwitchUiState, copy: SwitchCopy) {
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.lg), verticalAlignment = Alignment.CenterVertically) {
        val shape = RoundedCornerShape(Radius.lg)
        Box(
            Modifier.size(86.dp).background(FausSwitchPalette.cardFill, shape).border(1.5.dp, FausSwitchPalette.lavender, shape),
            contentAlignment = Alignment.Center,
        ) { FausSwitchRobot(state.color, Modifier.size(64.dp)) }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(copy("faus_switch_kicker"), style = FausCrewType.caption.copy(fontWeight = FontWeight.Black, letterSpacing = 1.4.sp),
                color = FausSwitchPalette.accent)
            Text(copy("faus_switch_title"), style = FausCrewType.largeTitle.copy(fontWeight = FontWeight.Black),
                color = FausSwitchPalette.ink)
            val subtitle = when (state.selectedMode) {
                SwitchMode.DEMO -> "faus_switch_subtitle"
                SwitchMode.ONLINE -> "faus_switch_online_subtitle"
                null -> "faus_switch_mode_prompt"
            }
            Text(copy(subtitle), style = FausCrewType.subheadline, color = FausSwitchPalette.secondaryInk)
        }
    }
}

@Composable
private fun ModeCard(mode: SwitchMode, copy: SwitchCopy, onClick: () -> Unit) {
    val isDemo = mode == SwitchMode.DEMO
    Row(
        Modifier.fillMaxWidth().scaleButton(onClick = onClick).switchCard(),
        horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(54.dp).background(if (isDemo) FausSwitchPalette.lavender else FausSwitchPalette.wine,
                RoundedCornerShape(Radius.md)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(modeIcon(mode), null, Modifier.size(28.dp), tint = if (isDemo) FausSwitchPalette.plum else FausSwitchPalette.lightSand)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(copy(if (isDemo) "faus_switch_mode_demo" else "faus_switch_mode_online"), style = FausCrewType.headline,
                color = FausSwitchPalette.ink)
            Text(copy(if (isDemo) "faus_switch_mode_demo_detail" else "faus_switch_mode_online_detail"),
                style = FausCrewType.subheadline, color = FausSwitchPalette.secondaryInk)
        }
        Icon(Icons.Rounded.ChevronRight, null, Modifier.size(20.dp), tint = FausSwitchPalette.accent)
    }
}

private fun modeIcon(mode: SwitchMode): ImageVector = if (mode == SwitchMode.DEMO) Icons.Rounded.Memory else Icons.Rounded.Groups

@Composable
private fun ModeBar(mode: SwitchMode, copy: SwitchCopy, onChange: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(FausSwitchPalette.cardFill, CircleShape)
            .border(1.dp, FausSwitchPalette.panelStroke, CircleShape).padding(horizontal = Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(modeIcon(mode), null, Modifier.size(18.dp), tint = FausSwitchPalette.ink)
        Text(copy(if (mode == SwitchMode.DEMO) "faus_switch_mode_demo" else "faus_switch_mode_online"),
            style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = FausSwitchPalette.ink,
            modifier = Modifier.weight(1f))
        Box(Modifier.heightIn(min = 44.dp).scaleButton(onClick = onChange), contentAlignment = Alignment.Center) {
            Text(copy("faus_switch_mode_change"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                color = FausSwitchPalette.accent)
        }
    }
}

@Composable
private fun SectionTitle(key: String, copy: SwitchCopy, modifier: Modifier = Modifier) {
    Text(copy.upper(key), style = FausCrewType.caption.copy(fontWeight = FontWeight.Black, letterSpacing = 1.2.sp),
        color = FausSwitchPalette.accent, modifier = modifier.semantics { heading() })
}

/**
 * In the online room colors other players hold are taken, the selection is the color the
 * server gives this player, and a footnote explains the first-claim rule.
 */
@Composable
private fun ColorPicker(
    selected: SwitchColor?,
    copy: SwitchCopy,
    constants: SwitchConstants,
    taken: Set<SwitchColor> = emptySet(),
    showsPreferredTaken: Boolean = false,
    /** Online: the player is ready, so the color stays until they take the ready back. */
    isLocked: Boolean = false,
    footnoteKey: String? = null,
    onSelect: (SwitchColor) -> Unit,
) {
    Column(Modifier.fillMaxWidth().switchCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionTitle("faus_switch_color_title", copy)
        constants.colors.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                row.forEach { color ->
                    val isSelected = color == selected
                    val isTaken = color in taken
                    val shape = RoundedCornerShape(Radius.md)
                    val label = if (isTaken) copy(color.titleKey) + ", " + copy("faus_switch_color_taken") else copy(color.titleKey)
                    Column(
                        Modifier.weight(1f).heightIn(min = 74.dp)
                            .alpha(if (isTaken || (isLocked && !isSelected)) .5f else 1f).clip(shape)
                            .background(if (isSelected) FausSwitchPalette.lavender.copy(alpha = .6f)
                                else FausSwitchPalette.lightSand.copy(alpha = .75f), shape)
                            .border(if (isSelected) 2.dp else 1.dp,
                                if (isSelected) FausSwitchPalette.deepWine else FausSwitchPalette.panelStroke, shape)
                            .scaleButton(enabled = !isTaken && !isLocked, onClick = { onSelect(color) })
                            .clearAndSetSemantics {
                                this.selected = isSelected
                                role = Role.RadioButton
                                contentDescription = label
                                if (isTaken || isLocked) disabled()
                            }
                            .padding(vertical = Spacing.sm),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Box {
                            FausSwitchRobot(color, Modifier.size(44.dp))
                            if (isTaken) {
                                Box(
                                    Modifier.align(Alignment.TopEnd).offset(x = 6.dp, y = (-4).dp).size(18.dp)
                                        .background(FausSwitchPalette.deepWine, CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) { Icon(Icons.Rounded.Person, null, Modifier.size(11.dp), tint = FausSwitchPalette.lightSand) }
                            }
                        }
                        Text(copy(color.titleKey), style = FausCrewType.caption2.copy(fontWeight = FontWeight.SemiBold),
                            color = FausSwitchPalette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        if (isLocked) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Lock, null, Modifier.size(16.dp), tint = FausSwitchPalette.secondaryInk)
                Text(copy("faus_switch_online_color_locked"), style = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = FausSwitchPalette.secondaryInk)
            }
        } else if (showsPreferredTaken) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.People, null, Modifier.size(16.dp), tint = FausSwitchPalette.berry)
                Text(copy("faus_switch_online_color_taken"), style = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold),
                    color = FausSwitchPalette.berry)
            }
        }
        if (footnoteKey != null) {
            Text(copy(footnoteKey), style = FausCrewType.caption, color = FausSwitchPalette.secondaryInk)
        }
    }
}

@Composable
private fun DemoSetup(
    state: FausSwitchUiState,
    copy: SwitchCopy,
    constants: SwitchConstants,
    onSelectColor: (SwitchColor) -> Unit,
    onSelectBotCount: (Int) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        ColorPicker(state.color, copy, constants, onSelect = onSelectColor)
        Column(Modifier.fillMaxWidth().switchCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            SectionTitle("faus_switch_bots_title", copy)
            SegmentedCount(state.botRange, state.botCount, copy("faus_switch_bots_title"), onSelectBotCount)
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                RosterRow(copy("faus_switch_you"), state.color, trailing = null)
                constants.botColors(state.color, state.botCount).forEachIndexed { index, color ->
                    RosterRow(copy(constants.botNameKeys[index % constants.botNameKeys.size]), color,
                        trailing = copy("faus_switch_bot_role"))
                }
            }
            state.bestTime?.let { best ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.EmojiEvents, null, Modifier.size(18.dp), tint = FausSwitchPalette.green)
                    Text(copy.template("faus_switch_best_time", "time" to String.format(Locale.ROOT, "%.1f", best)),
                        style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = FausSwitchPalette.green)
                }
            }
        }
    }
}

/** SwiftUI's segmented `Picker` for the bot count. */
@Composable
private fun SegmentedCount(range: IntRange, selected: Int, label: String, onSelect: (Int) -> Unit) {
    val shape = RoundedCornerShape(Radius.sm)
    Row(
        Modifier.fillMaxWidth().background(FausSwitchPalette.sand.copy(alpha = .7f), shape).padding(2.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        for (count in range) {
            val isSelected = count == selected
            Box(
                Modifier.weight(1f).heightIn(min = 36.dp).clip(RoundedCornerShape(Radius.sm - 2.dp))
                    .background(if (isSelected) FausSwitchPalette.lightSand else Color.Transparent)
                    .scaleButton(role = Role.RadioButton, onClick = { onSelect(count) })
                    .semantics { this.selected = isSelected; contentDescription = "$label $count" },
                contentAlignment = Alignment.Center,
            ) {
                Text("$count", style = FausCrewType.subheadline.copy(fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium),
                    color = FausSwitchPalette.ink)
            }
        }
    }
}

@Composable
private fun RosterRow(name: String, color: SwitchColor?, trailing: String?, trailingIcon: ImageVector? = null,
                      highlightsTrailing: Boolean = false) {
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (color != null) {
            FausSwitchRobot(color, Modifier.size(28.dp))
        } else {
            Box(Modifier.size(28.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(22.dp).background(FausSwitchPalette.lavender.copy(alpha = .45f), CircleShape))
            }
        }
        Text(name, style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = FausSwitchPalette.ink,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        if (trailing != null) {
            val tint = if (highlightsTrailing) FausSwitchPalette.green else FausSwitchPalette.secondaryInk
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                if (trailingIcon != null) Icon(trailingIcon, null, Modifier.size(14.dp), tint = tint)
                Text(trailing, style = FausCrewType.caption.copy(fontWeight = FontWeight.Bold), color = tint)
            }
        }
    }
}

@Composable
private fun StartButton(copy: SwitchCopy, isLandscapeLayout: Boolean, isWaiting: Boolean, onStart: () -> Unit) {
    PrimarySwitchButton(enabled = !isWaiting, onClick = onStart) {
        if (isWaiting) {
            CircularProgressIndicator(Modifier.size(18.dp), color = FausSwitchPalette.lightSand, strokeWidth = 2.dp)
            Text(copy("faus_switch_rotating"), style = FausCrewType.headline, color = FausSwitchPalette.lightSand)
        } else {
            Icon(if (isLandscapeLayout) Icons.Rounded.SwapVert else Icons.Rounded.ScreenRotation, null, Modifier.size(20.dp),
                tint = FausSwitchPalette.lightSand)
            Text(copy(if (isLandscapeLayout) "faus_switch_start" else "faus_switch_start_landscape"), style = FausCrewType.headline,
                color = FausSwitchPalette.lightSand)
        }
    }
}

private fun onlineBlocker(state: FausSwitchUiState, userId: String?, houseId: String?): String? = when {
    userId.isNullOrEmpty() -> "faus_switch_online_sign_in"
    houseId == null -> "faus_switch_online_house_required"
    !state.onlineServiceAvailable -> "faus_switch_online_soon_detail"
    else -> null
}

/** The house room: why it cannot open, the house has it closed, or its status, colors and roster. */
@Composable
private fun OnlineRoom(
    state: FausSwitchUiState,
    copy: SwitchCopy,
    constants: SwitchConstants,
    userId: String?,
    houseId: String?,
    online: SwitchOnlineRoomUi,
    onSelectColor: (SwitchColor) -> Unit,
    onStartCardVisible: (Boolean) -> Unit,
) {
    val blocker = onlineBlocker(state, userId, houseId)
    when {
        blocker != null -> Notice("faus_switch_online_unavailable", blocker, Icons.Rounded.WifiOff, copy)
        state.catalogAvailable == false ->
            Notice("faus_switch_online_closed", "faus_switch_online_closed_detail", Icons.Rounded.Lock, copy)
        else -> Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
            val lobby = online.lobby ?: OnlineLobbyUi(statusKey = "faus_switch_online_connecting",
                detailKey = "faus_switch_online_connecting_detail")
            val colors = online.room.colors
            OnlineStatus(lobby, state.isOnlineRematchRoom, copy, online)
            StartCountdown(lobby, copy, online.uptime, onStartCardVisible)
            ColorPicker(colors.local ?: state.color, copy, constants, taken = colors.takenByOthers,
                showsPreferredTaken = colors.isPreferredTaken, isLocked = colors.isLocked,
                footnoteKey = "faus_switch_online_color_note", onSelect = onSelectColor)
            OnlineRoster(lobby, colors.local ?: state.color, copy, online,
                showsActions = online.lobby?.let { it.sessionState != null && it.isLobby && !it.isTerminal } == true)
        }
    }
}

/**
 * The ready window and the start countdown in large seconds, from the server's deadline (like
 * House Tanks' start card); before the window opens, what starts it.
 */
@Composable
private fun StartCountdown(lobby: OnlineLobbyUi, copy: SwitchCopy, uptime: () -> Double, onVisible: (Boolean) -> Unit) {
    val seconds = rememberSecondsUntil(lobby.deadlineUptime.takeIf { lobby.deadlineKind != null }, uptime)
    val shape = RoundedCornerShape(Radius.md)
    DisposableEffect(Unit) { onDispose { onVisible(true) } }
    Column(Modifier.fillMaxWidth().switchCard().reportsOnScreen(onChange = onVisible),
        verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionTitle("faus_switch_online_start_title", copy)
        Column(
            Modifier.fillMaxWidth().aspectRatio(872f / 400f).clip(shape)
                .background(FausSwitchPalette.lightSand.copy(alpha = .75f), shape)
                .drawBehind {
                    val dash = 4.dp.toPx()
                    drawRoundRect(FausSwitchPalette.panelStroke, cornerRadius = CornerRadius(Radius.md.toPx()),
                        style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(dash, dash))))
                }
                .padding(Spacing.md)
                .clearAndSetSemantics {
                    contentDescription = if (seconds != null) copy.template("faus_switch_online_seconds", "seconds" to "$seconds")
                    else copy("faus_switch_online_start_waiting")
                },
            verticalArrangement = Arrangement.spacedBy(Spacing.xs, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (seconds != null) {
                Text(copy("faus_switch_online_start_until"),
                    style = FausCrewType.caption.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = 1.4.sp),
                    color = FausSwitchPalette.secondaryInk)
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                    Text("$seconds", style = FausCrewType.largeTitle.copy(fontSize = 88.sp, lineHeight = 92.sp,
                        fontWeight = FontWeight.Black, fontFeatureSettings = "tnum"),
                        color = if (seconds <= 5) FausSwitchPalette.danger else FausSwitchPalette.ink)
                    Text(copy("faus_switch_online_seconds_unit"), style = FausCrewType.title3.copy(fontWeight = FontWeight.ExtraBold),
                        color = FausSwitchPalette.secondaryInk, modifier = Modifier.padding(bottom = 14.dp))
                }
            } else {
                Icon(Icons.Rounded.HourglassTop, null, Modifier.size(40.dp), tint = FausSwitchPalette.accent)
                Text(copy("faus_switch_online_start_waiting"), style = FausCrewType.headline, color = FausSwitchPalette.ink)
                Text(copy.template("faus_switch_online_start_waiting_detail", "minimum" to "${lobby.minimumPlayers}"),
                    style = FausCrewType.caption, color = FausSwitchPalette.secondaryInk, textAlign = TextAlign.Center)
            }
            if (lobby.sessionState != null) {
                Text(copy.template("faus_switch_online_ready_count", "ready" to "${lobby.readyCount}",
                    "total" to "${lobby.participants.size}"),
                    style = FausCrewType.caption.copy(fontWeight = FontWeight.ExtraBold), color = FausSwitchPalette.plum)
            }
        }
    }
}

@Composable
private fun OnlineStatus(lobby: OnlineLobbyUi, isRematchRoom: Boolean, copy: SwitchCopy, online: SwitchOnlineRoomUi) {
    val warns = lobby.requiresUpdate || lobby.isFailed
    Column(Modifier.fillMaxWidth().switchCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(Modifier.size(28.dp), contentAlignment = Alignment.Center) {
                if (lobby.showsProgress) {
                    CircularProgressIndicator(Modifier.size(22.dp), color = FausSwitchPalette.wine, strokeWidth = 2.5.dp)
                } else {
                    Icon(if (warns) Icons.Rounded.WifiOff else Icons.Rounded.Sensors, null, Modifier.size(24.dp),
                        tint = if (warns) FausSwitchPalette.danger else FausSwitchPalette.green)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text(copy(if (isRematchRoom) "faus_switch_online_rematch_room" else lobby.statusKey), style = FausCrewType.headline,
                    color = if (warns) FausSwitchPalette.danger else FausSwitchPalette.ink)
                Text(copy.template(lobby.detailKey, "minimum" to "${lobby.minimumPlayers}"), style = FausCrewType.subheadline,
                    color = FausSwitchPalette.secondaryInk)
                val issue = lobby.issueKey
                if (lobby.isConnected && issue != null) {
                    Text(copy(issue), style = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold),
                        color = FausSwitchPalette.danger)
                }
            }
        }
        if (lobby.isFailed && lobby.canRetry) {
            val shape = RoundedCornerShape(Radius.sm)
            Row(
                Modifier.heightIn(min = 44.dp).clip(shape).background(FausSwitchPalette.wine, shape)
                    .scaleButton(onClick = online.onRetry).padding(horizontal = Spacing.lg),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Refresh, null, Modifier.size(18.dp), tint = FausSwitchPalette.lightSand)
                Text(copy("faus_switch_online_retry"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold),
                    color = FausSwitchPalette.lightSand)
            }
        }
    }
}

/** The room's players, then (in the lobby) the ready and cancel buttons at the card's foot. */
@Composable
private fun OnlineRoster(
    lobby: OnlineLobbyUi,
    localColor: SwitchColor,
    copy: SwitchCopy,
    online: SwitchOnlineRoomUi,
    showsActions: Boolean,
) {
    val members = online.members
    val players = lobby.participants.sortedBy { if (it.isLocal) 0 else 1 }
    Column(Modifier.fillMaxWidth().switchCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionTitle("faus_switch_online_roster", copy, Modifier.weight(1f))
            if (lobby.sessionState != null) {
                Text(copy.template("faus_switch_online_ready_count", "ready" to "${lobby.readyCount}",
                    "total" to "${lobby.participants.size}"),
                    style = FausCrewType.caption.copy(fontWeight = FontWeight.ExtraBold), color = FausSwitchPalette.secondaryInk)
            }
        }
        if (players.isEmpty()) {
            Text(copy("faus_switch_online_syncing"), style = FausCrewType.subheadline, color = FausSwitchPalette.secondaryInk)
        }
        players.forEach { player ->
            val name = (members[player.playerId] ?: copy("faus_switch_online_player")) +
                if (player.isLocal) " · " + copy("faus_switch_you") else ""
            RosterRow(name, if (player.isLocal) localColor else SwitchColor.from(player.color), copy(player.statusKey),
                trailingIcon = if (player.isReady) Icons.Rounded.Verified else Icons.Rounded.AccessTime,
                highlightsTrailing = player.isReady)
        }
        if (showsActions) OnlineActions(lobby, copy, online)
    }
}

@Composable
private fun OnlineActions(lobby: OnlineLobbyUi, copy: SwitchCopy, online: SwitchOnlineRoomUi) {
    val isReady = lobby.localReady
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm), horizontalAlignment = Alignment.CenterHorizontally) {
        PrimarySwitchButton(
            Modifier.alpha(if (lobby.canChangeReady) 1f else .5f),
            fill = if (isReady) FausSwitchPalette.plum else FausSwitchPalette.wine,
            enabled = lobby.canChangeReady,
            onClick = { online.onReady(!isReady) },
        ) {
            Icon(if (isReady) Icons.Rounded.HighlightOff else Icons.Rounded.CheckCircle, null, Modifier.size(20.dp),
                tint = FausSwitchPalette.lightSand)
            Text(copy(if (isReady) "faus_switch_online_not_ready" else "faus_switch_online_ready"), style = FausCrewType.headline,
                color = FausSwitchPalette.lightSand)
        }
        if (lobby.canCancel) {
            Box(Modifier.heightIn(min = 44.dp).scaleButton(onClick = online.onCancel), contentAlignment = Alignment.Center) {
                Text(copy("faus_switch_online_cancel"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                    color = FausSwitchPalette.danger)
            }
        }
    }
}

@Composable
private fun Notice(title: String, detail: String, icon: ImageVector, copy: SwitchCopy) {
    Column(Modifier.fillMaxWidth().switchCard().semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, Modifier.size(20.dp), tint = FausSwitchPalette.ink)
            Text(copy(title), style = FausCrewType.headline, color = FausSwitchPalette.ink)
        }
        Text(copy(detail), style = FausCrewType.subheadline, color = FausSwitchPalette.secondaryInk)
    }
}

/** Each rule is a tiny looping clip with a few words under it; the full sentence is kept for TalkBack. */
@Composable
private fun Rules(color: SwitchColor, copy: SwitchCopy, reduceMotion: Boolean) {
    val rules = listOf(
        Triple(SwitchRuleClip.TAP, "faus_switch_rule_tap_title", "faus_switch_rule_tap_detail"),
        Triple(SwitchRuleClip.SOLID, "faus_switch_rule_solid_title", "faus_switch_rule_solid_detail"),
        Triple(SwitchRuleClip.ROBOTS, "faus_switch_rule_robots_title", "faus_switch_rule_robots_detail"),
        Triple(SwitchRuleClip.GAP, "faus_switch_rule_gap_title", "faus_switch_rule_gap_detail"),
        Triple(SwitchRuleClip.BOOST, "faus_switch_rule_boost_title", "faus_switch_rule_boost_detail"),
        Triple(SwitchRuleClip.SLOW, "faus_switch_rule_slow_title", "faus_switch_rule_slow_detail"),
        Triple(SwitchRuleClip.PORTAL, "faus_switch_rule_portal_title", "faus_switch_rule_portal_detail"),
    )
    Column(Modifier.fillMaxWidth().switchCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        SectionTitle("faus_switch_rules_title", copy)
        rules.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                row.forEach { (clip, title, detail) ->
                    Column(
                        Modifier.weight(1f).clearAndSetSemantics { contentDescription = "${copy(title)}. ${copy(detail)}" },
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        FausSwitchRuleClipView(clip, color, reduceMotion)
                        Text(copy(title), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold),
                            color = FausSwitchPalette.ink, maxLines = 2)
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun BottomBar(content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxWidth().background(FausSwitchPalette.lightSand.copy(alpha = .96f)).navigationBarsPadding(),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(FausSwitchPalette.wine.copy(alpha = .2f)).align(Alignment.TopCenter))
        Box(Modifier.widthIn(max = 620.dp).fillMaxWidth().padding(horizontal = Spacing.xl, vertical = Spacing.lg)) { content() }
    }
}

/** The sand panel every Faus Switch section sits on (light sand fading to sand). */
internal fun Modifier.switchCard(): Modifier {
    val shape = RoundedCornerShape(Radius.lg)
    return background(FausSwitchPalette.cardFill, shape).border(1.dp, FausSwitchPalette.panelStroke, shape).padding(Spacing.lg)
}

@Composable
internal fun PrimarySwitchButton(
    modifier: Modifier = Modifier,
    fill: Color = FausSwitchPalette.wine,
    height: androidx.compose.ui.unit.Dp = ButtonHeightLarge,
    enabled: Boolean = true,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.md)
    Row(
        modifier.fillMaxWidth().heightIn(min = height).clip(shape).background(fill, shape)
            .scaleButton(enabled = enabled, onClick = onClick).padding(horizontal = Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) { content() }
}
