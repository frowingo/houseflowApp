package com.fauscrew.ui.games.tanks

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
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
import com.fauscrew.platform.TanksFrame
import com.fauscrew.platform.TanksPhase
import com.fauscrew.platform.TanksPlayer
import com.fauscrew.platform.TanksRole
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton
import kotlinx.coroutines.delay

/** The HUD reads only what changes between engine phases, not every arena frame. */
private data class HudState(
    val matchId: String,
    val phase: TanksPhase,
    val countdown: Int?,
    val roundNumber: Int,
    val players: List<TanksPlayer>,
    val roundWinner: TanksPlayer?,
    val champion: TanksPlayer?,
    val humanId: String?,
)

private fun TanksFrame.hud() = HudState(matchId, phase, countdown, roundNumber, players, roundWinner, champion, human?.id)

/**
 * `HouseTanksView.gameplayLayer`: the arena canvas, the playfield press, the HUD and the
 * countdown, pause and report overlays. One engine step per display frame via [onFrame].
 */
@Composable
internal fun HouseTanksGameLayer(
    frameState: State<TanksFrame?>,
    copy: TanksCopy,
    renderer: HouseTanksArenaRenderer,
    reduceMotion: Boolean,
    isForeground: Boolean,
    onFrame: (Long) -> Unit,
    onPressStart: () -> Unit,
    onPressEnd: () -> Unit,
    onAccessiblePress: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onNextRound: () -> Unit,
    onRestart: () -> Unit,
    onDrillSetup: () -> Unit,
    onExit: () -> Unit,
) {
    val painters = rememberJokerPainters()
    // Recompose only when the HUD's slice changes; the arena itself redraws in the draw phase.
    val hudState by remember(frameState) { derivedStateOf { frameState.value?.hud() } }
    val hud = hudState ?: return
    var showsTapHint by remember(hud.matchId) { mutableStateOf(true) }

    LaunchedEffect(isForeground, hud.phase) {
        if (!isForeground || hud.phase != TanksPhase.PLAYING) return@LaunchedEffect
        while (true) withFrameNanos(onFrame)
    }

    Box(Modifier.fillMaxSize()) {
        // The arena: SpriteKit's scene, drawn edge to edge over the paper backdrop.
        Box(Modifier.fillMaxSize().drawBehind {
            val current = frameState.value ?: return@drawBehind
            renderer.draw(this, current, reduceMotion, painters)
        })

        if (hud.phase == TanksPhase.PLAYING) {
            Box(
                Modifier.fillMaxSize()
                    .pointerInput(Unit) {
                        awaitEachGesture {
                            awaitFirstDown(requireUnconsumed = false)
                            onPressStart()
                            waitForUpOrCancellation()
                            onPressEnd()
                        }
                    }
                    .semantics {
                        role = Role.Button
                        contentDescription = "${copy("house_tanks_playfield_accessibility")}. ${copy("house_tanks_playfield_hint")}"
                        onClick { onAccessiblePress(); true }
                    },
            )
        }

        Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = Spacing.lg).padding(top = Spacing.sm),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Box(
                    Modifier.size(44.dp).hudPanel().clip(RoundedCornerShape(Radius.xs))
                        .scaleButton(onClick = onPause).semantics { contentDescription = copy("house_tanks_pause") },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Rounded.Pause, null, Modifier.size(22.dp), tint = HouseTanksFieldTheme.ink) }
                hud.players.forEach { player -> PlayerStatus(player, copy, Modifier.weight(1f)) }
            }
            Spacer(Modifier.weight(1f))
            AnimatedVisibility(hud.phase == TanksPhase.PLAYING && showsTapHint, Modifier.align(Alignment.CenterHorizontally),
                exit = fadeOut()) {
                Row(
                    Modifier.padding(bottom = Spacing.xl).heightIn(min = 44.dp).hudPanel().padding(horizontal = Spacing.lg),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(Icons.Rounded.TouchApp, null, Modifier.size(18.dp), tint = HouseTanksFieldTheme.ink)
                    Text(copy("house_tanks_tap_hint"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                        color = HouseTanksFieldTheme.ink)
                }
            }
        }
        LaunchedEffect(hud.phase == TanksPhase.PLAYING, showsTapHint) {
            if (hud.phase == TanksPhase.PLAYING && showsTapHint) {
                delay(4_000)
                showsTapHint = false
            }
        }

        when (hud.phase) {
            TanksPhase.COUNTDOWN -> Countdown(hud, copy)
            TanksPhase.PAUSED -> ReportOverlay(
                kicker = copy("house_tanks_report_paused"), icon = Icons.Rounded.Pause, accent = HouseTanksPalette.slate,
                title = copy("house_tanks_paused"), detail = copy("house_tanks_paused_detail"), players = null, copy = copy,
                primaryTitle = copy("house_tanks_resume"), primaryIcon = Icons.Rounded.PlayArrow,
                primaryColor = HouseTanksPalette.steel, onPrimary = onResume, onDrillSetup = onDrillSetup, onExit = onExit,
            )
            TanksPhase.ROUND_ENDED -> {
                val humanWon = hud.roundWinner?.id == hud.humanId
                val (title, detail, accent, action) = when {
                    hud.roundWinner == null -> Quad(copy("house_tanks_round_draw"), copy("house_tanks_round_draw_detail"),
                        HouseTanksPalette.khaki, HouseTanksPalette.umber)
                    humanWon -> Quad(copy("house_tanks_round_won"), copy("house_tanks_round_won_detail"),
                        HouseTanksPalette.steel, HouseTanksPalette.steel)
                    else -> Quad(copy.template("house_tanks_round_lost", "name" to copy(hud.roundWinner.nameKey)),
                        copy("house_tanks_round_lost_detail"), HouseTanksPalette.rust, HouseTanksPalette.rust)
                }
                ReportOverlay(
                    kicker = copy.template("house_tanks_report_round", "number" to hud.roundNumber.toString()),
                    icon = if (humanWon) Icons.Rounded.Shield else Icons.Rounded.Flag, accent = accent,
                    title = title, detail = detail, players = hud.players, copy = copy,
                    primaryTitle = copy("house_tanks_next_round"), primaryIcon = Icons.AutoMirrored.Rounded.ArrowForward,
                    primaryColor = action, onPrimary = { showsTapHint = false; onNextRound() },
                    onDrillSetup = onDrillSetup, onExit = onExit,
                )
            }
            TanksPhase.MATCH_ENDED -> {
                val humanWon = hud.champion?.id == hud.humanId
                val color = if (humanWon) HouseTanksPalette.steel else HouseTanksPalette.rust
                ReportOverlay(
                    kicker = copy("house_tanks_report_match"), icon = Icons.Rounded.EmojiEvents, accent = color,
                    title = if (humanWon) copy("house_tanks_champion_you")
                    else copy.template("house_tanks_champion_bot", "name" to copy(hud.champion?.nameKey ?: "house_tanks_bot_one")),
                    detail = copy("house_tanks_champion_detail"), players = hud.players, copy = copy,
                    primaryTitle = copy("house_tanks_rematch"), primaryIcon = Icons.Rounded.Refresh, primaryColor = color,
                    onPrimary = { showsTapHint = true; onRestart() }, onDrillSetup = onDrillSetup, onExit = onExit,
                )
            }
            TanksPhase.PLAYING -> Unit
        }
    }
}

