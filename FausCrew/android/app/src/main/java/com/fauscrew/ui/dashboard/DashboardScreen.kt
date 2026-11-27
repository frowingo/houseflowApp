package com.fauscrew.ui.dashboard

import androidx.compose.runtime.getValue
import com.fauscrew.viewmodel.ChoreCatalogViewModel
import androidx.compose.runtime.setValue
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.ChoreReminder
import com.fauscrew.ui.dashboard.notifications.NotificationActions
import com.fauscrew.ui.dashboard.notifications.NotificationBellButton
import com.fauscrew.ui.dashboard.notifications.NotificationsPopup
import com.fauscrew.ui.dashboard.archive.ChoreArchiveActions
import com.fauscrew.ui.dashboard.archive.ChoreArchivePopup
import com.fauscrew.viewmodel.ChoreArchiveUiState
import com.fauscrew.viewmodel.NotificationUiState
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.ReviewPhoto
import com.fauscrew.ui.components.BrandHeroCard
import com.fauscrew.ui.components.FausCrewToast
import com.fauscrew.ui.components.FausHouseIcon
import com.fauscrew.ui.components.RemoteImage
import com.fauscrew.ui.components.mainScreenBackground
import com.fauscrew.ui.dashboard.catalog.ChoreCatalogEntry
import com.fauscrew.ui.dashboard.catalog.ChoreCatalogPopup
import com.fauscrew.ui.main.TabBarClearance
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.Sizes
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.entrance
import com.fauscrew.ui.theme.rememberEntrance
import com.fauscrew.ui.theme.softShadow
import com.fauscrew.viewmodel.HouseUiState

/**
 * `HouseDashboardView`: hero greeting, announcements, today's chores (with the chore catalog
 * entry) and members, and the dashboard popups. `house/details` is the only data source.
 */
@Composable
internal fun DashboardScreen(
    state: HouseUiState,
    strings: LocalizedText,
    onAnnouncement: (String, String) -> Unit,
    onCreateChore: (ChoreInput) -> Unit,
    onStatus: (String, Int, ReviewPhoto?) -> Unit,
    onReview: (String, Boolean) -> Unit,
    onClearMessage: () -> Unit,
    onOverlayChange: (Boolean) -> Unit = {},
    onLoadReviewPhoto: suspend (String, Int) -> ByteArray? = { _, _ -> null },
    /** `chore/catalog`; without one (UI tests) the catalog shows its error state. */
    catalog: ChoreCatalogViewModel = remember { ChoreCatalogViewModel(null) },
    notifications: NotificationUiState = NotificationUiState(),
    notificationActions: NotificationActions = NotificationActions(),
    archive: ChoreArchiveUiState = ChoreArchiveUiState(),
    archiveActions: ChoreArchiveActions = ChoreArchiveActions(),
    /** A push asked for this chore's detail; [onOpenChoreHandled] acknowledges it. */
    openChoreRequest: String? = null,
    onOpenChoreHandled: () -> Unit = {},
    /** Bumped by the push router to close every popup before it shows the dashboard. */
    closePopupsSignal: Int = 0,
) {
    val details = state.details ?: return
    var popup by remember { mutableStateOf<DashboardPopup?>(null) }
    var reviewing by remember { mutableStateOf(false) }

    LaunchedEffect(details.id) { popup = null }
    LaunchedEffect(closePopupsSignal) {
        if (closePopupsSignal > 0) {
            popup = null
            notificationActions.close()
        }
    }
    LaunchedEffect(openChoreRequest) {
        val id = openChoreRequest ?: return@LaunchedEffect
        notificationActions.close()
        popup = DashboardPopup.Chore(id)
        onOpenChoreHandled()
    }
    LaunchedEffect(state.mutationSerial) {
        // The catalog stays open after a create so several chores can be added in a row.
        if (state.mutationSerial > 0 && popup !is DashboardPopup.Catalog &&
            state.mutationMessageKey !in listOf("chore_approved_toast", "chore_sent_back_toast"))
            popup = null
    }
    val overlayCallback by rememberUpdatedState(onOverlayChange)
    val panel = notifications.panel
    LaunchedEffect(popup != null || panel != null) { overlayCallback(popup != null || panel != null) }
    DisposableEffect(Unit) { onDispose { overlayCallback(false) } }

    val header = rememberEntrance(50)
    val progress = rememberEntrance(140)
    val chores = rememberEntrance(220)
    val members = rememberEntrance(320)

    Box(Modifier.fillMaxSize().mainScreenBackground()) {
        LazyColumn(
            Modifier.fillMaxSize(), contentPadding = WindowInsets.statusBars.asPaddingValues(),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            item(key = "header") {
                DashboardHeader(state, details.name, strings, notifications.badge, Modifier.entrance(header, 12.dp),
                    onNotifications = notificationActions.open) {
                    popup = DashboardPopup.Announcement
                }
            }
            item(key = "progress") {
                ChoreProgressCard(details.chores, strings,
                    Modifier.padding(horizontal = Spacing.xxl).entrance(progress, 22.dp))
            }
            item(key = "chores") {
                TodaysChoresCard(details.chores, details.members, strings, { popup = DashboardPopup.Chore(it.id) },
                    Modifier.padding(horizontal = Spacing.xxl).entrance(chores, 26.dp),
                    onAddChore = { popup = DashboardPopup.Catalog(ChoreCatalogEntry.Drafts) },
                    onOpenArchive = { archiveActions.open(); popup = DashboardPopup.Archive })
            }
            item(key = "members") {
                HouseMembersCard(details.members, strings,
                    Modifier.padding(horizontal = Spacing.xxl).entrance(members, 26.dp))
            }
            item(key = "bottom-clearance") {
                Spacer(Modifier.navigationBarsPadding().height(TabBarClearance))
            }
        }
        FausCrewToast(
            message = state.mutationError ?: state.mutationMessageKey?.let(strings::get),
            isError = state.mutationError != null,
            onDismiss = onClearMessage,
            modifier = Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 60.dp),
        )
    }

    if (panel != null) {
        NotificationsPopup(panel, details.name, details.members, strings, notificationActions) { item ->
            // A reminder opens its chore when it is in the loaded house; everything else just closes.
            notificationActions.close()
            if (item.isChoreReminder && details.chores.any { it.id == item.choreId }) popup = DashboardPopup.Chore(item.choreId!!)
        }
    }

    when (val shown = popup) {
        DashboardPopup.Announcement -> NewAnnouncementPopup(strings, state.mutationBusy, state.mutationError,
            { popup = null }, onAnnouncement)
        is DashboardPopup.Catalog -> ChoreCatalogPopup(
            entry = shown.entry, catalog = catalog, details = details, userId = state.userId, strings = strings,
            busy = state.mutationBusy, error = state.mutationError,
            mutationSerial = state.mutationSerial, mutationMessageKey = state.mutationMessageKey,
            onCreate = onCreateChore, onDismiss = { popup = null },
        )
        is DashboardPopup.Chore -> details.chores.firstOrNull { it.id == shown.id }?.let { chore ->
            // Decided once when the popup is shown (and when the chore changes); no timer.
            val canRemind = remember(chore.id, chore.assignedTo, chore.status, chore.dueDate, state.userId) {
                ChoreReminder.canRemind(chore, state.userId)
            }
            ChoreDetailPopup(
                chore = chore, members = details.members, userId = state.userId, strings = strings,
                busy = state.mutationBusy, reviewing = reviewing, error = state.mutationError,
                isReviewPhotoRequired = details.isChoreReviewPhotoRequired,
                onDismiss = { notificationActions.clearToast(); popup = null },
                onStatus = { id, status, photo -> reviewing = false; onStatus(id, status, photo) },
                onReview = { id, approved -> reviewing = true; onReview(id, approved) },
                onLoadReviewPhoto = onLoadReviewPhoto,
                reminder = ChoreReminderUi(
                    canRemind = canRemind, reminded = chore.id in notifications.remindedChoreIds,
                    sending = notifications.sendingChoreId == chore.id, result = notifications.toast,
                    onRemind = { notificationActions.remind(chore.id) }, onClearResult = notificationActions.clearToast,
                ),
            )
        }
        DashboardPopup.Archive -> ChoreArchivePopup(archive, details, state.userId, strings, archiveActions,
            onLoadReviewPhoto) { popup = null }
        null -> Unit
    }
}

