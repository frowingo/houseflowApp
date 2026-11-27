package com.fauscrew.ui.dashboard.archive

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.ApiLanguage
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.HouseDetails
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.auth.social
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.dashboard.ChoreDetailPopup
import com.fauscrew.ui.dashboard.ChoreStatusUi
import com.fauscrew.ui.dashboard.ModernChoreRow
import com.fauscrew.ui.dashboard.displayApiDate
import com.fauscrew.ui.dashboard.message
import com.fauscrew.ui.dashboard.notifications.NotificationSkeletonRow
import com.fauscrew.ui.dashboard.notifications.NotificationStatusCard
import com.fauscrew.ui.profile.ProfilePopupHeader
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.viewmodel.ChoreArchivePhase
import com.fauscrew.viewmodel.ChoreArchiveUiState
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

/** What the dashboard can ask of the archive state holder. */
internal data class ChoreArchiveActions(
    val open: () -> Unit = {},
    val previousMonth: () -> Unit = {},
    val nextMonth: () -> Unit = {},
    val reload: () -> Unit = {},
    val loadMore: () -> Unit = {},
)

/**
 * Closed chores of the selected house, one month at a time, as a popup like [com.fauscrew.ui.dashboard.notifications.NotificationsPopup].
 * A tapped row opens its read-only detail on top of this popup.
 */
@Composable
internal fun ChoreArchivePopup(
    state: ChoreArchiveUiState,
    details: HouseDetails,
    userId: String,
    strings: LocalizedText,
    actions: ChoreArchiveActions,
    onLoadReviewPhoto: suspend (String, Int) -> ByteArray?,
    onDismiss: () -> Unit,
) {
    var selected by remember { mutableStateOf<HouseChore?>(null) }
    val locale = Locale.forLanguageTag(if ((strings.prefix ?: ApiLanguage.code).startsWith("tr", ignoreCase = true)) "tr" else "en")

    FausCrewPopup(
        onDismiss = onDismiss,
        maxBodyHeight = 500.dp,
        scrollableBody = false,
        bodyPadding = 0.dp,
        header = {
            ProfilePopupHeader(
                strings.social("chore_archive_title", "Arşiv", "Archive"), details.name.ifBlank { null }, FausCrewIcons.clockFill, true,
                strings.get("common_close"), onDismiss, leadingIcon = FausCrewIcons.clockFill, decorativeOffsetX = 84.dp,
            )
        },
    ) {
        PullToRefreshBox(isRefreshing = state.refreshing, onRefresh = actions.reload) {
            LazyColumn(
                Modifier.fillMaxWidth().heightIn(max = 500.dp),
                contentPadding = PaddingValues(Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                item(key = "month") { MonthNavigator(state.month, state.canShowNextMonth, locale, actions) }
                when {
                    state.phase == ChoreArchivePhase.LOADING -> items(4) { NotificationSkeletonRow() }
                    state.phase == ChoreArchivePhase.ERROR -> item(key = "error") {
                        // The whole card retries, like the notifications popup.
                        NotificationStatusCard(FausCrewIcons.wifiExclamationmark, FausCrewColors.error,
                            state.errorMessage ?: strings.social("chore_archive_error", "Arşiv yüklenemedi", "Couldn't load the archive"),
                            actions.reload)
                    }
                    state.chores.isEmpty() -> item(key = "empty") {
                        NotificationStatusCard(FausCrewIcons.calendar, FausCrewColors.accentOrangeInk,
                            strings.social("chore_archive_empty", "Bu ayda kapanmış görev yok", "No chores closed this month"))
                    }
                    else -> {
                        items(state.chores, key = { it.id }) { chore ->
                            ModernChoreRow(chore, details.members.firstOrNull { it.id == chore.assignedTo }, strings,
                                detail = archiveDetail(chore, details.members, strings)) { selected = chore }
                        }
                        item(key = "paging") {
                            when {
                                state.loadingMore -> Box(Modifier.fillMaxWidth().padding(vertical = Spacing.md), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(Modifier.size(20.dp), color = FausCrewColors.accentOrange, strokeWidth = 2.dp)
                                }
                                state.loadMoreFailed -> RetryRow(strings, actions.loadMore)
                                state.canLoadMore -> LoadMoreButton(strings, actions.loadMore)
                            }
                        }
                    }
                }
            }
        }
    }

    // Layered above the archive, so closing it returns here. Closed chores take no actions.
    selected?.let { chore ->
        ChoreDetailPopup(
            chore = chore, members = details.members, userId = userId, strings = strings,
            busy = false, reviewing = false, error = null,
            isReviewPhotoRequired = details.isChoreReviewPhotoRequired,
            onDismiss = { selected = null }, onStatus = { _, _, _ -> }, onReview = { _, _ -> },
            onLoadReviewPhoto = onLoadReviewPhoto,
        )
    }
}

/** `‹ Kasım 2026 ›`; the forward arrow is dimmed and inert when [canGoForward] is false. */
@Composable
private fun MonthNavigator(month: YearMonth, canGoForward: Boolean, locale: Locale, actions: ChoreArchiveActions) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        MonthArrow(FausCrewIcons.chevronLeft, true, actions.previousMonth)
        Text(month.format(DateTimeFormatter.ofPattern("LLLL yyyy", locale)), style = FausCrewType.headline,
            color = FausCrewColors.textPrimary, textAlign = TextAlign.Center)
        MonthArrow(FausCrewIcons.chevronRightSmall, canGoForward, actions.nextMonth)
    }
}

