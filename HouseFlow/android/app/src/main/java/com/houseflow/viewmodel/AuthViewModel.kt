package com.houseflow.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.houseflow.platform.AndroidHttpAdapter
import com.houseflow.platform.AndroidLocalizationState
import com.houseflow.platform.AuthDestination
import com.houseflow.platform.AuthProfile
import com.houseflow.platform.AuthProfileException
import com.houseflow.platform.AuthRequestException
import com.houseflow.platform.AuthRestoreResult
import com.houseflow.platform.AuthSessionRepository
import com.houseflow.platform.LocalizedText
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal sealed interface AuthRoute {
    data object Restoring : AuthRoute
    data object SignIn : AuthRoute
    data class Next(val destination: AuthDestination, val email: String) : AuthRoute
    data class RestoreError(val message: String?) : AuthRoute
}

internal data class AuthUiState(
    val route: AuthRoute = AuthRoute.Restoring,
    val email: String = "",
    val password: String = "",
    val busy: Boolean = false,
    val error: String? = null,
) {
    val canSubmit: Boolean get() = email.isNotEmpty() && password.isNotEmpty() && !busy
}

internal class AuthViewModel(
    private val session: AuthSessionRepository,
    private val localization: AndroidLocalizationState,
    private val now: () -> Long = System::currentTimeMillis,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AuthUiState())
    val state: StateFlow<AuthUiState> = mutableState.asStateFlow()
    val text: StateFlow<LocalizedText> = localization.text
    private var sessionJob: Job? = null
    private var backgroundAt: Long? = null

    init {
        viewModelScope.launch {
            try { localization.start() } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) { /* Key fallback remains available. */ }
        }
        restore()
    }

    fun setEmail(value: String) { mutableState.value = mutableState.value.copy(email = value, error = null) }
    fun setPassword(value: String) { mutableState.value = mutableState.value.copy(password = value, error = null) }

    fun login() {
        val current = state.value
        if (!current.canSubmit) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                val profile = session.login(current.email, current.password)
                applyLanguageBestEffort(profile.language)
                route(profile)
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: AuthProfileException) {
                mutableState.value = mutableState.value.copy(
                    route = AuthRoute.RestoreError(error.serverMessage), busy = false, password = "",
                )
            } catch (error: AuthRequestException) {
                mutableState.value = mutableState.value.copy(busy = false, error = error.serverMessage ?: "Request failed.")
            } catch (_: IOException) {
                mutableState.value = mutableState.value.copy(busy = false, error = "Request failed.")
            } catch (_: Exception) {
                mutableState.value = mutableState.value.copy(busy = false, error = "Request failed.")
            }
        }
    }

    fun restore() {
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = mutableState.value.copy(route = AuthRoute.Restoring, busy = true, error = null)
            try {
                when (val result = session.restore()) {
                    AuthRestoreResult.SignedOut -> mutableState.value = mutableState.value.copy(route = AuthRoute.SignIn, busy = false)
                    is AuthRestoreResult.PendingEmailVerification -> mutableState.value = mutableState.value.copy(
                        route = AuthRoute.Next(AuthDestination.EMAIL_VERIFICATION, result.email), busy = false,
                    )
                    is AuthRestoreResult.SignedIn -> {
                        applyLanguageBestEffort(result.profile.language)
                        route(result.profile)
                    }
                    is AuthRestoreResult.Error -> mutableState.value = mutableState.value.copy(
                        route = AuthRoute.RestoreError(result.message), busy = false,
                    )
                }
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.value = mutableState.value.copy(route = AuthRoute.RestoreError(null), busy = false)
            }
        }
    }

    fun logout() {
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = mutableState.value.copy(busy = true)
            try {
                session.logout()
                mutableState.value = AuthUiState(route = AuthRoute.SignIn)
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.value = mutableState.value.copy(
                    route = AuthRoute.RestoreError("Request failed."), busy = false,
                )
            }
        }
    }

    fun onBackground() { backgroundAt = now() }
    fun onForeground() {
        val elapsed = backgroundAt?.let { now() - it } ?: return
        backgroundAt = null
        if (elapsed >= 15 * 60_000 && state.value.route is AuthRoute.Next) restore()
    }

    private fun route(profile: AuthProfile) {
        mutableState.value = mutableState.value.copy(
            route = AuthRoute.Next(profile.destination, profile.email), password = "", busy = false, error = null,
        )
    }

    private suspend fun applyLanguageBestEffort(prefix: String?) {
        try { localization.applyProfileLanguage(prefix) } catch (cancel: CancellationException) {
            throw cancel
        } catch (_: Exception) { /* A language refresh must not invalidate a valid login. */ }
    }

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val applicationContext = context.applicationContext
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            val http = AndroidHttpAdapter.live()
            return AuthViewModel(
                AuthSessionRepository.live(applicationContext, http),
                AndroidLocalizationState.live(applicationContext, http),
            ) as T
        }
    }
}
