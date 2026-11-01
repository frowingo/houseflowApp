package com.fauscrew.ui.games.tanks

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Verified
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
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.TanksFrame
import com.fauscrew.platform.TanksOnlineMatch
import com.fauscrew.platform.TanksOnlineResult
import com.fauscrew.platform.TanksOnlineSeatStatus
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton
import kotlinx.coroutines.delay

/**
 * `HouseTanksOnlineMatchView`: the server's arena in landscape, the seat bar for up to
 * eight tanks, the one button over the whole field, the round countdown and a banner for
 * every state that needs words, the vote between rounds, the result and a rematch room
 * ([rematchLobby], the new session before its first snapshot). One engine presentation per
 * display frame via [onFrame]; the engine decides when the button works and who may vote.
 */
@Composable
internal fun HouseTanksOnlineGameLayer(
    frameState: State<TanksFrame?>,
    match: TanksOnlineMatch?,
    copy: TanksCopy,
    renderer: HouseTanksArenaRenderer,
    reduceMotion: Boolean,
    isForeground: Boolean,
    isConfirmingLeave: Boolean,
    onConfirmingLeaveChange: (Boolean) -> Unit,
    onFrame: () -> Unit,
    onPressStart: () -> Unit,
    onPressEnd: () -> Unit,
    onRetry: () -> Unit,
    onReclaim: () -> Unit,
    onExit: () -> Unit,
    onVote: (Boolean) -> Unit,
    onRetryResult: () -> Unit,
    onRematch: () -> Unit,
    rematchLobby: OnlineLobbyUi?,
    members: Map<String, String>,
    uptime: () -> Double,
    onSetReady: (Boolean) -> Unit,
    onCancel: () -> Unit,
    fps: Int? = null,
) {
    val painters = rememberJokerPainters()
    val showsRematchRoom = rematchLobby != null && match?.showsResult != true
    val exitsDirectly = match?.isFinished == true || showsRematchRoom
    var showsPressHint by remember { mutableStateOf(true) }
    val currentPressStart by rememberUpdatedState(onPressStart)
    val currentPressEnd by rememberUpdatedState(onPressEnd)

    LaunchedEffect(isForeground) {
        if (!isForeground) return@LaunchedEffect
        while (true) withFrameNanos { onFrame() }
    }

    Box(Modifier.fillMaxSize()) {
        Box(Modifier.fillMaxSize().drawBehind {
            val current = frameState.value ?: return@drawBehind
            renderer.draw(this, current, reduceMotion, painters)
        })

        if (!exitsDirectly) {
            Box(
                Modifier.fillMaxSize()
                    .pointerInput(Unit) {
                        awaitEachGesture {
                            // Down presses, up (or cancel) releases. A finger held across a round
                            // boundary or a sync pause is the engine's: it never presses again
                            // until the finger lifts and comes back.
                            awaitFirstDown(requireUnconsumed = false)
                            currentPressStart()
                            waitForUpOrCancellation()
                            currentPressEnd()
                        }
                    }
                    .semantics {
                        role = Role.Button
                        contentDescription = "${copy("house_tanks_playfield_accessibility")}. ${copy("house_tanks_playfield_hint")}"
                        onClick { onPressStart(); onPressEnd(); true }
                    },
            )
        }

        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = Spacing.lg).padding(top = Spacing.sm),
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            ) {
                // The top-left exit is for a live round only: the round panel, the end menu
                // and the rematch room carry their own way out.
                if (match?.showsResult != true && !showsRematchRoom) {
                    if (match?.showsRoundPanel != true) {
                        Box(
                            Modifier.size(44.dp).hudPanel().clip(RoundedCornerShape(Radius.xs))
                                .scaleButton(onClick = { if (exitsDirectly) onExit() else onConfirmingLeaveChange(true) })
                                .semantics { contentDescription = copy("house_tanks_online_leave") },
                            contentAlignment = Alignment.Center,
                        ) { Icon(Icons.Rounded.Close, null, Modifier.size(22.dp), tint = HouseTanksFieldTheme.ink) }
                    }
                    fps?.let { FramesPerSecond(it, copy) }
                }
                match?.seats.orEmpty().forEach { seat ->
                    SeatStatus(seat, copy, showsVote = match?.showsRoundPanel == true, modifier = Modifier.weight(1f))
                }
            }
            Spacer(Modifier.weight(1f))
            val hint = showsPressHint && match?.roundPhase == "roundPlaying" && match.canPress
            AnimatedVisibility(hint, Modifier.align(Alignment.CenterHorizontally), exit = fadeOut()) {
                Row(
                    Modifier.padding(bottom = Spacing.xl).heightIn(min = 44.dp).hudPanel().padding(horizontal = Spacing.lg),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Rounded.TouchApp, null, Modifier.size(18.dp), tint = HouseTanksFieldTheme.ink)
                    Text(copy("house_tanks_online_press_hint"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = HouseTanksFieldTheme.ink)
                }
            }
            LaunchedEffect(hint) {
                if (!hint) return@LaunchedEffect
                delay(4_000)
                showsPressHint = false
            }
        }

        if (match != null && match.noticeTitleKey == null && !match.showsResult && !showsRematchRoom &&
            (match.roundPhase == "roundCountdown" || match.phase == "countdown")) RoundCountdown(match, copy)
        if (!showsRematchRoom) match?.noticeTitleKey?.let { title ->
            Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).padding(bottom = Spacing.lg),
                contentAlignment = Alignment.BottomCenter) {
                Notice(match, title, copy, onRetry, onReclaim, onExit)
            }
        }
        if (match?.showsRoundPanel == true && !showsRematchRoom) {
            RoundPanel(match, copy, onVote, onLeave = { onConfirmingLeaveChange(true) })
        }
        val result = match?.result
        if (match?.showsResult == true && result != null) {
            ResultPanel(result, copy, members, onRetryResult, onRematch, onExit)
        } else if (showsRematchRoom) {
            RematchRoom(rematchLobby, copy, members, uptime, onSetReady, onCancel, onRetry, onExit)
        }
    }

    if (isConfirmingLeave) {
        AlertDialog(
            onDismissRequest = { onConfirmingLeaveChange(false) },
            title = { Text(copy("house_tanks_online_leave_confirm_title")) },
            text = { Text(copy("house_tanks_online_leave_confirm_detail")) },
            confirmButton = {
                TextButton(onClick = { onConfirmingLeaveChange(false); onExit() }) {
                    Text(copy("house_tanks_online_leave"), color = HouseTanksPalette.rust)
                }
            },
            dismissButton = {
                TextButton(onClick = { onConfirmingLeaveChange(false) }) { Text(copy("house_tanks_online_stay")) }
            },
        )
    }
}

