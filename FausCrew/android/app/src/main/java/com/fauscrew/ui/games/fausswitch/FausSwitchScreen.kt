package com.fauscrew.ui.games.fausswitch

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.graphics.BitmapFactory
import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.fauscrew.R
import com.fauscrew.platform.FausSwitchNative
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.SwitchRoom
import com.fauscrew.ui.games.rockets.rememberReduceMotion
import com.fauscrew.viewmodel.FausSwitchViewModel
import com.fauscrew.viewmodel.FausSwitchViewModelFactory
import com.fauscrew.viewmodel.SwitchHaptic
import kotlinx.coroutines.delay

/**
 * `FausSwitchView`: the portrait lobby, then a landscape race against local bots. The rules
 * run in FausCrewCore; orientation, app visibility, immersive bars, sound and haptics are
 * platform concerns and live here and in [FausSwitchViewModel].
 */
@Composable
internal fun FausSwitchScreen(
    strings: LocalizedText,
    houseId: String?,
    userId: String?,
    onExit: () -> Unit,
    houseOwnerId: String? = null,
    /** House members' names by user id, for the online roster and result. */
    members: Map<String, String> = emptyMap(),
    /** The server no longer accepts this sign-in (HTTP 401). */
    onRequireSignIn: () -> Unit = {},
    bundledCopy: (String?) -> Map<String, String> = FausSwitchNative::copy,
    model: FausSwitchViewModel = viewModel(factory = FausSwitchViewModelFactory(LocalContext.current)),
) {
    val state by model.state.collectAsStateWithLifecycle()
    val frameState = model.frame.collectAsStateWithLifecycle()
    val match by model.match.collectAsStateWithLifecycle()
    val onlineSession by model.onlineSession.collectAsStateWithLifecycle()
    val onlineMatch by model.onlineMatch.collectAsStateWithLifecycle()
    val lobby = onlineSession?.lobby?.collectAsStateWithLifecycle()?.value
    val room = onlineSession?.room?.collectAsStateWithLifecycle()?.value
    val copy = remember(strings) { SwitchCopy(strings, bundledCopy(strings.prefix)) }
    val context = LocalContext.current
    val activity = context.findActivity()
    val view = LocalView.current
    val density = LocalDensity.current
    val reduceMotion = rememberReduceMotion()
    val constants = remember { FausSwitchNative.constants }
    val renderer = remember {
        val texture = runCatching { BitmapFactory.decodeResource(context.resources, R.drawable.faus_switch_texture) }.getOrNull()
        FausSwitchCourseRenderer(FausSwitchNative.course, constants.colorHex, texture)
    }

    var isLandscapeLayout by remember { mutableStateOf(false) }
    var isWaitingForLandscape by rememberSaveable { mutableStateOf(false) }
    var orientationFailed by rememberSaveable { mutableStateOf(false) }
    var orientationRequest by rememberSaveable { mutableIntStateOf(0) }
    var isForeground by remember { mutableStateOf(true) }
    var canvasSize by remember { mutableStateOf(IntSize.Zero) }

    fun returnToPortrait() {
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }

    fun requestLandscape() {
        if (!isForeground) return
        orientationFailed = false
        isWaitingForLandscape = !isLandscapeLayout
        orientationRequest += 1
        activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        if (isLandscapeLayout) {
            isWaitingForLandscape = false
            orientationRequest = 0
            model.startDemo()
        }
    }

    fun exitGame() {
        model.stop()
        returnToPortrait()
        onExit()
    }

    fun leaveOnlineRace() {
        model.leaveOnlineMatch()
        returnToPortrait()
    }

    fun exitDemoToSetup() {
        isWaitingForLandscape = false
        orientationFailed = false
        orientationRequest = 0
        model.exitDemo()
        returnToPortrait()
    }

    // A rotation the system never delivers fails like iOS's geometry request error.
    LaunchedEffect(orientationRequest, isWaitingForLandscape) {
        if (orientationRequest == 0 || !isWaitingForLandscape) return@LaunchedEffect
        delay(LandscapeTimeoutMillis)
        if (isWaitingForLandscape && !state.isDemoVisible) {
            isWaitingForLandscape = false
            orientationRequest = 0
            orientationFailed = true
            returnToPortrait()
        }
    }

    // Another house or account closes the room, a running race included.
    LaunchedEffect(houseId, userId, houseOwnerId) { model.updateContext(houseId, userId, houseOwnerId) }
    LaunchedEffect(reduceMotion) { model.setReduceMotion(reduceMotion) }

    // The room is portrait; the race countdown turns the screen.
    LaunchedEffect(state.isOnlineMatchVisible) {
        if (state.isOnlineMatchVisible) {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else if (!state.isDemoVisible && !isWaitingForLandscape) {
            returnToPortrait()
        }
    }

    LaunchedEffect(lobby?.requiresAuthentication, onlineMatch?.result) {
        if (model.requiresOnlineSignIn()) {
            model.stop()
            returnToPortrait()
            onRequireSignIn()
        }
    }

    LaunchedEffect(canvasSize) {
        if (canvasSize == IntSize.Zero) return@LaunchedEffect
        isLandscapeLayout = canvasSize.width > canvasSize.height
        model.setOnlineLandscape(isLandscapeLayout)
        with(density) { model.setViewport(canvasSize.width.toDp().value.toDouble(), canvasSize.height.toDp().value.toDouble()) }
        if (isLandscapeLayout && isWaitingForLandscape && !state.isDemoVisible && isForeground && !orientationFailed) {
            isWaitingForLandscape = false
            orientationRequest = 0
            model.startDemo()
        }
    }

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
                    if (isWaitingForLandscape) {
                        isWaitingForLandscape = false
                        orientationRequest = 0
                        returnToPortrait()
                    }
                    model.pauseDemo()
                    model.setForeground(false)
                }
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    // The race is immersive; the lobby keeps the status bar like the iOS navigation stack.
    val isRaceVisible = state.isDemoVisible || state.isOnlineMatchVisible
    val isImmersive = isRaceVisible
    DisposableEffect(isImmersive, activity) {
        activity?.window?.let { window ->
            val controller = WindowCompat.getInsetsController(window, view)
            if (isImmersive) {
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
                SwitchHaptic.LIGHT -> HapticFeedbackConstants.KEYBOARD_TAP
                SwitchHaptic.RIGID, SwitchHaptic.SOFT -> HapticFeedbackConstants.CLOCK_TICK
                SwitchHaptic.MEDIUM -> HapticFeedbackConstants.VIRTUAL_KEY
                SwitchHaptic.WARNING -> HapticFeedbackConstants.CONTEXT_CLICK
                SwitchHaptic.ERROR -> HapticFeedbackConstants.REJECT
                SwitchHaptic.SUCCESS -> HapticFeedbackConstants.CONFIRM
            })
        }
    }

    BackHandler {
        when {
            state.isDemoVisible -> if (state.isPaused || state.showsDemoResult) exitDemoToSetup() else model.pauseDemo()
            state.selectedMode != null -> model.returnToModeSelection()
            else -> exitGame()
        }
    }

    Box(Modifier.fillMaxSize().onSizeChanged { canvasSize = it }) {
        if (isRaceVisible) {
            FausSwitchGameLayer(
                frameState = frameState, match = match, state = state, copy = copy, renderer = renderer,
                reduceMotion = reduceMotion, isForeground = isForeground,
                actions = SwitchRaceActions(
                    onFrame = model::onFrame, onFlip = model::flip, onPause = model::pauseDemo, onResume = model::resumeDemo,
                    onRestart = model::restartDemo, onWatch = model::watchDemo, onChangeSetup = ::exitDemoToSetup,
                    onExit = ::exitGame, onToggleMusic = model::toggleMusic, onToggleSound = model::toggleSound,
                ),
                online = if (state.isOnlineMatchVisible) SwitchOnlineRaceUi(
                    match = onlineMatch, members = members, onLeave = ::leaveOnlineRace, onRematch = model::rematchOnline,
                    onRetry = { model.retryOnline() }, onRetryResult = { model.retryOnlineResult() },
                    onReclaim = { model.reclaimOnlineControl() },
                ) else null,
            )
        } else {
            FausSwitchTextureBackdrop(Modifier.fillMaxSize())
            FausSwitchLobby(
                state = state, copy = copy, constants = constants, reduceMotion = reduceMotion, userId = userId, houseId = houseId,
                isLandscapeLayout = isLandscapeLayout, isWaitingForLandscape = isWaitingForLandscape,
                orientationFailed = orientationFailed,
                online = SwitchOnlineRoomUi(
                    lobby = lobby, room = room ?: SwitchRoom(), members = members,
                    uptime = { onlineSession?.uptime() ?: 0.0 },
                    onReady = { model.setOnlineReady(it) }, onCancel = { model.cancelOnlineMatch() },
                    onRetry = { model.retryOnline() },
                ),
                onBack = ::exitGame, onSelectMode = model::selectMode,
                onChangeMode = model::returnToModeSelection, onSelectColor = model::selectColor,
                onSelectBotCount = model::selectBotCount, onStart = ::requestLandscape,
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
