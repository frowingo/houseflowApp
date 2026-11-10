package com.fauscrew.ui.games.fausswitch

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.HighlightOff
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.MusicOff
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.SportsScore
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchDemoOutcome
import com.fauscrew.platform.SwitchMatchUi
import com.fauscrew.platform.SwitchOnlineMatch
import com.fauscrew.platform.SwitchOnlineResult
import com.fauscrew.platform.SwitchNameTag
import com.fauscrew.platform.SwitchPhase
import com.fauscrew.platform.SwitchRunnerStatus
import com.fauscrew.platform.SwitchStanding
import com.fauscrew.platform.SwitchWorld
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.games.tanks.rememberSecondsUntil
import com.fauscrew.ui.theme.scaleButton
import com.fauscrew.viewmodel.FausSwitchUiState
import kotlinx.coroutines.delay
import java.util.Locale

/** What the race's buttons do; the screen wires them to the view model and orientation. */
internal class SwitchRaceActions(
    val onFrame: (Long) -> Unit,
    val onFlip: () -> Unit,
    val onPause: () -> Unit,
    val onResume: () -> Unit,
    val onRestart: () -> Unit,
    val onWatch: () -> Unit,
    val onChangeSetup: () -> Unit,
    val onExit: () -> Unit,
    val onToggleMusic: () -> Unit,
    val onToggleSound: () -> Unit,
)

/** The online race's panels and what their buttons do. */
internal class SwitchOnlineRaceUi(
    val match: SwitchOnlineMatch?,
    /** House members' names by user id, for the winner when the server sent none. */
    val members: Map<String, String>,
    val onLeave: () -> Unit,
    /** Play Again: the room's next session, readied in place; the race starts from its countdown. */
    val onPlayAgain: () -> Unit,
    /** Back to Lobby: the portrait online room. */
    val onBackToLobby: () -> Unit,
    val onRetry: () -> Unit,
    val onRetryResult: () -> Unit,
    val onReclaim: () -> Unit,
    /** Play Again's room over the finished race, until the next race's first snapshot. */
    val replay: SwitchReplayRoomUi? = null,
)

/** The next session's room as Play Again shows it over the arena. */
internal class SwitchReplayRoomUi(
    val lobby: OnlineLobbyUi?,
    val localColor: SwitchColor,
    val uptime: () -> Double,
    val onReady: (Boolean) -> Unit,
    val onRetry: () -> Unit,
)

/**
 * `FausSwitchView.raceLayer`: the scene canvas, the playfield tap, the name tags, the HUD
 * and the countdown, then the demo's pause and result panels or the online notice,
 * spectating card and result. One Core step (or online presentation) per display frame.
 */