/** One tank of up to eight: name, round wins, armor, a lost connection or, between rounds, the vote. */
@Composable
private fun SeatStatus(seat: TanksOnlineSeatStatus, copy: TanksCopy, showsVote: Boolean, modifier: Modifier) {
    val tint = seat.color.ink
    val alpha = if (seat.isAlive && seat.isConnected) 1f else .5f
    val description = buildList {
        add(seat.name)
        add("${copy("house_tanks_armor")} ${seat.armor}")
        add("${copy("house_tanks_round_score")} ${seat.roundsWon}")
        if (showsVote && seat.roundReady) add(copy("house_tanks_online_ready_badge"))
        if (!seat.isConnected) add(copy("house_tanks_online_offline"))
        if (seat.hasLeft) add(copy("house_tanks_online_left_badge"))
    }.joinToString(", ")
    Column(
        modifier.heightIn(min = 44.dp).hudPanel()
            .drawBehind {
                drawRect(tint, Offset(3.dp.toPx(), 7.dp.toPx()), Size(3.dp.toPx(), size.height - 14.dp.toPx()))
                if (seat.isLocal) {
                    drawRoundRect(tint, size = size, cornerRadius = CornerRadius(Radius.xs.toPx()), style = Stroke(1.5.dp.toPx()))
                }
            }
            .padding(start = 9.dp, end = 6.dp, top = 6.dp, bottom = 6.dp)
            .clearAndSetSemantics { contentDescription = description },
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            if (showsVote && seat.roundReady) {
                Icon(Icons.Rounded.Verified, null, Modifier.size(11.dp), tint = HouseTanksPalette.steel)
            } else if (!seat.isConnected) {
                Icon(Icons.Rounded.WifiOff, null, Modifier.size(11.dp), tint = HouseTanksPalette.rust)
            }
            Text(seat.name, style = FausCrewType.caption2.copy(fontWeight = FontWeight.Bold,
                textDecoration = if (seat.hasLeft) TextDecoration.LineThrough else null),
                color = HouseTanksFieldTheme.ink.copy(alpha = alpha), maxLines = 1, modifier = Modifier.weight(1f))
            Text("${seat.roundsWon}/$RoundWinsNeeded", style = HouseTanksFieldTheme.stencil,
                color = HouseTanksPalette.umber.copy(alpha = alpha))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (index in 0 until ArmorPerRound) {
                Box(Modifier.weight(1f).height(5.dp).clip(RoundedCornerShape(1.dp)).background(
                    if (index < seat.armor && seat.isAlive) tint.copy(alpha = alpha) else HouseTanksPalette.slate.copy(alpha = .2f)))
            }
        }
    }
}

