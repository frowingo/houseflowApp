package com.fauscrew.ui.dashboard.notifications

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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.clickable
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fauscrew.platform.ApiLanguage
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.NotificationItem
import com.fauscrew.platform.notificationText
import com.fauscrew.ui.components.FausCrewPopup
import com.fauscrew.ui.profile.ProfilePopupHeader
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.viewmodel.NotificationPanelState
import com.fauscrew.viewmodel.NotificationPhase
import java.time.Instant

/** What the dashboard can ask of the notification state holder. */
internal data class NotificationActions(
    val open: () -> Unit = {},
    val close: () -> Unit = {},
    val reload: () -> Unit = {},
    val loadMore: () -> Unit = {},
    val remind: (String) -> Unit = {},
    val clearToast: () -> Unit = {},
)

/**
 * The selected house's notifications as a full-screen popup like `NewAnnouncementPopup`. Opening it
 * moves the seen marker; rows newer than the old marker keep their accent bar.
 */
@Composable
internal fun NotificationsPopup(
    panel: NotificationPanelState,
    houseName: String,
    members: List<HouseMember>,
    strings: LocalizedText,
    actions: NotificationActions,
    onSelect: (NotificationItem) -> Unit,
) {
    val listState = rememberLazyListState()
    val nearEnd by remember(panel.items.size) {
        derivedStateOf { (listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1) >= panel.items.size - 3 }
    }
    LaunchedEffect(nearEnd, panel.items.size, panel.hasMore, panel.loadingMore, panel.moreFailed, panel.refreshing) {
        if (nearEnd && panel.hasMore && !panel.moreFailed && panel.phase == NotificationPhase.READY) actions.loadMore()
    }
    val tr = { key: String -> strings.notificationText(key) }
    val now = remember(panel.items) { Instant.now() }
    val turkish = (strings.prefix ?: ApiLanguage.code).startsWith("tr", ignoreCase = true)

    FausCrewPopup(
        onDismiss = actions.close,
        maxBodyHeight = 500.dp,
        scrollableBody = false,
        bodyPadding = 0.dp,
        header = {
            ProfilePopupHeader(
                tr("notifications_title"), houseName.ifBlank { null }, FausCrewIcons.bellFill, true,
                strings.get("common_close"), actions.close, leadingIcon = FausCrewIcons.bellFill, decorativeOffsetX = 84.dp,
            )
        },
    ) {
        PullToRefreshBox(isRefreshing = panel.refreshing && panel.phase == NotificationPhase.READY, onRefresh = actions.reload) {
            LazyColumn(
                Modifier.fillMaxWidth().heightIn(max = 500.dp), state = listState,
                contentPadding = PaddingValues(Spacing.xl), verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                when {
                    panel.phase == NotificationPhase.LOADING -> items(4) { NotificationSkeletonRow() }
                    panel.phase == NotificationPhase.ERROR -> item {
                        NotificationStatusCard(FausCrewIcons.wifiExclamationmark, FausCrewColors.error,
                            tr("notifications_error_retry"), actions.reload)
                    }
                    panel.items.isEmpty() -> item {
                        NotificationStatusCard(FausCrewIcons.bellSlash, FausCrewColors.accentOrangeInk, tr("notifications_empty"))
                    }
                    else -> {
                        items(panel.items, key = { it.id }) { item ->
                            val sender = members.firstOrNull { it.id == item.senderUserId }
                            NotificationRow(
                                item, sender, tr("notifications_former_member"), item.id in panel.unreadIds,
                                relativeNotificationTime(item.createdAt, now, turkish)
                            ) { onSelect(item) }
                        }
                        item(key = "paging") {
                            if (panel.loadingMore) {
                                Box(Modifier.fillMaxWidth().padding(vertical = Spacing.md), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(Modifier.size(20.dp), color = FausCrewColors.accentOrange, strokeWidth = 2.dp)
                                }
                            } else if (panel.moreFailed) {
                                Row(
                                    Modifier.fillMaxWidth().clickable(onClick = actions.loadMore).padding(vertical = Spacing.md),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Icon(FausCrewIcons.arrowClockwise, null, Modifier.size(14.dp), tint = FausCrewColors.accentOrangeInk)
                                    Text(tr("notifications_error_retry"), style = FausCrewType.caption,
                                        fontWeight = FontWeight.SemiBold, color = FausCrewColors.accentOrangeInk)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