@Composable
internal fun FausSwitchGameLayer(
    frameState: State<SwitchWorld?>,
    match: SwitchMatchUi?,
    state: FausSwitchUiState,
    copy: SwitchCopy,
    renderer: FausSwitchCourseRenderer,
    reduceMotion: Boolean,
    isForeground: Boolean,
    actions: SwitchRaceActions,
    online: SwitchOnlineRaceUi? = null,
) {
    var showsTapHint by remember { mutableStateOf(true) }
    var confirmsLeave by remember { mutableStateOf(false) }
    val isOnline = state.isOnlineMatchVisible && online != null
    val replay = online?.replay?.takeIf { isOnline }
    // Online the server's result and notices arrive through frames even after the race ends.
    val isRunning = isOnline || (state.isDemoVisible && !state.isPaused && match?.phase != SwitchPhase.ENDED)
    // Back asks before leaving a running race; on the result it goes back to the modes.
    BackHandler(enabled = isOnline) {
        when {
            replay != null -> online?.onBackToLobby?.invoke()
            match?.showsResult == true -> online?.onLeave?.invoke()
            else -> confirmsLeave = true
        }
    }
    LaunchedEffect(isForeground, isRunning) {
        if (!isForeground || !isRunning) return@LaunchedEffect
        while (true) withFrameNanos(actions.onFrame)
    }

    Box(Modifier.fillMaxSize()) {
        SwitchSceneCanvas(frameState, renderer, reduceMotion)
        Box(
            Modifier.fillMaxSize()
                .pointerInput(Unit) {
                    awaitEachGesture {
                        awaitFirstDown(requireUnconsumed = false)
                        actions.onFlip()
                        waitForUpOrCancellation()
                    }
                }
                .semantics {
                    role = Role.Button
                    contentDescription = "${copy("faus_switch_playfield_accessibility")}. ${copy("faus_switch_playfield_hint")}"
                    onClick { actions.onFlip(); true }
                },
        )
        if (replay != null && online != null) {
            match?.let { Hud(it, state, copy, showsTapHint = false, actions, onClose = {}, hidesClose = true) }
            ReplayRoomPanel(replay, online, copy)
            return@Box
        }
        if (match == null) return@Box
        if (match.nameTags.isNotEmpty()) NameTags(match.nameTags, copy)
        Hud(match, state, copy, showsTapHint, actions, onClose = if (isOnline) ({ confirmsLeave = true }) else null,
            hidesClose = match.showsResult)
        LaunchedEffect(match.phase == SwitchPhase.PLAYING && match.canFlip, showsTapHint) {
            if (match.phase == SwitchPhase.PLAYING && match.canFlip && showsTapHint) {
                delay(3_500)
                showsTapHint = false
            }
        }
        if (match.phase == SwitchPhase.COUNTDOWN) match.countdown?.let { Countdown(it, copy) }
        if (isOnline) {
            OnlineOverlays(match, online, copy, onLeave = { confirmsLeave = false; online.onLeave() })
            return@Box
        }
        when {
            state.isPaused -> Panel(
                info = {
                    PanelHeader(Icons.Rounded.Pause, FausSwitchPalette.wine, copy("faus_switch_paused"), copy("faus_switch_paused_detail"))
                },
                actions = { focus ->
                    PanelButton(copy("faus_switch_resume"), Icons.Rounded.PlayArrow, focus, onClick = actions.onResume)
                    SecondaryButton(copy("faus_switch_restart")) { showsTapHint = true; actions.onRestart() }
                    SecondaryButton(copy("faus_switch_change_setup"), actions.onChangeSetup)
                },
            )
            state.showsDemoResult -> Panel(
                info = {
                    DemoResultHeader(match, copy)
                    StandingsTable(match.standings, copy)
                },
                actions = { focus ->
                    PanelButton(copy("faus_switch_restart"), Icons.Rounded.Refresh, focus) { showsTapHint = true; actions.onRestart() }
                    if (match.phase != SwitchPhase.ENDED) SecondaryButton(copy("faus_switch_watch"), actions.onWatch)
                    SecondaryButton(copy("faus_switch_change_setup"), actions.onChangeSetup)
                    SecondaryButton(copy("faus_switch_exit"), actions.onExit)
                },
            )
        }
    }

    if (confirmsLeave && isOnline) {
        AlertDialog(
            onDismissRequest = { confirmsLeave = false },
            title = { Text(copy("faus_switch_online_leave_title")) },
            text = { Text(copy("faus_switch_online_leave_detail")) },
            confirmButton = {
                TextButton(onClick = { confirmsLeave = false; online.onLeave() }) {
                    Text(copy("faus_switch_online_leave"), color = FausSwitchPalette.danger)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmsLeave = false }) { Text(stringResource(android.R.string.cancel)) }
            },
        )
    }
}

