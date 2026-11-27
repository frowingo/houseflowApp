package com.fauscrew.ui.dashboard

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector2D
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Poll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.GameStanding
import com.fauscrew.platform.GameStatsBoardData
import com.fauscrew.platform.GameStatsSection
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.auth.social
import com.fauscrew.ui.components.UserAvatar
import com.fauscrew.ui.games.OnlineGameVisual
import com.fauscrew.ui.games.rockets.rememberReduceMotion
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.viewmodel.GameStatsPhase
import com.fauscrew.viewmodel.GameStatsUiState
import kotlin.math.max
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** A game's own tab, or the sum of all of them. */
internal sealed interface GameStatsTab {
    data class Game(val visual: OnlineGameVisual) : GameStatsTab
    data object Overall : GameStatsTab
}

/**
 * iOS `GameStatsCard`: the dashboard's game standings, two thirds of the row beside the progress
 * card. The title names the selected game (or "Genel"); a peak line joins the members in the
 * backend's order, each node as high as their wins; small tiles with each game's own figure switch
 * the game. The dashboard asks for a refresh when it appears, so coming back from a match reloads.
 */
@Composable
internal fun GameStatsCard(
    state: GameStatsUiState,
    members: List<HouseMember>,
    currentUserId: String?,
    strings: LocalizedText,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val board = state.board
    val tabs = remember(board) { tabs(board) }
    var selected by remember { mutableStateOf<GameStatsTab?>(null) }
    val tab = selected?.takeIf { it in tabs } ?: tabs.firstOrNull()
    val section = tab?.let { section(it, board) }
    var focused by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(tab) { focused = null }
    val byId = remember(members) { members.associateBy { it.id } }

    Box(modifier.fillMaxSize()) {
        DashboardMetricChrome(DpOffset(120.dp, 90.dp), Modifier.matchParentSize())
        Column(Modifier.fillMaxSize().padding(Spacing.md), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Header(strings.social("game_stats_title", "Oyun istatistikleri", "Game stats"), tab?.let { title(it, strings) })
            Box(Modifier.fillMaxWidth().height(82.dp)) {
                when {
                    section != null -> {
                        val standings = section.standings.filter { it.userId in byId }
                        PeakLineChart(standings, byId, currentUserId, focused, { focused = it }, tab, strings,
                            Modifier.fillMaxSize().clearAndSetSemantics { contentDescription = summary(standings, byId, strings) })
                    }
                    state.phase == GameStatsPhase.READY -> StatsMessage(
                        strings.social("game_stats_empty", "Henüz tamamlanmış oyun yok", "No finished games yet"),
                        FausCrewIcons.gameControllerFill)
                    state.phase == GameStatsPhase.ERROR -> Column(Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        StatsMessage(state.errorMessage
                            ?: strings.social("game_stats_error", "İstatistikler yüklenemedi", "Couldn't load the stats"),
                            FausCrewIcons.exclamationmarkTriangleFill, Modifier.weight(1f, fill = false))
                        Text(strings.social("game_stats_retry", "Tekrar dene", "Try again"),
                            Modifier.clickable(role = Role.Button, onClick = onRetry).padding(horizontal = 8.dp, vertical = 2.dp),
                            fontSize = 11.sp, fontWeight = FontWeight.Bold, color = FausCrewColors.teal)
                    }
                    else -> CircularProgressIndicator(Modifier.size(18.dp).align(Alignment.Center),
                        color = FausCrewColors.teal, strokeWidth = 2.dp)
                }
            }
            Caption(caption(section, focused, byId, strings), section?.standings?.firstOrNull { it.isLeader }?.let { byId[it.userId] })
            if (tabs.isNotEmpty()) {
                Row(Modifier.padding(start = 2.dp)) {
                    tabs.forEach { item ->
                        key(item) {
                            GameStatsTabTile(item, item == tab, title(item, strings)) { selected = item }
                        }
                    }
                }
            }
        }
    }
}

/** "Genel" first, then the games in the backend's order. */
private fun tabs(board: GameStatsBoardData?): List<GameStatsTab> =
    listOfNotNull(board?.overall?.let { GameStatsTab.Overall }) +
        board?.games.orEmpty().mapNotNull { OnlineGameVisual.of(it.gameKey) }.map { GameStatsTab.Game(it) }

