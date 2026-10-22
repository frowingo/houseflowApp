package com.fauscrew.ui.games.rockets

import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.KeyboardDoubleArrowRight
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.People
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.RocketsColor
import com.fauscrew.platform.RocketsEffect
import com.fauscrew.platform.RocketsFrame
import com.fauscrew.platform.RocketsPhase
import com.fauscrew.platform.RocketsPlayer
import com.fauscrew.platform.RocketsRegion
import com.fauscrew.platform.RocketsRole
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

/** What the HUD shows; it changes a few times per second, unlike the course. */
private data class HudModel(
    val phase: RocketsPhase,
    val seconds: Int,
    val aliveCount: Int,
    val countdown: Int?,
    val turnTargetIsVertical: Boolean?,
    val humanAlive: Boolean,
    val humanEffect: RocketsEffect?,
    val players: List<HudPlayer>,
    val regions: List<RocketsRegion>,
    val winner: HudPlayer?,
    val hasWinner: Boolean,
)

private data class HudPlayer(val nameKey: String, val role: RocketsRole, val color: RocketsColor, val alive: Boolean)

private fun RocketsPlayer.hud() = HudPlayer(nameKey, role, color, isAlive)

/** Android's "Remove animations" setting, iOS's Reduce Motion. */
@Composable
internal fun rememberReduceMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
}

/** The SpriteKit scene: draws [frameState] in SpriteKit's y-up space, reading it only while drawing. */
@Composable
internal fun HouseRocketsCourseCanvas(frameState: State<RocketsFrame?>, reduceMotion: Boolean) {
    val renderer = remember { HouseRocketsCourseRenderer() }
    Box(
        Modifier.fillMaxSize().drawBehind {
            val frame = frameState.value ?: return@drawBehind
            drawIntoCanvas { canvas ->
                val native = canvas.nativeCanvas
                val width = size.width / density
                val height = size.height / density
                native.save()
                native.scale(density, density)
                // SpriteKit's scene space: origin bottom-left, y up.
                native.translate(0f, height)
                native.scale(1f, -1f)
                renderer.draw(native, frame, width, height, reduceMotion)
                native.restore()
            }
        },
    )
}

/** `HouseRocketsView.gameLayer`: the SpriteKit course plus its SwiftUI overlays. */
@Composable
internal fun HouseRocketsGameLayer(
    frameState: State<RocketsFrame?>,
    copy: RocketsCopy,
    isForeground: Boolean,
    onSteer: (Double) -> Unit,
    onEndSteering: () -> Unit,
    onAdjust: (Double) -> Unit,
    onFrame: (Long) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onRestart: () -> Unit,
    onExit: () -> Unit,
) {
    val reduceMotion = rememberReduceMotion()
    val hud by remember {
        derivedStateOf {
            frameState.value?.let { frame ->
                HudModel(
                    phase = frame.phase, seconds = frame.elapsed.toInt(), aliveCount = frame.aliveCount,
                    countdown = frame.countdown, turnTargetIsVertical = frame.turnTargetIsVertical,
                    humanAlive = frame.human?.isAlive == true, humanEffect = frame.human?.effect,
                    players = frame.players.map { it.hud() }, regions = frame.regions,
                    winner = frame.winner?.hud(), hasWinner = frame.winnerId != null,
                )
            }
        }
    }
    val matchId by remember { derivedStateOf { frameState.value?.matchId } }
    val lastEliminatedId by remember { derivedStateOf { frameState.value?.lastEliminatedId } }
    val humanHeading by remember { derivedStateOf { frameState.value?.human?.heading ?: 0.0 } }
    val model = hud ?: return
    val isPlaying = model.phase == RocketsPhase.PLAYING

    // One physics step per display frame while playing, like SpriteView's update loop.
    LaunchedEffect(isPlaying, isForeground) {
        if (!isPlaying || !isForeground) return@LaunchedEffect
        while (true) withFrameNanos(onFrame)
    }

    var eliminationNotice by remember(matchId) { mutableStateOf<String?>(null) }
    LaunchedEffect(lastEliminatedId) {
        val id = lastEliminatedId ?: return@LaunchedEffect
        val player = frameState.value?.players?.firstOrNull { it.id == id } ?: return@LaunchedEffect
        eliminationNotice = if (player.role == RocketsRole.HUMAN) copy("house_rockets_eliminated")
        else copy.template("house_rockets_bot_eliminated", "name" to copy(player.nameKey))
        delay(1_800)
        eliminationNotice = null
    }

    HouseRocketsCourseCanvas(frameState, reduceMotion)
    Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        if (isPlaying && model.humanAlive && isForeground) {
            FloatingJoystick(humanHeading, copy("house_rockets_joystick"), copy("house_rockets_joystick_hint"),
                onSteer, onEndSteering, onAdjust)
        }
        if (isPlaying || model.phase == RocketsPhase.COUNTDOWN) {
            InformationLayer(model, copy, eliminationNotice, onPause)
        }
        when (model.phase) {
            RocketsPhase.PAUSED -> StateOverlay(copy("house_rockets_paused"), null, copy("house_rockets_resume"),
                copy("house_rockets_exit"), onResume, onExit)
            RocketsPhase.ENDED -> {
                val title = when {
                    model.winner == null -> copy("house_rockets_draw")
                    model.winner.role == RocketsRole.HUMAN -> copy("house_rockets_won")
                    else -> copy.template("house_rockets_lost", "name" to copy(model.winner.nameKey))
                }
                StateOverlay(title, copy(if (model.hasWinner) "house_rockets_result_detail" else "house_rockets_draw_detail"),
                    copy("house_rockets_rematch"), copy("house_rockets_exit"), onRestart, onExit)
            }
            else -> Unit
        }
    }
}