/** The result panel, else a connection notice at the top, else the spectating card after a crash. */
@Composable
private fun OnlineOverlays(match: SwitchMatchUi, online: SwitchOnlineRaceUi, copy: SwitchCopy, onLeave: () -> Unit) {
    val result = online.match?.result
    val noticeTitle = match.noticeTitleKey
    val noticeDetail = match.noticeDetailKey
    when {
        match.showsResult && result != null -> OnlineResultPanel(result, online, copy, onLeave)
        noticeTitle != null && noticeDetail != null -> Box(
            Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).padding(top = 64.dp, start = Spacing.lg, end = Spacing.lg),
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(Modifier.widthIn(max = 420.dp).fillMaxWidth().switchCard(), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    verticalAlignment = Alignment.CenterVertically) {
                    Icon(if (match.noticeIsBlocking) Icons.Rounded.WifiOff else Icons.Rounded.Sync, null, Modifier.size(20.dp),
                        tint = FausSwitchPalette.ink)
                    Text(copy(noticeTitle), style = FausCrewType.headline, color = FausSwitchPalette.ink)
                }
                Text(copy(noticeDetail), style = FausCrewType.subheadline, color = FausSwitchPalette.secondaryInk)
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    if (match.canRetry) SmallButton(copy("faus_switch_online_retry"), online.onRetry)
                    if (match.canReclaim) SmallButton(copy("faus_switch_online_reclaim"), online.onReclaim)
                    if (match.noticeIsBlocking) SmallButton(copy("faus_switch_online_leave"), onLeave)
                }
            }
        }
        match.localStatus == SwitchRunnerStatus.CRASHED -> Box(
            Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).padding(bottom = Spacing.lg),
            contentAlignment = Alignment.BottomCenter,
        ) {
            Row(Modifier.switchCard(), horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                    verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Visibility, null, Modifier.size(22.dp), tint = FausSwitchPalette.berry)
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(copy(crashReasonKey(match.localCrashReason)),
                            style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = FausSwitchPalette.ink)
                        Text(copy("faus_switch_online_spectating"), style = FausCrewType.caption, color = FausSwitchPalette.secondaryInk)
                    }
                }
                SmallButton(copy("faus_switch_online_leave"), onLeave)
            }
        }
    }
}

@Composable
private fun OnlineResultPanel(result: SwitchOnlineResult, online: SwitchOnlineRaceUi, copy: SwitchCopy, onLeave: () -> Unit) {
    val title = if (result.titleKey == "faus_switch_online_lost") {
        copy.template(result.titleKey, "name" to (result.winnerName ?: result.winnerId?.let(online.members::get)
            ?: copy("faus_switch_online_player")))
    } else {
        copy(result.titleKey)
    }
    Panel(
        info = {
            PanelHeader(if (result.isWaiting) Icons.Rounded.HourglassTop else Icons.Rounded.Flag,
                if (result.isFailed) FausSwitchPalette.berry else FausSwitchPalette.green, title, copy(result.detailKey))
            if (result.isWaiting) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(Modifier.size(24.dp), color = FausSwitchPalette.wine, strokeWidth = 2.5.dp)
                }
            }
            StandingsTable(result.standings, copy)
        },
        actions = { focus ->
            if (result.canRematch) {
                PanelButton(copy("faus_switch_online_play_again"), Icons.Rounded.Refresh, focus, onClick = online.onPlayAgain)
                SecondaryButton(copy("faus_switch_online_back_to_lobby"), online.onBackToLobby)
            } else {
                if (result.isFailed && result.canRetry) {
                    PanelButton(copy("faus_switch_online_retry"), Icons.Rounded.Refresh, focus, onClick = online.onRetryResult)
                }
                SecondaryButton(copy("faus_switch_online_back_to_modes"), onLeave)
            }
        },
    )
}

/**
 * Play Again's room over the finished race: the local player is readied after the color;
 * once the room is ready (or its ready window ends) the server counts the new race down
 * from 3 and it starts right here. Back to Lobby goes to the portrait room instead.
 */
