package com.fauscrew.ui.dashboard

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.BrandHeroCard
import com.fauscrew.ui.components.FausCrewToast
import com.fauscrew.ui.components.mainScreenBackground
import com.fauscrew.ui.main.TabBarClearance
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Motion
import com.fauscrew.ui.theme.Sizes
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.entrance
import com.fauscrew.ui.theme.rememberEntrance
import com.fauscrew.ui.theme.softShadow
import com.fauscrew.viewmodel.HouseUiState
import kotlinx.coroutines.delay

/**
 * `HouseDashboardView`: hero greeting, announcements, today's chores and members, the
 * two-step new-chore FAB and the dashboard popups. `house/details` is the only data source.
 */
@Composable
internal fun DashboardScreen(
    state: HouseUiState,
    strings: LocalizedText,
    onAnnouncement: (String, String) -> Unit,
    onCreateChore: (ChoreInput) -> Unit,
    onStatus: (String, Int) -> Unit,
    onReview: (String, Boolean) -> Unit,
    onClearMessage: () -> Unit,
    onOverlayChange: (Boolean) -> Unit = {},
) {
    val details = state.details ?: return
    var announcementsExpanded by remember { mutableStateOf(false) }
    var fabExpanded by remember { mutableStateOf(false) }
    var popup by remember { mutableStateOf<DashboardPopup?>(null) }
    var reviewing by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val readStore = remember(context) { AnnouncementReadStore(context) }
    var readIds by remember(details.id, state.userId) { mutableStateOf(readStore.load(details.id, state.userId)) }

    LaunchedEffect(fabExpanded) { if (fabExpanded) { delay(3_000); fabExpanded = false } }
    LaunchedEffect(details.id) { popup = null; announcementsExpanded = false; fabExpanded = false }
    LaunchedEffect(state.mutationSerial) {
        if (state.mutationSerial > 0 && state.mutationMessageKey !in listOf("chore_approved_toast", "chore_sent_back_toast"))
            popup = null
    }
    LaunchedEffect(state.mutationError) {
        if (state.mutationError != null && popup == DashboardPopup.NewChore) popup = null
    }
    val overlayCallback by rememberUpdatedState(onOverlayChange)
    LaunchedEffect(popup != null) { overlayCallback(popup != null) }
    DisposableEffect(Unit) { onDispose { overlayCallback(false) } }

    val header = rememberEntrance(50)
    val announcements = rememberEntrance(120)
    val chores = rememberEntrance(220)
    val members = rememberEntrance(320)

    Box(Modifier.fillMaxSize().mainScreenBackground()) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            DashboardHeader(state, details.name, strings, Modifier.entrance(header, 12.dp)) {
                popup = DashboardPopup.Announcement
            }
            AnnouncementCard(
                announcements = details.announcements, members = details.members, readIds = readIds,
                expanded = announcementsExpanded, strings = strings,
                onToggleExpanded = { announcementsExpanded = !announcementsExpanded },
                onToggleRead = { id ->
                    readIds = if (id in readIds) readIds - id else readIds + id
                    readStore.save(details.id, state.userId, readIds)
                },
                modifier = Modifier.padding(horizontal = Spacing.xl).entrance(announcements, 20.dp),
            )
            TodaysChoresCard(details.chores, details.members, strings, { popup = DashboardPopup.Chore(it.id) },
                Modifier.padding(horizontal = Spacing.xxl).entrance(chores, 26.dp))
            HouseMembersCard(details.members, strings, Modifier.padding(horizontal = Spacing.xxl).entrance(members, 26.dp))
            Spacer(Modifier.navigationBarsPadding().height(TabBarClearance))
        }
        NewChoreFab(
            expanded = fabExpanded,
            label = strings.get("floating_new_chore_button"),
            modifier = Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(end = Spacing.xxl, bottom = 76.dp),
        ) {
            if (fabExpanded) {
                fabExpanded = false
                popup = DashboardPopup.NewChore
            } else {
                fabExpanded = true
            }
        }
        FausCrewToast(
            message = state.mutationError ?: state.mutationMessageKey?.let(strings::get),
            isError = state.mutationError != null,
            onDismiss = onClearMessage,
            modifier = Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 60.dp),
        )
    }

    when (val shown = popup) {
        DashboardPopup.Announcement -> NewAnnouncementPopup(strings, state.mutationBusy, state.mutationError,
            { popup = null }, onAnnouncement)
        DashboardPopup.NewChore -> NewChorePopup(details, strings, state.mutationBusy, state.mutationError,
            { popup = null }, onCreateChore)
        is DashboardPopup.Chore -> details.chores.firstOrNull { it.id == shown.id }?.let { chore ->
            ChoreDetailPopup(
                chore = chore, members = details.members, userId = state.userId, strings = strings,
                busy = state.mutationBusy, reviewing = reviewing, error = state.mutationError,
                onDismiss = { popup = null },
                onStatus = { id, status -> reviewing = false; onStatus(id, status) },
                onReview = { id, approved -> reviewing = true; onReview(id, approved) },
            )
        }
        null -> Unit
    }
}

