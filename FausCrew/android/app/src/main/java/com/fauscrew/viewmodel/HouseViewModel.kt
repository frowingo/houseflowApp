package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.AuthProfile
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.DashboardRepository
import com.fauscrew.platform.HouseAnnouncement
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.HouseCreationRules
import com.fauscrew.platform.HouseDetails
import com.fauscrew.platform.HouseInfo
import com.fauscrew.platform.HouseInvite
import com.fauscrew.platform.HouseRequestException
import com.fauscrew.platform.HouseSessionRepository
import com.fauscrew.platform.HouseSummary
import com.fauscrew.platform.ReviewPhoto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal enum class HouseRoute { LOADING, SELECTION, CREATE, JOIN, DASHBOARD, ERROR }
/** iOS `HouseLoadingPhase`; CHECKING_AUTH covers the session restore before a house is known. */
internal enum class HouseLoadingPhase { CHECKING_AUTH, LOADING_HOUSE, CREATING, JOINING, LOADING_DETAILS }

internal data class HouseUiState(
    val route: HouseRoute = HouseRoute.LOADING,
    val phase: HouseLoadingPhase = HouseLoadingPhase.LOADING_HOUSE,
    val houses: List<HouseSummary> = emptyList(),
    val details: HouseDetails? = null,
    val info: HouseInfo? = null,
    val invite: HouseInvite? = null,
    val inviteBusy: Boolean = false,
    val userId: String = "",
    val firstName: String = "",
    val busy: Boolean = false,
    val error: String? = null,
    val mutationBusy: Boolean = false,
    val mutationError: String? = null,
    val mutationSerial: Long = 0,
    val mutationMessageKey: String? = null,
    val infoHouseId: String? = null,
    val infoBusy: Boolean = false,
    val profileActionBusy: Boolean = false,
    val profileError: String? = null,
    val profileActionSerial: Long = 0,
    val profileActionKind: String? = null,
)

