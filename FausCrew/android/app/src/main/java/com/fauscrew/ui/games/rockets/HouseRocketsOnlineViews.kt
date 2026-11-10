package com.fauscrew.ui.games.rockets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.material.icons.outlined.People
import androidx.compose.material.icons.outlined.ScreenRotation
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.rounded.CellTower
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.OnlineClock
import com.fauscrew.platform.OnlineFlightUi
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.OnlineResultUi
import com.fauscrew.platform.RocketsColor
import com.fauscrew.platform.RocketsEffect
import com.fauscrew.platform.RocketsFrame
import com.fauscrew.platform.RocketsPhase
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton
import java.util.Locale
import kotlin.math.ceil
import kotlinx.coroutines.delay

/** iOS `TimelineView(.periodic)`: the engine clock, refreshed on a fixed period. */
@Composable
internal fun rememberOnlineNow(periodMillis: Long = 250): Double {
    var now by remember { mutableDoubleStateOf(OnlineClock.now()) }
    LaunchedEffect(periodMillis) {
        while (true) {
            delay(periodMillis)
            now = OnlineClock.now()
        }
    }
    return now
}

internal fun remaining(until: Double?, now: Double): Int? = until?.let { maxOf(0, ceil(it - now).toInt()) }

/** iOS `confirmationDialog` for cancelling the flight for everyone. */
@Composable
internal fun CancelFlightDialog(copy: RocketsCopy, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        text = { Text(copy("house_rockets_cancel_confirmation"), style = FausCrewType.subheadline) },
        confirmButton = {
            TextButton(onClick = { onDismiss(); onConfirm() }) {
                Text(copy("house_rockets_cancel_flight"), color = HouseRocketsPalette.red, fontWeight = FontWeight.SemiBold)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(copy("common_cancel")) } },
    )
}

/** `HouseRocketsOnlineFlightOverlay` over the shared course canvas. */
@Composable
internal fun BoxScope.HouseRocketsOnlineFlightOverlay(
    frameState: State<RocketsFrame?>,
    flight: OnlineFlightUi?,
    lobby: OnlineLobbyUi,
    copy: RocketsCopy,
    isForeground: Boolean,
    onSteer: (Double) -> Unit,
    onEndSteering: () -> Unit,
    onAdjust: (Double) -> Unit,
    onRetry: () -> Unit,
    onReclaim: () -> Unit,
    onCancel: () -> Unit,
    onExit: () -> Unit,
) {
    val hud by remember {
        derivedStateOf {
            frameState.value?.let { frame ->
                OnlineHud(frame.phase, frame.elapsed.toInt(), frame.players.count { it.isAlive },
                    frame.human?.effect, frame.players.map { Triple(it.name, it.color, it.isAlive) }, frame.regions)
            }
        }
    }
    val humanHeading by remember { derivedStateOf { frameState.value?.human?.heading ?: 0.0 } }
    val model = hud ?: return
    Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        if (flight?.canSteer == true && isForeground) {
            FloatingJoystick(humanHeading, copy("house_rockets_joystick"), copy("house_rockets_joystick_hint"),
                onSteer, onEndSteering, onAdjust)
        }
        CompositionLocalProvider(
            LocalContentColor provides HouseRocketsTheme.ink,
            LocalTextStyle provides FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"),
        ) {
            model.regions.forEachIndexed { index, region ->
                Box(
                    Modifier.offset { IntOffset(region.x.dp.roundToPx(), region.y.dp.roundToPx()) }
                        .size(region.width.dp, region.height.dp),
                    contentAlignment = Alignment.TopCenter,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                        if (index == 0) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                                HudLabel(if (flight?.isSyncing == true) Icons.Rounded.Sync else Icons.Rounded.CellTower,
                                    copy(flight?.statusKey ?: "house_rockets_online_flying"))
                                if (model.phase == RocketsPhase.PLAYING) {
                                    HudLabel(Icons.Outlined.Timer, "${model.seconds}",
                                        Modifier.semantics { contentDescription = copy("house_rockets_time") + " ${model.seconds}" })
                                    HudLabel(Icons.Rounded.People, "${model.aliveCount}",
                                        Modifier.semantics {
                                            contentDescription = copy.template("house_rockets_alive", "count" to "${model.aliveCount}")
                                        })
                                }
                            }
                            model.humanEffect?.let {
                                Text(copy(if (it == RocketsEffect.BOOST) "house_rockets_boost_active" else "house_rockets_slow_active"),
                                    color = HouseRocketsTheme.accent, maxLines = 1)
                            }
                        } else {
                            val eliminations = flight?.eliminations.orEmpty()
                            if (eliminations.isEmpty()) {
                                val columns = if (region.width < 340) 2 else 4
                                Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                                    model.players.chunked(columns).forEach { row ->
                                        Row(Modifier.fillMaxWidth()) {
                                            row.forEach { (name, color, alive) ->
                                                Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically,
                                                    horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                                    Box(Modifier.size(7.dp).clip(CircleShape).background(HouseRocketsPalette.player(color)))
                                                    Text(name, maxLines = 1,
                                                        color = if (alive) HouseRocketsTheme.ink else HouseRocketsTheme.muted,
                                                        textDecoration = if (alive) null else TextDecoration.LineThrough)
                                                }
                                            }
                                            repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                                        }
                                    }
                                }
                            } else {
                                Text(copy.template("house_rockets_online_eliminated", "names" to eliminations.joinToString(", ")),
                                    color = HouseRocketsTheme.danger, maxLines = if (region.width < 340) 4 else 2,
                                    textAlign = TextAlign.Center)
                            }
                        }
                    }
                }
            }
        }
        FlightActionsMenu(copy, lobby, onCancel, onExit, Modifier.align(Alignment.BottomEnd).padding(8.dp))
        if (model.phase == RocketsPhase.COUNTDOWN && !lobby.isTerminal) {
            val now = rememberOnlineNow()
            val seconds = remaining(lobby.flightCountdownUptime, now)
            Column(
                Modifier.align(Alignment.Center).background(HouseRocketsTheme.panel, RoundedCornerShape(Radius.xl))
                    .padding(Spacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                if (seconds != null && seconds > 0) {
                    Text("$seconds", fontSize = 64.sp, fontWeight = FontWeight.Black, color = HouseRocketsTheme.ink,
                        style = LocalTextStyle.current.copy(fontFeatureSettings = "tnum"))
                } else {
                    Text(copy(if (seconds == null) "house_rockets_online_launching" else "house_rockets_online_waiting_start"),
                        style = FausCrewType.headline, color = HouseRocketsTheme.ink)
                }
                Text(copy("house_rockets_online_launching_detail"), style = FausCrewType.subheadline,
                    color = HouseRocketsTheme.ink, textAlign = TextAlign.Center)
            }
        }
        if (flight?.showsConnectionPanel == true) {
            BoxWithConstraints(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                HouseRocketsOnlineConnectionPanel(lobby, copy, onRetry, onReclaim,
                    Modifier.widthIn(max = minOf(430.dp, maxWidth - 48.dp)).heightIn(max = maxHeight - 96.dp))
            }
        }
    }
}

