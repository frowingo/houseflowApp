package com.fauscrew.ui.games.tanks

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.ArrowCircleDown
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.GpsFixed
import androidx.compose.material.icons.rounded.Inventory2
import androidx.compose.material.icons.rounded.Map
import androidx.compose.material.icons.rounded.PanoramaFishEye
import androidx.compose.material.icons.rounded.People
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.ScreenRotation
import androidx.compose.material.icons.rounded.Shield
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksDifficulty
import com.fauscrew.platform.TanksJoker
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksMapPreview
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.scaleButton
import com.fauscrew.viewmodel.HouseTanksUiState
import com.fauscrew.viewmodel.TanksMode
import com.fauscrew.viewmodel.TanksSetupStep
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Remote plaintext first, then Core's bundled FauseTanks copy, then the key. */
internal class TanksCopy(private val strings: LocalizedText, private val bundled: Map<String, String>) {
    operator fun invoke(key: String): String = strings.values[key] ?: bundled[key] ?: key

    fun template(key: String, vararg replacements: Pair<String, String>): String =
        replacements.fold(invoke(key)) { text, (name, value) -> text.replace("{$name}", value) }
}

private val ButtonHeightLarge = 56.dp
private val BotNameKeys = listOf("house_tanks_bot_one", "house_tanks_bot_two", "house_tanks_bot_three")
private val TitleStyle = FausCrewType.largeTitle.copy(fontWeight = FontWeight.Black, letterSpacing = (-0.6).sp)

