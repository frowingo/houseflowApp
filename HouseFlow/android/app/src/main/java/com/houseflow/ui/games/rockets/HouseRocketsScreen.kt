package com.houseflow.ui.games.rockets

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
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
import com.houseflow.platform.HouseRocketsNative
import com.houseflow.platform.LocalizedText
import com.houseflow.viewmodel.HouseRocketsViewModel
import com.houseflow.viewmodel.RocketsHaptic
import kotlinx.coroutines.delay

/** Remote plaintext first, then Core's bundled House Rockets copy, then the key. */
internal class RocketsCopy(private val strings: LocalizedText, private val bundled: Map<String, String>) {
    operator fun invoke(key: String): String = strings.values[key] ?: bundled[key] ?: key

    fun template(key: String, vararg replacements: Pair<String, String>): String =
        replacements.fold(invoke(key)) { text, (name, value) -> text.replace("{$name}", value) }
}

/**
 * `HouseRocketsView`: the portrait lobby, then a landscape flight. Orientation, app
 * visibility and immersive bars are platform concerns, so they live here; the match
 * itself is scheduled by [HouseRocketsViewModel] and simulated in HouseFlowCore.
 */
@Composable
internal fun HouseRocketsScreen(
    strings: LocalizedText,
    houseId: String?,
    userId: String?,
    onExit: () -> Unit,
    bundledCopy: (String?) -> Map<String, String> = HouseRocketsNative::copy,
    model: HouseRocketsViewModel = viewModel { HouseRocketsViewModel() },
) {
    val state by model.state.collectAsStateWithLifecycle()
    val frameState = model.frame.collectAsStateWithLifecycle()
    val hasMatch = frameState.value != null
    val copy = remember(strings) { RocketsCopy(strings, bundledCopy(strings.prefix)) }
    val activity = LocalContext.current.findActivity()
    val view = LocalView.current
    val density = LocalDensity.current

    var isLandscapeLayout by remember { mutableStateOf(false) }
    var isWaitingForLandscape by rememberSaveable { mutableStateOf(false) }
    var orientationFailed by rememberSaveable { mutableStateOf(false) }
    var orientationRequest by rememberSaveable { mutableStateOf(0) }
    var isForeground by remember { mutableStateOf(true) }
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }
    var hudSize by remember { mutableStateOf(IntSize.Zero) }

    fun returnToPortrait() {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }

    fun finishLandscapePreparation() {
        isWaitingForLandscape = false
        orientationRequest = 0
        model.startMatch()
    }

    fun requestLandscape() {
        if (state.selectedMode == null || !isForeground) return
        orientationFailed = false
        isWaitingForLandscape = !isLandscapeLayout
        orientationRequest += 1
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        if (isLandscapeLayout) finishLandscapePreparation()
    }

    fun changeMode() {
        isWaitingForLandscape = false
        orientationRequest = 0
        orientationFailed = false
        model.returnToModeSelection()
        returnToPortrait()
    }

    fun exitGame() {
        model.stop()
        returnToPortrait()
        onExit()
    }

    LaunchedEffect(houseId, userId) {
        if (state.houseId != houseId || state.userId != userId) {
            isWaitingForLandscape = false
            orientationRequest = 0
            orientationFailed = false
            if (state.houseId != null || state.userId != null) returnToPortrait()
            model.updateContext(houseId, userId)
        }
    }

    // A rotation the system never delivers (multi-window, a locked tablet) fails like iOS's
    // geometry request error: back to portrait with the landscape error copy.
    LaunchedEffect(orientationRequest, isWaitingForLandscape) {
        if (orientationRequest == 0 || !isWaitingForLandscape) return@LaunchedEffect
        delay(LandscapeTimeoutMillis)
        if (isWaitingForLandscape) {
            isWaitingForLandscape = false
            orientationRequest = 0
            orientationFailed = true
            returnToPortrait()
        }
    }

    LaunchedEffect(canvasSize, hudSize) {
        if (canvasSize == IntSize.Zero) return@LaunchedEffect
        with(density) {
            model.setViewport(canvasSize.width.toDp().value, canvasSize.height.toDp().value,
                hudSize.width.toDp().value, hudSize.height.toDp().value)
        }
        isLandscapeLayout = canvasSize.width > canvasSize.height
        if (isLandscapeLayout && isWaitingForLandscape && !hasMatch && state.selectedMode != null &&
            isForeground && !orientationFailed) finishLandscapePreparation()
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

    // The flight is immersive; the lobby keeps the status bar like the iOS navigation stack.
    DisposableEffect(hasMatch, activity) {
        val window = activity?.window
        if (window != null) {
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
            view.performHapticFeedback(
                if (it == RocketsHaptic.SUCCESS) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.REJECT,
            )
        }
    }

    BackHandler {
        if (state.selectedMode != null && !hasMatch) changeMode() else exitGame()
    }

    Box(Modifier.fillMaxSize().onSizeChanged { canvasSize = it }) {
        // Measures the safe area the HUD lays out in (iOS's information-layer GeometryReader).
        Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).onSizeChanged { hudSize = it })
        if (!hasMatch) {
            HouseRocketsPreparationBackdrop()
            HouseRocketsLobby(
                state = state, copy = copy, isWaitingForLandscape = isWaitingForLandscape,
                orientationFailed = orientationFailed,
                onBack = ::exitGame, onSelectMode = model::selectMode, onChangeMode = ::changeMode,
                onBotCount = model::setBotCount, onStart = ::requestLandscape,
            )
        } else {
            Box(Modifier.fillMaxSize().background(HouseRocketsTheme.background))
            HouseRocketsGameLayer(
                frameState = frameState, copy = copy, isForeground = isForeground,
                onSteer = model::steer, onEndSteering = model::endSteering, onAdjust = model::adjustHeading,
                onFrame = model::onFrame, onPause = model::pause, onResume = model::resume,
                onRestart = model::restart, onExit = ::exitGame,
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