private data class OnlineHud(
    val phase: RocketsPhase,
    val seconds: Int,
    val aliveCount: Int,
    val humanEffect: RocketsEffect?,
    val players: List<Triple<String, RocketsColor, Boolean>>,
    val regions: List<com.fauscrew.platform.RocketsRegion>,
)

@Composable
private fun FlightActionsMenu(copy: RocketsCopy, lobby: OnlineLobbyUi, onCancel: () -> Unit, onExit: () -> Unit,
                              modifier: Modifier) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier) {
        Box(
            Modifier.size(44.dp).clip(CircleShape).background(HouseRocketsTheme.panel)
                .clickable(enabled = !lobby.isLeaving, role = Role.Button) { expanded = true }
                .semantics { contentDescription = copy("house_rockets_flight_actions") },
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Rounded.MoreHoriz, null, Modifier.size(22.dp), tint = HouseRocketsTheme.ink) }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(text = { Text(copy("house_rockets_exit")) }, onClick = { expanded = false; onExit() })
            if (lobby.canCancel) {
                DropdownMenuItem(text = { Text(copy("house_rockets_cancel_flight"), color = HouseRocketsPalette.red) },
                    onClick = { expanded = false; onCancel() })
            }
        }
    }
}

/** `HouseRocketsOnlineConnectionView`: connection/control feedback over the retained course. */
@Composable
internal fun HouseRocketsOnlineConnectionPanel(
    state: OnlineLobbyUi, copy: RocketsCopy, onRetry: () -> Unit, onReclaim: () -> Unit, modifier: Modifier = Modifier,
) {
    val now = rememberOnlineNow()
    Column(
        modifier.background(HouseRocketsTheme.panel, RoundedCornerShape(Radius.lg)).verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        if (!state.isFailed && !state.controlTransferred) {
            CircularProgressIndicator(Modifier.size(22.dp), color = HouseRocketsTheme.accent, strokeWidth = 2.dp)
        }
        Text(copy(state.connectionTitleKey), style = FausCrewType.headline, color = HouseRocketsTheme.ink,
            textAlign = TextAlign.Center)
        Text(copy(state.connectionDetailKey), style = FausCrewType.subheadline, color = HouseRocketsTheme.muted,
            textAlign = TextAlign.Center)
        if (state.isReconnecting) {
            Text(copy.template("house_rockets_reconnect_wait", "seconds" to "${remaining(state.retryNotBefore, now) ?: 0}"),
                style = FausCrewType.caption.copy(fontFeatureSettings = "tnum"), color = HouseRocketsTheme.muted)
        }
        if (state.controlTransferred && state.isConnected) {
            CapsuleButton(copy("house_rockets_reclaim_control"), HouseRocketsTheme.background, HouseRocketsTheme.accent,
                Modifier, enabled = state.isForeground && state.isSynced, minHeight = 44.dp, onClick = onReclaim)
        } else if (state.isFailed && state.canRetry) {
            CapsuleButton(copy("house_rockets_online_retry"), HouseRocketsTheme.background, HouseRocketsTheme.accent,
                Modifier, enabled = now >= (state.retryNotBefore ?: 0.0) && state.isForeground, minHeight = 44.dp,
                onClick = onRetry)
        }
    }
}