private fun section(tab: GameStatsTab, board: GameStatsBoardData?): GameStatsSection? = when (tab) {
    is GameStatsTab.Game -> board?.games?.firstOrNull { it.gameKey == tab.visual.gameKey }
    GameStatsTab.Overall -> board?.overall
}

private fun title(tab: GameStatsTab, strings: LocalizedText): String = when (tab) {
    is GameStatsTab.Game -> tab.visual.title(strings)
    GameStatsTab.Overall -> strings.social("game_stats_overall_title", "Genel", "Overall")
}

private fun record(standing: GameStanding, strings: LocalizedText): String =
    if (!standing.hasPlayed) strings.social("game_stats_not_played", "oynamadı", "didn't play")
    else strings.social("game_stats_record", "{wins} galibiyet / {matches} maç", "{wins} wins / {matches} matches")
        .replace("{wins}", standing.wins.toString())
        .replace("{matches}", standing.matchesPlayed.toString())

private fun caption(section: GameStatsSection?, focused: String?, members: Map<String, HouseMember>, strings: LocalizedText): String {
    val standing = section?.standings?.firstOrNull { it.userId == focused }
    val member = focused?.let(members::get)
    return when {
        standing != null && member != null -> "${member.firstName} · ${record(standing, strings)}"
        section != null -> strings.social("game_stats_ranking", "Sıralama", "Ranking")
        else -> ""
    }
}

/** The whole ranking as one sentence, since TalkBack does not scroll the chart. */
private fun summary(standings: List<GameStanding>, members: Map<String, HouseMember>, strings: LocalizedText): String =
    standings.mapIndexedNotNull { index, standing ->
        members[standing.userId]?.let { "${index + 1}. ${it.name}, ${record(standing, strings)}" }
    }.joinToString("; ")

/** A small "Oyun istatistikleri:" label, the selected game's name (or "Genel") beside it. */
@Composable
private fun Header(label: String, title: String?) {
    Row(Modifier.fillMaxWidth().height(18.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label.uppercase() + ":", fontSize = 9.sp, fontWeight = FontWeight.SemiBold, letterSpacing = .4.sp,
            color = FausCrewColors.textTertiary, maxLines = 1, softWrap = false)
        if (title != null) {
            Spacer(Modifier.width(6.dp))
            AnimatedContent(title, Modifier.weight(1f), transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "statsTitle") {
                BasicText(it, style = TextStyle(color = FausCrewColors.textPrimary, fontSize = 14.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 10.sp, maxFontSize = 14.sp))
            }
        }
    }
}

/** The focused member's record (or "Sıralama"), with the leader in small type on the right. */
@Composable
private fun Caption(text: String, leader: HouseMember?) {
    Row(Modifier.fillMaxWidth().height(14.dp), verticalAlignment = Alignment.CenterVertically) {
        BasicText(text, Modifier.weight(1f),
            style = TextStyle(color = FausCrewColors.textSecondary, fontSize = 11.sp, fontWeight = FontWeight.Medium),
            maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 8.sp, maxFontSize = 11.sp))
        if (leader != null) {
            Spacer(Modifier.width(Spacing.xs))
            Icon(FausCrewIcons.crownFill, null, Modifier.size(9.dp), tint = FausCrewColors.accentOrangeDeep)
            Spacer(Modifier.width(2.dp))
            Text(leader.firstName, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = FausCrewColors.accentOrangeDeep,
                maxLines = 1, softWrap = false)
        }
    }
}

@Composable
private fun StatsMessage(text: String, icon: androidx.compose.ui.graphics.vector.ImageVector, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xs, Alignment.CenterVertically)) {
        Icon(icon, null, Modifier.size(18.dp), tint = FausCrewColors.teal.copy(alpha = .7f))
        BasicText(text, style = TextStyle(color = FausCrewColors.textSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center), maxLines = 2, autoSize = TextAutoSize.StepBased(minFontSize = 9.sp, maxFontSize = 12.sp))
    }
}