/** The server's round countdown (`roundCountdownEndsAt`), read every frame from the engine. */
@Composable
private fun RoundCountdown(match: TanksOnlineMatch, copy: TanksCopy) {
    val text = match.countdown?.takeIf { it > 0 }?.toString() ?: copy("house_tanks_countdown_go")
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.background(HouseTanksPalette.paper.copy(alpha = .78f), RoundedCornerShape(Radius.sm))
                .drawBehind { drawCornerMarks(HouseTanksPalette.steel.copy(alpha = .6f), 10.dp.toPx(), 0f, 1.5.dp.toPx()) }
                .padding(horizontal = Spacing.xxl, vertical = Spacing.md)
                .clearAndSetSemantics { contentDescription = text },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            val heading = if (match.phase == "countdown") copy("house_tanks_online_countdown")
                else copy.template("house_tanks_round", "number" to match.roundNumber.toString())
            Text(heading.uppercase(),
                style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 15.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp),
                color = HouseTanksPalette.umber)
            Box {
                val style = TextStyle(fontSize = 84.sp, fontWeight = FontWeight.Black, letterSpacing = (-2).sp)
                Text(text, style = style, color = HouseTanksPalette.paper, modifier = Modifier.padding(start = 3.dp, top = 3.dp))
                Text(text, style = style, color = HouseTanksPalette.steel)
            }
        }
    }
}

/** Reconnecting, recovering, control moved, round death, round over or match over. */
@Composable
private fun Notice(
    match: TanksOnlineMatch, title: String, copy: TanksCopy, onRetry: () -> Unit, onReclaim: () -> Unit, onExit: () -> Unit,
) {
    Column(
        Modifier.widthIn(max = 360.dp).background(HouseTanksPalette.paper.copy(alpha = .92f), RoundedCornerShape(Radius.sm))
            .fieldCard(Spacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(copy.template(title, "name" to match.noticeName.orEmpty()),
            style = FausCrewType.headline.copy(fontWeight = FontWeight.Black), color = HouseTanksFieldTheme.ink,
            textAlign = TextAlign.Center)
        match.noticeDetailKey?.let { detail ->
            Text(copy(detail), style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted, textAlign = TextAlign.Center)
        }
        when {
            match.canRetry -> NoticeButton(copy("house_tanks_online_retry"), Icons.Rounded.Refresh, onRetry)
            match.canReclaim -> NoticeButton(copy("house_tanks_online_reclaim"), Icons.Rounded.PanTool, onReclaim)
            match.isFinished || match.isSpectating ->
                NoticeButton(copy("house_tanks_exit"), Icons.AutoMirrored.Rounded.Logout, onExit)
        }
    }
}

/** Frames drawn in the last second, green at a smooth rate through to red at a choppy one (`HouseTanksFrameRate`). */
@Composable
private fun FramesPerSecond(fps: Int, copy: TanksCopy) {
    val quality = (fps - 20).coerceIn(0, 35) / 35f
    val tint = Color.hsv(120f * quality, .8f, .62f)
    Row(
        Modifier.heightIn(min = 44.dp).widthIn(min = 72.dp).hudPanel().padding(horizontal = Spacing.sm)
            .clearAndSetSemantics { contentDescription = copy.template("house_tanks_online_fps_accessibility", "fps" to "$fps") },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally),
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(tint))
        Text(copy.template("house_tanks_online_fps", "fps" to "$fps"),
            style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold), color = tint)
    }
}