@Composable
private fun ReplayRoomPanel(replay: SwitchReplayRoomUi, online: SwitchOnlineRaceUi, copy: SwitchCopy) {
    val lobby = replay.lobby ?: OnlineLobbyUi(statusKey = "faus_switch_online_connecting",
        detailKey = "faus_switch_online_connecting_detail")
    val inRoom = lobby.isLobby && lobby.isConnected && lobby.isSynced
    val detailKey = when {
        !inRoom -> lobby.detailKey
        lobby.localReady -> "faus_switch_online_replay_detail"
        else -> "faus_switch_online_replay_not_ready"
    }
    val seconds = rememberSecondsUntil(lobby.deadlineUptime.takeIf { lobby.deadlineKind != null }, replay.uptime)
    val players = lobby.participants.sortedBy { if (it.isLocal) 0 else 1 }
    Panel(
        info = {
            PanelHeader(Icons.Rounded.Refresh, FausSwitchPalette.wine, copy("faus_switch_online_replay_title"),
                copy.template(detailKey, "minimum" to "${lobby.minimumPlayers}"))
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalAlignment = Alignment.CenterVertically) {
                Text(copy(lobby.statusKey), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold),
                    color = if (lobby.isFailed) FausSwitchPalette.danger else FausSwitchPalette.ink,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                if (seconds != null) {
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Timer, null, Modifier.size(14.dp), tint = FausSwitchPalette.ink)
                        Text(copy.template("faus_switch_online_seconds", "seconds" to "$seconds"),
                            style = FausCrewType.caption.copy(fontWeight = FontWeight.ExtraBold, fontFeatureSettings = "tnum"),
                            color = FausSwitchPalette.ink)
                    }
                }
                if (lobby.sessionState != null) {
                    Text(copy.template("faus_switch_online_ready_count", "ready" to "${lobby.readyCount}",
                        "total" to "${lobby.participants.size}"),
                        style = FausCrewType.caption.copy(fontWeight = FontWeight.ExtraBold), color = FausSwitchPalette.secondaryInk)
                }
            }
            val columns = if (players.size > 4) 2 else 1
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                players.chunked(columns).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        row.forEach { player ->
                            ReplayRosterRow(
                                name = if (player.isLocal) copy("faus_switch_you")
                                    else online.members[player.playerId] ?: copy("faus_switch_online_player"),
                                color = if (player.isLocal) replay.localColor else SwitchColor.from(player.color),
                                isLocal = player.isLocal, isReady = player.isReady, status = copy(player.statusKey),
                                modifier = Modifier.weight(1f),
                            )
                        }
                        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        },
        actions = { focus ->
            if (lobby.isFailed && lobby.canRetry) {
                PanelButton(copy("faus_switch_online_retry"), Icons.Rounded.Refresh, focus, onClick = replay.onRetry)
            } else {
                PanelButton(copy(if (lobby.localReady) "faus_switch_online_not_ready" else "faus_switch_online_ready"),
                    if (lobby.localReady) Icons.Rounded.HighlightOff else Icons.Rounded.CheckCircle, focus,
                    onClick = { replay.onReady(!lobby.localReady) }, enabled = lobby.canChangeReady)
            }
            if (!lobby.isLeaving) SecondaryButton(copy("faus_switch_online_back_to_lobby"), online.onBackToLobby)
        },
    )
}

