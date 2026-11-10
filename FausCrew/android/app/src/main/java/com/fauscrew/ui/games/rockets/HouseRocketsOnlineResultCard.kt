package com.fauscrew.ui.games.rockets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.material.icons.automirrored.rounded.List
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.HighlightOff
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.OnlineResultUi
import com.fauscrew.platform.RocketsColor
import com.fauscrew.platform.RocketsLobbyColors
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton
import java.util.Locale

/**
 * `HouseRocketsOnlineResultView`: the end menu over the frozen course, like Faus Tanks' and
 * Faus Switch's — the result (persisted ranks as supplied, ties and unranked cancellations
 * included), then Back to Lobby (the portrait online room) and Play Again (a new flight with
 * the crew that stays). The card fits the landscape screen; only the standings scroll.
 */
@Composable
internal fun HouseRocketsOnlineResultCard(
    state: OnlineResultUi,
    copy: RocketsCopy,
    memberNames: Map<String, String>,
    canReturnToLobby: Boolean,
    onRetry: () -> Unit,
    onBackToLobby: () -> Unit,
    onPlayAgain: () -> Unit,
) {
    val locale = Locale.getDefault()
    val ink = HouseRocketsPreparationTheme.ink
    val muted = HouseRocketsPreparationTheme.muted
    fun name(id: String, fallback: String?, isLocal: Boolean) =
        fallback ?: memberNames[id] ?: copy(if (isLocal) "house_rockets_you" else "house_rockets_member")
    val title = state.winnerId?.let { winner ->
        val player = state.players.firstOrNull { it.playerId == winner }
        copy.template("house_rockets_lost", "name" to name(winner, player?.name, player?.isLocal == true))
    } ?: copy(state.titleKey)
    ArenaCard {
        Column(
            Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            HouseRocketsRocketMark(Modifier.size(34.dp))
            Text(title, Modifier.semantics { heading() }, style = FausCrewType.title3, fontWeight = FontWeight.Black,
                color = ink, textAlign = TextAlign.Center)
            Text(copy(state.detailKey), style = FausCrewType.subheadline, color = muted, textAlign = TextAlign.Center)
            if (state.isWaiting || state.phase == "idle") {
                CircularProgressIndicator(Modifier.size(20.dp), color = HouseRocketsPreparationTheme.accent, strokeWidth = 2.dp)
            }
            state.durationSeconds?.let { seconds ->
                RocketsLabel(Icons.Outlined.Timer,
                    copy.template("house_rockets_result_duration", "seconds" to String.format(locale, "%.1f", seconds)),
                    FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold, fontFeatureSettings = "tnum"), muted)
            }
            if (state.players.isNotEmpty()) {
                Column(Modifier.padding(top = Spacing.xs), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                    state.players.forEach { player ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                            Text(player.rank?.let { "$it." } ?: "—", Modifier.width(28.dp),
                                style = FausCrewType.subheadline.copy(fontFeatureSettings = "tnum"),
                                fontWeight = FontWeight.Black, color = ink)
                            player.color?.let { RocketBadge(it) }
                            Text(name(player.playerId, player.name, player.isLocal), Modifier.weight(1f, fill = false),
                                style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = ink,
                                maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (player.isLocal) Text(copy("house_rockets_you"), style = FausCrewType.caption, color = muted)
                            Spacer(Modifier.weight(1f))
                            Text(copy.template("house_rockets_result_distance",
                                "distance" to String.format(locale, "%.0f", player.distance)),
                                style = FausCrewType.caption.copy(fontFeatureSettings = "tnum"),
                                fontWeight = FontWeight.SemiBold, color = muted)
                        }
                    }
                }
            }
        }
        if (state.isFailed && state.canRetry) {
            val now = rememberOnlineNow(1_000)
            val wait = remaining(state.retryNotBefore, now) ?: 0
            Row {
                ArenaButton(copy.template(if (wait > 0) "house_rockets_result_retry_after" else "house_rockets_result_retry",
                    "seconds" to "$wait"), Icons.Rounded.Refresh, isPrimary = false, enabled = wait == 0, onClick = onRetry)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ArenaButton(copy("house_rockets_back_to_lobby"), Icons.AutoMirrored.Rounded.List, isPrimary = false,
                enabled = canReturnToLobby, onClick = onBackToLobby)
            ArenaButton(copy("house_rockets_rematch"), Icons.Rounded.Replay, isPrimary = true,
                enabled = state.canRematch, onClick = onPlayAgain)
        }
    }
}

/**
 * `HouseRocketsOnlineReplayRoom`: Play Again's new room over the last flight's frozen course,
 * until the new flight's countdown — who is in and ready (the player is made ready on
 * joining), the room's deadline, the ready toggle and Back to Lobby.
 */