/**
 * `roundReady`, centered for every device: who took the round, the vote window, and the way
 * out beside this device's vote (the top-left exit is hidden between rounds).
 */
@Composable
private fun RoundPanel(match: TanksOnlineMatch, copy: TanksCopy, onVote: (Boolean) -> Unit, onLeave: () -> Unit) {
    PanelScrim(dim = .18f) {
        Icon(if (match.noticeName == null) Icons.Rounded.Flag else Icons.Rounded.EmojiEvents, null, Modifier.size(28.dp),
            tint = HouseTanksPalette.umber)
        Text(copy.template(match.roundTitleKey.orEmpty(), "name" to match.noticeName.orEmpty()),
            style = FausCrewType.title3.copy(fontWeight = FontWeight.Black), color = HouseTanksFieldTheme.ink,
            textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
        Text(copy.template(match.roundDetailKey.orEmpty(), "seconds" to (match.roundWindowSeconds ?: 0).toString()),
            style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted, textAlign = TextAlign.Center)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(Icons.Rounded.Groups, null, Modifier.size(16.dp), tint = HouseTanksPalette.umber)
            Text(copy.template("house_tanks_online_round_ready_count", "ready" to match.readyCount.toString(),
                "total" to match.voterCount.toString()), style = HouseTanksFieldTheme.stencil, color = HouseTanksPalette.umber)
        }
        Row(Modifier.padding(top = Spacing.xs), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            PanelButton(copy("house_tanks_online_leave_match"), Icons.AutoMirrored.Rounded.Logout, HouseTanksPalette.umber,
                modifier = Modifier.weight(1f), onClick = onLeave)
            if (match.canVote) {
                val ready = match.isLocalReady
                PanelButton(
                    copy(if (ready) "house_tanks_online_round_unready" else "house_tanks_online_round_ready"),
                    if (ready) Icons.Rounded.Cancel else Icons.Rounded.CheckCircle,
                    if (ready) HouseTanksPalette.slate else HouseTanksPalette.steel,
                    modifier = Modifier.weight(1f),
                    isBusy = match.isVotePending,
                ) { onVote(!ready) }
            }
        }
    }
}

/**
 * The end menu over the frozen arena, centered from the match's end: finalizing, the champion or
 * the cancellation, the standings (the last seats until the stored ranks arrive: ties shared, a
 * cancelled match unranked), the exit and the rematch.
 */
