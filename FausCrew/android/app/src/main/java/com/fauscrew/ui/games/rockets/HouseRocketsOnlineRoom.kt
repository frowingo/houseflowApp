package com.fauscrew.ui.games.rockets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CellTower
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Flag
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.HighlightOff
import androidx.compose.material.icons.rounded.HourglassTop
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.RocketsColor
import com.fauscrew.platform.RocketsLobbyColors
import com.fauscrew.ui.games.reportsOnScreen
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton

/** The room's monospaced labels ("01 /", the ready count). */
internal val RocketsStencil = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp, fontWeight = FontWeight.Black)

/** The room's cream card on the light preparation backdrop. */
internal fun Modifier.rocketsRoomCard(): Modifier =
    fillMaxWidth().background(HouseRocketsPreparationTheme.surface, RoundedCornerShape(Radius.xl)).padding(Spacing.lg)

/** `HouseRocketsSectionHeader`: the room's numbered section title ("01 / Launch countdown"). */
@Composable
internal fun RocketsSectionHeader(code: String?, title: String, modifier: Modifier = Modifier) {
    Row(modifier.semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        if (code != null) {
            Text("$code /", style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 15.sp, fontWeight = FontWeight.Bold),
                color = HouseRocketsPreparationTheme.accent, modifier = Modifier.clearAndSetSemantics {})
        }
        Text(title, style = FausCrewType.title3.copy(fontWeight = FontWeight.Bold), color = HouseRocketsPreparationTheme.ink)
    }
}

internal fun RocketsColor.nameKey(): String = "house_rockets_color_$raw"

/**
 * `HouseRocketsOnlineLobbyView`: the online room in Faus Tanks' order — the room status, 01 the
 * launch countdown, 02 the rocket color, 03 the crew with ready and cancel under it (How to
 * play follows as 04). Presentation only; commands and deadlines live in Core.
 */
@Composable
internal fun HouseRocketsOnlineRoom(
    state: OnlineLobbyUi,
    colors: RocketsLobbyColors,
    copy: RocketsCopy,
    memberNames: Map<String, String>,
    orientationFailed: Boolean,
    onReady: () -> Unit,
    onRetry: () -> Unit,
    onCancel: () -> Unit,
    onSelectColor: (RocketsColor) -> Unit,
    onStartCardVisible: (Boolean) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
        StatusCard(state, copy, orientationFailed, onRetry)
        DisposableEffect(Unit) { onDispose { onStartCardVisible(true) } }
        Column(Modifier.reportsOnScreen(onChange = onStartCardVisible), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            RocketsSectionHeader("01", copy("house_rockets_online_start_title"))
            Box(Modifier.rocketsRoomCard()) { StartCountdown(state, copy) }
        }
        ColorPicker(colors, copy, onSelectColor)
        Crew(state, colors, copy, memberNames, onReady, onCancel)
    }
}