// Tiles

/** The top of each figure's move: the robot jumps, the rocket lifts off up and right, the tank turns its barrel, the bars grow. */
private data class TileMove(val x: Float = 0f, val y: Float = 0f, val angle: Float = 0f, val scale: Float = 1f) {
    companion object {
        fun peak(tab: GameStatsTab): TileMove = when (tab) {
            GameStatsTab.Game(OnlineGameVisual.FAUS_SWITCH) -> TileMove(y = -6f)
            GameStatsTab.Game(OnlineGameVisual.HOUSE_ROCKETS) -> TileMove(x = 4f, y = -6f)
            GameStatsTab.Game(OnlineGameVisual.HOUSE_TANKS) -> TileMove(angle = 18f)
            else -> TileMove(scale = 1.25f)
        }
    }
}

/**
 * A small square with the game's own figure; no text. The selected one is teal and the figure does
 * its move. The touch area spans the gap to the next tile, like the iOS inset content shape.
 */
@Composable
private fun GameStatsTabTile(tab: GameStatsTab, isSelected: Boolean, title: String, onSelect: () -> Unit) {
    val reduceMotion = rememberReduceMotion()
    val scope = rememberCoroutineScope()
    val move = remember { Animatable(0f) }
    val scale by animateFloatAsState(if (isSelected) 1.08f else 1f, spring(dampingRatio = .7f, stiffness = 300f), label = "tileScale")
    val peak = remember(tab) { TileMove.peak(tab) }
    val shape = RoundedCornerShape(9.dp)
    Box(
        Modifier.size(39.dp, 34.dp)
            .clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Tab) {
                if (isSelected) return@clickable
                onSelect()
                if (!reduceMotion) scope.launch {
                    move.animateTo(1f, tween(180))
                    move.animateTo(0f, spring(dampingRatio = .45f, stiffness = Spring.StiffnessMediumLow))
                }
            }
            .semantics { contentDescription = title; selected = isSelected },
        contentAlignment = Alignment.CenterStart,
    ) {
        Box(
            Modifier.size(32.dp)
                .graphicsLayer { scaleX = scale; scaleY = scale }
                .background(if (isSelected) FausCrewColors.teal.copy(alpha = .14f) else FausCrewColors.systemGray4, shape)
                .border(if (isSelected) 1.5.dp else 1.dp, if (isSelected) FausCrewColors.teal else FausCrewColors.hairline, shape),
            contentAlignment = Alignment.Center,
        ) {
            val figure = Modifier.size(22.dp).graphicsLayer {
                val t = move.value
                translationX = peak.x.dp.toPx() * t
                translationY = peak.y.dp.toPx() * t
                rotationZ = peak.angle * t
                val grow = 1f + (peak.scale - 1f) * t
                scaleX = grow; scaleY = grow
                alpha = if (isSelected) 1f else .5f
            }
            when (tab) {
                is GameStatsTab.Game -> tab.visual.Artwork(figure)
                GameStatsTab.Overall -> Box(figure, contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.Poll, null, Modifier.size(20.dp), tint = FausCrewColors.teal)
                }
            }
        }
    }
}

// Peak line

private const val FittingCount = 4
private val Step = 48.dp
private val NodeSize = 22.dp
private val LeaderSize = 26.dp
private val Fade = 18.dp
/** Room above the highest node for its count, below the lowest for the "Sen" label. */
private val TopRoom = 20.dp
private val BottomRoom = 8.dp

/**
 * Members left to right in ranking order, each node as high as their wins, joined by one line. Up
 * to four members share the width; more scroll sideways inside the same area at a fixed step.
 */