@Composable
private fun ReplayRosterRow(name: String, color: SwitchColor?, isLocal: Boolean, isReady: Boolean, status: String,
                            modifier: Modifier) {
    Row(
        modifier.heightIn(min = 32.dp)
            .background(if (isLocal) FausSwitchPalette.lavender.copy(alpha = .55f) else FausSwitchPalette.lightSand.copy(alpha = .8f),
                RoundedCornerShape(Radius.sm))
            .padding(horizontal = Spacing.sm)
            .semantics(mergeDescendants = true) { contentDescription = "$name, $status" },
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FausSwitchRobot(color ?: SwitchColor.OCEAN, Modifier.size(22.dp))
        Text(name, style = FausCrewType.subheadline.copy(fontWeight = if (isLocal) FontWeight.Bold else FontWeight.SemiBold),
            color = FausSwitchPalette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Icon(if (isReady) Icons.Rounded.Verified else Icons.Rounded.AccessTime, null, Modifier.size(16.dp),
            tint = if (isReady) FausSwitchPalette.green else FausSwitchPalette.secondaryInk)
    }
}

/** `FausSwitchOnlineCopyKeys.crashReason`. */
private fun crashReasonKey(reason: String?): String = when (reason) {
    "leftBehind" -> "faus_switch_crashed_left_behind"
    "forfeit", "membershipRevoked" -> "faus_switch_crashed_forfeit"
    else -> "faus_switch_crashed_boundary"
}

@Composable
private fun SmallButton(title: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.sm)
    Box(
        Modifier.heightIn(min = 40.dp).clip(shape).background(FausSwitchPalette.wine, shape).scaleButton(onClick = onClick)
            .padding(horizontal = Spacing.md),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = FausSwitchPalette.lightSand,
            maxLines = 1)
    }
}

/** SpriteKit's scene: the backdrop in screen space, then the course in its y-up space. */
@Composable
private fun SwitchSceneCanvas(frameState: State<SwitchWorld?>, renderer: FausSwitchCourseRenderer, reduceMotion: Boolean) {
    Box(
        Modifier.fillMaxSize().drawBehind {
            val world = frameState.value
            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                val width = size.width / density
                val height = size.height / density
                native.save()
                native.scale(density, density)
                renderer.drawBackdrop(native, world, width, height, reduceMotion)
                if (world != null) {
                    native.translate(0f, height)
                    native.scale(1f, -1f)
                    renderer.draw(native, world, reduceMotion)
                }
                native.restore()
            }
        },
    )
}

/** Each robot's player name beside it on its start platform, until the run starts. */
@Composable
private fun NameTags(tags: List<SwitchNameTag>, copy: SwitchCopy) {
    BoxWithConstraints(Modifier.fillMaxSize().clearAndSetSemantics {}) {
        val height = maxHeight
        val hex = switchColorHex()
        for (tag in tags) {
            val tagHeight = 22.dp
            Box(Modifier.offset(tag.x.toFloat().dp, height - tag.y.toFloat().dp - tagHeight / 2).width(150.dp)) {
                Text(
                    name(tag.isLocal, tag.nameKey, tag.displayName, copy),
                    style = FausCrewType.caption.copy(fontWeight = FontWeight.Black),
                    color = if (tag.isLocal) FausSwitchPalette.ink else FausSwitchPalette.mint,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.heightIn(min = tagHeight)
                        .background(if (tag.isLocal) FausSwitchPalette.lavender else tag.color.tone(hex).copy(alpha = .92f),
                            CircleShape)
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
        }
    }
}

/** [onClose] is the online race's leave button (confirmed first); the demo has pause instead. */
@Composable
private fun Hud(
    match: SwitchMatchUi,
    state: FausSwitchUiState,
    copy: SwitchCopy,
    showsTapHint: Boolean,
    actions: SwitchRaceActions,
    onClose: (() -> Unit)?,
    hidesClose: Boolean,
) {
    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = Spacing.lg).padding(top = Spacing.sm),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            if (onClose != null) {
                Box(Modifier.alpha(if (hidesClose) 0f else 1f)) {
                    HudButton(Icons.Rounded.Close, copy("faus_switch_online_leave"), enabled = !hidesClose, onClick = onClose)
                }
            } else {
                val canPause = match.phase != SwitchPhase.ENDED && !state.showsDemoResult
                HudButton(Icons.Rounded.Pause, copy("faus_switch_pause"), enabled = canPause, onClick = actions.onPause)
            }
            Spacer(Modifier.weight(1f))
            HudButton(if (state.isMusicEnabled) Icons.Rounded.MusicNote else Icons.Rounded.MusicOff,
                copy(if (state.isMusicEnabled) "faus_switch_music_off" else "faus_switch_music_on"), onClick = actions.onToggleMusic)
            HudButton(if (state.isSoundEnabled) Icons.AutoMirrored.Rounded.VolumeUp else Icons.AutoMirrored.Rounded.VolumeOff,
                copy(if (state.isSoundEnabled) "faus_switch_sound_off" else "faus_switch_sound_on"), onClick = actions.onToggleSound)
        }
        Spacer(Modifier.weight(1f))
        AnimatedVisibility(match.phase == SwitchPhase.PLAYING && match.canFlip && showsTapHint,
            Modifier.align(Alignment.CenterHorizontally), enter = fadeIn(), exit = fadeOut()) {
            Row(
                Modifier.padding(bottom = Spacing.xl).heightIn(min = 40.dp).background(FausSwitchPalette.panel, CircleShape)
                    .padding(horizontal = Spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Rounded.TouchApp, null, Modifier.size(18.dp), tint = FausSwitchPalette.ink)
                Text(copy("faus_switch_tap_hint"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                    color = FausSwitchPalette.ink)
            }
        }
    }
}