/**
 * `HouseTanksLobbyView`: choose demo or online, then set up the match on a field-map sheet.
 * Orientation and match start stay with [HouseTanksScreen].
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun HouseTanksLobby(
    state: HouseTanksUiState,
    copy: TanksCopy,
    maps: Map<TanksMap, TanksMapPreview>,
    userId: String?,
    houseId: String?,
    members: List<Pair<String, String>>,
    isLandscapeLayout: Boolean,
    isWaitingForLandscape: Boolean,
    orientationFailed: Boolean,
    onBack: () -> Unit,
    onSelectMode: (TanksMode) -> Unit,
    onChangeMode: () -> Unit,
    onSelectMap: (TanksMap) -> Unit,
    onSelectColor: (TanksColor) -> Unit,
    onSelectDifficulty: (TanksDifficulty) -> Unit,
    onStart: () -> Unit,
) {
    val requesters = remember { TanksSetupStep.entries.associateWith { BringIntoViewRequester() } }
    var highlighted by remember { mutableStateOf<TanksSetupStep?>(null) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(highlighted) {
        if (highlighted != null) {
            delay(1_200)
            highlighted = null
        }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(44.dp)) {
            Box(
                Modifier.padding(start = Spacing.sm).size(44.dp).clickable(role = Role.Button, onClick = onBack)
                    .semantics { contentDescription = copy("house_tanks_exit") },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.AutoMirrored.Rounded.ArrowBackIos, null, Modifier.size(20.dp), tint = HouseTanksFieldTheme.accent) }
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                Modifier.widthIn(max = 620.dp).fillMaxWidth()
                    .padding(start = Spacing.xl, end = Spacing.xl, top = Spacing.xl, bottom = Spacing.xxl),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                Header(copy, state.selectedMode)
                when (val mode = state.selectedMode) {
                    null -> Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                        TanksMode.entries.forEach { ModeCard(it, copy) { onSelectMode(it) } }
                    }
                    else -> {
                        ModeBar(mode, copy, enabled = !isWaitingForLandscape, onChangeMode)
                        if (mode == TanksMode.DEMO) {
                            DemoSetup(state, copy, maps, requesters, highlighted, enabled = !isWaitingForLandscape,
                                onSelectMap, onSelectColor, onSelectDifficulty)
                        } else {
                            OnlineRoom(state, copy, maps, userId, houseId, members)
                        }
                    }
                }
                FieldManual(copy, state.selectedMode)
                if (state.selectedMode == TanksMode.DEMO || orientationFailed) {
                    IconLabel(Icons.Rounded.ScreenRotation,
                        copy(if (orientationFailed) "house_tanks_landscape_error" else "house_tanks_landscape_detail"),
                        FausCrewType.subheadline, if (orientationFailed) HouseTanksFieldTheme.danger else HouseTanksFieldTheme.muted)
                }
            }
        }
        if (state.selectedMode == TanksMode.DEMO) {
            StartBar(state, copy, isLandscapeLayout, isWaitingForLandscape, onStart) { step ->
                highlighted = step
                scope.launch { requesters.getValue(step).bringIntoView() }
            }
        }
    }
}

// MARK: - Header and mode

@Composable
private fun Header(copy: TanksCopy, mode: TanksMode?) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Box(
            Modifier.size(88.dp).background(HouseTanksPalette.steel, RoundedCornerShape(Radius.md))
                .drawBehind { drawCornerMarks(HouseTanksPalette.paper.copy(alpha = .7f), 7.dp.toPx(), 6.dp.toPx(), 1.2.dp.toPx()) },
            contentAlignment = Alignment.Center,
        ) { HouseTanksArenaTank(Color.White, Modifier.size(70.dp)) }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(copy("house_tanks_kicker"), style = HouseTanksFieldTheme.stencil.copy(letterSpacing = 1.4.sp),
                color = HouseTanksPalette.umber)
            Text(copy("house_tanks_title"), style = TitleStyle, color = HouseTanksFieldTheme.ink)
            Text(copy(when (mode) {
                TanksMode.DEMO -> "house_tanks_subtitle"
                TanksMode.ONLINE -> "house_tanks_online_subtitle"
                null -> "house_tanks_mode_prompt"
            }), style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted)
        }
    }
}

@Composable
private fun ModeCard(mode: TanksMode, copy: TanksCopy, onClick: () -> Unit) {
    val demo = mode == TanksMode.DEMO
    val tint = if (demo) HouseTanksPalette.steel else HouseTanksPalette.khaki
    val tintInk = if (demo) HouseTanksPalette.steel else HouseTanksPalette.umber
    RaisedButton(tint, onClick, Modifier.fillMaxWidth()) {
        Box {
            Column(Modifier.fieldCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    Box(Modifier.size(44.dp).background(tint, RoundedCornerShape(Radius.sm)), contentAlignment = Alignment.Center) {
                        Icon(if (demo) Icons.Rounded.GpsFixed else Icons.Rounded.People, null, Modifier.size(22.dp),
                            tint = HouseTanksPalette.paper)
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(if (demo) "OP-01" else "OP-02", style = HouseTanksFieldTheme.stencil.copy(letterSpacing = 1.4.sp),
                            color = HouseTanksFieldTheme.muted)
                        Text(copy(if (demo) "house_tanks_mode_demo_title" else "house_tanks_mode_online_title"),
                            style = FausCrewType.headline.copy(fontWeight = FontWeight.Bold), color = HouseTanksFieldTheme.ink)
                    }
                    Pill(if (demo) Icons.Rounded.Map else Icons.Rounded.Casino,
                        copy(if (demo) "house_tanks_mode_demo_map" else "house_tanks_mode_online_map"), tintInk, tint)
                }
                Text(copy(if (demo) "house_tanks_mode_demo_detail" else "house_tanks_mode_online_detail"),
                    style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted)
                // A filled action strip makes the whole card read as a control.
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 44.dp).background(tintInk, RoundedCornerShape(Radius.xs))
                        .padding(horizontal = Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(copy(if (demo) "house_tanks_mode_demo_action" else "house_tanks_mode_online_action"),
                        style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = HouseTanksPalette.paper,
                        modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, Modifier.size(18.dp), tint = HouseTanksPalette.paper)
                }
            }
            Box(Modifier.align(Alignment.CenterStart).padding(vertical = Spacing.lg).width(3.dp).fillMaxHeight().background(tint))
        }
    }
}

@Composable
private fun ModeBar(mode: TanksMode, copy: TanksCopy, enabled: Boolean, onChangeMode: () -> Unit) {
    val demo = mode == TanksMode.DEMO
    Row(
        Modifier.fillMaxWidth()
            .drawBehind { drawRect(HouseTanksFieldTheme.hairline, Offset(0f, size.height - 1.dp.toPx()), Size(size.width, 1.dp.toPx())) }
            .padding(bottom = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconLabel(if (demo) Icons.Rounded.GpsFixed else Icons.Rounded.People,
            copy(if (demo) "house_tanks_mode_demo_title" else "house_tanks_mode_online_title"),
            FausCrewType.title3.copy(fontWeight = FontWeight.Bold), HouseTanksFieldTheme.ink, Modifier.weight(1f))
        Box(Modifier.heightIn(min = 44.dp).clickable(enabled = enabled, role = Role.Button, onClick = onChangeMode),
            contentAlignment = Alignment.Center) {
            Text(copy("house_tanks_change_mode"), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold),
                color = HouseTanksFieldTheme.accent.copy(alpha = if (enabled) 1f else .45f))
        }
    }
}

// MARK: - Demo

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun DemoSetup(
    state: HouseTanksUiState,
    copy: TanksCopy,
    maps: Map<TanksMap, TanksMapPreview>,
    requesters: Map<TanksSetupStep, BringIntoViewRequester>,
    highlighted: TanksSetupStep?,
    enabled: Boolean,
    onSelectMap: (TanksMap) -> Unit,
    onSelectColor: (TanksColor) -> Unit,
    onSelectDifficulty: (TanksDifficulty) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
        SetupStep(TanksSetupStep.MAP, state, copy, requesters, highlighted) {
            TanksMap.entries.chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Max), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    row.forEach { map ->
                        MapTile(map, maps[map], copy, state.map == map, enabled, Modifier.weight(1f).fillMaxHeight()) { onSelectMap(map) }
                    }
                }
            }
        }
        SetupStep(TanksSetupStep.COLOR, state, copy, requesters, highlighted) {
            Column(Modifier.fieldCard(), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                FieldLabel(copy("house_tanks_color"))
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    TanksColor.entries.forEach { color ->
                        TankSwatch(color, copy, state.color == color, enabled, Modifier.weight(1f)) { onSelectColor(color) }
                    }
                }
                Box(Modifier.fillMaxWidth().height(1.dp).background(HouseTanksFieldTheme.hairline))
                Roster(state.color, copy)
            }
        }
        SetupStep(TanksSetupStep.DIFFICULTY, state, copy, requesters, highlighted) {
            Column(Modifier.fieldCard(), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                FieldLabel(copy("house_tanks_difficulty"))
                SegmentedDifficulty(state.difficulty, copy, enabled, onSelectDifficulty)
                if (state.difficulty == TanksDifficulty.HARD) {
                    IconLabel(Icons.Rounded.GpsFixed, copy("house_tanks_difficulty_hard_note"),
                        FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold), HouseTanksFieldTheme.danger)
                }
            }
        }
    }
}

/** One numbered pick with its status; the next missing pick gets a dashed frame. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SetupStep(
    step: TanksSetupStep,
    state: HouseTanksUiState,
    copy: TanksCopy,
    requesters: Map<TanksSetupStep, BringIntoViewRequester>,
    highlighted: TanksSetupStep?,
    content: @Composable () -> Unit,
) {
    val isNext = state.pendingSetupStep == step
    val glow by animateFloatAsState(if (highlighted == step) .26f else .08f, label = "stepGlow")
    Column(
        Modifier.bringIntoViewRequester(requesters.getValue(step))
            .drawBehind {
                if (!isNext) return@drawBehind
                val pad = Spacing.sm.toPx()
                val radius = CornerRadius(Radius.md.toPx())
                drawRoundRect(HouseTanksPalette.khaki.copy(alpha = glow), Offset(-pad, -pad),
                    Size(size.width + pad * 2, size.height + pad * 2), radius)
                drawRoundRect(HouseTanksPalette.umber.copy(alpha = .7f), Offset(-pad, -pad),
                    Size(size.width + pad * 2, size.height + pad * 2), radius,
                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 4.dp.toPx()))))
            },
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SectionHeader("%02d".format(step.ordinal + 1), copy(stepTitleKey(step)), Modifier.weight(1f))
            StepBadge(step, state, copy)
        }
        content()
    }
}

private fun stepTitleKey(step: TanksSetupStep) = when (step) {
    TanksSetupStep.MAP -> "house_tanks_map_pick"
    TanksSetupStep.COLOR -> "house_tanks_step_color"
    TanksSetupStep.DIFFICULTY -> "house_tanks_step_difficulty"
}

@Composable
private fun StepBadge(step: TanksSetupStep, state: HouseTanksUiState, copy: TanksCopy) {
    val done = state.isComplete(step)
    val next = state.pendingSetupStep == step
    val tint = if (done) HouseTanksPalette.steel else if (next) HouseTanksPalette.umber else HouseTanksFieldTheme.muted
    Row(
        Modifier.clip(CircleShape).background(tint.copy(alpha = .12f)).padding(horizontal = Spacing.sm, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(if (done) Icons.Rounded.CheckCircle else if (next) Icons.Rounded.TouchApp else Icons.Rounded.PanoramaFishEye,
            null, Modifier.size(12.dp), tint = tint)
        Text(copy(if (done) "house_tanks_step_done" else if (next) "house_tanks_step_next" else "house_tanks_step_waiting"),
            style = HouseTanksFieldTheme.stencil.copy(letterSpacing = 1.sp), color = tint)
    }
}

@Composable
private fun MapTile(
    map: TanksMap, preview: TanksMapPreview?, copy: TanksCopy, selected: Boolean, enabled: Boolean,
    modifier: Modifier, onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.sm)
    Column(
        modifier.clip(shape)
            .background(if (selected) HouseTanksPalette.paper else HouseTanksFieldTheme.surface.copy(alpha = .66f), shape)
            .border(if (selected) 2.dp else 1.dp, if (selected) HouseTanksFieldTheme.accent else HouseTanksFieldTheme.hairline, shape)
            .clickable(enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(Spacing.sm),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        HouseTanksMapPreview(preview, selected, Modifier.clip(RoundedCornerShape(Radius.xs)))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(copy(map.titleKey), style = FausCrewType.headline, color = HouseTanksFieldTheme.ink, modifier = Modifier.weight(1f))
            if (selected) Icon(Icons.Rounded.CheckCircle, null, Modifier.size(18.dp), tint = HouseTanksFieldTheme.accent)
        }
        Text(copy(map.detailKey), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
    }
}

/** The player's own tank in each color, as it will look on the arena. */
@Composable
private fun TankSwatch(color: TanksColor, copy: TanksCopy, selected: Boolean, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.sm)
    Box(
        modifier.clip(shape)
            .background(if (selected) HouseTanksPalette.paper else HouseTanksPalette.sand.copy(alpha = .35f), shape)
            .border(if (selected) 2.dp else 1.dp, if (selected) color.ink else HouseTanksFieldTheme.hairline, shape)
            .clickable(enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected; contentDescription = copy(color.nameKey) },
    ) {
        Column(Modifier.fillMaxWidth().padding(vertical = Spacing.sm), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            HouseTanksArenaTank(color, Modifier.size(52.dp))
            Text(copy(color.nameKey), style = FausCrewType.caption.copy(fontWeight = if (selected) FontWeight.Bold else FontWeight.SemiBold),
                color = if (selected) HouseTanksFieldTheme.ink else HouseTanksFieldTheme.muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (selected) {
            Icon(Icons.Rounded.CheckCircle, null, Modifier.align(Alignment.TopEnd).padding(5.dp).size(14.dp), tint = color.ink)
        }
    }
}

@Composable
private fun SegmentedDifficulty(selection: TanksDifficulty?, copy: TanksCopy, enabled: Boolean, onSelect: (TanksDifficulty) -> Unit) {
    val shape = RoundedCornerShape(Radius.sm)
    Row(
        Modifier.widthIn(max = 300.dp).fillMaxWidth().clip(shape).background(HouseTanksPalette.slate.copy(alpha = .14f), shape).padding(2.dp),
    ) {
        TanksDifficulty.entries.forEach { difficulty ->
            val selected = selection == difficulty
            Box(
                Modifier.weight(1f).heightIn(min = 32.dp).clip(RoundedCornerShape(Radius.sm - 2.dp))
                    .background(if (selected) HouseTanksPalette.paper else Color.Transparent)
                    .clickable(enabled = enabled, role = Role.RadioButton) { onSelect(difficulty) }
                    .semantics { this.selected = selected },
                contentAlignment = Alignment.Center,
            ) {
                Text(copy(difficulty.titleKey), style = FausCrewType.subheadline.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal),
                    color = HouseTanksFieldTheme.ink)
            }
        }
    }
}

