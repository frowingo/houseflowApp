package com.fauscrew.ui.games.rockets

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
import androidx.compose.runtime.withFrameNanos
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
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.RocketsLobbyColors
import com.fauscrew.platform.HouseRocketsNative
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.RocketsFrame
import com.fauscrew.viewmodel.HouseRocketsViewModel
import com.fauscrew.viewmodel.HouseRocketsViewModelFactory
import com.fauscrew.viewmodel.RocketsMode
import com.fauscrew.viewmodel.RocketsHaptic
import kotlinx.coroutines.delay

/** Remote plaintext first, then Core's bundled House Rockets copy, then the key. */
internal class RocketsCopy(private val strings: LocalizedText, private val bundled: Map<String, String>) {
    operator fun invoke(key: String): String = strings.values[key] ?: bundled[key] ?: key

    fun template(key: String, vararg replacements: Pair<String, String>): String =
        replacements.fold(invoke(key)) { text, (name, value) -> text.replace("{$name}", value) }
}

/**
 * `HouseRocketsView`: the portrait lobby, then a landscape flight — against local bots or
 * online with housemates. Orientation, app visibility and immersive bars are platform
 * concerns, so they live here; bot matches are scheduled by [HouseRocketsViewModel] and
 * online matches are decided by FausCrewCore's online engine.
 */