/** One owner for the active house. A generation gates every async completion. */
internal class HouseViewModel(
    private val repository: HouseSessionRepository,
    private val preferences: AndroidPreferencesStore,
    private val dashboard: DashboardRepository? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(HouseUiState())
    val state: StateFlow<HouseUiState> = mutableState.asStateFlow()
    private var generation = 0L
    private var work: Job? = null
    private var mutationWork: Job? = null
    private var profileKey: String? = null
    private var pendingHouse: HouseSummary? = null
    private var pendingRequestKey: String? = null
    private var infoRequestSerial = 0L

    fun acceptProfile(profile: AuthProfile) {
        val key = profile.userId + ":" + profile.firstName + ":" + profile.houses.joinToString { it.id + "/" + it.name }
        if (profileKey == key) return
        val current = state.value
        // A refreshed profile that still contains the open house only updates the list.
        if (profileKey != null && current.userId == profile.userId && current.route == HouseRoute.DASHBOARD &&
            profile.houses.any { it.id == current.details?.id }) {
            profileKey = key
            mutableState.value = current.copy(houses = profile.houses, firstName = profile.firstName)
            return
        }
        invalidate()
        profileKey = key
        val houses = profile.houses
        mutableState.value = HouseUiState(houses = houses, userId = profile.userId, firstName = profile.firstName)
        if (houses.isEmpty()) {
            mutableState.value = state.value.copy(route = HouseRoute.SELECTION)
            return
        }
        val ticket = generation
        work = viewModelScope.launch {
            try {
                val chosen = preferences.chosenHouse()
                val selected = houses.firstOrNull { it.id == chosen } ?: houses.first()
                loadSelected(selected, ticket, HouseRoute.ERROR)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) fail(HouseRoute.ERROR, error) }
        }
    }

    /**
     * Forced `house/details` refresh for the events channel. Dropped when another house
     * was selected meanwhile, so a late response never overwrites the new selection.
     */
    fun refreshDetails(houseId: String) {
        val current = state.value
        if (current.route != HouseRoute.DASHBOARD || current.details?.id != houseId || current.busy) return
        val ticket = generation
        viewModelScope.launch {
            val details = try { repository.details(houseId) } catch (cancel: CancellationException) { throw cancel }
                catch (_: Exception) { return@launch }
            if (ticket != generation || state.value.details?.id != houseId) return@launch
            mutableState.value = state.value.copy(details = details)
        }
    }

    fun resetSession() {
        invalidate()
        profileKey = null
        pendingHouse = null
        pendingRequestKey = null
        mutableState.value = HouseUiState()
    }

    fun showCreate() { if (!state.value.busy) mutableState.value = state.value.copy(route = HouseRoute.CREATE, error = null) }
    fun showJoin() { if (!state.value.busy) mutableState.value = state.value.copy(route = HouseRoute.JOIN, error = null) }
    fun backToSelection() {
        if (!state.value.busy) {
            pendingHouse = null
            pendingRequestKey = null
            mutableState.value = state.value.copy(route = HouseRoute.SELECTION, error = null)
        }
    }

    fun create(name: String, type: Int, maxMemberCount: Int) {
        if (state.value.busy || name.isBlank() || state.value.route != HouseRoute.CREATE) return
        val ticket = begin(HouseLoadingPhase.CREATING)
        work = viewModelScope.launch {
            try {
                val requestKey = "create:${name.trim()}:$type:$maxMemberCount"
                val created = pendingHouse?.takeIf { pendingRequestKey == requestKey }
                    ?: repository.create(name.trim(), type, maxMemberCount)
                if (ticket != generation) return@launch
                pendingHouse = created
                pendingRequestKey = requestKey
                mutableState.value = state.value.copy(phase = HouseLoadingPhase.LOADING_DETAILS)
                loadSelected(created, ticket, HouseRoute.CREATE)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) fail(HouseRoute.CREATE, error) }
        }
    }

    fun join(code: String) {
        if (state.value.busy || state.value.route != HouseRoute.JOIN || code.length != 8) return
        val ticket = begin(HouseLoadingPhase.JOINING)
        work = viewModelScope.launch {
            try {
                val requestKey = "join:$code"
                val joined = pendingHouse?.takeIf { pendingRequestKey == requestKey } ?: repository.join(code)
                if (ticket != generation) return@launch
                pendingHouse = joined
                pendingRequestKey = requestKey
                mutableState.value = state.value.copy(phase = HouseLoadingPhase.LOADING_DETAILS)
                loadSelected(joined, ticket, HouseRoute.JOIN)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) fail(HouseRoute.JOIN, error) }
        }
    }

    fun retry() {
        val pending = pendingHouse
        if (pending != null) {
            val ticket = begin(HouseLoadingPhase.LOADING_DETAILS)
            work = viewModelScope.launch {
                try { loadSelected(pending, ticket, HouseRoute.ERROR) }
                catch (cancel: CancellationException) { throw cancel }
                catch (error: Exception) { if (ticket == generation) fail(HouseRoute.ERROR, error) }
            }
        } else {
            val selected = state.value.houses.firstOrNull() ?: run {
                mutableState.value = state.value.copy(route = HouseRoute.SELECTION, busy = false)
                return
            }
            val ticket = begin(HouseLoadingPhase.LOADING_HOUSE)
            work = viewModelScope.launch {
                try {
                    val chosen = preferences.chosenHouse()
                    loadSelected(state.value.houses.firstOrNull { it.id == chosen } ?: selected, ticket, HouseRoute.ERROR)
                } catch (cancel: CancellationException) { throw cancel }
                catch (error: Exception) { if (ticket == generation) fail(HouseRoute.ERROR, error) }
            }
        }
    }

    fun switchHouse(houseId: String) {
        val selected = state.value.houses.firstOrNull { it.id == houseId } ?: return
        if (state.value.route != HouseRoute.DASHBOARD || state.value.details?.id == houseId) return
        val previous = state.value.details
        val ticket = begin(HouseLoadingPhase.LOADING_HOUSE)
        work = viewModelScope.launch {
            try { loadSelected(selected, ticket, HouseRoute.DASHBOARD) }
            catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (ticket == generation) {
                    mutableState.value = state.value.copy(details = previous)
                    fail(HouseRoute.DASHBOARD, error)
                }
            }
        }
    }

    fun leaveHouse(houseId: String) {
        val current = state.value
        if (current.busy || current.houses.none { it.id == houseId } || current.userId.isBlank()) return
        val ticket = begin(HouseLoadingPhase.LOADING_HOUSE)
        work = viewModelScope.launch {
            try {
                repository.exit(houseId, current.userId)
                if (ticket != generation) return@launch
                val remaining = current.houses.filterNot { it.id == houseId }
                mutableState.value = state.value.copy(houses = remaining, info = null, invite = null)
                if (current.details?.id != houseId) {
                    mutableState.value = state.value.copy(route = HouseRoute.DASHBOARD, busy = false)
                    return@launch
                }
                mutableState.value = state.value.copy(details = null)
                try { preferences.setChosenHouse(null) } catch (cancel: CancellationException) { throw cancel }
                catch (_: Exception) { /* Removed house is absent from profile; restore falls back safely. */ }
                if (remaining.isEmpty()) {
                    mutableState.value = state.value.copy(route = HouseRoute.SELECTION, busy = false)
                } else {
                    loadSelected(remaining.first(), ticket, HouseRoute.ERROR)
                }
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) fail(HouseRoute.ERROR, error) }
        }
    }

    fun joinFromProfile(code: String) {
        if (state.value.profileActionBusy || state.value.busy || state.value.route != HouseRoute.DASHBOARD ||
            !code.matches(Regex("[A-Za-z0-9]{8}"))) return
        val ticket = generation
        mutableState.value = state.value.copy(profileActionBusy = true, profileError = null)
        viewModelScope.launch {
            try {
                val joined = repository.join(code.uppercase())
                if (ticket != generation) return@launch
                mutableState.value = state.value.copy(
                    houses = state.value.houses.filterNot { it.id == joined.id } + joined,
                    profileActionBusy = false, profileActionSerial = state.value.profileActionSerial + 1,
                    profileActionKind = "join",
                )
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) profileFail(error) }
        }
    }

    fun createFromProfile(name: String, type: Int, maxMemberCount: Int) {
        if (state.value.profileActionBusy || state.value.busy || state.value.route != HouseRoute.DASHBOARD ||
            !HouseCreationRules.isValid(name, type, maxMemberCount)) return
        val ticket = generation
        mutableState.value = state.value.copy(profileActionBusy = true, profileError = null)
        viewModelScope.launch {
            try {
                val created = repository.create(name.trim(), type, maxMemberCount)
                if (ticket != generation) return@launch
                mutableState.value = state.value.copy(
                    houses = state.value.houses.filterNot { it.id == created.id } + created,
                    profileActionBusy = false, profileActionSerial = state.value.profileActionSerial + 1,
                    profileActionKind = "create",
                )
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) profileFail(error) }
        }
    }

    fun loadInfo(houseId: String) {
        if (state.value.houses.none { it.id == houseId }) return
        val ticket = generation
        val request = ++infoRequestSerial
        mutableState.value = state.value.copy(infoHouseId = houseId, info = null, invite = null,
            infoBusy = true, inviteBusy = false, profileError = null)
        viewModelScope.launch {
            try {
                val info = repository.info(houseId)
                if (ticket == generation && request == infoRequestSerial && state.value.infoHouseId == houseId)
                    mutableState.value = state.value.copy(info = info, infoBusy = false)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation && request == infoRequestSerial) profileFail(error, infoBusy = false) }
        }
    }

    fun clearInfo() {
        infoRequestSerial++
        mutableState.value = state.value.copy(info = null, infoHouseId = null, invite = null,
            infoBusy = false, inviteBusy = false, profileError = null)
    }

    fun clearProfileError() { mutableState.value = state.value.copy(profileError = null) }

    fun createInvite(houseId: String) {
        if (state.value.houses.none { it.id == houseId } || state.value.infoHouseId != houseId ||
            state.value.inviteBusy) return
        val ticket = generation
        mutableState.value = state.value.copy(inviteBusy = true, profileError = null)
        viewModelScope.launch {
            try {
                val invite = repository.invite(houseId)
                if (ticket == generation && state.value.infoHouseId == houseId)
                    mutableState.value = state.value.copy(invite = invite, inviteBusy = false)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation && state.value.infoHouseId == houseId) {
                mutableState.value = state.value.copy(inviteBusy = false)
                profileFail(error)
            } }
        }
    }

    fun updateHouseProfile(
        houseId: String, name: String, maxMemberCount: Int, imageUrl: String, isChoreReviewPhotoRequired: Boolean,
    ) {
        val old = state.value.info ?: return
        if (state.value.infoHouseId != houseId || old.ownerId != state.value.userId ||
            state.value.profileActionBusy || name.isBlank() || maxMemberCount < maxOf(2, old.houseMemberCount)) return
        val ticket = generation
        mutableState.value = state.value.copy(profileActionBusy = true, profileError = null)
        viewModelScope.launch {
            try {
                val updated = repository.updateProfile(houseId, name.trim(), old.houseType, maxMemberCount, imageUrl,
                    isChoreReviewPhotoRequired)
                if (ticket != generation || state.value.infoHouseId != houseId) return@launch
                // The server response is the source of truth, including the review-photo flag.
                mutableState.value = state.value.copy(info = updated,
                    houses = state.value.houses.map { if (it.id == houseId) it.copy(name = updated.houseName,
                        profileImage = updated.houseProfileImage) else it },
                    details = state.value.details?.let {
                        if (it.id == houseId) it.copy(name = updated.houseName,
                            isChoreReviewPhotoRequired = updated.isChoreReviewPhotoRequired) else it
                    }, profileActionBusy = false,
                    profileActionSerial = state.value.profileActionSerial + 1, profileActionKind = "update")
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) profileFail(error) }
        }
    }

    fun removeMember(houseId: String, userId: String) {
        val info = state.value.info ?: return
        if (state.value.infoHouseId != houseId || info.ownerId != state.value.userId ||
            userId == state.value.userId || info.members.none { it.userId == userId } ||
            state.value.profileActionBusy) return
        val ticket = generation
        mutableState.value = state.value.copy(profileActionBusy = true, profileError = null)
        viewModelScope.launch {
            try {
                repository.exit(houseId, userId)
                if (ticket != generation || state.value.infoHouseId != houseId) return@launch
                val refreshed = try { repository.info(houseId) } catch (cancel: CancellationException) {
                    throw cancel
                } catch (_: Exception) {
                    info.copy(members = info.members.filterNot { it.userId == userId },
                        houseMemberCount = info.houseMemberCount - 1)
                }
                if (ticket != generation || state.value.infoHouseId != houseId) return@launch
                mutableState.value = state.value.copy(info = refreshed,
                    details = state.value.details?.let { details ->
                        if (details.id == houseId) details.copy(members = details.members.filterNot { it.id == userId }) else details
                    }, profileActionBusy = false, profileActionSerial = state.value.profileActionSerial + 1,
                    profileActionKind = "remove")
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) { if (ticket == generation) profileFail(error) }
        }
    }

    private fun profileFail(error: Exception, infoBusy: Boolean = state.value.infoBusy) {
        mutableState.value = state.value.copy(infoBusy = infoBusy, profileActionBusy = false,
            profileError = (error as? HouseRequestException)?.serverMessage ?: "Request failed.")
    }

    fun clearMutationMessage() {
        mutableState.value = state.value.copy(mutationError = null, mutationMessageKey = null)
    }

    fun createAnnouncement(title: String, message: String) {
        val current = activeDetails() ?: return
        if (title.isBlank() || message.isBlank()) return
        mutate(current.id, "announcement_created_toast") {
            val result = requireNotNull(dashboard).announce(current.id, title.trim(), message.trim())
            require(result.houseId == null || result.houseId == current.id)
            current.copy(announcements = current.announcements.filterNot { it.id == result.id } + result)
        }
    }

    fun createChore(input: ChoreInput) {
        val current = activeDetails() ?: return
        if (input.houseId != current.id || input.title.isBlank() || current.members.none { it.id == input.assignedTo }) return
        mutate(current.id, "chore_created_toast") {
            current.merge(requireNotNull(dashboard).createChore(input))
        }
    }

    fun updateChore(choreId: String, input: ChoreInput) {
        val current = activeDetails() ?: return
        if (input.houseId != current.id || current.chores.none { it.id == choreId }) return
        mutate(current.id, "chore_status_updated_toast") {
            current.merge(requireNotNull(dashboard).updateChore(choreId, input))
        }
    }

    /** Progress → InTest goes multipart only while the house requires a review photo. */
    fun updateChoreStatus(choreId: String, status: Int, photo: ReviewPhoto? = null) {
        val current = activeDetails() ?: return
        val chore = current.chores.firstOrNull { it.id == choreId } ?: return
        if (chore.assignedTo != state.value.userId || status != chore.status + 1 || status !in 1..2) return
        val requiresPhoto = current.isChoreReviewPhotoRequired && status == 2
        // The backend rejects a JSON InTest with 400 while a photo is required.
        if (requiresPhoto && photo == null) return
        mutate(current.id, "chore_status_updated_toast") {
            val repository = requireNotNull(dashboard)
            val updated = if (requiresPhoto) repository.updateStatusWithReviewPhoto(current.id, choreId, requireNotNull(photo))
                else repository.updateStatus(current.id, choreId, status)
            require(updated.any { it.id == choreId })
            updated.fold(current) { details, item -> details.merge(item) }
        }
    }

    /**
     * Lazily loads one round's photo bytes; failures surface through the existing
     * mutation error toast. The signed URL never reaches the UI state.
     */
    suspend fun reviewPhoto(choreId: String, round: Int): ByteArray? {
        val houseId = state.value.details?.id ?: return null
        val repository = dashboard ?: return null
        val ticket = generation
        return try {
            repository.loadReviewPhoto(choreId, round)
        } catch (cancel: CancellationException) { throw cancel }
        catch (error: Exception) {
            if (ticket == generation && state.value.details?.id == houseId) {
                mutableState.value = state.value.copy(
                    mutationError = (error as? HouseRequestException)?.serverMessage ?: "Request failed.")
            }
            null
        }
    }

    fun reviewChore(choreId: String, approved: Boolean) {
        val current = activeDetails() ?: return
        val chore = current.chores.firstOrNull { it.id == choreId } ?: return
        val userId = state.value.userId
        if (userId.isBlank() || chore.status != 2 || chore.assignedTo == userId ||
            chore.reviewVotes.any { it.reviewRound == chore.reviewRound && it.reviewerId == userId }) return
        mutate(current.id, if (approved) "chore_approved_toast" else "chore_sent_back_toast") {
            current.merge(requireNotNull(dashboard).review(choreId, approved))
        }
    }

    private fun activeDetails(): HouseDetails? = state.value.takeIf {
        it.route == HouseRoute.DASHBOARD && !it.busy && !it.mutationBusy
    }?.details

    private fun mutate(houseId: String, messageKey: String, operation: suspend () -> HouseDetails) {
        if (dashboard == null) return
        val ticket = generation
        mutableState.value = state.value.copy(mutationBusy = true, mutationError = null, mutationMessageKey = null)
        mutationWork = viewModelScope.launch {
            try {
                val updated = operation()
                if (ticket == generation && state.value.details?.id == houseId) {
                    mutableState.value = state.value.copy(details = updated, mutationBusy = false,
                        mutationSerial = state.value.mutationSerial + 1, mutationMessageKey = messageKey)
                }
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (ticket == generation && state.value.details?.id == houseId) {
                    mutableState.value = state.value.copy(mutationBusy = false,
                        mutationError = (error as? HouseRequestException)?.serverMessage ?: "Request failed.")
                }
            }
        }
    }

    private fun HouseDetails.merge(chore: HouseChore): HouseDetails {
        require(chore.houseId == id)
        return copy(chores = if (chores.any { it.id == chore.id })
            chores.map { if (it.id == chore.id) chore else it } else chores + chore)
    }

    private suspend fun loadSelected(selected: HouseSummary, ticket: Long, failureRoute: HouseRoute) {
        try {
            val details = repository.details(selected.id)
            if (ticket != generation) return
            preferences.setChosenHouse(details.id)
            if (ticket != generation) return
            pendingHouse = null
            pendingRequestKey = null
            mutableState.value = state.value.copy(
                route = HouseRoute.DASHBOARD, busy = false, details = details, info = null, invite = null,
                houses = (state.value.houses.filterNot { it.id == selected.id } + selected).let { list ->
                    if (state.value.houses.any { it.id == selected.id }) state.value.houses else list
                }, error = null,
            )
        } catch (cancel: CancellationException) { throw cancel }
        catch (error: Exception) { if (ticket == generation) fail(failureRoute, error) }
    }

    private fun begin(phase: HouseLoadingPhase): Long {
        invalidate()
        mutableState.value = state.value.copy(route = HouseRoute.LOADING, phase = phase, busy = true,
            error = null, mutationBusy = false, mutationError = null, mutationMessageKey = null)
        return generation
    }

    private fun invalidate() {
        generation++
        infoRequestSerial++
        work?.cancel(); work = null
        mutationWork?.cancel(); mutationWork = null
    }
    private fun fail(route: HouseRoute, error: Exception) {
        mutableState.value = state.value.copy(route = route, busy = false,
            error = (error as? HouseRequestException)?.serverMessage ?: "Request failed.")
    }

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val applicationContext = context.applicationContext
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            val http = AndroidHttpAdapter.live()
            return HouseViewModel(HouseSessionRepository.live(applicationContext, http),
                AndroidPreferencesStore(applicationContext), DashboardRepository.live(applicationContext, http)) as T
        }
    }
}