@Composable
private fun Roster(humanColor: TanksColor?, copy: TanksCopy) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        FieldLabel(copy("house_tanks_roster"))
        // Bot colors are whatever the player leaves; until then the roster stays blank.
        val botColors: List<TanksColor?> = humanColor?.let { human -> TanksColor.entries.filter { it != human } } ?: listOf(null, null, null)
        val entries = listOf(Triple("house_tanks_you", "house_tanks_human_role", humanColor)) +
            BotNameKeys.zip(botColors).map { (name, color) -> Triple(name, "house_tanks_bot_role", color) }
        entries.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                row.forEach { (name, role, color) -> RosterChip(copy(name), copy(role), color, Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun RosterChip(name: String, role: String, color: TanksColor?, modifier: Modifier) {
    Row(
        modifier.heightIn(min = 46.dp).background(HouseTanksPalette.sand.copy(alpha = .5f), RoundedCornerShape(Radius.xs))
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Box(Modifier.size(12.dp).drawBehind {
            if (color != null) drawCircle(color.ink)
            drawCircle(HouseTanksFieldTheme.ink.copy(alpha = .4f), style = Stroke(1.dp.toPx(),
                pathEffect = if (color == null) PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 2.dp.toPx())) else null))
        })
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(name, style = FausCrewType.caption.copy(fontWeight = FontWeight.Bold), color = HouseTanksFieldTheme.ink, maxLines = 1)
            Text(role, style = HouseTanksFieldTheme.stencil, color = HouseTanksFieldTheme.muted)
        }
    }
}

