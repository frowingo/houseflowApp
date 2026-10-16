package com.houseflow.ui.main

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.houseflow.platform.HouseSummary
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.HouseSwitcherIcon
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowTheme
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow
import com.houseflow.ui.components.tabBarBackground
import kotlin.math.max
import kotlin.math.min
import kotlinx.coroutines.launch

/** `AppTab`. */
internal enum class MainTab(val icon: ImageVector, val labelKey: String, val fallback: String, val isAvailable: Boolean) {
    PROFILE(HouseFlowIcons.personFill, "tab_profile", "Profile", true),
    HOME(HouseFlowIcons.houseFill, "tab_home", "Home", true),
    GAMES(HouseFlowIcons.gameControllerFill, "tab_games", "Games", true),
}

/**
 * `MainTabView`: tab content with the floating brand tab bar laid over it. The bar hides
 * while a tab reports an overlay (popup) so it never competes with modal content.
 */
@Composable
internal fun MainTabScreen(
    selectedTab: MainTab,
    onSelectTab: (MainTab) -> Unit,
    houses: List<HouseSummary>,
    currentHouseId: String?,
    onSwitchHouse: (String) -> Unit,
    strings: LocalizedText,
    profile: @Composable (onOverlayChange: (Boolean) -> Unit) -> Unit,
    dashboard: @Composable (onOverlayChange: (Boolean) -> Unit) -> Unit,
    games: @Composable (onOverlayChange: (Boolean) -> Unit) -> Unit,
) {
    HouseFlowTheme {
        var overlayPresented by remember(selectedTab) { mutableStateOf(false) }
        val onOverlayChange: (Boolean) -> Unit = { overlayPresented = it }
        Box(Modifier.fillMaxSize()) {
            when (selectedTab) {
                MainTab.PROFILE -> profile(onOverlayChange)
                MainTab.HOME -> dashboard(onOverlayChange)
                MainTab.GAMES -> games(onOverlayChange)
            }
            AnimatedVisibility(
                visible = !overlayPresented,
                modifier = Modifier.align(Alignment.BottomCenter),
                enter = slideInVertically(Motion.standard()) { it } + fadeIn(Motion.standard()),
                exit = slideOutVertically(Motion.standard()) { it } + fadeOut(Motion.standard()),
            ) {
                MainTabBar(selectedTab, onSelectTab, houses, currentHouseId, onSwitchHouse, strings)
            }
        }
    }
}

private val ItemIconHeight = 32.dp
private val HomeLift = 3.dp
private val HomePressedLift = 5.dp

@Composable
private fun MainTabBar(
    selectedTab: MainTab,
    onSelectTab: (MainTab) -> Unit,
    houses: List<HouseSummary>,
    currentHouseId: String?,
    onSwitchHouse: (String) -> Unit,
    strings: LocalizedText,
) {
    val shape = RoundedCornerShape(28.dp)
    var homePressed by remember { mutableStateOf(false) }
    Box(
        Modifier.navigationBarsPadding()
            .padding(start = 24.dp, end = 24.dp, bottom = 20.dp)
            .softShadow(HouseFlowColors.softBerry.copy(alpha = .3f), 20.dp, y = 9.dp, shape = shape)
            .clip(shape)
            .tabBarBackground()
            .border(1.dp, Brush.linearGradient(listOf(Color.White.copy(alpha = .35f), Color.White.copy(alpha = .10f))), shape)
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
    ) {
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            SelectionHighlight(selectedTab, maxWidth, homePressed)
            Row(Modifier.fillMaxWidth()) {
                MainTab.entries.forEach { tab ->
                    val label = strings.get(tab.labelKey, tab.fallback)
                    if (tab == MainTab.HOME) {
                        HomeTabItem(label, selectedTab == tab, houses, currentHouseId, strings,
                            onPressedChange = { homePressed = it }, onSwitchHouse = onSwitchHouse,
                            onTap = { onSelectTab(tab) }, modifier = Modifier.weight(1f))
                    } else {
                        TabItem(tab, label, selectedTab == tab, Modifier.weight(1f)) {
                            if (tab.isAvailable) onSelectTab(tab)
                        }
                    }
                }
            }
        }
    }
}