@Composable
private fun StatusCard(state: OnlineLobbyUi, copy: RocketsCopy, orientationFailed: Boolean, onRetry: () -> Unit) {
    val ink = HouseRocketsPreparationTheme.ink
    val muted = HouseRocketsPreparationTheme.muted
    val danger = HouseRocketsPreparationTheme.danger
    val accent = HouseRocketsPreparationTheme.accent
    val now = rememberOnlineNow()
    Column(Modifier.rocketsRoomCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(Modifier.size(28.dp), contentAlignment = Alignment.Center) {
                if (state.showsProgress) {
                    CircularProgressIndicator(Modifier.size(20.dp), color = accent, strokeWidth = 2.dp)
                } else {
                    Icon(when {
                        state.isFailed -> Icons.Rounded.WifiOff
                        state.isTerminal -> Icons.Rounded.Flag
                        else -> Icons.Rounded.CellTower
                    }, null, Modifier.size(22.dp), tint = if (state.isFailed) danger else accent)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text(copy(state.statusKey), style = FausCrewType.headline, color = if (state.isFailed) danger else ink)
                Text(copy.template(state.detailKey, "minimum" to "${state.minimumPlayers}"),
                    style = FausCrewType.subheadline, color = muted)
                if (state.isReconnecting) {
                    Text(copy.template("house_rockets_reconnect_wait", "seconds" to "${remaining(state.retryNotBefore, now) ?: 0}"),
                        style = FausCrewType.caption.copy(fontFeatureSettings = "tnum"), color = muted)
                }
                if (state.issueKey != null && !state.isReconnecting) {
                    Text(copy(state.issueKey), style = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold), color = danger)
                }
                if (orientationFailed) {
                    Text(copy("house_rockets_landscape_error"), style = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold),
                        color = danger)
                }
            }
        }
        if (state.isFailed && state.canRetry) {
            val wait = remaining(state.retryNotBefore, now) ?: 0
            val enabled = wait == 0
            Row(
                Modifier.heightIn(min = 36.dp).alpha(if (enabled) 1f else .5f)
                    .scaleButton(enabled = enabled, onClick = onRetry)
                    .background(accent, RoundedCornerShape(Radius.sm)).padding(horizontal = Spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Icon(Icons.Rounded.Refresh, null, Modifier.size(16.dp), tint = HouseRocketsPreparationTheme.surface)
                Text(copy.template(if (wait > 0) "house_rockets_online_retry_after" else "house_rockets_online_retry",
                    "seconds" to "$wait"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold),
                    color = HouseRocketsPreparationTheme.surface)
            }
        }
    }
}

/** The ready window's (then the countdown's) seconds, large; before the window opens, what starts it. */
@Composable
private fun StartCountdown(state: OnlineLobbyUi, copy: RocketsCopy) {
    val now = rememberOnlineNow()
    val deadline = if (state.deadlineKind == "countdown") state.flightCountdownUptime ?: state.deadlineUptime
        else state.deadlineUptime.takeIf { state.deadlineKind != null }
    val seconds = remaining(deadline, now)
    val ink = HouseRocketsPreparationTheme.ink
    val muted = HouseRocketsPreparationTheme.muted
    val line = ink.copy(alpha = .3f)
    Column(
        Modifier.fillMaxWidth().aspectRatio(872f / 400f).clip(RoundedCornerShape(Radius.sm))
            .background(HouseRocketsPalette.ice.copy(alpha = .35f))
            .drawBehind {
                val inset = 0.5.dp.toPx()
                drawRoundRect(line, topLeft = androidx.compose.ui.geometry.Offset(inset, inset),
                    size = androidx.compose.ui.geometry.Size(size.width - inset * 2, size.height - inset * 2),
                    cornerRadius = CornerRadius(Radius.sm.toPx()),
                    style = Stroke(1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))))
            }
            .padding(Spacing.md)
            .clearAndSetSemantics {
                contentDescription = if (seconds != null) copy.template("house_rockets_online_seconds", "seconds" to "$seconds")
                else copy("house_rockets_online_start_waiting")
            },
        verticalArrangement = Arrangement.spacedBy(Spacing.xs, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (seconds != null) {
            Text(copy("house_rockets_online_start_until"), style = RocketsStencil, color = muted)
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Text("$seconds", style = TextStyle(fontSize = 88.sp, fontWeight = FontWeight.Black, fontFeatureSettings = "tnum",
                    lineHeight = 88.sp), color = if (seconds <= 5) HouseRocketsPreparationTheme.danger else ink)
                Text(copy("house_rockets_online_seconds_unit"), style = FausCrewType.title3.copy(fontWeight = FontWeight.ExtraBold),
                    color = muted, modifier = Modifier.padding(bottom = 14.dp))
            }
        } else {
            Icon(Icons.Rounded.HourglassTop, null, Modifier.size(40.dp), tint = HouseRocketsPreparationTheme.accent)
            Text(copy("house_rockets_online_start_waiting"), style = FausCrewType.headline, color = ink)
            Text(copy.template("house_rockets_online_start_waiting_detail", "minimum" to "${state.minimumPlayers}"),
                style = FausCrewType.caption, color = muted, textAlign = TextAlign.Center)
        }
        if (state.sessionState != null) {
            Text(copy.template("house_rockets_ready_count", "ready" to "${state.readyCount}",
                "total" to "${state.participants.size}"), style = RocketsStencil, color = HouseRocketsPreparationTheme.accent)
        }
    }
}

