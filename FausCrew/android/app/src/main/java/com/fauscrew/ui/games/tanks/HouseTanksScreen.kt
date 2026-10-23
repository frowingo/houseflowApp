package com.fauscrew.ui.games.tanks

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.IntSize
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fauscrew.platform.HouseTanksNative
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksMapPreview
import com.fauscrew.ui.games.rockets.rememberReduceMotion
import com.fauscrew.viewmodel.HouseTanksViewModel
import com.fauscrew.viewmodel.TanksHaptic
import com.fauscrew.viewmodel.TanksMode
import kotlinx.coroutines.delay

/**
 * `HouseTanksView`: the portrait lobby, then a landscape match against three bots. The
 * rules run in FausCrewCore; orientation, app visibility and immersive bars are platform
 * concerns and live here, scheduling lives in [HouseTanksViewModel].
 */
@Composable
internal fun HouseTanksScreen(
    strings: LocalizedText,
    houseId: String?,
    userId: String?,
    onExit: () -> Unit,
    members: List<Pair<String, String>> = emptyList(),
    bundledCopy: (String?) -> Map<String, String> = HouseTanksNative::copy,
    maps: () -> Map<TanksMap, TanksMapPreview> = { HouseTanksNative.maps },
    model: HouseTanksViewModel = viewModel(),
) {
    val state by model.state.collectAsStateWithLifecycle()
    val frameState = model.frame.collectAsStateWithLifecycle()
    val hasMatch = frameState.value != null
    val copy = remember(strings) { TanksCopy(strings, bundledCopy(strings.prefix)) }
    val mapPreviews = remember { maps() }
    val renderer = remember { HouseTanksArenaRenderer() }
    val activity = LocalContext.current.findActivity()
    val view = LocalView.current
    val density = LocalDensity.current
    val reduceMotion = rememberReduceMotion()

    var isLandscapeLayout by remember { mutableStateOf(false) }
    var isWaitingForLandscape by rememberSaveable { mutableStateOf(false) }
    var orientationFailed by rememberSaveable { mutableStateOf(false) }
    var orientationRequest by rememberSaveable { mutableStateOf(0) }
    var isForeground by remember { mutableStateOf(true) }
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }

    fun returnToPortrait() {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }

    fun requestLandscape() {
        if (state.pendingSetupStep != null || !isForeground) return
        orientationFailed = false
        isWaitingForLandscape = !isLandscapeLayout
        orientationRequest += 1
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        if (isLandscapeLayout) {
            isWaitingForLandscape = false
            orientationRequest = 0
            model.startMatch()
        }
    }

    fun exitGame() {
        model.stop()
        returnToPortrait()
        onExit()
    }

    fun returnToDrillSetup() {
        isWaitingForLandscape = false
        orientationFailed = false
        orientationRequest = 0
        model.returnToDemoSetup()
        returnToPortrait()
    }

    // A rotation the system never delivers fails like iOS's geometry request error.
    LaunchedEffect(orientationRequest, isWaitingForLandscape) {
        if (orientationRequest == 0 || !isWaitingForLandscape) return@LaunchedEffect
        delay(LandscapeTimeoutMillis)
        if (isWaitingForLandscape && !hasMatch) {
            isWaitingForLandscape = false
            orientationRequest = 0
            orientationFailed = true
            returnToPortrait()
        }
    }

    LaunchedEffect(canvasSize) {
        if (canvasSize == IntSize.Zero) return@LaunchedEffect
        with(density) { model.setViewport(canvasSize.width.toDp().value, canvasSize.height.toDp().value) }
        isLandscapeLayout = canvasSize.width > canvasSize.height
        if (isLandscapeLayout && isWaitingForLandscape && !hasMatch && isForeground && !orientationFailed) {
            isWaitingForLandscape = false
            orientationRequest = 0
            model.startMatch()
        }
    }

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> isForeground = true
                Lifecycle.Event.ON_STOP -> {
                    isForeground = false
                    if (isWaitingForLandscape) {
                        isWaitingForLandscape = false
                        orientationRequest = 0
                        returnToPortrait()
                    }
                    model.pause()
                }
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    // The match is immersive; the lobby keeps the status bar like the iOS navigation stack.
    DisposableEffect(hasMatch, activity) {
        activity?.window?.let { window ->
            val controller = WindowCompat.getInsetsController(window, view)
            if (hasMatch) {
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                controller.hide(WindowInsetsCompat.Type.systemBars())
            } else {
                controller.show(WindowInsetsCompat.Type.systemBars())
            }
        }
        onDispose {}
    }

    DisposableEffect(Unit) {
        onDispose {
            model.stop()
            activity?.window?.let { WindowCompat.getInsetsController(it, view).show(WindowInsetsCompat.Type.systemBars()) }
            returnToPortrait()
        }
    }

    LaunchedEffect(model) {
        model.haptics.collect {
            view.performHapticFeedback(when (it) {
                TanksHaptic.HIT -> HapticFeedbackConstants.CLOCK_TICK
                TanksHaptic.ROUND_END -> HapticFeedbackConstants.CONTEXT_CLICK
                TanksHaptic.WIN -> HapticFeedbackConstants.CONFIRM
                TanksHaptic.LOSS -> HapticFeedbackConstants.REJECT
            })
        }
    }
    LaunchedEffect(model) { model.hits.collect(renderer::flash) }

    BackHandler {
        when {
            hasMatch -> model.pause()
            state.selectedMode != null -> model.returnToModeSelection()
            else -> exitGame()
        }
    }

    Box(Modifier.fillMaxSize().onSizeChanged { canvasSize = it }) {
        HouseTanksMapBackdrop(Modifier.fillMaxSize())
        if (hasMatch) {
            HouseTanksGameLayer(
                frameState = frameState, copy = copy, renderer = renderer, reduceMotion = reduceMotion,
                isForeground = isForeground, onFrame = model::onFrame, onPressStart = model::beginPress,
                onPressEnd = model::endPress, onAccessiblePress = model::performAccessiblePress, onPause = model::pause,
                onResume = model::resume, onNextRound = model::nextRound, onRestart = model::restartMatch,
                onDrillSetup = ::returnToDrillSetup, onExit = ::exitGame,
            )
        } else {
            HouseTanksLobby(
                state = state, copy = copy, maps = mapPreviews, userId = userId, houseId = houseId, members = members,
                isLandscapeLayout = isLandscapeLayout, isWaitingForLandscape = isWaitingForLandscape,
                orientationFailed = orientationFailed, onBack = ::exitGame,
                onSelectMode = { mode: TanksMode -> model.selectMode(mode) },
                onChangeMode = model::returnToModeSelection, onSelectMap = model::selectMap,
                onSelectColor = model::selectColor, onSelectDifficulty = model::selectDifficulty,
                onStart = ::requestLandscape,
            )
        }
    }
}

private const val LandscapeTimeoutMillis = 2_500L

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
