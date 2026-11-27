package com.fauscrew

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.core.view.WindowCompat
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.ui.Modifier
import com.fauscrew.ui.components.DebugCrashDialog
import com.fauscrew.ui.components.FausSplash
import com.fauscrew.ui.components.LocalFausSplashActive
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.tween
import com.fauscrew.ui.components.dismissKeyboardOnTap
import com.fauscrew.viewmodel.HouseLoadingPhase
import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.fauscrew.platform.DebugCrashReport
import com.fauscrew.platform.ThemeAppearance
import com.fauscrew.platform.AppLifecycle
import com.fauscrew.platform.SocialActivityHolder
import com.fauscrew.push.PushChannels
import com.fauscrew.push.PushInbox
import com.fauscrew.push.PushRouteContext
import com.fauscrew.push.PushRouteStep
import com.fauscrew.push.PushRouter
import com.fauscrew.push.isRealSignOut
import com.fauscrew.push.notificationUserId
import com.fauscrew.ui.dashboard.notifications.NotificationActions
import com.fauscrew.ui.dashboard.archive.ChoreArchiveActions
import com.fauscrew.viewmodel.ChoreArchiveEffect
import com.fauscrew.viewmodel.ChoreArchiveViewModel
import com.fauscrew.viewmodel.GameStatsEffect
import com.fauscrew.viewmodel.GameStatsViewModel
import com.fauscrew.ui.games.OnlineGameVisual
import com.fauscrew.viewmodel.NotificationEffect
import com.fauscrew.viewmodel.NotificationViewModel
import com.fauscrew.platform.AppVisibility
import com.fauscrew.viewmodel.AppEventsRequest
import com.fauscrew.viewmodel.AppEventsViewModel
import com.fauscrew.viewmodel.ChoreCatalogViewModel
import com.fauscrew.platform.AuthDestination
import com.fauscrew.ui.auth.AuthScreen
import com.fauscrew.ui.auth.BirthdaySetupScreen
import com.fauscrew.ui.auth.EmailVerificationScreen
import com.fauscrew.ui.auth.ForgotPasswordScreen
import com.fauscrew.ui.auth.SocialEmailScreen
import com.fauscrew.ui.onboarding.OnboardingScreen
import com.fauscrew.ui.house.CreateHouseScreen
import com.fauscrew.ui.dashboard.DashboardScreen
import com.fauscrew.ui.games.GamesHubScreen
import com.fauscrew.ui.games.tanks.HouseTanksScreen
import com.fauscrew.ui.games.fausswitch.FausSwitchScreen
import com.fauscrew.ui.games.rockets.HouseRocketsScreen
import com.fauscrew.ui.house.HouseErrorScreen
import com.fauscrew.ui.house.HouseLoadingScreen
import com.fauscrew.ui.house.HouseSelectionScreen
import com.fauscrew.ui.house.JoinHouseScreen
import com.fauscrew.ui.main.MainTab
import com.fauscrew.ui.main.MainTabScreen
import com.fauscrew.ui.profile.ProfileScreen
import com.fauscrew.viewmodel.AuthRoute
import com.fauscrew.viewmodel.AuthViewModel
import com.fauscrew.viewmodel.HouseRoute
import com.fauscrew.viewmodel.HouseViewModel
import com.fauscrew.viewmodel.pushSessionUserId
import android.graphics.drawable.ColorDrawable
import androidx.compose.ui.graphics.toArgb
import androidx.lifecycle.lifecycleScope
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.ui.theme.FausCrewTheme
import com.fauscrew.ui.theme.FausThemeController
import com.fauscrew.ui.theme.FausThemeId
import com.fauscrew.ui.theme.LocalFausThemeController
import com.fauscrew.platform.PushSignOutReason
import com.fauscrew.push.PushPermission
import com.fauscrew.push.PushRegistrationHost
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class MainActivity : ComponentActivity() {
    private var authViewModel: AuthViewModel? = null
    private lateinit var themeController: FausThemeController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Debug builds: keep the last crash on the phone and show it (DebugCrashDialog below).
        DebugCrashReport.install(applicationContext)
        // Provider SDKs (Credential Manager, Facebook, Snap) present from this activity.
        SocialActivityHolder.attach(this)
        // The user's theme is needed for the very first frame (splash, window and bar colors), so
        // this one small preferences read blocks; every write after it is asynchronous.
        val preferences = AndroidPreferencesStore(applicationContext)
        val storedTheme = FausThemeId.fromStorage(runBlocking { preferences.selectedTheme() })
        themeController = FausThemeController(storedTheme) { id ->
            lifecycleScope.launch { preferences.setSelectedTheme(id.storageValue) }
        }
        // The launch window shows the theme's launch color (black on Android 11); the app itself
        // sits on the theme's base.
        window.setBackgroundDrawable(ColorDrawable(themeController.theme.palette.background.toArgb()))
        // A tapped push opens the app here; the routing effect below takes it to its house/chore.
        if (savedInstanceState == null && !launchedFromHistory(intent)) offerPushTap(intent)
        val coldStart = savedInstanceState == null
        // Compose owns every inset (status/nav bars and the keyboard) on all API levels, matching
        // the edge-to-edge behavior Android 15+ enforces. Screens pad themselves; the IME is
        // handled once at the root below.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContent {
            val theme = themeController.theme
            FausCrewTheme(theme) {
            CompositionLocalProvider(LocalFausThemeController provides themeController) {
            val model: AuthViewModel = viewModel(factory = AuthViewModel.Factory(applicationContext))
            val houseModel: HouseViewModel = viewModel(factory = HouseViewModel.Factory(applicationContext))
            val catalogModel: ChoreCatalogViewModel = viewModel(factory = ChoreCatalogViewModel.Factory(applicationContext))
            authViewModel = model
            val state by model.state.collectAsStateWithLifecycle()
            val houseState by houseModel.state.collectAsStateWithLifecycle()
            val profileState by model.profileState.collectAsStateWithLifecycle()
            val accountState by model.accountState.collectAsStateWithLifecycle()
            val text by model.text.collectAsStateWithLifecycle()
            var selectedTab by rememberSaveable { mutableStateOf(MainTab.HOME) }
            var showsHouseRockets by rememberSaveable { mutableStateOf(false) }
            var showsHouseTanks by rememberSaveable { mutableStateOf(false) }
            var showsFausSwitch by rememberSaveable { mutableStateOf(false) }
            // The dashboard has a popup open (it covers the dashboard for push routing).
            var dashboardOverlay by remember { mutableStateOf(false) }
            // Push routing asks the dashboard to close its popups / open a chore.
            var closeDashboardPopups by remember { mutableIntStateOf(0) }
            var openChoreRequest by remember { mutableStateOf<String?>(null) }
            // Brand intro on every cold start (not on configuration changes).
            var showsSplash by rememberSaveable { mutableStateOf(coldStart) }
            // Until the splash starts opening, the app underneath is hidden and holds its animations.
            var splashCovering by rememberSaveable { mutableStateOf(coldStart) }
            LaunchedEffect(state.profile) {
                state.profile?.let(houseModel::acceptProfile) ?: houseModel.resetSession()
            }
            // Push registration follows the fully signed-in user (verified, birthday set).
            val pushUserId = pushSessionUserId(state.profile, state.route)
            LaunchedEffect(pushUserId) { PushRegistrationHost.setSession(pushUserId) }
            // The channel name follows the app language (same channel id).
            LaunchedEffect(text.prefix) { PushChannels.ensureDefault(applicationContext) }
            LaunchedEffect(state.profile?.userId) {
                catalogModel.setOwner(state.profile?.userId)
            }
            // `/api/v1/events`: one socket while visible and signed in; signals trigger HTTP refreshes.
            val eventsModel: AppEventsViewModel = viewModel(factory = AppEventsViewModel.Factory(applicationContext))
            val visibility by AppLifecycle.bridge.visibility.collectAsStateWithLifecycle()
            val signedIn = state.profile != null && state.route is AuthRoute.Next
            // Ask for notification permission once, a moment after the dashboard first shows (after the splash).
            val notificationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
            var askedForPush by rememberSaveable { mutableStateOf(false) }
            val onDashboard = signedIn && houseState.route == HouseRoute.DASHBOARD
            LaunchedEffect(onDashboard, showsSplash) {
                if (!onDashboard || showsSplash || askedForPush) return@LaunchedEffect
                askedForPush = true
                delay(1_000)
                if (PushPermission.needsRuntimeRequest(applicationContext) && !preferences.hasRequestedNotificationPermission()) {
                    preferences.setRequestedNotificationPermission(true)
                    notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
            LaunchedEffect(visibility, signedIn) {
                eventsModel.update(foreground = visibility == AppVisibility.ACTIVE, authenticated = signedIn)
            }
            LaunchedEffect(houseState.details?.id) { eventsModel.setSelectedHouse(houseState.details?.id) }
            // Unread badge, notification panel and reminders follow the selected house.
            val notificationModel: NotificationViewModel = viewModel(factory = NotificationViewModel.Factory(applicationContext))
            val notificationState by notificationModel.state.collectAsStateWithLifecycle()
            // A session restore blips the push user to null; keep the badge and reminders through it.
            var lastNotificationUser by remember { mutableStateOf<String?>(null) }
            val notificationUser = notificationUserId(lastNotificationUser, pushUserId, state.route)
            SideEffect { lastNotificationUser = notificationUser }
            LaunchedEffect(notificationUser, houseState.details?.id) { notificationModel.setContext(notificationUser, houseState.details?.id) }
            LaunchedEffect(notificationModel) { PushInbox.foregroundMessages.collect(notificationModel::onForegroundPush) }
            LaunchedEffect(notificationModel) {
                notificationModel.effects.collect { effect ->
                    when (effect) {
                        NotificationEffect.SessionRejected -> model.logout(PushSignOutReason.SessionRejected)
                        NotificationEffect.RefreshProfile -> model.refreshProfile()
                        is NotificationEffect.RefreshHouse -> houseModel.refreshDetails(effect.houseId)
                    }
                }
            }
            // The archive loads only when its popup opens; it follows the same user and house.
            val archiveModel: ChoreArchiveViewModel = viewModel(factory = ChoreArchiveViewModel.Factory(applicationContext))
            val archiveState by archiveModel.state.collectAsStateWithLifecycle()
            LaunchedEffect(notificationUser, houseState.details?.id) { archiveModel.setContext(notificationUser, houseState.details?.id) }
            LaunchedEffect(archiveModel) {
                archiveModel.effects.collect { effect ->
                    when (effect) {
                        ChoreArchiveEffect.SessionRejected -> model.logout(PushSignOutReason.SessionRejected)
                        ChoreArchiveEffect.RefreshProfile -> model.refreshProfile()
                    }
                }
            }
            // The dashboard stats card loads when it appears; it follows the same user, house and members.
            val gameStatsModel: GameStatsViewModel = viewModel(
                factory = GameStatsViewModel.Factory(applicationContext, OnlineGameVisual.knownGameKeys))
            val gameStatsState by gameStatsModel.state.collectAsStateWithLifecycle()
            LaunchedEffect(notificationUser, houseState.details?.id) { gameStatsModel.setContext(notificationUser, houseState.details?.id) }
            val statsMemberIds = houseState.details?.members.orEmpty().map { it.id }
            LaunchedEffect(statsMemberIds) { gameStatsModel.setMembers(statsMemberIds) }
            LaunchedEffect(gameStatsModel) {
                gameStatsModel.effects.collect { effect ->
                    when (effect) {
                        GameStatsEffect.SessionRejected -> model.logout(PushSignOutReason.SessionRejected)
                        GameStatsEffect.RefreshProfile -> model.refreshProfile()
                    }
                }
            }
            LaunchedEffect(houseModel) {
                houseModel.signOutRequests.collect { model.logout(PushSignOutReason.SessionRejected) }
            }
            LaunchedEffect(eventsModel) {
                eventsModel.requests.collect { request ->
                    when (request) {
                        is AppEventsRequest.Refresh -> {
                            if (request.profile) model.refreshProfile()
                            request.houseId?.let(houseModel::refreshDetails)
                        }
                        is AppEventsRequest.RefreshNotifications -> notificationModel.refresh(request.houseId)
                        AppEventsRequest.SignOut -> model.logout(PushSignOutReason.SessionRejected)
                    }
                }
            }
            LaunchedEffect(state.route) {
                if (state.route !is AuthRoute.Next) {
                    selectedTab = MainTab.HOME
                    showsHouseRockets = false
                    showsHouseTanks = false
                    showsFausSwitch = false
                }
            }
            LaunchedEffect(state.route, showsSplash, theme) {
                val isAuth = state.route is AuthRoute.SignIn || state.route is AuthRoute.ForgotPassword ||
                    state.route is AuthRoute.SocialEmail ||
                    (state.route is AuthRoute.Next && (state.route as AuthRoute.Next).destination == AuthDestination.EMAIL_VERIFICATION)
                val base = theme.palette.background.toArgb()
                window.setBackgroundDrawable(ColorDrawable(base))
                window.statusBarColor = when {
                    showsSplash -> android.graphics.Color.TRANSPARENT
                    isAuth -> theme.decor.headerStops.first().second.toArgb()
                    else -> base
                }
                window.navigationBarColor = base
                val lightBars = !theme.isDark
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility =
                    (if (lightBars) android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR else 0) or
                    (if (isAuth || showsSplash || !lightBars) 0 else android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)
            }
            val nav = rememberNavController()
            val currentRoute = state.route
            val target = when (currentRoute) {
                AuthRoute.Onboarding -> "onboarding"
                AuthRoute.SignIn -> "auth"
                AuthRoute.ForgotPassword -> "forgot"
                AuthRoute.SocialEmail -> "socialEmail"
                is AuthRoute.Next -> when (currentRoute.destination) {
                    AuthDestination.EMAIL_VERIFICATION -> "verify"
                    AuthDestination.BIRTHDAY_SETUP -> "birthday"
                    else -> when (houseState.route) {
                        HouseRoute.LOADING -> "houseLoading"
                        HouseRoute.SELECTION -> "houseSelection"
                        HouseRoute.CREATE -> "houseCreate"
                        HouseRoute.JOIN -> "houseJoin"
                        HouseRoute.DASHBOARD -> "main"
                        HouseRoute.ERROR -> "houseError"
                    }
                }
                AuthRoute.Restoring -> "houseLoading"
                is AuthRoute.RestoreError -> "status"
            }
            // A tapped push: Core says what is next; each step changes the context and runs again.
            val pushRouter = remember { PushRouter() }
            val pendingTap by PushInbox.pendingTap.collectAsStateWithLifecycle()
            val routeContext = PushRouteContext(
                isSignedIn = pushUserId != null,
                houseIds = if (pushUserId != null && houseState.userId == pushUserId) houseState.houses.map { it.id } else null,
                selectedHouseId = houseState.details?.id,
                isSwitchingHouse = houseState.route != HouseRoute.DASHBOARD || houseState.busy,
                isGameOpen = showsHouseRockets || showsHouseTanks || showsFausSwitch,
                isDashboardShown = target == "main" && selectedTab == MainTab.HOME && !dashboardOverlay,
                loadedChoreIds = houseState.details?.chores?.mapTo(mutableSetOf()) { it.id },
            )
            var hadSession by remember { mutableStateOf(false) }
            LaunchedEffect(state.profile?.userId, state.route) {
                if (isRealSignOut(hadSession, state.profile?.userId, state.route)) PushInbox.take()
                if (state.route != AuthRoute.Restoring) hadSession = state.profile != null
            }
            LaunchedEffect(pendingTap) { pushRouter.reset() }
            LaunchedEffect(pendingTap, routeContext) {
                val tap = pendingTap ?: return@LaunchedEffect
                when (val step = pushRouter.next(tap, routeContext)) {
                    PushRouteStep.Wait -> Unit
                    PushRouteStep.Drop, PushRouteStep.Finished -> PushInbox.take()
                    is PushRouteStep.SwitchHouse -> houseModel.switchHouse(step.houseId)
                    PushRouteStep.ShowDashboard -> {
                        selectedTab = MainTab.HOME
                        closeDashboardPopups++
                    }
                    is PushRouteStep.OpenChore -> {
                        openChoreRequest = step.choreId
                        PushInbox.take()
                    }
                }
            }
            LaunchedEffect(target) {
                nav.navigate(target) { popUpTo(nav.graph.id) { inclusive = true }; launchSingleTop = true }
            }
            // Root keyboard policy: content shrinks above the IME (focused fields scroll into view)
            // and taps on empty space dismiss it, like iOS keyboard avoidance + dismissKeyboardOnTap.
            Box(Modifier.fillMaxSize().imePadding().dismissKeyboardOnTap()) {
            CompositionLocalProvider(LocalFausSplashActive provides splashCovering) {
            NavHost(
                navController = nav, startDestination = "houseLoading",
                // Route changes behind the splash land instantly; nobody can see the fade.
                enterTransition = { if (splashCovering) EnterTransition.None else fadeIn(tween(700)) },
                exitTransition = { if (splashCovering) ExitTransition.None else fadeOut(tween(700)) },
            ) {
                composable("onboarding") {
                    OnboardingScreen(text, state.busy, model::completeOnboarding)
                }
                composable("auth") {
                    AuthScreen(state, text, model::setEmail, model::setPassword, model::setFirstName,
                        model::setLastName, model::selectMode, model::openForgotPassword, model::submitAuth,
                        model::signInWithSocial)
                }
                composable("socialEmail") {
                    SocialEmailScreen(state, text, model::cancelSocial, model::setSocialEmail, model::sendSocialCode,
                        model::setSocialCode, model::setSocialFirstName, model::setSocialLastName, model::completeSocial)
                }
                composable("forgot") {
                    ForgotPasswordScreen(state, text, model::closeForgotPassword, model::setForgotEmail,
                        model::requestPasswordReset, model::setCode, model::setNewPassword, model::resetPassword)
                }
                composable("verify") {
                    val route = state.route as? AuthRoute.Next
                    if (route != null) EmailVerificationScreen(state, text, route.email, { model.logout(PushSignOutReason.UserInitiated) },
                        model::sendVerificationCode, { model.setCode(it) }, model::verifyEmail, model::dismissSignupSuccess)
                }
                composable("birthday") {
                    BirthdaySetupScreen(state, text, model::setBirthday, model::saveBirthday)
                }
                composable("status") {
                    HouseErrorScreen(text, model::restore) { model.logout(PushSignOutReason.UserInitiated) }
                    BackHandler { /* iOS restore error requires Retry or Log out. */ }
                }
                composable("houseLoading") {
                    // One loading surface for session restore and house work, like iOS HouseLoadingView:
                    // only the phase copy/color changes, so there is no second loader on launch.
                    val phase = if (state.route is AuthRoute.Next) houseState.phase else HouseLoadingPhase.CHECKING_AUTH
                    HouseLoadingScreen(phase, text)
                    BackHandler { /* Match iOS loading: await the active operation. */ }
                }
                composable("houseSelection") {
                    HouseSelectionScreen(text, houseModel::showCreate, houseModel::showJoin)
                    BackHandler { /* The signed-in empty-house entry has no prior house. */ }
                }
                composable("houseCreate") {
                    CreateHouseScreen(houseState, text, houseModel::backToSelection, houseModel::create)
                    BackHandler { houseModel.backToSelection() }
                }
                composable("houseJoin") {
                    JoinHouseScreen(houseState, text, houseModel::backToSelection, houseModel::join)
                    BackHandler { houseModel.backToSelection() }
                }
                composable("houseError") {
                    HouseErrorScreen(text, houseModel::retry) { model.logout(PushSignOutReason.UserInitiated) }
                    BackHandler { /* iOS house error requires Retry or Log out. */ }
                }
                composable("main") {
                    MainTabScreen(
                        selectedTab = selectedTab,
                        onSelectTab = { selectedTab = it },
                        houses = houseState.houses,
                        currentHouseId = houseState.details?.id,
                        onSwitchHouse = houseModel::switchHouse,
                        strings = text,
                        profile = { onOverlayChange ->
                            state.profile?.let { user ->
                                ProfileScreen(user, houseState, profileState, text, { model.logout(PushSignOutReason.UserInitiated) }, model::updateProfile,
                                    model::loadProfileImages, model::loadLanguages, model::saveLanguage,
                                    model::clearProfileError, houseModel::joinFromProfile,
                                    houseModel::loadInfo, houseModel::clearInfo, houseModel::createInvite,
                                    houseModel::updateHouseProfile, houseModel::removeMember,
                                    houseModel::leaveHouse, houseModel::clearProfileError, onOverlayChange,
                                    onCreateHouse = houseModel::createFromProfile,
                                    accountState = accountState,
                                    socialProviders = state.socialProviders,
                                    onOpenAccount = { model.clearAccountMessage(); model.refreshProfile() },
                                    onLinkProvider = model::linkProvider,
                                    onUnlinkProvider = model::unlinkProvider,
                                    onRequestPasswordCode = model::requestPasswordSetup,
                                    onSetPassword = model::setPassword,
                                    onDeleteAccount = model::deleteAccount)
                            }
                        },
                        dashboard = { onOverlayChange ->
                            DashboardScreen(houseState, text, houseModel::createAnnouncement, houseModel::createChore,
                                houseModel::updateChoreStatus, houseModel::reviewChore,
                                houseModel::clearMutationMessage,
                                { dashboardOverlay = it; onOverlayChange(it) },
                                onLoadReviewPhoto = houseModel::reviewPhoto, catalog = catalogModel,
                                notifications = notificationState,
                                notificationActions = NotificationActions(
                                    open = notificationModel::open, close = notificationModel::close,
                                    reload = notificationModel::reload, loadMore = notificationModel::loadMore,
                                    remind = notificationModel::remind, clearToast = notificationModel::clearToast),
                                archive = archiveState,
                                archiveActions = ChoreArchiveActions(
                                    open = archiveModel::open, previousMonth = archiveModel::previousMonth,
                                    nextMonth = archiveModel::nextMonth, reload = archiveModel::reload,
                                    loadMore = archiveModel::loadMore),
                                gameStats = gameStatsState, onRefreshGameStats = gameStatsModel::refresh,
                                currentUserId = notificationUser,
                                openChoreRequest = openChoreRequest, onOpenChoreHandled = { openChoreRequest = null },
                                closePopupsSignal = closeDashboardPopups)
                        },
                        games = { onOverlayChange ->
                            // The game is a full-screen destination of the Games tab, so the
                            // floating tab bar steps aside while it is open.
                            LaunchedEffect(showsHouseRockets, showsHouseTanks, showsFausSwitch) {
                                onOverlayChange(showsHouseRockets || showsHouseTanks || showsFausSwitch)
                            }
                            if (showsFausSwitch) {
                                FausSwitchScreen(text, houseState.details?.id, state.profile?.userId,
                                    onExit = { showsFausSwitch = false },
                                    houseOwnerId = houseState.details?.ownerId?.ifBlank { null },
                                    members = houseState.details?.members.orEmpty()
                                        .filter { it.name.isNotBlank() }.associate { it.id to it.name },
                                    onRequireSignIn = {
                                        showsFausSwitch = false
                                        model.logout(PushSignOutReason.SessionRejected)
                                    })
                            } else if (showsHouseTanks) {
                                HouseTanksScreen(text, houseState.details?.id, state.profile?.userId,
                                    onExit = { showsHouseTanks = false },
                                    houseOwnerId = houseState.details?.ownerId?.ifBlank { null },
                                    members = houseState.details?.members.orEmpty()
                                        .filter { it.name.isNotBlank() }.map { it.id to it.name },
                                    onRequireSignIn = {
                                        showsHouseTanks = false
                                        model.logout(PushSignOutReason.SessionRejected)
                                    })
                            } else if (showsHouseRockets) {
                                HouseRocketsScreen(text, houseState.details?.id, state.profile?.userId,
                                    onExit = { showsHouseRockets = false },
                                    houseOwnerId = houseState.details?.ownerId?.ifBlank { null },
                                    memberNames = houseState.details?.members.orEmpty()
                                        .associate { it.id to it.name }.filterValues(String::isNotBlank),
                                    onRequireSignIn = {
                                        showsHouseRockets = false
                                        model.logout(PushSignOutReason.SessionRejected)
                                    })
                            } else {
                                GamesHubScreen(text, onOpenHouseRockets = { showsHouseRockets = true },
                                    onOpenHouseTanks = { showsHouseTanks = true },
                                    onOpenFausSwitch = { showsFausSwitch = true })
                            }
                        },
                    )
                    // Profile returns to Home; Home is the root tab and keeps the session screen.
                    // An open game owns Back (pause/exit), so the tab fallback yields to it.
                    BackHandler(enabled = !(selectedTab == MainTab.GAMES && (showsHouseRockets || showsHouseTanks || showsFausSwitch))) {
                        if (selectedTab != MainTab.HOME) selectedTab = MainTab.HOME
                    }
                }
            }
            }
            if (showsSplash) FausSplash(onReveal = { splashCovering = false }) { showsSplash = false }
            DebugCrashDialog()
            }
            }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        offerPushTap(intent)
    }

    private fun offerPushTap(intent: Intent?) {
        PushInbox.fromIntent(intent)?.let(PushInbox::offer)
    }

    /** Recents relaunches the task's original intent, which would replay an old push tap. */
    private fun launchedFromHistory(intent: Intent) =
        intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0

    override fun onDestroy() {
        SocialActivityHolder.detach(this)
        super.onDestroy()
    }

    override fun onStart() {
        super.onStart()
        AppLifecycle.bridge.onStarted()
        authViewModel?.onForeground()
    }

    override fun onStop() {
        ThemeAppearance.applyLauncherIcon(applicationContext, themeController.themeId)
        ThemeAppearance.applyLaunchScreen(this, themeController.themeId)
        authViewModel?.onBackground()
        AppLifecycle.bridge.onStopped()
        super.onStop()
    }
}
