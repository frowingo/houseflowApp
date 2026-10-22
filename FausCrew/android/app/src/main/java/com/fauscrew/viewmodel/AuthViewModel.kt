package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.AndroidLocalizationState
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.AuthDestination
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.AuthProfileException
import com.fauscrew.platform.AuthRequestException
import com.fauscrew.platform.AuthRestoreResult
import com.fauscrew.platform.AuthSessionRepository
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.PlatformLanguage
import com.fauscrew.platform.ProfileChange
import com.fauscrew.platform.ProfileImage
import com.fauscrew.platform.ProfileRepository
import com.fauscrew.platform.FacebookCredentialAdapter
import com.fauscrew.platform.GoogleCredentialAdapter
import com.fauscrew.platform.SnapchatCredentialAdapter
import com.fauscrew.platform.SocialActivityHolder
import com.fauscrew.platform.SocialAuthConfig
import com.fauscrew.platform.SocialAuthException
import com.fauscrew.platform.SocialCredential
import com.fauscrew.platform.SocialCredentialProvider
import com.fauscrew.platform.SocialCredentialRouter
import com.fauscrew.platform.SocialProvider
import com.fauscrew.platform.SocialSignInException
import com.fauscrew.platform.SocialSignInResult
import java.io.IOException
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal sealed interface AuthRoute {
    data object Restoring : AuthRoute
    data object Onboarding : AuthRoute
    data object SignIn : AuthRoute
    data object ForgotPassword : AuthRoute
    /** A provider gave no email; the account opens only after the user verifies one. */
    data object SocialEmail : AuthRoute
    data class Next(val destination: AuthDestination, val email: String) : AuthRoute
    data class RestoreError(val message: String?) : AuthRoute
}

internal enum class AuthMode { SIGN_IN, SIGN_UP }
internal enum class ForgotPhase { IDLE, CODE_ENTRY, FAILED, COMPLETE }
internal enum class SocialEmailStep { EMAIL, CODE }

/** `needsEmail` registration. Memory only: the pending token is valid for 10 minutes and never persisted. */
internal data class SocialPending(
    val provider: SocialProvider,
    val pendingToken: String,
    val step: SocialEmailStep = SocialEmailStep.EMAIL,
    val email: String = "",
    val code: String = "",
    val firstName: String = "",
    val lastName: String = "",
) {
    val canSubmit: Boolean get() = when (step) {
        SocialEmailStep.EMAIL -> email.trim().contains('@')
        SocialEmailStep.CODE -> code.length == 6
    }
    override fun toString() = "SocialPending(provider=$provider, step=$step)"
}

/** Settings → sign-in methods and account deletion. */
internal data class AccountUiState(
    val busyProvider: SocialProvider? = null,
    val message: String? = null,
    /** [message] explains (not configured) rather than reports a failure. */
    val messageIsInfo: Boolean = false,
    val passwordBusy: Boolean = false,
    val passwordCodeSent: Boolean = false,
    val passwordSaved: Boolean = false,
    val deleting: Boolean = false,
    val deleteError: String? = null,
)

internal data class AuthUiState(
    val route: AuthRoute = AuthRoute.Restoring,
    val profile: AuthProfile? = null,
    val email: String = "",
    val password: String = "",
    val firstName: String = "",
    val lastName: String = "",
    val mode: AuthMode = AuthMode.SIGN_IN,
    val code: String = "",
    val newPassword: String = "",
    val forgotEmail: String = "",
    val forgotPhase: ForgotPhase = ForgotPhase.IDLE,
    val verificationSent: Boolean = false,
    val resendDeadline: Long = 0,
    val signupSuccess: Boolean = false,
    val birthday: LocalDate = LocalDate.now().minusYears(25),
    val busy: Boolean = false,
    val error: String? = null,
    val notice: String? = null,
    /** Neutral explanation, e.g. a sign-in method that is not set up in this build. */
    val info: String? = null,
    val socialProviders: List<SocialProvider> = emptyList(),
    val socialPending: SocialPending? = null,
) {
    val canSubmit: Boolean get() = email.isNotEmpty() && password.isNotEmpty() &&
        (mode == AuthMode.SIGN_IN || (firstName.isNotEmpty() && lastName.isNotEmpty())) && !busy
}