/**
 * The online room's rocket color (Faus Switch's and Faus Tanks' rules, from Core): colors other
 * players hold are taken, the selection is the color the server gives this player, and a ready
 * player's color is locked until they take the ready back.
 */
@Composable
private fun ColorPicker(colors: RocketsLobbyColors, copy: RocketsCopy, onSelectColor: (RocketsColor) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        RocketsSectionHeader("02", copy("house_rockets_online_color_title"))
        Column(Modifier.rocketsRoomCard(), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            RocketsColor.entries.chunked(4).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    row.forEach { color ->
                        val selected = colors.local == color
                        val taken = color in colors.takenByOthers
                        RocketSwatch(color, copy, selected, enabled = !taken && !colors.isLocked, Modifier.weight(1f),
                            taken = taken, dimmed = taken || (colors.isLocked && !selected)) { onSelectColor(color) }
                    }
                }
            }
            val note = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold)
            if (colors.isLocked) {
                RocketsLabel(Icons.Rounded.Lock, copy("house_rockets_online_color_locked"), note,
                    HouseRocketsPreparationTheme.muted, iconSize = 14.dp)
            } else if (colors.isPreferredTaken) {
                RocketsLabel(Icons.Rounded.Group, copy("house_rockets_online_color_taken"), note,
                    HouseRocketsPreparationTheme.danger, iconSize = 14.dp)
            }
            Text(copy("house_rockets_online_color_note"), style = FausCrewType.caption, color = HouseRocketsPreparationTheme.muted)
        }
    }
}