@Composable
private fun PeakLineChart(
    standings: List<GameStanding>,
    members: Map<String, HouseMember>,
    currentUserId: String?,
    focused: String?,
    onFocus: (String?) -> Unit,
    /** The selected tab: a change scrolls back to the leader, then to the user's own node. */
    resetKey: GameStatsTab?,
    strings: LocalizedText,
    modifier: Modifier = Modifier,
) {
    val reduceMotion = rememberReduceMotion()
    val drawn = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        if (reduceMotion) drawn.snapTo(1f) else {
            delay(250)
            drawn.animateTo(1f, tween(800, easing = FastOutSlowInEasing))
        }
    }
    BoxWithConstraints(modifier) {
        if (standings.size > FittingCount) {
            val scroll = rememberScrollState()
            val density = LocalDensity.current
            val viewport = maxWidth
            val height = maxHeight
            LaunchedEffect(resetKey, standings.size) {
                scroll.scrollTo(0)
                val own = standings.indexOfFirst { it.userId == currentUserId }
                if (own < FittingCount) return@LaunchedEffect
                delay(450)
                val target = with(density) { (Step * (own + .5f) - viewport / 2).toPx() }.roundToInt().coerceIn(0, scroll.maxValue)
                if (reduceMotion) scroll.scrollTo(target) else scroll.animateScrollTo(target, tween(500))
            }
            val startFade by animateDpAsState(if (scroll.value <= 1) 0.dp else Fade, tween(200), label = "startFade")
            val endFade by animateDpAsState(if (scroll.value >= scroll.maxValue - 1) 0.dp else Fade, tween(200), label = "endFade")
            Box(Modifier.fillMaxSize().edgeFade(startFade, endFade).horizontalScroll(scroll)) {
                ChartCanvas(standings, members, currentUserId, focused, onFocus, drawn.value, strings,
                    Step * standings.size, height, reduceMotion)
            }
        } else {
            ChartCanvas(standings, members, currentUserId, focused, onFocus, drawn.value, strings, maxWidth, maxHeight, reduceMotion)
        }
    }
}

/** Fades the content out at the edges that have more to scroll to. */
private fun Modifier.edgeFade(start: Dp, end: Dp): Modifier =
    graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen).drawWithContent {
        drawContent()
        val s = start.toPx()
        val e = end.toPx()
        if (s > 0f) drawRect(Brush.horizontalGradient(listOf(Color.Transparent, Color.Black), 0f, s),
            size = Size(s, size.height), blendMode = BlendMode.DstIn)
        if (e > 0f) drawRect(Brush.horizontalGradient(listOf(Color.Black, Color.Transparent), size.width - e, size.width),
            topLeft = Offset(size.width - e, 0f), size = Size(e, size.height), blendMode = BlendMode.DstIn)
    }

@Composable
private fun ChartCanvas(
    standings: List<GameStanding>,
    members: Map<String, HouseMember>,
    currentUserId: String?,
    focused: String?,
    onFocus: (String?) -> Unit,
    drawn: Float,
    strings: LocalizedText,
    width: Dp,
    height: Dp,
    reduceMotion: Boolean,
) {
    val density = LocalDensity.current
    val targets = remember(standings, width, height, density) {
        with(density) { points(standings, width.toPx(), height.toPx(), this) }
    }
    // Each node slides to its new place on a game switch; the line bends along with them.
    val positions = remember { mutableStateMapOf<String, Animatable<Offset, AnimationVector2D>>() }
    standings.forEachIndexed { index, standing ->
        if (standing.userId !in positions) positions[standing.userId] = Animatable(targets[index], Offset.VectorConverter)
    }
    LaunchedEffect(targets) {
        standings.forEachIndexed { index, standing ->
            val position = positions[standing.userId] ?: return@forEachIndexed
            launch {
                if (reduceMotion) position.snapTo(targets[index])
                else position.animateTo(targets[index], spring(dampingRatio = .72f, stiffness = Spring.StiffnessLow))
            }
        }
    }
    val current = standings.mapIndexed { index, standing -> positions[standing.userId]?.value ?: targets[index] }

    val hairline = FausCrewColors.hairline
    val drop = FausCrewColors.textTertiary.copy(alpha = .45f)
    val line = Brush.horizontalGradient(listOf(FausCrewColors.teal, FausCrewColors.indigo))
    Box(Modifier.size(width, height)) {
        Canvas(Modifier.matchParentSize()) {
            val baseline = size.height - 3.dp.toPx()
            drawLine(hairline, Offset(2.dp.toPx(), baseline), Offset(size.width - 2.dp.toPx(), baseline), 1.dp.toPx())
            val dash = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 3.dp.toPx()))
            current.forEach { point ->
                drawLine(drop, Offset(point.x, point.y + 12.dp.toPx()), Offset(point.x, baseline), 1.dp.toPx(), pathEffect = dash)
            }
            if (current.size > 1 && drawn > 0f) {
                val full = Path().apply {
                    moveTo(current[0].x, current[0].y)
                    current.drop(1).forEach { lineTo(it.x, it.y) }
                }
                val measure = PathMeasure().apply { setPath(full, false) }
                val shown = Path()
                measure.getSegment(0f, measure.length * drawn.coerceIn(0f, 1f), shown, true)
                drawPath(shown, line, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            }
        }
        standings.forEachIndexed { index, standing ->
            key(standing.userId) {
                PeakNode(standing, members[standing.userId], standing.userId == currentUserId, focused, current[index], strings) {
                    onFocus(if (focused == standing.userId) null else standing.userId)
                }
            }
        }
    }
}