internal data class ProfileUiState(
    val images: List<ProfileImage> = emptyList(),
    val languages: List<PlatformLanguage> = emptyList(),
    val loadingImages: Boolean = false,
    val loadingLanguages: Boolean = false,
    val busy: Boolean = false,
    val error: String? = null,
    val savedSerial: Long = 0,
)

internal class AuthViewModel(
    private val session: AuthSessionRepository,
    private val localization: AndroidLocalizationState,
    private val preferences: AndroidPreferencesStore,
    private val now: () -> Long = System::currentTimeMillis,
    private val profileRepository: ProfileRepository? = null,
    private val socialCredentials: SocialCredentialProvider = SocialCredentialRouter(emptyMap()),
    private val socialConfig: SocialAuthConfig = SocialAuthConfig(emptyList()),
) : ViewModel() {
    private val mutableState = MutableStateFlow(AuthUiState(socialProviders = socialConfig.shown))
    val state: StateFlow<AuthUiState> = mutableState.asStateFlow()
    val text: StateFlow<LocalizedText> = localization.text
    private val mutableProfileState = MutableStateFlow(ProfileUiState())
    val profileState: StateFlow<ProfileUiState> = mutableProfileState.asStateFlow()
    private val mutableAccountState = MutableStateFlow(AccountUiState())
    val accountState: StateFlow<AccountUiState> = mutableAccountState.asStateFlow()
    private var sessionJob: Job? = null
    private var accountJob: Job? = null
    private var profileJob: Job? = null
    private var imageJob: Job? = null
    private var languageJob: Job? = null
    private var backgroundAt: Long? = null

    init {
        viewModelScope.launch {
            try { localization.start() } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) { /* Key fallback remains available. */ }
        }
        restore()
    }

    fun setEmail(value: String) { mutableState.value = mutableState.value.copy(email = value, error = null, info = null) }
    fun setPassword(value: String) { mutableState.value = mutableState.value.copy(password = value, error = null, info = null) }
    fun setFirstName(value: String) { mutableState.value = mutableState.value.copy(firstName = value, error = null, info = null) }
    fun setLastName(value: String) { mutableState.value = mutableState.value.copy(lastName = value, error = null, info = null) }
    fun setCode(value: String) {
        mutableState.value = mutableState.value.copy(code = value.filter { it.isLetterOrDigit() }
            .take(6).uppercase(), error = null)
    }
    fun setNewPassword(value: String) { mutableState.value = mutableState.value.copy(newPassword = value, error = null) }
    fun setBirthday(value: LocalDate) { mutableState.value = mutableState.value.copy(birthday = value, error = null) }
    fun selectMode(mode: AuthMode) {
        if (state.value.mode == mode || state.value.busy) return
        mutableState.value = state.value.copy(mode = mode, email = "", password = "", firstName = "", lastName = "", error = null)
    }

    fun submitAuth() {
        if (state.value.mode == AuthMode.SIGN_UP) signup() else login()
    }

    private fun signup() {
        val current = state.value
        if (!current.canSubmit) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                session.signup(current.email, current.password, current.firstName, current.lastName)
                mutableState.value = mutableState.value.copy(
                    route = AuthRoute.Next(AuthDestination.EMAIL_VERIFICATION, current.email),
                    password = "", busy = false, signupSuccess = true,
                )
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { fail(error) }
        }
    }

    fun dismissSignupSuccess() { mutableState.value = state.value.copy(signupSuccess = false) }

    fun openForgotPassword() {
        if (state.value.busy) return
        mutableState.value = state.value.copy(route = AuthRoute.ForgotPassword, forgotEmail = "", code = "",
            newPassword = "", forgotPhase = ForgotPhase.IDLE, error = null)
    }
    fun setForgotEmail(value: String) { mutableState.value = state.value.copy(forgotEmail = value, error = null) }
    fun closeForgotPassword() {
        sessionJob?.cancel()
        mutableState.value = state.value.copy(route = AuthRoute.SignIn, busy = false, error = null)
    }
    fun requestPasswordReset() {
        val current = state.value
        if (current.busy || !EMAIL_PATTERN.matches(current.forgotEmail)) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                session.forgotPassword(current.forgotEmail)
                mutableState.value = mutableState.value.copy(busy = false, forgotPhase = ForgotPhase.CODE_ENTRY)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                fail(error)
                mutableState.value = mutableState.value.copy(forgotPhase = ForgotPhase.FAILED)
            }
        }
    }
    fun resetPassword() {
        val current = state.value
        if (current.busy || current.code.length != 6 || current.newPassword.isEmpty()) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                session.resetPassword(current.forgotEmail, current.code, current.newPassword)
                mutableState.value = mutableState.value.copy(busy = false, forgotPhase = ForgotPhase.COMPLETE)
                delay(1_800)
                if (state.value.route == AuthRoute.ForgotPassword) closeForgotPassword()
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { fail(error) }
        }
    }

    fun sendVerificationCode() {
        val current = state.value
        if (current.busy || now() < current.resendDeadline) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null, code = "", verificationSent = true,
                resendDeadline = now() + 180_000)
            try { session.sendVerificationCode(); mutableState.value = state.value.copy(busy = false) }
            catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                fail(error)
                mutableState.value = state.value.copy(verificationSent = current.verificationSent, resendDeadline = 0)
            }
        }
    }
    fun verifyEmail() {
        val current = state.value
        if (current.busy || current.code.length != 6) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                val profile = session.verifyEmail(current.code)
                applyLanguageBestEffort(profile.language)
                route(profile)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { fail(error) }
        }
    }
    fun saveBirthday() {
        val current = state.value
        if (current.busy) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                val instant = current.birthday.atStartOfDay(ZoneId.systemDefault()).toInstant()
                val date = API_DATE.format(instant)
                val profile = session.updateBirthday(date)
                applyLanguageBestEffort(profile.language)
                route(profile)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { fail(error) }
        }
    }
    private fun fail(error: Exception) {
        mutableState.value = state.value.copy(busy = false, error =
            (error as? AuthRequestException)?.serverMessage ?: (error as? AuthProfileException)?.serverMessage ?: "Request failed.")
    }

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

    fun completeOnboarding() {
        if (state.value.route != AuthRoute.Onboarding || state.value.busy) return
        sessionJob?.cancel()
        mutableState.value = mutableState.value.copy(busy = true)
        sessionJob = viewModelScope.launch {
            try {
                preferences.setHasSeenOnboarding(true)
                mutableState.value = mutableState.value.copy(route = AuthRoute.SignIn, busy = false, error = null)
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.value = mutableState.value.copy(route = AuthRoute.RestoreError(null), busy = false)
            }
        }
    }

    fun restore() {
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = mutableState.value.copy(route = AuthRoute.Restoring, busy = true, error = null)
            try {
                when (val result = session.restore()) {
                    AuthRestoreResult.SignedOut -> mutableState.value = mutableState.value.copy(
                        route = signedOutRoute(preferences.hasSeenOnboarding()), busy = false,
                    )
                    is AuthRestoreResult.PendingEmailVerification -> mutableState.value = mutableState.value.copy(
                        route = AuthRoute.Next(AuthDestination.EMAIL_VERIFICATION, result.email), busy = false,
                        verificationSent = false, code = "", signupSuccess = false,
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

    /**
     * Silent `auth/isAuth` refresh for the events channel: only the profile (and its
     * house list) changes; the current route stays. A lost session signs out.
     */
    fun refreshProfile() {
        val signedIn = mutableState.value.profile ?: return
        if (mutableState.value.route !is AuthRoute.Next) return
        viewModelScope.launch {
            val result = try { session.restore() } catch (cancel: CancellationException) { throw cancel }
                catch (_: Exception) { return@launch }
            val current = mutableState.value
            if (current.profile?.userId != signedIn.userId || current.route !is AuthRoute.Next) return@launch
            when (result) {
                is AuthRestoreResult.SignedIn ->
                    if (result.profile.userId == signedIn.userId) mutableState.value = current.copy(profile = result.profile)
                AuthRestoreResult.SignedOut -> logout()
                else -> Unit
            }
        }
    }

    fun logout() {
        sessionJob?.cancel()
        profileJob?.cancel()
        imageJob?.cancel()
        languageJob?.cancel()
        accountJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = mutableState.value.copy(busy = true)
            try {
                session.logout()
                socialCredentials.signOutAll()
                mutableProfileState.value = ProfileUiState()
                mutableAccountState.value = AccountUiState()
                mutableState.value = signedOutState()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                mutableState.value = mutableState.value.copy(
                    route = AuthRoute.RestoreError("Request failed."), busy = false,
                )
            }
        }
    }

    fun loadProfileImages(category: String) {
        val repository = profileRepository ?: return
        imageJob?.cancel()
        imageJob = viewModelScope.launch {
            mutableProfileState.value = profileState.value.copy(images = emptyList(), loadingImages = true, error = null)
            try {
                val images = repository.images(category)
                mutableProfileState.value = profileState.value.copy(images = images, loadingImages = false)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { profileFail(error, loadingImages = false) }
        }
    }

    fun loadLanguages() {
        languageJob?.cancel()
        languageJob = viewModelScope.launch {
            mutableProfileState.value = profileState.value.copy(loadingLanguages = true, error = null)
            try {
                val languages = localization.availableLanguages()
                mutableProfileState.value = profileState.value.copy(languages = languages, loadingLanguages = false)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { profileFail(error, loadingLanguages = false) }
        }
    }

    fun clearProfileError() { mutableProfileState.value = profileState.value.copy(error = null) }

    fun updateProfile(change: ProfileChange) {
        val current = state.value.profile ?: return
        val repository = profileRepository ?: return
        if (profileState.value.busy || current.userId.isBlank()) return
        profileJob?.cancel()
        profileJob = viewModelScope.launch {
            mutableProfileState.value = profileState.value.copy(busy = true, error = null)
            try {
                val saved = repository.update(current.userId, change)
                mutableState.value = state.value.copy(profile = current.copy(
                    firstName = saved.firstName ?: current.firstName,
                    lastName = saved.lastName ?: current.lastName,
                    imageUrl = saved.imageUrl ?: current.imageUrl,
                    birthDay = saved.birthDay ?: current.birthDay,
                    phoneNumber = saved.phoneNumber ?: current.phoneNumber,
                    language = saved.language ?: current.language,
                ))
                mutableProfileState.value = profileState.value.copy(busy = false,
                    savedSerial = profileState.value.savedSerial + 1)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { profileFail(error, busy = false) }
        }
    }

    fun saveLanguage(prefix: String) {
        val current = state.value.profile ?: return
        val repository = profileRepository ?: return
        if (profileState.value.busy || current.userId.isBlank() ||
            profileState.value.languages.none { it.isActive && it.prefix.equals(prefix, true) }) return
        profileJob?.cancel()
        profileJob = viewModelScope.launch {
            mutableProfileState.value = profileState.value.copy(busy = true, error = null)
            try {
                repository.update(current.userId, ProfileChange(language = prefix))
                localization.select(prefix, forceRefresh = true)
                session.logout()
                imageJob?.cancel()
                languageJob?.cancel()
                mutableProfileState.value = ProfileUiState()
                mutableState.value = signedOutState().copy(
                    notice = localization.text.value.get("language_settings_relogin_message"))
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { profileFail(error, busy = false) }
        }
    }

    private fun profileFail(error: Exception, busy: Boolean? = null,
        loadingImages: Boolean? = null, loadingLanguages: Boolean? = null) {
        mutableProfileState.value = profileState.value.copy(
            busy = busy ?: profileState.value.busy,
            loadingImages = loadingImages ?: profileState.value.loadingImages,
            loadingLanguages = loadingLanguages ?: profileState.value.loadingLanguages,
            error = (error as? AuthRequestException)?.serverMessage ?: "Request failed.",
        )
    }

    // MARK: - Social sign-in / sign-up

    /** Same request for sign-in and sign-up; the answer says whether the account is new. */
    fun signInWithSocial(provider: SocialProvider) {
        val current = state.value
        if (current.busy) return
        if (!socialConfig.isShown(provider)) {
            mutableState.value = current.copy(error = SocialMessages.unavailable(), info = null)
            return
        }
        if (!socialConfig.isConfigured(provider)) {
            mutableState.value = current.copy(error = null, info = SocialMessages.notConfigured(provider))
            return
        }
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null, notice = null, info = null)
            val credential = providerCredential(provider) { message ->
                mutableState.value = state.value.copy(busy = false, error = message)
            } ?: return@launch
            try {
                when (val result = session.socialSignIn(provider, credential)) {
                    is SocialSignInResult.SignedIn -> {
                        applyLanguageBestEffort(result.profile.language)
                        route(result.profile)
                    }
                    is SocialSignInResult.NeedsEmail -> mutableState.value = state.value.copy(
                        route = AuthRoute.SocialEmail, busy = false, error = null,
                        socialPending = SocialPending(provider, result.pendingToken,
                            firstName = credential.firstName.orEmpty(), lastName = credential.lastName.orEmpty()),
                    )
                }
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: AuthProfileException) {
                mutableState.value = state.value.copy(route = AuthRoute.RestoreError(error.serverMessage), busy = false)
            } catch (error: Exception) {
                // 401: the provider token was rejected; close the SDK session so a retry starts clean.
                if ((error as? SocialAuthException)?.status == 401) socialCredentials.signOutAll()
                mutableState.value = state.value.copy(busy = false, error = SocialMessages.of(error))
            }
        }
    }

    fun setSocialEmail(value: String) = updatePending { it.copy(email = value) }
    fun setSocialCode(value: String) = updatePending { it.copy(code = value.filter(Char::isLetterOrDigit).take(6).uppercase()) }
    fun setSocialFirstName(value: String) = updatePending { it.copy(firstName = value.take(50)) }
    fun setSocialLastName(value: String) = updatePending { it.copy(lastName = value.take(50)) }

    /** Step 1, and "resend" on step 2: `POST auth/social/complete/code`. */
    fun sendSocialCode() {
        val current = state.value
        val pending = current.socialPending ?: return
        if (current.busy || !pending.email.trim().contains('@')) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                session.requestSocialCode(pending.pendingToken, pending.email)
                updatePending(busy = false) { it.copy(step = SocialEmailStep.CODE, code = "") }
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { socialStepFailed(error) }
        }
    }

    /** Step 2: `POST auth/social/complete`; 201 opens the account with a verified email. */
    fun completeSocial() {
        val current = state.value
        val pending = current.socialPending ?: return
        if (current.busy || pending.code.length != 6) return
        sessionJob?.cancel()
        sessionJob = viewModelScope.launch {
            mutableState.value = current.copy(busy = true, error = null)
            try {
                val profile = session.completeSocial(pending.pendingToken, pending.email, pending.code,
                    pending.firstName, pending.lastName)
                applyLanguageBestEffort(profile.language)
                mutableState.value = state.value.copy(socialPending = null)
                route(profile)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: AuthProfileException) {
                mutableState.value = state.value.copy(route = AuthRoute.RestoreError(error.serverMessage),
                    busy = false, socialPending = null)
            } catch (error: Exception) { socialStepFailed(error) }
        }
    }

    fun cancelSocial() {
        sessionJob?.cancel()
        socialCredentials.signOutAll()
        mutableState.value = state.value.copy(route = AuthRoute.SignIn, socialPending = null, busy = false, error = null)
    }

    /** 401: the pending token expired, so start the provider again. 409: try another email. */
    private fun socialStepFailed(error: Exception) {
        val message = SocialMessages.of(error)
        when ((error as? SocialAuthException)?.status) {
            401 -> {
                socialCredentials.signOutAll()
                mutableState.value = state.value.copy(route = AuthRoute.SignIn, socialPending = null, busy = false, error = message)
            }
            409 -> updatePending(busy = false, error = message) { it.copy(step = SocialEmailStep.EMAIL, code = "") }
            else -> mutableState.value = state.value.copy(busy = false, error = message)
        }
    }

    private fun updatePending(busy: Boolean? = null, error: String? = null, change: (SocialPending) -> SocialPending) {
        val current = state.value
        val pending = current.socialPending ?: return
        mutableState.value = current.copy(socialPending = change(pending), busy = busy ?: current.busy, error = error)
    }

    // MARK: - Settings: sign-in methods

    fun clearAccountMessage() {
        mutableAccountState.value = accountState.value.copy(message = null, messageIsInfo = false, deleteError = null,
            passwordSaved = false)
    }

    fun linkProvider(provider: SocialProvider) {
        if (accountState.value.busyProvider != null || !socialConfig.isShown(provider)) return
        if (!socialConfig.isConfigured(provider)) {
            mutableAccountState.value = accountState.value.copy(message = SocialMessages.notConfigured(provider), messageIsInfo = true)
            return
        }
        accountJob?.cancel()
        accountJob = viewModelScope.launch {
            mutableAccountState.value = accountState.value.copy(busyProvider = provider, message = null, messageIsInfo = false)
            val credential = providerCredential(provider) { message ->
                mutableAccountState.value = accountState.value.copy(busyProvider = null, message = message)
            } ?: return@launch
            try {
                applyLinked(session.linkSocial(provider, credential))
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                // 401 means a bad session *or* a bad provider token: ask auth/isAuth before signing out.
                if ((error as? SocialAuthException)?.status == 401 && session.isSessionValid() == false) {
                    mutableAccountState.value = AccountUiState()
                    logout()
                    return@launch
                }
                mutableAccountState.value = accountState.value.copy(busyProvider = null, message = SocialMessages.of(error))
            }
        }
    }

    fun unlinkProvider(provider: SocialProvider) {
        if (accountState.value.busyProvider != null) return
        accountJob?.cancel()
        accountJob = viewModelScope.launch {
            mutableAccountState.value = accountState.value.copy(busyProvider = provider, message = null, messageIsInfo = false)
            try {
                applyLinked(session.unlinkSocial(provider))
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                val status = (error as? SocialAuthException)?.status
                if (status == 401) {
                    mutableAccountState.value = AccountUiState()
                    logout()
                    return@launch
                }
                if (status == 404) refreshProfile()
                val message = SocialMessages.of(error) + if (status == 409) " " + SocialMessages.onlyMethodHint() else ""
                mutableAccountState.value = accountState.value.copy(busyProvider = null, message = message)
            }
        }
    }

    /** Social accounts have no password; the forgot-password endpoints set one. */
    fun requestPasswordSetup() {
        val email = state.value.profile?.email ?: return
        if (accountState.value.passwordBusy) return
        accountJob?.cancel()
        accountJob = viewModelScope.launch {
            mutableAccountState.value = accountState.value.copy(passwordBusy = true, message = null)
            try {
                session.forgotPassword(email)
                mutableAccountState.value = accountState.value.copy(passwordBusy = false, passwordCodeSent = true)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                mutableAccountState.value = accountState.value.copy(passwordBusy = false,
                    message = (error as? AuthRequestException)?.serverMessage ?: SocialMessages.of(error))
            }
        }
    }

    fun setPassword(code: String, newPassword: String) {
        val email = state.value.profile?.email ?: return
        if (accountState.value.passwordBusy || code.length != 6 || newPassword.isEmpty()) return
        accountJob?.cancel()
        accountJob = viewModelScope.launch {
            mutableAccountState.value = accountState.value.copy(passwordBusy = true, message = null)
            try {
                session.resetPassword(email, code, newPassword)
                state.value.profile?.let { mutableState.value = state.value.copy(profile = it.copy(hasPassword = true)) }
                mutableAccountState.value = accountState.value.copy(passwordBusy = false, passwordCodeSent = false, passwordSaved = true)
                refreshProfile()
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                mutableAccountState.value = accountState.value.copy(passwordBusy = false,
                    message = (error as? AuthRequestException)?.serverMessage ?: SocialMessages.of(error))
            }
        }
    }

    private fun applyLinked(providers: List<Int>) {
        state.value.profile?.let { mutableState.value = state.value.copy(profile = it.copy(linkedProviders = providers)) }
        mutableAccountState.value = accountState.value.copy(busyProvider = null, message = null)
    }

    // MARK: - Account deletion (App Store 5.1.1(v); same flow on Android)

    fun deleteAccount() {
        if (accountState.value.deleting) return
        accountJob?.cancel()
        accountJob = viewModelScope.launch {
            mutableAccountState.value = accountState.value.copy(deleting = true, deleteError = null)
            try {
                session.deleteAccount()
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                mutableAccountState.value = accountState.value.copy(deleting = false, deleteError = SocialMessages.of(error))
                return@launch
            }
            sessionJob?.cancel(); profileJob?.cancel(); imageJob?.cancel(); languageJob?.cancel()
            socialCredentials.signOutAll()
            mutableProfileState.value = ProfileUiState()
            mutableAccountState.value = AccountUiState()
            mutableState.value = signedOutState()
        }
    }

    /** Returns null after reporting the failure; a closed provider sheet reports nothing. */
    private suspend fun providerCredential(provider: SocialProvider, onFailure: (String?) -> Unit): SocialCredential? =
        try {
            socialCredentials.credential(provider)
        } catch (cancel: CancellationException) { throw cancel }
        catch (_: SocialSignInException.Cancelled) { onFailure(null); null }
        catch (error: Exception) { onFailure(SocialMessages.of(error)); null }

    private suspend fun signedOutState() =
        AuthUiState(route = signedOutRoute(preferences.hasSeenOnboarding()), socialProviders = socialConfig.shown)

    fun onBackground() { backgroundAt = now() }
    fun onForeground() {
        val elapsed = backgroundAt?.let { now() - it } ?: return
        backgroundAt = null
        if (elapsed >= 15 * 60_000 && state.value.route is AuthRoute.Next) restore()
    }

    private fun route(profile: AuthProfile) {
        mutableState.value = mutableState.value.copy(
            route = AuthRoute.Next(profile.destination, profile.email), password = "", busy = false, error = null,
            code = "", verificationSent = false, signupSuccess = false, profile = profile,
            notice = null,
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
                AndroidPreferencesStore(applicationContext),
                profileRepository = ProfileRepository.live(applicationContext, http),
                socialCredentials = SocialCredentialRouter(mapOf(
                    SocialProvider.GOOGLE to GoogleCredentialAdapter(applicationContext, SocialActivityHolder::current),
                    SocialProvider.FACEBOOK to FacebookCredentialAdapter(applicationContext, SocialActivityHolder::current),
                    SocialProvider.SNAPCHAT to SnapchatCredentialAdapter(applicationContext, SocialActivityHolder::current),
                )),
                socialConfig = SocialAuthConfig.load(applicationContext),
            ) as T
        }
    }

    companion object {
        private val EMAIL_PATTERN = Regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
        private val API_DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss'Z'").withZone(ZoneOffset.UTC)
    }
}

internal fun signedOutRoute(hasSeenOnboarding: Boolean): AuthRoute =
    if (hasSeenOnboarding) AuthRoute.SignIn else AuthRoute.Onboarding