@Composable
private fun HudButton(icon: ImageVector, label: String, enabled: Boolean = true, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.md)
    Box(
        Modifier.size(44.dp).alpha(if (enabled) 1f else .5f).clip(shape).background(FausSwitchPalette.deepWine.copy(alpha = .92f), shape)
            .scaleButton(enabled = enabled, onClick = onClick).semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, Modifier.size(22.dp), tint = FausSwitchPalette.lightSand) }
}

/** Off to the right, so the robots and their name tags on the start line stay visible. */
@Composable
private fun Countdown(value: Int, copy: SwitchCopy) {
    Box(Modifier.fillMaxSize().padding(end = 56.dp), contentAlignment = Alignment.CenterEnd) {
        Box(
            Modifier.size(150.dp).background(FausSwitchPalette.plum.copy(alpha = .82f), CircleShape)
                .clearAndSetSemantics { contentDescription = copy.template("faus_switch_online_seconds", "seconds" to "$value") },
            contentAlignment = Alignment.Center,
        ) {
            Text("$value", style = TextStyle(fontSize = 92.sp, fontWeight = FontWeight.Black), color = FausSwitchPalette.lightSand)
        }
    }
}

@Composable
private fun DemoResultHeader(match: SwitchMatchUi, copy: SwitchCopy) {
    val (icon, tint) = when (match.demoOutcome) {
        SwitchDemoOutcome.WON, SwitchDemoOutcome.FINISHED -> Icons.Rounded.SportsScore to FausSwitchPalette.green
        SwitchDemoOutcome.CRASHED -> Icons.Rounded.Warning to FausSwitchPalette.berry
        SwitchDemoOutcome.TIME_UP -> Icons.Rounded.Timer to FausSwitchPalette.deepWine
    }
    PanelHeader(icon, tint, copy(match.demoTitleKey), copy.template(match.demoDetailKey,
        "rank" to "${match.localRank ?: 0}", "time" to String.format(Locale.ROOT, "%.1f", match.localTime ?: 0.0)))
}

/**
 * A race panel laid out for the landscape screen: what happened on the left, every action on
 * the right, so the panel fits the screen height; very large text scrolls instead.
 */
@Composable
private fun Panel(info: @Composable () -> Unit, actions: @Composable (FocusRequester) -> Unit) {
    val focus = remember { FocusRequester() }
    Box(
        Modifier.fillMaxSize().background(FausSwitchPalette.plum.copy(alpha = .38f))
            .pointerInput(Unit) { awaitEachGesture { awaitFirstDown(); waitForUpOrCancellation() } },
        contentAlignment = Alignment.Center,
    ) {
        val shape = RoundedCornerShape(Radius.xl)
        Row(
            Modifier.windowInsetsPadding(WindowInsets.safeDrawing).verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
                .widthIn(max = 660.dp).fillMaxWidth()
                .background(FausSwitchPalette.cardFill, shape).border(1.dp, FausSwitchPalette.wine.copy(alpha = .3f), shape)
                .padding(Spacing.lg),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xl),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.md)) { info() }
            Column(Modifier.width(210.dp), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) { actions(focus) }
        }
    }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }
}