@Composable
private fun BoxScope.InformationLayer(model: HudModel, copy: RocketsCopy, eliminationNotice: String?, onPause: () -> Unit) {
    val isPlaying = model.phase == RocketsPhase.PLAYING
    // Pause remains available while informational labels are hidden during a turn.
    if (model.regions.isEmpty() && isPlaying) {
        PauseButton(copy, onPause, Modifier.offset(8.dp, 8.dp))
    }
    CompositionLocalProvider(
        LocalContentColor provides HouseRocketsTheme.ink,
        LocalTextStyle provides FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"),
    ) {
        model.regions.forEachIndexed { index, region ->
            val compact = region.width < 340
            Box(
                Modifier.offset { IntOffset(region.x.dp.roundToPx(), region.y.dp.roundToPx()) }
                    .size(region.width.dp, region.height.dp),
                contentAlignment = Alignment.TopCenter,
            ) {
                if (index == 0) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        if (isPlaying) PauseButton(copy, onPause)
                        val content: @Composable () -> Unit = {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                                HudLabel(Icons.Outlined.Timer, "${model.seconds}",
                                    Modifier.semantics { contentDescription = copy("house_rockets_time") + " ${model.seconds}" })
                                HudLabel(Icons.Rounded.People, "${model.aliveCount}",
                                    Modifier.semantics {
                                        contentDescription = copy.template("house_rockets_alive", "count" to "${model.aliveCount}")
                                    })
                            }
                            if (model.humanAlive && model.humanEffect != null) {
                                val boost = model.humanEffect == RocketsEffect.BOOST
                                HudLabel(if (boost) Icons.Rounded.KeyboardDoubleArrowRight else Icons.Rounded.Pause,
                                    copy(if (boost) "house_rockets_boost_active" else "house_rockets_slow_active"),
                                    color = HouseRocketsTheme.accent)
                            }
                            DirectionCue(model, copy)
                        }
                        if (compact) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(Spacing.xs)) { content() }
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(Spacing.md)) { content() }
                        }
                    }
                } else {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                        val notice: @Composable () -> Unit = {
                            if (eliminationNotice != null) {
                                Text(eliminationNotice, color = HouseRocketsTheme.danger, maxLines = 1)
                            } else if (!model.humanAlive) {
                                HudLabel(Icons.Outlined.Visibility, copy("house_rockets_spectating_short"),
                                    color = HouseRocketsTheme.muted)
                            }
                        }
                        if (compact) {
                            Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs),
                                horizontalAlignment = Alignment.CenterHorizontally) {
                                model.players.chunked(2).forEach { pair ->
                                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                                        pair.forEach { PlayerLabel(it, copy, Modifier.weight(1f)) }
                                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                                    }
                                }
                                notice()
                            }
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                                    model.players.forEach { PlayerLabel(it, copy) }
                                }
                                notice()
                            }
                        }
                        DirectionCue(model, copy)
                    }
                }
            }
        }
    }
}