/** The sliding capsule behind the selected item (`matchedGeometryEffect("tabHighlight")`). */
@Composable
private fun SelectionHighlight(selectedTab: MainTab, barWidth: Dp, homePressed: Boolean) {
    val isHome = selectedTab == MainTab.HOME
    val itemWidth = barWidth / MainTab.entries.size
    val spec = Motion.spring<Dp>()
    val centerX by animateDpAsState(itemWidth * (selectedTab.ordinal + .5f), spec, label = "tabX")
    val width by animateDpAsState(if (isHome) 56.dp else 52.dp, spec, label = "tabW")
    val height by animateDpAsState(if (isHome) 38.dp else 32.dp, spec, label = "tabH")
    val lift = when {
        !isHome -> 0.dp
        homePressed -> HomePressedLift
        else -> HomeLift
    }
    val centerY by animateDpAsState(ItemIconHeight / 2 - lift, spec, label = "tabY")
    val fill by animateColorAsState(
        if (isHome) Color(0xFFFFE0B3).copy(alpha = .30f) else Color.White.copy(alpha = .2f),
        Motion.spring(), label = "tabFill",
    )
    val stroke by animateFloatAsState(if (isHome) .30f else .24f, Motion.spring(), label = "tabStroke")
    val scale by animateFloatAsState(if (isHome && homePressed) 1.05f else 1f, tween(120), label = "tabScale")
    val shadowAlpha = if (isHome && homePressed) .20f else .12f
    val capsule = RoundedCornerShape(50)
    Box(
        Modifier.offset(x = centerX - width / 2, y = centerY - height / 2)
            .size(width, height)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .softShadow(Color.Black.copy(alpha = shadowAlpha), if (homePressed) 10.dp else 7.dp,
                y = if (homePressed) 5.dp else 3.dp, shape = capsule)
            .clip(capsule)
            .background(fill)
            .border(1.dp, Color.White.copy(alpha = stroke), capsule),
    )
}

@Composable
private fun rememberBounce(): Pair<Animatable<Float, AnimationVector1D>, () -> Unit> {
    val scale = remember { Animatable(1f) }
    val scope = rememberCoroutineScope()
    return scale to {
        scope.launch {
            scale.animateTo(1.25f, tween(90))
            scale.animateTo(1f, tween(90))
        }
    }
}

@Composable
private fun TabItem(tab: MainTab, label: String, selected: Boolean, modifier: Modifier, onTap: () -> Unit) {
    val (bounce, triggerBounce) = rememberBounce()
    val tint = if (selected) Color.White else Color.White.copy(alpha = .55f)
    Column(
        modifier.clickable(remember { MutableInteractionSource() }, indication = null, role = Role.Tab) {
            triggerBounce()
            onTap()
        }.semantics { this.selected = selected },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Box(Modifier.size(52.dp, ItemIconHeight), contentAlignment = Alignment.Center) {
            Icon(tab.icon, null, Modifier.size(22.dp).graphicsLayer { scaleX = bounce.value; scaleY = bounce.value },
                tint = tint)
        }
        TabLabel(label, selected)
    }
}