private sealed interface DashboardPopup {
    data object Announcement : DashboardPopup
    data class Catalog(val entry: ChoreCatalogEntry) : DashboardPopup
    data class Chore(val id: String) : DashboardPopup
    data object Archive : DashboardPopup
}

@Composable
private fun DashboardHeader(
    state: HouseUiState,
    houseName: String,
    strings: LocalizedText,
    unreadNotifications: Int,
    modifier: Modifier,
    onNotifications: () -> Unit,
    onAnnouncement: () -> Unit,
) {
    val houseImage = state.houses.firstOrNull { it.id == state.details?.id }?.profileImage
    BrandHeroCard(
        modifier.padding(start = Spacing.xl, end = Spacing.xl, top = Spacing.xl, bottom = Spacing.sm).fillMaxWidth(),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = Spacing.xl),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            DashboardHouseImage(houseImage)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    strings.template("dashboard_greeting_template",
                        "first_name" to state.firstName.ifBlank { strings.get("common_user_fallback") }),
                    color = LocalFausTheme.current.decor.heroAccentText, fontSize = 14.sp, fontWeight = FontWeight.Medium,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
                BasicText(
                    houseName,
                    style = TextStyle(color = FausCrewColors.onHero, fontSize = 24.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1,
                    autoSize = TextAutoSize.StepBased(minFontSize = 17.sp, maxFontSize = 24.sp),
                )
            }
            NotificationBellButton(unreadNotifications, strings, onNotifications)
            val description = strings.get("new_announcement_action_accessibility_label", "Create announcement")
            Box(
                Modifier.size(40.dp).clip(CircleShape).background(LocalFausTheme.current.decor.heroOrnament.copy(alpha = .18f))
                    .clickable(role = Role.Button, onClick = onAnnouncement)
                    .semantics { contentDescription = description },
                contentAlignment = Alignment.Center,
            ) {
                Icon(FausCrewIcons.megaphoneFill, null, Modifier.size(Sizes.iconMedium + 2.dp),
                    tint = FausCrewColors.onHero.copy(alpha = .9f))
            }
        }
    }
}

/** House artwork in a white frame; falls back to the brand house icon. */
@Composable
private fun DashboardHouseImage(url: String?) {
    val shape = RoundedCornerShape(20.dp)
    Box(
        Modifier.softShadow(Color(0xFF3A0A1E).copy(alpha = .3f), 7.dp, y = 5.dp, shape = shape)
            .clip(shape).background(LocalFausTheme.current.decor.heroFrame.let { if (it.size == 1) SolidColor(it.first()) else Brush.linearGradient(it) }).padding(3.dp),
    ) {
        RemoteImage(url, Modifier.size(66.dp).clip(RoundedCornerShape(17.dp))) {
            Box(Modifier.fillMaxSize().background(LocalFausTheme.current.decor.heroTile), contentAlignment = Alignment.Center) {
                FausHouseIcon(32.dp)
            }
        }
    }
}