/** Starts the match once every pick is made; until then it leads to the next missing pick. */
@Composable
private fun StartBar(
    state: HouseTanksUiState, copy: TanksCopy, isLandscapeLayout: Boolean, isWaitingForLandscape: Boolean,
    onStart: () -> Unit, onGuide: (TanksSetupStep) -> Unit,
) {
    val pending = state.pendingSetupStep
    Column(
        Modifier.fillMaxWidth().background(HouseTanksPalette.paper.copy(alpha = .94f))
            .drawBehind { drawRect(HouseTanksFieldTheme.hairline, Offset.Zero, Size(size.width, 1.dp.toPx())) }
            .padding(horizontal = Spacing.xl, vertical = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        if (pending != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    TanksSetupStep.entries.forEach { step ->
                        Box(Modifier.size(18.dp, 4.dp).clip(CircleShape)
                            .background(if (state.isComplete(step)) HouseTanksPalette.steel else HouseTanksPalette.slate.copy(alpha = .25f)))
                    }
                }
                Text(copy.template("house_tanks_setup_progress", "done" to state.completedSetupSteps.toString()),
                    style = HouseTanksFieldTheme.stencil, color = HouseTanksFieldTheme.muted)
            }
            Row(
                Modifier.fillMaxWidth().heightIn(min = ButtonHeightLarge).clip(RoundedCornerShape(Radius.md))
                    .background(HouseTanksPalette.umber).scaleButton { onGuide(pending) }
                    .semantics { stateDescription = copy("house_tanks_setup_hint") },
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.ArrowCircleDown, null, Modifier.size(20.dp), tint = HouseTanksPalette.paper)
                Text(copy.template("house_tanks_setup_next", "step" to copy(stepTitleKey(pending))),
                    style = FausCrewType.headline, color = HouseTanksPalette.paper)
            }
        } else {
            Row(
                Modifier.fillMaxWidth().heightIn(min = ButtonHeightLarge).clip(RoundedCornerShape(Radius.md))
                    .background(HouseTanksPalette.steel).scaleButton(enabled = !isWaitingForLandscape, onClick = onStart),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (isWaitingForLandscape) {
                    CircularProgressIndicator(Modifier.size(18.dp), color = HouseTanksPalette.paper, strokeWidth = 2.dp)
                    Text(copy("house_tanks_rotating"), style = FausCrewType.headline, color = HouseTanksPalette.paper)
                } else {
                    Icon(if (isLandscapeLayout) Icons.Rounded.GpsFixed else Icons.Rounded.ScreenRotation, null,
                        Modifier.size(20.dp), tint = HouseTanksPalette.paper)
                    Text(copy("house_tanks_start"), style = FausCrewType.headline, color = HouseTanksPalette.paper)
                }
            }
        }
    }
}