@Composable
private fun PanelHeader(icon: ImageVector, tint: Color, title: String, detail: String) {
    Row(Modifier.semantics(mergeDescendants = true) {}, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Box(Modifier.size(44.dp).background(tint, RoundedCornerShape(Radius.md)), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(24.dp), tint = FausSwitchPalette.lightSand)
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(title, style = FausCrewType.title3.copy(fontWeight = FontWeight.Black), color = FausSwitchPalette.ink)
            Text(detail, style = FausCrewType.subheadline, color = FausSwitchPalette.secondaryInk)
        }
    }
}

/** Up to four robots in one column; more in two, so eight robots take four rows. */
@Composable
private fun StandingsTable(standings: List<SwitchStanding>, copy: SwitchCopy) {
    val columns = if (standings.size > 4) 2 else 1
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        standings.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { StandingRow(it, copy, Modifier.weight(1f)) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun StandingRow(standing: SwitchStanding, copy: SwitchCopy, modifier: Modifier) {
    val digits = FausCrewType.subheadline.copy(fontWeight = FontWeight.Black, fontFeatureSettings = "tnum")
    Row(
        modifier.heightIn(min = 32.dp)
            .background(if (standing.isLocal) FausSwitchPalette.lavender.copy(alpha = .55f) else FausSwitchPalette.lightSand.copy(alpha = .8f),
                RoundedCornerShape(Radius.sm))
            .padding(horizontal = Spacing.sm)
            .semantics(mergeDescendants = true) {},
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(standing.rank?.let { "$it." } ?: "–", style = digits, color = FausSwitchPalette.ink, modifier = Modifier.width(24.dp))
        FausSwitchRobot(standing.color, Modifier.size(22.dp))
        Text(name(standing.isLocal, standing.nameKey, standing.displayName, copy),
            style = FausCrewType.subheadline.copy(fontWeight = if (standing.isLocal) FontWeight.Bold else FontWeight.SemiBold),
            color = FausSwitchPalette.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        val status = if (standing.status == SwitchRunnerStatus.FINISHED && standing.time != null) {
            String.format(Locale.ROOT, "%.1fs", standing.time)
        } else {
            copy(standing.statusKey)
        }
        Text(status, style = FausCrewType.caption.copy(fontWeight = FontWeight.Bold, fontFeatureSettings = "tnum"),
            color = if (standing.isOut) FausSwitchPalette.berry else FausSwitchPalette.green, maxLines = 1)
    }
}

@Composable
private fun PanelButton(title: String, icon: ImageVector, focus: FocusRequester, enabled: Boolean = true, onClick: () -> Unit) {
    PrimarySwitchButton(Modifier.focusRequester(focus).alpha(if (enabled) 1f else .5f), height = 48.dp, enabled = enabled,
        onClick = onClick) {
        Icon(icon, null, Modifier.size(18.dp), tint = FausSwitchPalette.lightSand)
        Text(title, style = FausCrewType.headline, color = FausSwitchPalette.lightSand, maxLines = 1)
    }
}

@Composable
private fun SecondaryButton(title: String, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().heightIn(min = 44.dp).scaleButton(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(title, style = FausCrewType.body.copy(fontWeight = FontWeight.SemiBold), color = FausSwitchPalette.accent, maxLines = 1)
    }
}

private fun name(isLocal: Boolean, nameKey: String?, displayName: String?, copy: SwitchCopy): String = when {
    isLocal -> copy("faus_switch_you")
    nameKey != null -> copy(nameKey)
    else -> displayName ?: copy("faus_switch_online_player")
}

@Composable
private fun switchColorHex() = remember { com.fauscrew.platform.FausSwitchNative.constants.colorHex }