@Composable
private fun PauseButton(copy: RocketsCopy, onPause: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier.size(44.dp).clip(CircleShape).background(HouseRocketsTheme.panel)
            .clickable(role = Role.Button, onClickLabel = copy("house_rockets_pause"), onClick = onPause)
            .semantics { contentDescription = copy("house_rockets_pause") },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Icons.Rounded.Pause, null, Modifier.size(18.dp), tint = HouseRocketsTheme.ink)
    }
}

@Composable
internal fun HudLabel(
    icon: ImageVector,
    text: String,
    modifier: Modifier = Modifier,
    color: Color = LocalContentColor.current,
) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Icon(icon, null, Modifier.size(14.dp), tint = color)
        Text(text, color = color, maxLines = 1)
    }
}

@Composable
private fun PlayerLabel(player: HudPlayer, copy: RocketsCopy, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Box(Modifier.size(7.dp).clip(CircleShape).background(HouseRocketsPalette.player(player.color))
            .border(.75.dp, HouseRocketsTheme.ink, CircleShape))
        Text(copy(player.nameKey), maxLines = 1,
            color = if (player.alive) HouseRocketsTheme.ink else HouseRocketsTheme.muted,
            textDecoration = if (player.alive) null else TextDecoration.LineThrough)
    }
}

@Composable
private fun DirectionCue(model: HudModel, copy: RocketsCopy) {
    if (model.phase == RocketsPhase.COUNTDOWN) {
        Text(model.countdown?.toString() ?: copy("house_rockets_countdown_go"),
            style = FausCrewType.title3.copy(fontWeight = FontWeight.Black), color = HouseRocketsTheme.accent)
    } else {
        val vertical = model.turnTargetIsVertical ?: return
        HudLabel(if (vertical) Icons.Rounded.ArrowUpward else Icons.AutoMirrored.Rounded.ArrowForward,
            copy("house_rockets_turn"),
            Modifier.semantics {
                contentDescription = copy(if (vertical) "house_rockets_vertical_transition" else "house_rockets_horizontal_transition")
            },
            color = HouseRocketsTheme.accent)
    }
}

@Composable
private fun StateOverlay(
    title: String,
    detail: String?,
    primary: String,
    exit: String,
    onPrimary: () -> Unit,
    onExit: () -> Unit,
) {
    Box(Modifier.fillMaxSize().background(HouseRocketsTheme.background.copy(alpha = .88f)), contentAlignment = Alignment.Center) {
        Column(
            Modifier.padding(Spacing.xl).widthIn(max = 430.dp)
                .background(HouseRocketsTheme.panel, RoundedCornerShape(Radius.xl))
                .padding(Spacing.xl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            HouseRocketsRocketMark(Modifier.size(64.dp))
            Text(title, style = FausCrewType.title, color = HouseRocketsTheme.ink, textAlign = TextAlign.Center)
            if (detail != null) {
                Text(detail, style = FausCrewType.subheadline, color = HouseRocketsTheme.muted, textAlign = TextAlign.Center)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                CapsuleButton(exit, HouseRocketsTheme.ink, Color.White.copy(alpha = .14f),
                    Modifier.weight(1f), onClick = onExit)
                CapsuleButton(primary, HouseRocketsTheme.background, HouseRocketsTheme.accent, Modifier.weight(1f), onClick = onPrimary)
            }
        }
    }
}

/** iOS 26 `.bordered` / `.borderedProminent` buttons: full capsules, 48 pt tall here. */
@Composable
internal fun CapsuleButton(
    text: String,
    content: Color,
    fill: Color,
    modifier: Modifier,
    enabled: Boolean = true,
    minHeight: androidx.compose.ui.unit.Dp = 48.dp,
    onClick: () -> Unit,
) {
    Box(
        modifier.heightIn(min = minHeight).fillMaxWidth()
            .alpha(if (enabled) 1f else .45f)
            .clip(CircleShape).background(fill)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .padding(horizontal = Spacing.lg),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = FausCrewType.body, color = content, maxLines = 1)
    }
}