@Composable
private fun RocketSwatch(
    color: RocketsColor, copy: RocketsCopy, selected: Boolean, enabled: Boolean, modifier: Modifier,
    taken: Boolean, dimmed: Boolean, onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.sm)
    val name = copy(color.nameKey())
    val cream = HouseRocketsPalette.cream
    Box(
        modifier.alpha(if (dimmed) .45f else 1f)
            .then(if (selected) Modifier.border(2.5.dp, HouseRocketsPalette.player(color).takeIf { color != RocketsColor.MINT }
                ?: HouseRocketsPalette.navy, RoundedCornerShape(Radius.sm + 3.dp)).padding(3.dp) else Modifier)
            .clip(shape).background(HouseRocketsPalette.navy, shape)
            .clickable(enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .semantics {
                this.selected = selected
                contentDescription = if (taken) "$name, ${copy("house_rockets_color_taken")}" else name
            },
    ) {
        Column(Modifier.fillMaxWidth().padding(vertical = Spacing.sm, horizontal = 2.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            HouseRocketsColorRocket(color, Modifier.size(46.dp))
            Text(name, style = FausCrewType.caption.copy(fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold),
                color = cream.copy(alpha = if (selected) 1f else .8f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (selected) {
            Icon(Icons.Rounded.CheckCircle, null, Modifier.align(Alignment.TopEnd).padding(5.dp).size(14.dp), tint = cream)
        } else if (taken) {
            Box(Modifier.align(Alignment.TopEnd).padding(4.dp).size(18.dp).clip(CircleShape).background(cream),
                contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Person, null, Modifier.size(11.dp), tint = HouseRocketsPalette.navy)
            }
        }
    }
}

/** The session's players, the local one first; each with their rocket in color, then ready and cancel. */
@Composable
private fun Crew(
    state: OnlineLobbyUi, colors: RocketsLobbyColors, copy: RocketsCopy, memberNames: Map<String, String>,
    onReady: () -> Unit, onCancel: () -> Unit,
) {
    val ink = HouseRocketsPreparationTheme.ink
    val muted = HouseRocketsPreparationTheme.muted
    val accent = HouseRocketsPreparationTheme.accent
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(verticalAlignment = Alignment.Bottom) {
            RocketsSectionHeader("03", copy("house_rockets_online_roster"), Modifier.weight(1f))
            if (state.sessionState != null) {
                Text(copy.template("house_rockets_ready_count", "ready" to "${state.readyCount}",
                    "total" to "${state.participants.size}"), style = RocketsStencil, color = muted)
            }
        }
        Column(Modifier.rocketsRoomCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            val players = state.participants.filter { it.isLocal } + state.participants.filter { !it.isLocal }
            if (players.isEmpty()) {
                Text(copy("house_rockets_online_syncing_roster"), style = FausCrewType.subheadline, color = muted)
            }
            players.forEach { player ->
                val color = player.color?.let(RocketsColor::from) ?: colors.local.takeIf { player.isLocal }
                Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    Box(Modifier.size(34.dp).clip(CircleShape).background(HouseRocketsPalette.navy), contentAlignment = Alignment.Center) {
                        if (color != null) {
                            HouseRocketsColorRocket(color, Modifier.size(26.dp))
                        } else {
                            Box(Modifier.size(14.dp).clip(CircleShape).background(HouseRocketsPalette.cream.copy(alpha = .3f)))
                        }
                    }
                    val name = memberNames[player.playerId]
                    Text(name ?: copy(if (player.isLocal) "house_rockets_you" else "house_rockets_member"),
                        style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = ink, maxLines = 1,
                        overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (player.isLocal && name != null) {
                        Text(copy("house_rockets_you"), style = FausCrewType.caption, color = muted)
                    }
                    Spacer(Modifier.weight(1f).widthIn(min = 8.dp))
                    RocketsLabel(if (player.isReady) Icons.Rounded.CheckCircle else Icons.Rounded.Schedule,
                        copy(player.statusKey), FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold),
                        if (player.isReady) accent else muted, spacing = Spacing.xs)
                }
            }
            // Ready and the creator's cancel sit right under the crew while the room is a lobby.
            if (state.isLobby && !state.isFailed && !state.isTerminal) {
                Actions(state, copy, onReady, onCancel)
            }
        }
    }
}

/** Ready (in the portrait room; the countdown turns the screen) and the creator's cancel. */
@Composable
private fun Actions(state: OnlineLobbyUi, copy: RocketsCopy, onReady: () -> Unit, onCancel: () -> Unit) {
    val surface = HouseRocketsPreparationTheme.surface
    val enabled = state.canChangeReady
    Column(Modifier.padding(top = Spacing.xs), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Row(
            Modifier.fillMaxWidth().height(56.dp).alpha(if (state.canChangeReady) 1f else .5f)
                .scaleButton(enabled = enabled, onClick = onReady)
                .background(if (state.localReady) HouseRocketsPalette.navy else HouseRocketsPreparationTheme.accent,
                    RoundedCornerShape(Radius.lg)),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(if (state.localReady) Icons.Rounded.HighlightOff else Icons.Rounded.CheckCircle, null,
                Modifier.size(20.dp), tint = surface)
            Text(copy(if (state.localReady) "house_rockets_not_ready_action" else "house_rockets_ready_action"),
                style = FausCrewType.headline, color = surface)
        }
        Text(copy("house_rockets_online_ready_detail"), style = FausCrewType.caption, color = HouseRocketsPreparationTheme.muted)
        if (state.canCancel) {
            Box(Modifier.heightIn(min = 44.dp).clickable(role = Role.Button, onClick = onCancel),
                contentAlignment = Alignment.CenterStart) {
                Text(copy("house_rockets_cancel_flight"), style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold,
                    color = HouseRocketsPreparationTheme.danger)
            }
        }
    }
}

/** How to play as tiny looping clips with a few words each; the full sentence stays for TalkBack. */
@Composable
internal fun RocketsFlightGuide(copy: RocketsCopy, code: String?) {
    val reduceMotion = rememberReduceMotion()
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        RocketsSectionHeader(code, copy("house_rockets_how_to_play"))
        Column(Modifier.rocketsRoomCard(), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
            RocketsRuleClip.entries.chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    row.forEach { clip ->
                        Column(
                            Modifier.weight(1f).clearAndSetSemantics {
                                contentDescription = "${copy(clip.titleKey)}. ${copy(clip.detailKey)}"
                            },
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            HouseRocketsRuleClipView(clip, reduceMotion)
                            Text(copy(clip.titleKey), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold),
                                color = HouseRocketsPreparationTheme.ink, maxLines = 2)
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}
