package com.houseflow

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.houseflow.platform.AppLifecycle
import com.houseflow.platform.AuthDestination
import com.houseflow.ui.auth.AuthScreen
import com.houseflow.ui.auth.AuthStatusScreen
import com.houseflow.ui.auth.BirthdaySetupScreen
import com.houseflow.ui.auth.EmailVerificationScreen
import com.houseflow.ui.auth.ForgotPasswordScreen
import com.houseflow.ui.onboarding.OnboardingScreen
import com.houseflow.ui.house.CreateHouseScreen
import com.houseflow.ui.dashboard.DashboardScreen
import com.houseflow.ui.house.HouseErrorScreen
import com.houseflow.ui.house.HouseLoadingScreen
import com.houseflow.ui.house.HouseSelectionScreen
import com.houseflow.ui.house.JoinHouseScreen
import com.houseflow.ui.profile.ProfileScreen
import com.houseflow.viewmodel.AuthRoute
import com.houseflow.viewmodel.AuthViewModel
import com.houseflow.viewmodel.HouseRoute
import com.houseflow.viewmodel.HouseViewModel

class MainActivity : ComponentActivity() {
    private var authViewModel: AuthViewModel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = android.graphics.Color.WHITE
        window.navigationBarColor = android.graphics.Color.WHITE
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        setContent {
            val model: AuthViewModel = viewModel(factory = AuthViewModel.Factory(applicationContext))
            val houseModel: HouseViewModel = viewModel(factory = HouseViewModel.Factory(applicationContext))
            authViewModel = model
            val state by model.state.collectAsStateWithLifecycle()
            val houseState by houseModel.state.collectAsStateWithLifecycle()
            val profileState by model.profileState.collectAsStateWithLifecycle()
            val text by model.text.collectAsStateWithLifecycle()
            var selectedTab by rememberSaveable { mutableStateOf("home") }
            LaunchedEffect(state.profile) {
                state.profile?.let(houseModel::acceptProfile) ?: houseModel.resetSession()
            }
            LaunchedEffect(state.route) {
                if (state.route !is AuthRoute.Next) selectedTab = "home"
            }
            LaunchedEffect(state.route) {
                val isAuth = state.route is AuthRoute.SignIn || state.route is AuthRoute.ForgotPassword ||
                    (state.route is AuthRoute.Next && (state.route as AuthRoute.Next).destination == AuthDestination.EMAIL_VERIFICATION)
                window.statusBarColor = if (isAuth) android.graphics.Color.rgb(255, 165, 0) else android.graphics.Color.WHITE
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR or
                    (if (isAuth) 0 else android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)
            }
            val nav = rememberNavController()
            val currentRoute = state.route
            val target = when (currentRoute) {
                AuthRoute.Onboarding -> "onboarding"
                AuthRoute.SignIn -> "auth"
                AuthRoute.ForgotPassword -> "forgot"
                is AuthRoute.Next -> when (currentRoute.destination) {
                    AuthDestination.EMAIL_VERIFICATION -> "verify"
                    AuthDestination.BIRTHDAY_SETUP -> "birthday"
                    else -> when (houseState.route) {
                        HouseRoute.LOADING -> "houseLoading"
                        HouseRoute.SELECTION -> "houseSelection"
                        HouseRoute.CREATE -> "houseCreate"
                        HouseRoute.JOIN -> "houseJoin"
                        HouseRoute.DASHBOARD -> if (selectedTab == "profile") "profile" else "dashboard"
                        HouseRoute.ERROR -> "houseError"
                    }
                }
                else -> "status"
            }
            LaunchedEffect(target) {
                nav.navigate(target) { popUpTo(nav.graph.id) { inclusive = true }; launchSingleTop = true }
            }
            NavHost(navController = nav, startDestination = "status") {
                composable("onboarding") {
                    OnboardingScreen(text, state.busy, model::completeOnboarding)
                }
                composable("auth") {
                    AuthScreen(state, text, model::setEmail, model::setPassword, model::setFirstName,
                        model::setLastName, model::selectMode, model::openForgotPassword, model::submitAuth)
                }
                composable("forgot") {
                    ForgotPasswordScreen(state, text, model::closeForgotPassword, model::setForgotEmail,
                        model::requestPasswordReset, { model.setCode(it, true) }, model::setNewPassword, model::resetPassword)
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
                    AuthStatusScreen(state.route, text, model::restore, model::logout)
                    BackHandler(state.route is AuthRoute.Next) { /* Keep authenticated route stable. */ }
                }
                composable("houseLoading") {
                    HouseLoadingScreen(houseState, text)
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
                    HouseErrorScreen(houseState, text, houseModel::retry, model::logout)
                    BackHandler { /* iOS house error requires Retry or Log out. */ }
                }
                composable("dashboard") {
                    DashboardScreen(houseState, text, houseModel::switchHouse,
                        houseModel::createAnnouncement, houseModel::createChore,
                        houseModel::updateChoreStatus, houseModel::reviewChore,
                        houseModel::clearMutationMessage, { selectedTab = "profile" })
                    BackHandler { /* Root tab screen. */ }
                }
                composable("profile") {
                    state.profile?.let { user ->
                        ProfileScreen(user, houseState, profileState, text,
                            { selectedTab = "home" }, model::logout, model::updateProfile,
                            model::loadProfileImages, model::loadLanguages, model::saveLanguage,
                            model::clearProfileError, houseModel::joinFromProfile,
                            houseModel::loadInfo, houseModel::clearInfo, houseModel::createInvite,
                            houseModel::updateHouseProfile, houseModel::removeMember,
                            houseModel::leaveHouse, houseModel::clearProfileError)
                    }
                    BackHandler { selectedTab = "home" }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        AppLifecycle.bridge.onStarted()
        authViewModel?.onForeground()
    }

    override fun onStop() {
        authViewModel?.onBackground()
        AppLifecycle.bridge.onStopped()
        super.onStop()
    }
}
