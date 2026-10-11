package com.houseflow

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.houseflow.platform.AppLifecycle
import com.houseflow.ui.auth.AuthScreen
import com.houseflow.ui.auth.AuthStatusScreen
import com.houseflow.viewmodel.AuthRoute
import com.houseflow.viewmodel.AuthViewModel

class MainActivity : ComponentActivity() {
    private var authViewModel: AuthViewModel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = android.graphics.Color.rgb(255, 165, 0)
        window.navigationBarColor = android.graphics.Color.WHITE
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        setContent {
            val model: AuthViewModel = viewModel(factory = AuthViewModel.Factory(applicationContext))
            authViewModel = model
            val state by model.state.collectAsStateWithLifecycle()
            val text by model.text.collectAsStateWithLifecycle()
            val nav = rememberNavController()
            val target = if (state.route is AuthRoute.SignIn) "auth" else "status"
            LaunchedEffect(target) {
                nav.navigate(target) { popUpTo(nav.graph.id) { inclusive = true }; launchSingleTop = true }
            }
            NavHost(navController = nav, startDestination = "status") {
                composable("auth") {
                    AuthScreen(state, text, model::setEmail, model::setPassword, model::login)
                }
                composable("status") {
                    AuthStatusScreen(state.route, text, model::restore, model::logout)
                    BackHandler(state.route is AuthRoute.Next) { /* Keep authenticated route stable. */ }
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