@Composable
private fun MonthArrow(icon: ImageVector, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.size(36.dp).alpha(if (enabled) 1f else .3f).clip(CircleShape)
            .background(FausCrewColors.secondaryBackground)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(22.dp), tint = FausCrewColors.textPrimary)
    }
}

@Composable
private fun RetryRow(strings: LocalizedText, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).padding(vertical = Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(FausCrewIcons.arrowClockwise, null, Modifier.size(14.dp), tint = FausCrewColors.accentOrangeInk)
        Text(strings.social("chore_archive_retry", "Tekrar dene", "Try again"), style = FausCrewType.caption,
            fontWeight = FontWeight.SemiBold, color = FausCrewColors.accentOrangeInk)
    }
}

@Composable
private fun LoadMoreButton(strings: LocalizedText, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Text(
            strings.social("chore_archive_load_more", "Daha fazla göster", "Show more"),
            Modifier.clip(CircleShape).background(FausCrewColors.accentOrange.copy(alpha = .12f))
                .clickable(role = Role.Button, onClick = onClick).padding(horizontal = Spacing.lg, vertical = Spacing.sm),
            style = FausCrewType.subheadline, fontWeight = FontWeight.SemiBold, color = FausCrewColors.accentOrangeInk,
        )
    }
}

/**
 * The closing date, then who closed it (Completed) or why it failed (Failed). `completedBy` is only
 * looked up for Completed chores: a Failed chore carries `system`, which is not a member.
 */
private fun archiveDetail(chore: HouseChore, members: List<HouseMember>, strings: LocalizedText): String? {
    val closedAt = displayApiDate(chore.completedAt)?.let {
        strings.social("chore_archive_closed_at", "Kapandı: {date}", "Closed {date}").replace("{date}", it)
    }
    val outcome = when (ChoreStatusUi.of(chore.status)) {
        ChoreStatusUi.COMPLETED -> {
            val name = members.firstOrNull { it.id == chore.completedBy }?.name?.ifBlank { null }
                ?: strings.social("chore_archive_former_member", "Eski üye", "Former member")
            strings.social("chore_archive_completed_by", "Tamamlayan: {name}", "Completed by {name}").replace("{name}", name)
        }
        ChoreStatusUi.FAILED -> chore.failureReason.message(strings)
        else -> null
    }
    return listOfNotNull(closedAt, outcome).joinToString(" · ").ifEmpty { null }
}