@Composable
internal fun HouseRocketsScreen(
    strings: LocalizedText,
    houseId: String?,
    userId: String?,
    onExit: () -> Unit,
    houseOwnerId: String? = null,
    memberNames: Map<String, String> = emptyMap(),
    onRequireSignIn: () -> Unit = {},
    bundledCopy: (String?) -> Map<String, String> = HouseRocketsNative::copy,
    model: HouseRocketsViewModel = viewModel(factory = HouseRocketsViewModelFactory(LocalContext.current)),
) {
    val state by model.state.collectAsStateWithLifecycle()
    val frameState = model.frame.collectAsStateWithLifecycle()
    val online by model.onlineSession.collectAsStateWithLifecycle()
    val session = online
    val onlineLobby = session?.lobby?.collectAsStateWithLifecycle()?.value
    val onlineResult = session?.result?.collectAsStateWithLifecycle()?.value
    val onlineFlight = session?.flight?.collectAsStateWithLifecycle()?.value
    val onlineColors = session?.colors?.collectAsStateWithLifecycle()?.value ?: RocketsLobbyColors()
    val noFrame = remember { mutableStateOf<RocketsFrame?>(null) }
    val onlineFrameState = session?.frame?.collectAsStateWithLifecycle() ?: noFrame
    val hasOnlineFrame = onlineFrameState.value != null
    val showsResult = onlineResult?.isVisible == true
    val hasMatch = frameState.value != null
    val isReplayRoom by model.isOnlineReplayRoom.collectAsStateWithLifecycle()
    val isHousemates = state.selectedMode == RocketsMode.HOUSEMATES
    // The result and Play Again's room sit over the last flight's frozen course.
    val showsArenaCard = isHousemates && ((showsResult && onlineResult != null) || isReplayRoom)
    val heldFrame = remember(showsArenaCard) { mutableStateOf(if (showsArenaCard) model.heldOnlineFrame else null) }
    val inFlight = hasMatch || (hasOnlineFrame && !showsResult) || showsArenaCard
    val copy = remember(strings) { RocketsCopy(strings, bundledCopy(strings.prefix)) }
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
    var hudSize by remember { mutableStateOf(IntSize.Zero) }
    var confirmsCancel by remember { mutableStateOf(false) }

    fun returnToPortrait() {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }

    fun finishLandscapePreparation() {
        isWaitingForLandscape = false
        orientationRequest = 0
        if (!isHousemates) model.startMatch()
    }

    fun requestLandscape() {
        if (state.selectedMode == null || !isForeground) return
        orientationFailed = false
        isWaitingForLandscape = !isLandscapeLayout
        orientationRequest += 1
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        if (isLandscapeLayout) finishLandscapePreparation()
    }

    /** The room is portrait like Faus Tanks' and Faus Switch's: ready never turns the screen. */
    fun onlineReady() {
        val lobby = onlineLobby ?: return
        if (lobby.localReady) model.setOnlineReady(false)
        else if (lobby.canChangeReady && isForeground) model.setOnlineReady(true)
    }

    fun resetOrientationState() {
        isWaitingForLandscape = false
        orientationRequest = 0
        orientationFailed = false
    }

    fun changeMode() {
        resetOrientationState()
        if (isHousemates) {
            model.leaveOnline { returnToPortrait() }
        } else {
            model.returnToModeSelection()
            returnToPortrait()
        }
    }

    fun exitGame() {
        if (isHousemates) {
            if (onlineLobby?.isLeaving == true) return
            model.leaveOnline {
                returnToPortrait()
                onExit()
            }
        } else {
            model.stop()
            returnToPortrait()
            onExit()
        }
    }

    /** Back to Lobby: the portrait online room (a new session unless Play Again's room is
     *  already the new one). */
    fun returnToOnlineLobby() {
        resetOrientationState()
        confirmsCancel = false
        model.setLandscape(false)
        model.returnToOnlineLobby()
        returnToPortrait()
    }

    LaunchedEffect(houseId, userId, houseOwnerId) {
        if (state.houseId != houseId || state.userId != userId || state.houseOwnerId != houseOwnerId) {
            resetOrientationState()
            if (state.houseId != null || state.userId != null) returnToPortrait()
            model.updateContext(houseId, userId, houseOwnerId)
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
            model.setLandscape(false)
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
        model.setLandscape(isLandscapeLayout)
        if (isLandscapeLayout && isWaitingForLandscape && !hasMatch && state.selectedMode != null &&
            isForeground && !orientationFailed) finishLandscapePreparation()
    }

    // The countdown turns the screen and the flight runs landscape until the result; returning
    // to the app re-requests it, and a countdown that falls back to the room turns it back.
    val isOnlineFlightStarting = isHousemates && !showsResult && onlineLobby?.isLeaving != true &&
        (hasOnlineFrame || isReplayRoom || onlineLobby?.isSessionLive == true)
    LaunchedEffect(isOnlineFlightStarting, isForeground) {
        if (isOnlineFlightStarting) {
            if (isForeground && !orientationFailed && !isLandscapeLayout && !isWaitingForLandscape) requestLandscape()
        } else if (isHousemates && !showsResult && activity?.requestedOrientation ==
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE) {
            isWaitingForLandscape = false
            orientationRequest = 0
            model.setLandscape(false)
            returnToPortrait()
        }
    }

    // A failed rotation cannot join a live flight: leave like iOS does.
    LaunchedEffect(orientationFailed, onlineLobby?.sessionState) {
        if (orientationFailed && onlineLobby?.isSessionLive == true) model.leaveOnline { returnToPortrait() }
    }

    LaunchedEffect(onlineLobby?.requiresAuthentication, onlineResult?.detailKey) {
        if (onlineLobby?.requiresAuthentication == true ||
            (onlineResult?.isFailed == true && onlineResult.detailKey == "house_rockets_online_sign_in")) {
            model.stop()
            returnToPortrait()
            onRequireSignIn()
        }
    }

    // One sample of the interpolated online flight per display frame.
    LaunchedEffect(session, onlineLobby?.hasGame == true, isForeground) {
        if (session == null || onlineLobby?.hasGame != true || !isForeground) return@LaunchedEffect
        while (true) withFrameNanos { model.onOnlineFrame() }
    }

    LaunchedEffect(reduceMotion, session) { model.setReduceMotion(reduceMotion) }

    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> {
                    isForeground = true
                    model.setForeground(true)
                }
                Lifecycle.Event.ON_STOP -> {
                    isForeground = false
                    model.setForeground(false)
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
    DisposableEffect(inFlight, activity) {
        val window = activity?.window
        if (window != null) {
            val controller = WindowCompat.getInsetsController(window, view)
            if (inFlight) {
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
        if (state.selectedMode != null && !inFlight && !showsResult && !isHousemates) changeMode() else exitGame()
    }

    Box(Modifier.fillMaxSize().onSizeChanged { canvasSize = it }) {
        // Measures the safe area the HUD lays out in (iOS's information-layer GeometryReader).
        Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing).onSizeChanged { hudSize = it })
        when {
            hasMatch -> {
                Box(Modifier.fillMaxSize().background(HouseRocketsTheme.background))
                HouseRocketsGameLayer(
                    frameState = frameState, copy = copy, isForeground = isForeground,
                    onSteer = model::steer, onEndSteering = model::endSteering, onAdjust = model::adjustHeading,
                    onFrame = model::onFrame, onPause = model::pause, onResume = model::resume,
                    onRestart = model::restart, onExit = ::exitGame,
                )
            }
            showsArenaCard -> {
                Box(Modifier.fillMaxSize().background(HouseRocketsTheme.background))
                HouseRocketsCourseCanvas(heldFrame, reduceMotion)
                if (showsResult && onlineResult != null) {
                    HouseRocketsOnlineResultCard(onlineResult, copy, memberNames,
                        canReturnToLobby = model.canReturnToOnlineLobby(onlineResult),
                        onRetry = model::retryOnlineResult, onBackToLobby = ::returnToOnlineLobby,
                        onPlayAgain = model::playOnlineAgain)
                } else {
                    HouseRocketsOnlineReplayRoom(onlineLobby ?: OnlineLobbyUi(), onlineColors, copy, memberNames,
                        onReady = { model.setOnlineReady(it) }, onRetry = model::retryOnline,
                        onBackToLobby = ::returnToOnlineLobby)
                }
            }
            hasOnlineFrame && onlineLobby != null -> {
                Box(Modifier.fillMaxSize().background(HouseRocketsTheme.background))
                HouseRocketsCourseCanvas(onlineFrameState, reduceMotion)
                HouseRocketsOnlineFlightOverlay(
                    frameState = onlineFrameState, flight = onlineFlight, lobby = onlineLobby, copy = copy,
                    isForeground = isForeground, onSteer = model::steer, onEndSteering = model::endSteering,
                    onAdjust = model::adjustHeading, onRetry = model::retryOnline,
                    onReclaim = model::reclaimOnlineControl, onCancel = { confirmsCancel = true }, onExit = ::exitGame,
                )
            }
            else -> {
                HouseRocketsPreparationBackdrop()
                HouseRocketsLobby(
                    state = state, copy = copy, isWaitingForLandscape = isWaitingForLandscape,
                    orientationFailed = orientationFailed,
                    onBack = ::exitGame, onSelectMode = model::selectMode, onChangeMode = ::changeMode,
                    onBotCount = model::setBotCount, onStart = ::requestLandscape,
                    online = onlineLobby, memberNames = memberNames, onOnlineReady = ::onlineReady,
                    onOnlineRetry = model::retryOnline, onOnlineCancel = { confirmsCancel = true },
                    onlineColors = onlineColors, onSelectColor = model::selectOnlineColor,
                )
            }
        }
        if (confirmsCancel) {
            CancelFlightDialog(copy, onConfirm = model::cancelOnlineMatch, onDismiss = { confirmsCancel = false })
        }
    }
}

private const val LandscapeTimeoutMillis = 2_500L

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