private data class Quad(val title: String, val detail: String, val accent: Color, val action: Color)

@Composable
private fun PlayerStatus(player: TanksPlayer, copy: TanksCopy, modifier: Modifier) {
    val tint = player.color.ink
    Column(
        modifier.heightIn(min = 44.dp).hudPanel()
            .drawBehind {
                drawRect(tint, Offset(3.dp.toPx(), 7.dp.toPx()), Size(3.dp.toPx(), size.height - 14.dp.toPx()))
                if (player.role == TanksRole.HUMAN) {
                    drawRoundRect(tint, size = size, cornerRadius = androidx.compose.ui.geometry.CornerRadius(Radius.xs.toPx()),
                        style = Stroke(1.5.dp.toPx()))
                }
            }
            .padding(start = 11.dp, end = 8.dp, top = 6.dp, bottom = 6.dp)
            .clearAndSetSemantics {
                contentDescription = "${copy(player.nameKey)}, ${copy("house_tanks_armor")} ${player.armor}, " +
                    "${copy("house_tanks_round_score")} ${player.roundsWon}"
            },
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        val alpha = if (player.isAlive) 1f else .5f
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(copy(player.nameKey), style = FausCrewType.caption2.copy(fontWeight = FontWeight.Bold,
                textDecoration = if (player.isAlive) null else TextDecoration.LineThrough),
                color = HouseTanksFieldTheme.ink.copy(alpha = alpha), maxLines = 1, modifier = Modifier.weight(1f))
            Text("${player.roundsWon}/3", style = HouseTanksFieldTheme.stencil, color = HouseTanksPalette.umber.copy(alpha = alpha))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (index in 0 until 5) {
                Box(Modifier.weight(1f).height(5.dp).clip(RoundedCornerShape(1.dp))
                    .background(if (index < player.armor) tint.copy(alpha = alpha) else HouseTanksPalette.slate.copy(alpha = .2f)))
            }
        }
    }
}

@Composable
private fun Countdown(hud: HudState, copy: TanksCopy) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.background(HouseTanksPalette.paper.copy(alpha = .78f), RoundedCornerShape(Radius.sm))
                .drawBehind { drawCornerMarks(HouseTanksPalette.steel.copy(alpha = .6f), 10.dp.toPx(), 0f, 1.5.dp.toPx()) }
                .padding(horizontal = Spacing.xxl, vertical = Spacing.md)
                .clearAndSetSemantics { contentDescription = "${hud.countdown ?: copy("house_tanks_countdown_go")}" },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Text(copy.template("house_tanks_round", "number" to hud.roundNumber.toString()).uppercase(),
                style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 15.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp),
                color = HouseTanksPalette.umber)
            Box {
                val text = hud.countdown?.toString() ?: copy("house_tanks_countdown_go")
                val style = TextStyle(fontSize = 84.sp, fontWeight = FontWeight.Black, letterSpacing = (-2).sp)
                Text(text, style = style, color = HouseTanksPalette.paper, modifier = Modifier.padding(start = 3.dp, top = 3.dp))
                Text(text, style = style, color = HouseTanksPalette.steel)
            }
        }
    }
}