// MARK: - Online

@Composable
private fun OnlineRoom(
    state: HouseTanksUiState, copy: TanksCopy, maps: Map<TanksMap, TanksMapPreview>, userId: String?, houseId: String?,
    members: List<Pair<String, String>>,
) {
    val blocker = when {
        userId.isNullOrEmpty() -> "house_tanks_online_sign_in"
        houseId.isNullOrEmpty() -> "house_tanks_online_house_required"
        else -> null
    }
    if (blocker != null) {
        Column(Modifier.fieldCard(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            IconLabel(Icons.Rounded.WifiOff, copy("house_tanks_online_unavailable"), FausCrewType.headline, HouseTanksFieldTheme.ink)
            Text(copy(blocker), style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted)
        }
        return
    }
    Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            SectionHeader("01", copy("house_tanks_online_map_title"))
            Column(Modifier.fieldCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                state.onlineMap?.let { map ->
                    Box {
                        HouseTanksMapPreview(maps[map], selected = true, modifier = Modifier.clip(RoundedCornerShape(Radius.xs)))
                        Text(copy("house_tanks_random_stamp"),
                            style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = 1.6.sp),
                            color = HouseTanksPalette.umber,
                            modifier = Modifier.align(Alignment.TopEnd).padding(Spacing.md).rotate(-8f)
                                .background(HouseTanksPalette.paper.copy(alpha = .8f))
                                .border(1.5.dp, HouseTanksPalette.umber).padding(horizontal = Spacing.sm, vertical = 3.dp))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        Icon(Icons.Rounded.Casino, null, Modifier.size(18.dp), tint = HouseTanksPalette.umber)
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(copy(map.titleKey), style = FausCrewType.headline, color = HouseTanksFieldTheme.ink)
                            Text(copy(map.detailKey), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
                        }
                    }
                }
                Text(copy("house_tanks_online_map_detail"), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            SectionHeader("02", copy("house_tanks_online_roster"))
            Column(Modifier.fieldCard(), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                val tints = listOf(HouseTanksPalette.steel, HouseTanksPalette.khaki, HouseTanksPalette.olive,
                    HouseTanksPalette.rust, HouseTanksPalette.slate)
                // The local player leads the list, as in the House Rockets room.
                val ordered = members.filter { it.first == userId } + members.filter { it.first != userId }
                val list = ordered.ifEmpty { listOfNotNull(userId?.let { it to copy("house_tanks_you") }) }
                list.forEachIndexed { index, (id, name) ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        Box(Modifier.size(10.dp).clip(CircleShape).background(tints[index % tints.size]))
                        Text(name, style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = HouseTanksFieldTheme.ink,
                            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                        if (id == userId && ordered.isNotEmpty()) {
                            Text(copy("house_tanks_you"), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
                        }
                        Spacer(Modifier.weight(1f))
                        IconLabel(Icons.Rounded.Schedule, copy("house_tanks_online_waiting"), HouseTanksFieldTheme.stencil, HouseTanksFieldTheme.muted)
                    }
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = ButtonHeightLarge).background(HouseTanksPalette.slate, RoundedCornerShape(Radius.md))
                    .clearAndSetSemantics { contentDescription = "${copy("house_tanks_online_ready")}, ${copy("house_tanks_soon")}" },
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.ScreenRotation, null, Modifier.size(20.dp), tint = HouseTanksPalette.paper)
                Text(copy("house_tanks_online_ready"), style = FausCrewType.headline, color = HouseTanksPalette.paper)
                Text(copy("house_tanks_soon"), style = FausCrewType.caption2.copy(fontWeight = FontWeight.Black),
                    color = HouseTanksFieldTheme.ink, modifier = Modifier.clip(CircleShape)
                        .background(HouseTanksPalette.khaki.copy(alpha = .55f)).padding(horizontal = 7.dp, vertical = 3.dp))
            }
            Text(copy("house_tanks_online_soon_detail"), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
        }
    }
}

// MARK: - Field manual

@Composable
private fun FieldManual(copy: TanksCopy, mode: TanksMode?) {
    var showsJokers by remember { mutableStateOf(false) }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        SectionHeader(when (mode) { TanksMode.DEMO -> "04"; TanksMode.ONLINE -> "03"; null -> "01" }, copy("house_tanks_rules_title"))
        Column {
            GuideStep(copy("house_tanks_rule_fire"), copy("house_tanks_rule_fire_detail"), Icons.Rounded.GpsFixed, HouseTanksPalette.steel)
            GuideStep(copy("house_tanks_rule_drive"), copy("house_tanks_rule_drive_detail"), Icons.Rounded.ArrowUpward, HouseTanksPalette.deepSteel)
            GuideStep(copy("house_tanks_rule_survive"), copy("house_tanks_rule_survive_detail"), Icons.Rounded.Shield, HouseTanksPalette.rust)
            GuideStep(copy("house_tanks_rule_crates"), copy("house_tanks_rule_crates_detail"), Icons.Rounded.Inventory2, HouseTanksPalette.khaki)
            GuideStep(copy("house_tanks_rule_jokers"), copy("house_tanks_rule_jokers_detail"), Icons.Rounded.Bolt, HouseTanksPalette.olive,
                isLast = true) { JokerAccordion(copy, showsJokers) { showsJokers = !showsJokers } }
        }
    }
}