/**
 * `HouseRocketsFloatingJoystick`: touches in the outer 30 % of either edge steer. The stick
 * appears at the touch-down point while dragging and disappears on release; the rocket
 * keeps its heading. Accessibility actions turn by 15°.
 */
@Composable
internal fun FloatingJoystick(
    heading: Double,
    label: String,
    hint: String,
    onSteer: (Double) -> Unit,
    onEnd: () -> Unit,
    onAdjust: (Double) -> Unit,
) {
    val density = LocalDensity.current
    var start by remember { mutableStateOf<Offset?>(null) }
    var translation by remember { mutableStateOf(Offset.Zero) }
    val minimumDistance = with(density) { 5.dp.toPx() }
    Box(
        Modifier.fillMaxSize()
            .pointerInput(Unit) {
                awaitEachGesture {
                    val down = awaitFirstDown(requireUnconsumed = false)
                    val zone = size.width * .3f
                    if (down.position.x > zone && down.position.x < size.width - zone) return@awaitEachGesture
                    var active = false
                    try {
                        while (true) {
                            val change = awaitPointerEvent().changes.firstOrNull { it.id == down.id } ?: break
                            if (!change.pressed) break
                            val delta = change.position - down.position
                            if (!active && delta.getDistance() > minimumDistance) {
                                active = true
                                start = down.position
                            }
                            if (active) {
                                change.consume()
                                translation = delta
                                onSteer(atan2(-delta.y.toDouble(), delta.x.toDouble()))
                            }
                        }
                    } finally {
                        if (active) {
                            start = null
                            translation = Offset.Zero
                            onEnd()
                        }
                    }
                }
            }
            .semantics {
                contentDescription = "$label. $hint"
                stateDescription = "${(heading * 180 / Math.PI).roundToInt()}°"
                customActions = listOf(
                    CustomAccessibilityAction("+15°") { onAdjust(Math.PI / 12); true },
                    CustomAccessibilityAction("-15°") { onAdjust(-Math.PI / 12); true },
                )
            },
    ) {
        val origin = start
        if (origin != null && translation.getDistance() > minimumDistance) {
            val pointsTranslation = translation / density.density
            val distance = hypot(pointsTranslation.x, pointsTranslation.y)
            val scale = min(1f, 34f / maxOf(distance, 1f))
            val angle = Math.toDegrees(atan2(pointsTranslation.y.toDouble(), pointsTranslation.x.toDouble())).toFloat()
            Box(
                Modifier.offset { IntOffset((origin.x - 58.dp.toPx()).roundToInt(), (origin.y - 58.dp.toPx()).roundToInt()) }
                    .size(116.dp).alpha(.55f),
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.fillMaxSize().clip(CircleShape).background(HouseRocketsTheme.panel)
                    .border(2.dp, HouseRocketsTheme.accent, CircleShape))
                Box(
                    Modifier.offset((pointsTranslation.x * scale).dp, (pointsTranslation.y * scale).dp)
                        .size(44.dp).clip(CircleShape).background(HouseRocketsTheme.accent),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, Modifier.size(22.dp).rotate(angle),
                        tint = HouseRocketsTheme.background)
                }
            }
        }
    }
}