@Composable
private fun ResultPanel(
    result: TanksOnlineResult, copy: TanksCopy, members: Map<String, String>,
    onRetry: () -> Unit, onRematch: () -> Unit, onExit: () -> Unit,
) {
    fun name(id: String, seated: String?) = seated ?: members[id] ?: copy("house_tanks_online_player")
    val title = result.championId?.let { id ->
        copy.template(result.titleKey, "name" to name(id, result.players.firstOrNull { it.playerId == id }?.name))
    } ?: copy(result.titleKey)
    PanelScrim {
        Icon(if (result.isCompleted) Icons.Rounded.EmojiEvents else Icons.Rounded.Flag, null, Modifier.size(28.dp),
            tint = HouseTanksPalette.steel)
        Text(title, style = FausCrewType.title3.copy(fontWeight = FontWeight.Black), color = HouseTanksFieldTheme.ink,
            textAlign = TextAlign.Center, modifier = Modifier.semantics { heading() })
        Text(copy(result.detailKey), style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted,
            textAlign = TextAlign.Center)
        if (result.isWaiting) CircularProgressIndicator(Modifier.size(24.dp), color = HouseTanksPalette.steel, strokeWidth = 2.5.dp)
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            result.players.forEach { player ->
                val rank = player.rank?.let { copy.template("house_tanks_online_result_rank", "rank" to it.toString()) }
                    ?: copy("house_tanks_online_result_unranked")
                Row(
                    Modifier.fillMaxWidth().clearAndSetSemantics {
                        contentDescription = "$rank, ${name(player.playerId, player.name)}, " +
                            copy.template("house_tanks_online_round_score", "wins" to player.roundsWon.toString())
                    },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Text(player.rank?.let { "$it." } ?: "—", style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Black),
                        color = HouseTanksFieldTheme.ink, modifier = Modifier.widthIn(min = 28.dp))
                    player.color?.let { Box(Modifier.size(10.dp).clip(CircleShape).background(it.ink)) }
                    Text(name(player.playerId, player.name), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = HouseTanksFieldTheme.ink, maxLines = 1)
                    if (player.isLocal) {
                        Text(copy("house_tanks_online_you"), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
                    }
                    Spacer(Modifier.weight(1f))
                    Text(copy.template("house_tanks_online_round_score", "wins" to player.roundsWon.toString()),
                        style = HouseTanksFieldTheme.stencil, color = HouseTanksPalette.umber)
                }
            }
            if (result.players.firstOrNull()?.isProvisional == true) {
                Text(copy("house_tanks_online_standings_provisional"), style = FausCrewType.caption,
                    color = HouseTanksFieldTheme.muted, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
        }
        if (result.isFailed && result.canRetry) {
            TextButton(onClick = onRetry, modifier = Modifier.heightIn(min = 44.dp)) {
                Text(copy("house_tanks_online_result_retry"), color = HouseTanksPalette.steel, fontWeight = FontWeight.Bold)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            PanelButton(copy("house_tanks_exit"), Icons.AutoMirrored.Rounded.Logout, HouseTanksPalette.umber,
                modifier = Modifier.weight(1f), onClick = onExit)
            if (result.canRematch) {
                PanelButton(copy("house_tanks_rematch"), Icons.Rounded.Replay, HouseTanksPalette.steel,
                    modifier = Modifier.weight(1f), onClick = onRematch)
            }
        }
    }
}

/** A rematch's new session until its first snapshot: status, who is ready, the toggle and window. */
@Composable
private fun RematchRoom(
    lobby: OnlineLobbyUi, copy: TanksCopy, members: Map<String, String>, uptime: () -> Double,
    onSetReady: (Boolean) -> Unit, onCancel: () -> Unit, onRetry: () -> Unit, onExit: () -> Unit,
) {
    val seconds = rememberSecondsUntil(lobby.deadlineUptime, uptime)
    val detail = if (lobby.isLobby && lobby.isConnected) "house_tanks_online_rematch_hint" else lobby.detailKey
    PanelScrim {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(copy("house_tanks_online_rematch_room").uppercase(),
                style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 15.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp),
                color = HouseTanksPalette.umber, modifier = Modifier.weight(1f).semantics { heading() })
            if (lobby.sessionState != null) {
                Text(copy.template("house_tanks_online_ready_count", "ready" to lobby.readyCount.toString(),
                    "total" to lobby.participants.size.toString()), style = HouseTanksFieldTheme.stencil,
                    color = HouseTanksFieldTheme.muted)
            }
        }
        Text(copy(lobby.statusKey), style = FausCrewType.headline.copy(fontWeight = FontWeight.Black),
            color = HouseTanksFieldTheme.ink, modifier = Modifier.fillMaxWidth())
        Text(copy.template(detail, "minimum" to lobby.minimumPlayers.toString()), style = FausCrewType.subheadline,
            color = HouseTanksFieldTheme.muted, modifier = Modifier.fillMaxWidth())
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            (lobby.participants.filter { it.isLocal } + lobby.participants.filter { !it.isLocal }).forEach { member ->
                Row(Modifier.fillMaxWidth().clearAndSetSemantics {
                    contentDescription = "${members[member.playerId] ?: copy("house_tanks_online_player")}, ${copy(member.statusKey)}"
                }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    Text(members[member.playerId] ?: copy("house_tanks_online_player"),
                        style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = HouseTanksFieldTheme.ink,
                        maxLines = 1)
                    if (member.isLocal) {
                        Text(copy("house_tanks_online_you"), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
                    }
                    Spacer(Modifier.weight(1f))
                    Icon(if (member.isReady) Icons.Rounded.Verified else Icons.Rounded.Schedule, null, Modifier.size(14.dp),
                        tint = if (member.isReady) HouseTanksPalette.steel else HouseTanksFieldTheme.muted)
                    Text(copy(member.statusKey), style = HouseTanksFieldTheme.stencil,
                        color = if (member.isReady) HouseTanksPalette.steel else HouseTanksFieldTheme.muted)
                }
            }
        }
        if (seconds != null && lobby.deadlineKind != null) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Rounded.Timer, null, Modifier.size(14.dp), tint = HouseTanksPalette.umber)
                Text(copy.template("house_tanks_online_seconds", "seconds" to seconds.toString()),
                    style = HouseTanksFieldTheme.stencil, color = HouseTanksPalette.umber)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            PanelButton(copy("house_tanks_online_leave"), Icons.AutoMirrored.Rounded.Logout, HouseTanksPalette.umber,
                modifier = Modifier.weight(1f), onClick = onExit)
            if (lobby.isFailed && lobby.canRetry) {
                PanelButton(copy("house_tanks_online_retry"), Icons.Rounded.Refresh, HouseTanksPalette.steel,
                    modifier = Modifier.weight(1f), onClick = onRetry)
            } else {
                val ready = lobby.localReady
                PanelButton(copy(if (ready) "house_tanks_online_not_ready" else "house_tanks_online_ready"),
                    if (ready) Icons.Rounded.Cancel else Icons.Rounded.CheckCircle,
                    if (ready) HouseTanksPalette.umber else HouseTanksPalette.steel,
                    modifier = Modifier.weight(1f), enabled = lobby.canChangeReady) { onSetReady(!ready) }
            }
        }
        if (lobby.canCancel) {
            TextButton(onClick = onCancel, modifier = Modifier.heightIn(min = 44.dp)) {
                Text(copy("house_tanks_online_cancel"), color = HouseTanksPalette.rust, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

/** A dimmed field with one centered card, for the result and the rematch room. */
@Composable
private fun PanelScrim(dim: Float = .34f, content: @Composable ColumnScope.() -> Unit) {
    Box(
        Modifier.fillMaxSize().background(HouseTanksPalette.ink.copy(alpha = dim))
            .pointerInput(Unit) { awaitEachGesture { awaitFirstDown(requireUnconsumed = false) } }
            .windowInsetsPadding(WindowInsets.safeDrawing).padding(Spacing.lg),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.widthIn(max = 460.dp).heightIn(max = 360.dp)
                .background(HouseTanksPalette.paper.copy(alpha = .96f), RoundedCornerShape(Radius.sm)).fieldCard(Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            content = content,
        )
    }
}

@Composable
private fun PanelButton(
    title: String, icon: ImageVector, tint: Color, modifier: Modifier = Modifier, enabled: Boolean = true,
    isBusy: Boolean = false, onClick: () -> Unit,
) {
    RaisedButton(tint, onClick, modifier.alpha(if (enabled) 1f else .5f), offset = 3.dp, enabled = enabled) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 44.dp).background(tint, RoundedCornerShape(Radius.xs))
                .padding(horizontal = Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (isBusy) {
                CircularProgressIndicator(Modifier.size(16.dp), color = HouseTanksPalette.paper, strokeWidth = 2.dp)
            } else {
                Icon(icon, null, Modifier.size(16.dp), tint = HouseTanksPalette.paper)
            }
            Text(title, style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = HouseTanksPalette.paper,
                maxLines = 1)
        }
    }
}

@Composable
private fun NoticeButton(title: String, icon: ImageVector, onClick: () -> Unit) {
    RaisedButton(HouseTanksPalette.steel, onClick, offset = 3.dp) {
        Row(
            Modifier.heightIn(min = 44.dp).background(HouseTanksPalette.steel, RoundedCornerShape(Radius.xs))
                .padding(horizontal = Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(icon, null, Modifier.size(16.dp), tint = HouseTanksPalette.paper)
            Text(title, style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = HouseTanksPalette.paper)
        }
    }
}

private const val RoundWinsNeeded = 3
private const val ArmorPerRound = 5