@Composable
private fun TabLabel(label: String, selected: Boolean) {
    Text(label, style = HouseFlowType.caption2,
        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (selected) Color.White else Color.White.copy(alpha = .55f), maxLines = 1)
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HomeTabItem(
    label: String,
    selected: Boolean,
    houses: List<HouseSummary>,
    currentHouseId: String?,
    strings: LocalizedText,
    onPressedChange: (Boolean) -> Unit,
    onSwitchHouse: (String) -> Unit,
    onTap: () -> Unit,
    modifier: Modifier,
) {
    val haptics = LocalHapticFeedback.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    LaunchedEffect(pressed) { onPressedChange(pressed) }
    val (bounce, triggerBounce) = rememberBounce()
    var switcherShown by remember { mutableStateOf(false) }
    fun presentSwitcher() {
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        switcherShown = true
    }
    val lift by animateDpAsState(if (pressed) HomePressedLift else HomeLift, tween(120), label = "homeLift")
    val pressScale by animateFloatAsState(if (pressed) 1.05f else 1f, tween(120), label = "homeScale")
    val tint = if (selected) Color.White else Color.White.copy(alpha = .62f)
    val switchAction = strings.get("main_tab_house_switcher_accessibility_action", "Choose house")
    Column(
        modifier.combinedClickable(
            interactionSource = interaction,
            indication = null,
            role = Role.Tab,
            onLongClickLabel = strings.get("house_switcher_accessibility_hint", "Press and hold to switch homes."),
            onLongClick = ::presentSwitcher,
            hapticFeedbackEnabled = false,
        ) {
            triggerBounce()
            onTap()
        }.semantics {
            this.selected = selected
            customActions = listOf(CustomAccessibilityAction(switchAction) { presentSwitcher(); true })
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Box(
            Modifier.size(52.dp, ItemIconHeight).offset(y = -lift)
                .graphicsLayer { scaleX = pressScale; scaleY = pressScale },
            contentAlignment = Alignment.Center,
        ) {
            Column(
                Modifier.graphicsLayer { scaleX = bounce.value; scaleY = bounce.value },
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(HouseFlowIcons.chevronUp, null, Modifier.size(12.dp).offset(y = 3.dp), tint = tint)
                Icon(HouseFlowIcons.houseFill, null, Modifier.size(23.dp), tint = tint)
            }
            if (switcherShown) {
                HouseSwitcherPopover(houses, currentHouseId, strings, onDismiss = { switcherShown = false }) { house ->
                    switcherShown = false
                    if (house.id != currentHouseId) onSwitchHouse(house.id)
                }
            }
        }
        TabLabel(label, selected)
    }
}

// ---- House switcher popover ------------------------------------------------------------

private val PopoverArrowHeight = 10.dp
private val PopoverArrowWidth = 24.dp
private val PopoverCorner = 13.dp

/** Places the popover above its anchor, horizontally centered and kept on screen. */
private class AboveAnchorPositionProvider(private val gapPx: Int, private val marginPx: Int) : PopupPositionProvider {
    override fun calculatePosition(
        anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection, popupContentSize: IntSize,
    ): IntOffset {
        val maxX = max(marginPx, windowSize.width - popupContentSize.width - marginPx)
        val x = (anchorBounds.center.x - popupContentSize.width / 2).coerceIn(marginPx, maxX)
        val y = (anchorBounds.top - popupContentSize.height - gapPx).coerceAtLeast(marginPx)
        return IntOffset(x, y)
    }
}

@Composable
private fun HouseSwitcherPopover(
    houses: List<HouseSummary>,
    currentHouseId: String?,
    strings: LocalizedText,
    onDismiss: () -> Unit,
    onSelect: (HouseSummary) -> Unit,
) {
    val density = LocalDensity.current
    val provider = remember(density) {
        with(density) { AboveAnchorPositionProvider(gapPx = 6.dp.roundToPx(), marginPx = 8.dp.roundToPx()) }
    }
    val shape = remember(density) {
        val corner = with(density) { PopoverCorner.toPx() }
        val arrowHeight = with(density) { PopoverArrowHeight.toPx() }
        val arrowWidth = with(density) { PopoverArrowWidth.toPx() }
        GenericShape { size, _ ->
            val bodyBottom = size.height - arrowHeight
            addRoundRect(RoundRect(Rect(0f, 0f, size.width, bodyBottom), CornerRadius(corner)))
            val center = size.width / 2
            moveTo(center - arrowWidth / 2, bodyBottom)
            lineTo(center, size.height)
            lineTo(center + arrowWidth / 2, bodyBottom)
            close()
        }
    }
    val appear = remember { Animatable(0f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, Motion.spring()) }
    val width = min(320f, LocalConfiguration.current.screenWidthDp - 16f).dp
    Popup(popupPositionProvider = provider, onDismissRequest = onDismiss, properties = PopupProperties(focusable = true)) {
        Column(
            Modifier.width(width)
                .graphicsLayer {
                    alpha = appear.value.coerceIn(0f, 1f)
                    scaleX = .9f + .1f * appear.value
                    scaleY = .9f + .1f * appear.value
                    transformOrigin = TransformOrigin(.5f, 1f)
                }
                .softShadow(Color.Black.copy(alpha = .18f), 24.dp, y = 8.dp, shape = shape)
                .clip(shape)
                .background(HouseFlowColors.secondaryBackground)
                .padding(start = Spacing.md, end = Spacing.md, top = Spacing.md, bottom = Spacing.md + PopoverArrowHeight),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(strings.get("house_switcher_title", "Your homes"), Modifier.padding(horizontal = Spacing.xs),
                style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
            val listHeight = min(max(houses.size, 1) * 62, 260).dp
            Column(Modifier.height(listHeight).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                houses.forEach { house ->
                    HouseSwitcherRow(house, house.id == currentHouseId,
                        strings.get("house_switcher_current", "Current home")) { onSelect(house) }
                }
            }
        }
    }
}

@Composable
private fun HouseSwitcherRow(house: HouseSummary, selected: Boolean, currentLabel: String, onSelect: () -> Unit) {
    val accent = HouseFlowColors.accentOrangeInk
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md))
            .background(if (selected) HouseFlowColors.accentOrange.copy(alpha = .10f) else Color.Transparent)
            .clickable(onClick = onSelect)
            .semantics { this.selected = selected }
            .padding(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        HouseSwitcherIcon(house.profileImage)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(house.name, style = HouseFlowType.bodyBold, color = HouseFlowColors.textPrimary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (selected) Text(currentLabel, style = HouseFlowType.caption, color = accent, maxLines = 1)
        }
        Spacer(Modifier.width(Spacing.sm))
        if (selected) {
            Icon(HouseFlowIcons.checkmarkCircleFill, null, Modifier.size(22.dp), tint = accent)
        } else {
            Icon(HouseFlowIcons.chevronRight, null, Modifier.size(18.dp), tint = HouseFlowColors.textTertiary)
        }
    }
}

/** Bottom clearance tab content keeps so its last card can scroll above the floating bar. */
internal val TabBarClearance = 140.dp