private fun points(standings: List<GameStanding>, width: Float, height: Float, density: androidx.compose.ui.unit.Density): List<Offset> =
    with(density) {
        val column = width / max(standings.size, 1)
        val maxWins = max(standings.maxOfOrNull { it.wins } ?: 0, 1)
        val top = (TopRoom + LeaderSize / 2).toPx()
        val bottom = height - (BottomRoom + NodeSize / 2).toPx()
        standings.mapIndexed { index, standing ->
            val share = standing.wins.toFloat() / maxWins
            Offset(column * (index + .5f), bottom - share * (bottom - top))
        }
    }

@Composable
private fun PeakNode(
    standing: GameStanding,
    member: HouseMember?,
    isMe: Boolean,
    focused: String?,
    center: Offset,
    strings: LocalizedText,
    onTap: () -> Unit,
) {
    val size = if (standing.isLeader) LeaderSize else NodeSize
    val dimmed = !standing.hasPlayed || (focused != null && focused != standing.userId)
    val scale by animateFloatAsState(if (focused == standing.userId) 1.15f else 1f,
        spring(dampingRatio = .7f, stiffness = 500f), label = "nodeScale")
    val orange = FausCrewColors.accentOrange
    val teal = FausCrewColors.teal
    // The count sits just above the outermost ring.
    val ringReach = when {
        standing.isLeader && isMe -> 6.dp
        standing.isLeader || isMe -> 3.dp
        else -> 0.dp
    }
    Box(
        Modifier
            .offset { IntOffset((center.x - (size / 2).toPx()).roundToInt(), (center.y - (size / 2).toPx()).roundToInt()) }
            .size(size)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .drawWithContent {
                drawContent()
                val radius = this.size.minDimension / 2
                if (standing.isLeader) drawCircle(orange, radius + 2.dp.toPx(), style = Stroke(2.dp.toPx()))
                if (isMe) drawCircle(teal, radius + (if (standing.isLeader) 5.dp else 2.dp).toPx(), style = Stroke(2.dp.toPx()))
            }
            .clickable(remember { MutableInteractionSource() }, indication = null, onClick = onTap),
    ) {
        if (member != null) UserAvatar(member, size, Modifier.graphicsLayer { alpha = if (dimmed) .35f else 1f })
        Text(if (standing.hasPlayed) standing.wins.toString() else "—",
            Modifier.align(Alignment.TopCenter).wrapContentSize(unbounded = true)
                .offset(y = -(ringReach + 1.dp + 13.dp)),
            fontSize = 11.sp, lineHeight = 13.sp, fontWeight = FontWeight.Bold, color = FausCrewColors.textSecondary, maxLines = 1)
        if (isMe) {
            Text(strings.social("game_stats_you", "Sen", "You"),
                Modifier.align(Alignment.BottomCenter).wrapContentSize(unbounded = true).offset(y = 7.dp)
                    .background(teal, CircleShape).padding(horizontal = 4.dp, vertical = 1.dp),
                fontSize = 8.sp, lineHeight = 10.sp, fontWeight = FontWeight.Black, color = Color.White, maxLines = 1)
        }
    }
}