@Composable
private fun GuideStep(
    title: String, detail: String, icon: ImageVector, tint: Color, isLast: Boolean = false,
    accessory: @Composable () -> Unit = {},
) {
    Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(44.dp).background(tint, RoundedCornerShape(Radius.sm)), contentAlignment = Alignment.Center) {
                Icon(icon, null, Modifier.size(22.dp), tint = HouseTanksPalette.paper)
            }
            if (!isLast) Box(Modifier.width(1.5.dp).weight(1f).heightIn(min = 30.dp).background(HouseTanksFieldTheme.hairline))
        }
        Column(Modifier.padding(top = 2.dp, bottom = Spacing.lg), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(title, style = FausCrewType.headline, color = HouseTanksFieldTheme.ink)
            Text(detail, style = FausCrewType.subheadline, color = HouseTanksFieldTheme.muted)
            accessory()
        }
    }
}

/** Every joker with its arena glyph, name and effect, folded under "Collect a joker". */
@Composable
private fun JokerAccordion(copy: TanksCopy, expanded: Boolean, onToggle: () -> Unit) {
    val shape = RoundedCornerShape(Radius.sm)
    val chevron by animateFloatAsState(if (expanded) 180f else 0f, label = "chevron")
    Column(
        Modifier.padding(top = Spacing.xs).fillMaxWidth().clip(shape).background(HouseTanksPalette.paper.copy(alpha = .9f), shape)
            .border(1.dp, if (expanded) HouseTanksFieldTheme.accent.copy(alpha = .5f) else HouseTanksFieldTheme.hairline, shape),
    ) {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onToggle)
                .semantics { stateDescription = copy("house_tanks_jokers_hint") }
                .padding(horizontal = Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy((-5).dp)) {
                TanksJoker.entries.forEach { joker ->
                    Box(Modifier.size(22.dp).clip(CircleShape).background(joker.tint).border(1.5.dp, HouseTanksPalette.paper, CircleShape),
                        contentAlignment = Alignment.Center) { JokerGlyph(joker, 10.dp, Modifier.size(22.dp)) }
                }
            }
            Text(if (expanded) copy("house_tanks_jokers_hide") else copy.template("house_tanks_jokers_show", "count" to TanksJoker.entries.size.toString()),
                style = FausCrewType.subheadline.copy(fontWeight = FontWeight.SemiBold), color = HouseTanksFieldTheme.ink,
                modifier = Modifier.weight(1f))
            Icon(Icons.Rounded.ExpandMore, null, Modifier.size(20.dp).rotate(chevron), tint = HouseTanksFieldTheme.accent)
        }
        AnimatedVisibility(expanded, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
            Column {
                Box(Modifier.fillMaxWidth().height(1.dp).background(HouseTanksFieldTheme.hairline))
                Column(Modifier.padding(Spacing.md), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    TanksJoker.entries.forEach { joker ->
                        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                            Box(Modifier.size(36.dp).background(joker.tint, RoundedCornerShape(Radius.xs)), contentAlignment = Alignment.Center) {
                                JokerGlyph(joker, 17.dp, Modifier.size(36.dp))
                            }
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(copy(joker.titleKey), style = FausCrewType.subheadline.copy(fontWeight = FontWeight.Bold), color = HouseTanksFieldTheme.ink)
                                Text(copy(joker.detailKey), style = FausCrewType.caption, color = HouseTanksFieldTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

@Composable
internal fun SectionHeader(code: String, title: String, modifier: Modifier = Modifier) {
    Row(modifier.semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Text("$code /", style = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 15.sp, fontWeight = FontWeight.Bold),
            color = HouseTanksFieldTheme.accent, modifier = Modifier.clearAndSetSemantics {})
        Text(title, style = FausCrewType.title3.copy(fontWeight = FontWeight.Bold), color = HouseTanksFieldTheme.ink)
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(text.uppercase(), style = HouseTanksFieldTheme.stencil.copy(letterSpacing = 1.2.sp), color = HouseTanksFieldTheme.muted)
}

@Composable
private fun Pill(icon: ImageVector, text: String, ink: Color, tint: Color) {
    Row(
        Modifier.clip(CircleShape).background(tint.copy(alpha = .14f)).padding(horizontal = Spacing.sm, vertical = Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(icon, null, Modifier.size(14.dp), tint = ink)
        Text(text, style = FausCrewType.caption.copy(fontWeight = FontWeight.SemiBold), color = ink)
    }
}

@Composable
internal fun IconLabel(icon: ImageVector, text: String, style: TextStyle, color: Color, modifier: Modifier = Modifier, iconSize: Dp = 18.dp) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, Modifier.size(iconSize), tint = color)
        Text(text, style = style, color = color)
    }
}
