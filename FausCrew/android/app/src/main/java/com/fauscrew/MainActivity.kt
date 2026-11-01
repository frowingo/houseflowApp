package com.fauscrew

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.core.view.WindowCompat
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.ui.Modifier
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.fauscrew.platform.ThemeAppearance
import com.fauscrew.platform.AppLifecycle
import com.fauscrew.platform.SocialActivityHolder
import com.fauscrew.platform.AppVisibility
import com.fauscrew.viewmodel.AppEventsRequest
import com.fauscrew.viewmodel.AppEventsViewModel
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
import android.graphics.drawable.ColorDrawable
import androidx.compose.ui.graphics.toArgb
import androidx.lifecycle.lifecycleScope
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.ui.theme.FausCrewTheme
import com.fauscrew.ui.theme.FausThemeController
import com.fauscrew.ui.theme.FausThemeId
import com.fauscrew.ui.theme.LocalFausThemeController
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class MainActivity : ComponentActivity() {
    private var authViewModel: AuthViewModel? = null
    private lateinit var themeController: FausThemeController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Provider SDKs (Credential Manager, Facebook, Snap) present from this activity.
        SocialActivityHolder.attach(this)
        // The user's theme is needed for the very first frame (splash, window and bar colors), so
        // this one small preferences read blocks; every write after it is asynchronous.
        val preferences = AndroidPreferencesStore(applicationContext)
        val storedTheme = FausThemeId.fromStorage(runBlocking { preferences.selectedTheme() })
        themeController = FausThemeController(storedTheme) { id ->
            lifecycleScope.launch { preferences.setSelectedTheme(id.storageValue) }
        }
        // The launch window shows `launch_background`; the app itself sits on the theme's base.
        window.setBackgroundDrawable(ColorDrawable(themeController.theme.palette.background.toArgb()))
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
            authViewModel = model
            val state by model.state.collectAsStateWithLifecycle()
            val houseState by houseModel.state.collectAsStateWithLifecycle()
            val profileState by model.profileState.collectAsStateWithLifecycle()
            val accountState by model.accountState.collectAsStateWithLifecycle()
            val text by model.text.collectAsStateWithLifecycle()
            var selectedTab by rememberSaveable { mutableStateOf(MainTab.HOME) }
            var showsHouseRockets by rememberSaveable { mutableStateOf(false) }
            var showsHouseTanks by rememberSaveable { mutableStateOf(false) }
            // Brand intro on every cold start (not on configuration changes).
            var showsSplash by rememberSaveable { mutableStateOf(coldStart) }
            // Until the splash starts opening, the app underneath is hidden and holds its animations.
            var splashCovering by rememberSaveable { mutableStateOf(coldStart) }
            LaunchedEffect(state.profile) {
                state.profile?.let(houseModel::acceptProfile) ?: houseModel.resetSession()
            }
            // `/api/v1/events`: one socket while visible and signed in; signals trigger HTTP refreshes.
            val eventsModel: AppEventsViewModel = viewModel(factory = AppEventsViewModel.Factory(applicationContext))
            val visibility by AppLifecycle.bridge.visibility.collectAsStateWithLifecycle()
            val signedIn = state.profile != null && state.route is AuthRoute.Next
            LaunchedEffect(visibility, signedIn) {
                eventsModel.update(foreground = visibility == AppVisibility.ACTIVE, authenticated = signedIn)
            }
            LaunchedEffect(houseState.details?.id) { eventsModel.setSelectedHouse(houseState.details?.id) }
            LaunchedEffect(eventsModel) {
                eventsModel.requests.collect { request ->
                    when (request) {
                        is AppEventsRequest.Refresh -> {
                            if (request.profile) model.refreshProfile()
                            request.houseId?.let(houseModel::refreshDetails)
                        }
                        AppEventsRequest.SignOut -> model.logout()
                    }
                }
            }
            LaunchedEffect(state.route) {
                if (state.route !is AuthRoute.Next) {
                    selectedTab = MainTab.HOME
                    showsHouseRockets = false
                    showsHouseTanks = false
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
                    if (route != null) EmailVerificationScreen(state, text, route.email, model::logout,
                        model::sendVerificationCode, { model.setCode(it) }, model::verifyEmail, model::dismissSignupSuccess)
                }
                composable("birthday") {
                    BirthdaySetupScreen(state, text, model::setBirthday, model::saveBirthday)
                }
                composable("status") {
                    HouseErrorScreen(text, model::restore, model::logout)
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
                    HouseErrorScreen(text, houseModel::retry, model::logout)
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
                                ProfileScreen(user, houseState, profileState, text, model::logout, model::updateProfile,
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
                                houseModel::clearMutationMessage, onOverlayChange,
                                onLoadReviewPhoto = houseModel::reviewPhoto)
                        },
                        games = { onOverlayChange ->
                            // The game is a full-screen destination of the Games tab, so the
                            // floating tab bar steps aside while it is open.
                            LaunchedEffect(showsHouseRockets, showsHouseTanks) {
                                onOverlayChange(showsHouseRockets || showsHouseTanks)
                            }
                            if (showsHouseTanks) {
                                HouseTanksScreen(text, houseState.details?.id, state.profile?.userId,
                                    onExit = { showsHouseTanks = false },
                                    houseOwnerId = houseState.details?.ownerId?.ifBlank { null },
                                    members = houseState.details?.members.orEmpty()
                                        .filter { it.name.isNotBlank() }.map { it.id to it.name },
                                    onRequireSignIn = {
                                        showsHouseTanks = false
                                        model.logout()
                                    })
                            } else if (showsHouseRockets) {
                                HouseRocketsScreen(text, houseState.details?.id, state.profile?.userId,
                                    onExit = { showsHouseRockets = false },
                                    houseOwnerId = houseState.details?.ownerId?.ifBlank { null },
                                    memberNames = houseState.details?.members.orEmpty()
                                        .associate { it.id to it.name }.filterValues(String::isNotBlank),
                                    onRequireSignIn = {
                                        showsHouseRockets = false
                                        model.logout()
                                    })
                            } else {
                                GamesHubScreen(text, onOpenHouseRockets = { showsHouseRockets = true },
                                    onOpenHouseTanks = { showsHouseTanks = true })
                            }
                        },
                    )
                    // Profile returns to Home; Home is the root tab and keeps the session screen.
                    // An open game owns Back (pause/exit), so the tab fallback yields to it.
                    BackHandler(enabled = !(selectedTab == MainTab.GAMES && (showsHouseRockets || showsHouseTanks))) {
                        if (selectedTab != MainTab.HOME) selectedTab = MainTab.HOME
                    }
                }
            }
            }
            if (showsSplash) FausSplash(onReveal = { splashCovering = false }) { showsSplash = false }
            }
            }
            }
        }
    }

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
        authViewModel?.onBackground()
        AppLifecycle.bridge.onStopped()
        super.onStop()
    }
}