private sealed interface DashboardPopup {
    data object Announcement : DashboardPopup
    data object NewChore : DashboardPopup
    data class Chore(val id: String) : DashboardPopup
}

@Composable
private fun DashboardHeader(
    state: HouseUiState,
    houseName: String,
    strings: LocalizedText,
    modifier: Modifier,
    onAnnouncement: () -> Unit,
) {
    BrandHeroCard(
        modifier.padding(start = Spacing.xl, end = Spacing.xl, top = Spacing.xl, bottom = Spacing.sm)
            .fillMaxWidth().height(112.dp),
    ) {
        Row(Modifier.fillMaxSize().padding(Spacing.xl), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                BasicText(
                    strings.template("dashboard_greeting_template",
                        "first_name" to state.firstName.ifBlank { strings.get("common_user_fallback") }),
                    style = TextStyle(color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1,
                    autoSize = TextAutoSize.StepBased(minFontSize = 16.sp, maxFontSize = 23.sp),
                )
                Text(houseName, style = FausCrewType.subheadline, color = Color.White.copy(alpha = .82f),
                    maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            val description = strings.get("new_announcement_action_accessibility_label", "Create announcement")
            Box(
                Modifier.clip(CircleShape).background(Color.White.copy(alpha = .18f))
                    .clickable(role = Role.Button, onClick = onAnnouncement)
                    .semantics { contentDescription = description }
                    .padding(10.dp),
            ) {
                Icon(FausCrewIcons.megaphoneFill, null, Modifier.size(Sizes.iconMedium + 2.dp),
                    tint = Color.White.copy(alpha = .85f))
            }
        }
    }
}

/** `FloatingActionButton`: + circle that stretches to "+ New Chore" on the first tap. */
@Composable
private fun NewChoreFab(expanded: Boolean, label: String, modifier: Modifier, onClick: () -> Unit) {
    val scale by animateFloatAsState(if (expanded) 1.05f else 1f, Motion.spring(), label = "fabScale")
    val shape = RoundedCornerShape(28.dp)
    Row(
        modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .softShadow(FausCrewColors.secondary.copy(alpha = .3f), 8.dp, y = 4.dp, shape = shape)
            .clip(shape)
            .background(Brush.linearGradient(listOf(FausCrewColors.secondary, FausCrewColors.secondary.copy(alpha = .8f))))
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label }
            .animateContentSize(Motion.spring())
            .then(if (expanded) Modifier.padding(horizontal = Spacing.xl, vertical = Spacing.lg) else Modifier.size(Sizes.fab)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(FausCrewIcons.plus, null, Modifier.size(if (expanded) 22.dp else 26.dp), tint = Color.White)
        AnimatedVisibility(expanded, enter = fadeIn() + scaleIn(), exit = fadeOut() + scaleOut()) {
            Row {
                Spacer(Modifier.width(Spacing.sm))
                Text(label, style = FausCrewType.headline, color = Color.White, maxLines = 1)
            }
        }
    }
}