@Composable
internal fun HouseRocketsOnlineReplayRoom(
    state: OnlineLobbyUi,
    colors: RocketsLobbyColors,
    copy: RocketsCopy,
    memberNames: Map<String, String>,
    onReady: (Boolean) -> Unit,
    onRetry: () -> Unit,
    onBackToLobby: () -> Unit,
) {
    val ink = HouseRocketsPreparationTheme.ink
    val muted = HouseRocketsPreparationTheme.muted
    val accent = HouseRocketsPreparationTheme.accent
    val inRoom = state.isLobby && state.isConnected && state.isSynced
    val detail = when {
        !inRoom -> state.detailKey
        state.localReady -> "house_rockets_online_replay_detail"
        else -> "house_rockets_online_replay_not_ready"
    }
    ArenaCard {
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(copy("house_rockets_online_replay_title").uppercase(), Modifier.weight(1f).semantics { heading() },
                    style = RocketsStencil, color = accent)
                val now = rememberOnlineNow()
                val deadline = if (state.deadlineKind == "countdown") state.flightCountdownUptime ?: state.deadlineUptime
                    else state.deadlineUptime
                remaining(deadline, now)?.let { seconds ->
                    RocketsLabel(Icons.Outlined.Timer, copy.template("house_rockets_online_seconds", "seconds" to "$seconds"),
                        RocketsStencil, ink, spacing = Spacing.xs)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                if (state.showsProgress) CircularProgressIndicator(Modifier.size(16.dp), color = accent, strokeWidth = 2.dp)
                Text(copy(state.statusKey), Modifier.weight(1f), style = FausCrewType.headline,
                    color = if (state.isFailed) HouseRocketsPreparationTheme.danger else ink)
                if (state.sessionState != null) {
                    Text(copy.template("house_rockets_ready_count", "ready" to "${state.readyCount}",
                        "total" to "${state.participants.size}"),
                        style = FausCrewType.caption.copy(fontFeatureSettings = "tnum"), fontWeight = FontWeight.SemiBold,
                        color = muted)
                }
            }
            Text(copy.template(detail, "minimum" to "${state.minimumPlayers}"), style = FausCrewType.subheadline, color = muted)
            state.issueKey?.takeIf { !state.isReconnecting }?.let {
                Text(copy(it), style = FausCrewType.caption, fontWeight = FontWeight.SemiBold,
                    color = HouseRocketsPreparationTheme.danger)
            }
        }
        Column(
            Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            val players = state.participants.filter { it.isLocal } + state.participants.filter { !it.isLocal }
            players.forEach { player ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    val color = player.color?.let(RocketsColor::from) ?: colors.local.takeIf { player.isLocal }
                    if (color != null) RocketBadge(color) else {
                        Box(Modifier.size(22.dp).clip(CircleShape).background(HouseRocketsPalette.navy))
                    }
                    val name = memberNames[player.playerId]
                    Text(name ?: copy(if (player.isLocal) "house_rockets_you" else "house_rockets_member"),
                        Modifier.weight(1f, fill = false), style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold,
                        color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (player.isLocal && name != null) Text(copy("house_rockets_you"), style = FausCrewType.caption, color = muted)
                    Spacer(Modifier.weight(1f))
                    RocketsLabel(if (player.isReady) Icons.Rounded.CheckCircle else Icons.Rounded.Schedule,
                        copy(player.statusKey), FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold),
                        if (player.isReady) accent else muted, spacing = Spacing.xs)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            ArenaButton(copy("house_rockets_back_to_lobby"), Icons.AutoMirrored.Rounded.List, isPrimary = false,
                enabled = !state.isLeaving, onClick = onBackToLobby)
            if (state.isFailed && state.canRetry) {
                val now = rememberOnlineNow(1_000)
                ArenaButton(copy("house_rockets_online_retry"), Icons.Rounded.Refresh, isPrimary = true,
                    enabled = now >= (state.retryNotBefore ?: 0.0), onClick = onRetry)
            } else {
                ArenaButton(copy(if (state.localReady) "house_rockets_not_ready_action" else "house_rockets_ready_action"),
                    if (state.localReady) Icons.Rounded.HighlightOff else Icons.Rounded.CheckCircle,
                    isPrimary = !state.localReady, enabled = state.canChangeReady,
                    onClick = { onReady(!state.localReady) })
            }
        }
    }
}

/** A cream card centered over the dimmed course, at most 460 dp wide and the safe screen's height. */
@Composable
private fun ArenaCard(content: @Composable ColumnScope.() -> Unit) {
    Box(
        Modifier.fillMaxSize().background(HouseRocketsPalette.navy.copy(alpha = .45f))
            .windowInsetsPadding(WindowInsets.safeDrawing).padding(Spacing.lg),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.widthIn(max = 460.dp).fillMaxWidth()
                .background(HouseRocketsPreparationTheme.surface.copy(alpha = .97f), RoundedCornerShape(Radius.lg))
                .border(1.dp, HouseRocketsPreparationTheme.hairline, RoundedCornerShape(Radius.lg))
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
            content = content,
        )
    }
}

@Composable
private fun RowScope.ArenaButton(
    text: String, icon: ImageVector, isPrimary: Boolean, enabled: Boolean, onClick: () -> Unit,
) {
    val content = if (isPrimary) HouseRocketsPreparationTheme.surface else HouseRocketsPreparationTheme.ink
    Row(
        Modifier.weight(1f).heightIn(min = 44.dp).alpha(if (enabled) 1f else .45f)
            .scaleButton(enabled = enabled, onClick = onClick)
            .background(if (isPrimary) HouseRocketsPreparationTheme.accent else HouseRocketsPalette.navy.copy(alpha = .08f),
                RoundedCornerShape(Radius.sm))
            .padding(horizontal = Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, Modifier.size(18.dp), tint = content)
        Text(text, style = FausCrewType.subheadline, fontWeight = FontWeight.Bold, color = content, maxLines = 1,
            overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun RocketBadge(color: RocketsColor) {
    Box(Modifier.size(22.dp).clip(CircleShape).background(HouseRocketsPalette.navy), contentAlignment = Alignment.Center) {
        HouseRocketsColorRocket(color, Modifier.size(17.dp))
    }
}