/** A field report on paper: kicker, verdict, the round tally and the next order. */
@Composable
private fun ReportOverlay(
    kicker: String, icon: ImageVector, accent: Color, title: String, detail: String, players: List<TanksPlayer>?,
    copy: TanksCopy, primaryTitle: String, primaryIcon: ImageVector, primaryColor: Color, onPrimary: () -> Unit,
    onDrillSetup: () -> Unit, onExit: () -> Unit,
) {
    Box(
        Modifier.fillMaxSize().background(HouseTanksFieldTheme.ink.copy(alpha = .34f))
            .pointerInput(Unit) { awaitEachGesture { awaitFirstDown(); waitForUpOrCancellation() } },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.windowInsetsPadding(WindowInsets.safeDrawing).verticalScroll(rememberScrollState())
                .padding(Spacing.lg).widthIn(max = 470.dp).fillMaxWidth()
                .background(HouseTanksPalette.paper, RoundedCornerShape(Radius.sm))
                .fieldCard(Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                Box(Modifier.size(48.dp).background(accent, RoundedCornerShape(Radius.sm)), contentAlignment = Alignment.Center) {
                    Icon(icon, null, Modifier.size(24.dp), tint = HouseTanksPalette.paper)
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(kicker.uppercase(), style = HouseTanksFieldTheme.stencil.copy(letterSpacing = 1.4.sp), color = HouseTanksPalette.umber)
                    Text(title, style = FausCrewType.title2.copy(fontWeight = FontWeight.Black, letterSpacing = (-0.4).sp),
                        color = HouseTanksFieldTheme.ink)
                }
            }
            Text(detail, style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted)
            players?.let { Scoreboard(it, copy) }
            BoxWithConstraints(Modifier.padding(top = Spacing.xs)) {
                val secondary = @Composable { modifier: Modifier ->
                    OverlayButton(copy("house_tanks_exit"), null, modifier, onExit)
                    OverlayButton(copy("house_tanks_back_to_drill"), Icons.Rounded.Tune, modifier, onDrillSetup)
                }
                val primary = @Composable { modifier: Modifier ->
                    RaisedButton(primaryColor, onPrimary, modifier, offset = 3.dp) {
                        Row(
                            Modifier.fillMaxWidth().heightIn(min = 48.dp).background(primaryColor, RoundedCornerShape(Radius.xs))
                                .padding(horizontal = Spacing.sm),
                            horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(primaryIcon, null, Modifier.size(18.dp), tint = HouseTanksPalette.paper)
                            Text(primaryTitle, style = FausCrewType.headline, color = HouseTanksPalette.paper, maxLines = 1)
                        }
                    }
                }
                // Three orders share a row when they fit; otherwise the main one gets its own.
                if (maxWidth >= 420.dp) {
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        secondary(Modifier.weight(1f))
                        primary(Modifier.weight(1f))
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        primary(Modifier.fillMaxWidth())
                        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) { secondary(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun OverlayButton(title: String, icon: ImageVector?, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.xs)
    Row(
        modifier.heightIn(min = 48.dp).clip(shape).background(HouseTanksPalette.paper, shape)
            .border(1.dp, HouseTanksPalette.slate.copy(alpha = .5f), shape).scaleButton(onClick = onClick)
            .padding(horizontal = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) Icon(icon, null, Modifier.size(16.dp), tint = HouseTanksFieldTheme.ink)
        Text(title, style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = HouseTanksFieldTheme.ink,
            maxLines = 1, textAlign = TextAlign.Center)
    }
}

/** Round wins per tank, leader first. */
@Composable
private fun Scoreboard(players: List<TanksPlayer>, copy: TanksCopy) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        players.sortedByDescending { it.roundsWon }.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                row.forEach { player ->
                    Row(
                        Modifier.weight(1f).heightIn(min = 30.dp).background(HouseTanksPalette.sand.copy(alpha = .45f), RoundedCornerShape(Radius.xs))
                            .padding(horizontal = Spacing.sm)
                            .clearAndSetSemantics { contentDescription = "${copy(player.nameKey)}, ${copy("house_tanks_round_score")} ${player.roundsWon}" },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Box(Modifier.size(9.dp).clip(CircleShape).background(player.color.ink))
                        Text(copy(player.nameKey), style = FausCrewType.caption.copy(fontWeight = FontWeight.Bold),
                            color = HouseTanksFieldTheme.ink, maxLines = 1, modifier = Modifier.weight(1f))
                        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                            for (index in 0 until 3) {
                                Box(Modifier.size(8.dp).background(
                                    if (index < player.roundsWon) HouseTanksPalette.umber else HouseTanksPalette.slate.copy(alpha = .2f)))
                            }
                        }
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}
