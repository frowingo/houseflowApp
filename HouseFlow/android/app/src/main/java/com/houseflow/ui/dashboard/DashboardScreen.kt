package com.houseflow.ui.dashboard

import android.content.Context
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.houseflow.platform.ChoreInput
import com.houseflow.platform.HouseAnnouncement
import com.houseflow.platform.HouseChore
import com.houseflow.platform.HouseDetails
import com.houseflow.platform.HouseMember
import com.houseflow.platform.LocalizedText
import com.houseflow.viewmodel.HouseUiState
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.delay

private val indigo = Color(0xFF45579E)
private val teal = Color(0xFF2E9187)
private val purple = Color(0xFF7A61AD)
private val orange = Color(0xFFFF7A26)
private val ink = Color(0xFF1C1C1E)
private val muted = Color(0xFF6B6B73)
private val page = Color(0xFFF7F7FA)
private val hero = Brush.linearGradient(listOf(Color(0xFFF59E59), Color(0xFFED7D40), Color(0xFF75304D)))

/** Dashboard matches the iOS hierarchy; house/details remains its sole initial data source. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
internal fun DashboardScreen(
    state: HouseUiState, strings: LocalizedText, onSwitch: (String) -> Unit,
    onAnnouncement: (String, String) -> Unit, onCreateChore: (ChoreInput) -> Unit,
    onStatus: (String, Int) -> Unit, onReview: (String, Boolean) -> Unit,
    onClearMessage: () -> Unit,
    onProfile: () -> Unit = {},
) {
    val details = state.details ?: return
    var switcher by remember { mutableStateOf(false) }
    var expanded by remember { mutableStateOf(false) }
    var fabExpanded by remember { mutableStateOf(false) }
    var popup by remember { mutableStateOf<DashboardPopup?>(null) }
    val context = LocalContext.current
    val readStore = remember(context) { AnnouncementReadStore(context) }
    var readIds by remember(details.id, state.userId) {
        mutableStateOf(readStore.load(details.id, state.userId))
    }
    LaunchedEffect(fabExpanded) { if (fabExpanded) { delay(3_000); fabExpanded = false } }
    LaunchedEffect(details.id) { popup = null; expanded = false; fabExpanded = false; switcher = false }
    LaunchedEffect(state.mutationSerial) {
        if (state.mutationSerial > 0 && state.mutationMessageKey !in listOf("chore_approved_toast", "chore_sent_back_toast"))
            popup = null
    }
    LaunchedEffect(state.mutationError) {
        if (state.mutationError != null && popup == DashboardPopup.NewChore) popup = null
    }

    Box(Modifier.fillMaxSize().background(page).statusBarsPadding().navigationBarsPadding()) {
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 8.dp)
                    .height(112.dp).clip(RoundedCornerShape(20.dp)).background(hero)) {
                    Column(Modifier.align(Alignment.BottomStart).padding(20.dp)) {
                        Text(strings.template("dashboard_greeting_template", "first_name" to
                            state.firstName.ifBlank { strings.get("common_user_fallback") }),
                            fontSize = 23.sp, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1)
                        Text(details.name, fontSize = 15.sp, color = Color.White.copy(alpha = .82f), maxLines = 1)
                    }
                    TextButton(onClick = { popup = DashboardPopup.Announcement },
                        modifier = Modifier.align(Alignment.CenterEnd).padding(end = 12.dp)
                            .semantics { contentDescription = strings.get("new_announcement_action_accessibility_label") }) {
                        Icon(Icons.Filled.Info, null, tint = Color.White, modifier = Modifier.size(25.dp))
                    }
                }
                AnnouncementCard(details, strings, expanded, { expanded = !expanded }, readIds) { id ->
                    readIds = if (id in readIds) readIds - id else readIds + id
                    readStore.save(details.id, state.userId, readIds)
                }
                ChoresCard(details, strings) { popup = DashboardPopup.Chore(it) }
                MembersCard(details.members, strings)
                Spacer(Modifier.height(140.dp))
            }
            if (popup == null) HomeBar(state, strings, { switcher = true }, onProfile)
        }
        Box(Modifier.align(Alignment.BottomEnd).padding(end = 24.dp, bottom = 108.dp)) {
            Button(onClick = {
                if (fabExpanded) { fabExpanded = false; popup = DashboardPopup.NewChore }
                else fabExpanded = true
            },
                modifier = Modifier.height(56.dp).semantics {
                    contentDescription = strings.get("floating_new_chore_button")
                }, shape = RoundedCornerShape(28.dp)) {
                Icon(Icons.Filled.Add, null)
                if (fabExpanded) {
                    Spacer(Modifier.width(8.dp))
                    Text(strings.get("floating_new_chore_button"))
                }
            }
        }
        if (state.mutationError != null || state.mutationMessageKey != null) {
            Row(Modifier.align(Alignment.BottomCenter).padding(bottom = 86.dp, start = 20.dp, end = 20.dp)
                .clip(RoundedCornerShape(14.dp)).background(if (state.mutationError == null) teal else Color(0xFFB43E45))
                .padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(state.mutationError ?: strings.get(state.mutationMessageKey!!), color = Color.White,
                    modifier = Modifier.weight(1f))
                TextButton(onClick = onClearMessage) { Icon(Icons.Filled.Close, strings.get("common_close"), tint = Color.White) }
            }
        }
    }
    if (switcher) AlertDialog(onDismissRequest = { switcher = false },
        title = { Text(strings.get("house_switcher_title")) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            state.houses.forEach { house ->
                Row(Modifier.fillMaxWidth().clickable { switcher = false; onSwitch(house.id) }.padding(8.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Home, null, tint = indigo)
                    Column(Modifier.padding(start = 12.dp)) {
                        Text(house.name)
                        if (house.id == details.id) Text(strings.get("house_switcher_current"), fontSize = 12.sp, color = orange)
                    }
                }
            }
        } }, confirmButton = { TextButton(onClick = { switcher = false }) { Text(strings.get("common_cancel")) } })
    when (val shown = popup) {
        DashboardPopup.Announcement -> AnnouncementPopup(strings, state.mutationBusy, state.mutationError,
            { popup = null }, onAnnouncement)
        DashboardPopup.NewChore -> NewChorePopup(details, strings, state.mutationBusy,
            state.mutationError, { popup = null }, onCreateChore)
        is DashboardPopup.Chore -> {
            val chore = details.chores.firstOrNull { it.id == shown.id }
            if (chore != null) ChorePopup(chore, details, state.userId, strings, state.mutationBusy,
                state.mutationError, { popup = null }, onStatus, onReview)
        }
        null -> Unit
    }
}

private sealed interface DashboardPopup {
    data object Announcement : DashboardPopup
    data object NewChore : DashboardPopup
    data class Chore(val id: String) : DashboardPopup
}

private fun LocalizedText.template(key: String, vararg values: Pair<String, String>): String =
    values.fold(get(key)) { text, (name, value) -> text.replace("{$name}", value) }

@Composable private fun DashboardCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Color.White).padding(20.dp)) { content() }
}

@Composable
private fun AnnouncementCard(details: HouseDetails, strings: LocalizedText, expanded: Boolean,
    onExpand: () -> Unit, readIds: Set<String>, onRead: (String) -> Unit) {
    val active = remember(details.announcements) { details.announcements.filter { it.isActive } }
    val sorted = remember(active, readIds) { active.sortedWith(compareBy<HouseAnnouncement> { it.id in readIds }
        .thenByDescending { runCatching { OffsetDateTime.parse(it.createdOn).toInstant() }.getOrNull() }) }
    DashboardCard(Modifier.padding(horizontal = 20.dp)) {
        Row(Modifier.fillMaxWidth().clickable(onClick = onExpand), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Info, null, modifier = Modifier.size(46.dp), tint = purple)
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(strings.get("announcement_title"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink)
                Text(if (active.isEmpty()) strings.get("announcement_empty_title") else
                    strings.template("announcement_count_template", "count" to active.size.toString()),
                    fontSize = 12.sp, color = muted)
            }
            val unread = active.count { it.id !in readIds }
            if (unread > 0) Text(unread.toString(), color = Color.White, fontSize = 11.sp,
                modifier = Modifier.background(orange, CircleShape).padding(horizontal = 7.dp, vertical = 3.dp))
            Text(if (expanded) "⌃" else "⌄", modifier = Modifier.padding(start = 8.dp), color = indigo)
        }
        if (expanded) {
            Spacer(Modifier.height(16.dp))
            if (sorted.isEmpty()) Text(strings.get("announcement_empty_title"), color = muted,
                modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp), textAlign = TextAlign.Center)
            sorted.forEach { item ->
                AnnouncementRow(item, details.members, strings, item.id in readIds) { onRead(item.id) }
                Spacer(Modifier.height(10.dp))
            }
        }
    }
}

@Composable
private fun AnnouncementRow(item: HouseAnnouncement, members: List<HouseMember>, strings: LocalizedText,
    read: Boolean, onRead: () -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
        .background(if (read) page else indigo.copy(alpha = .055f)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(item.title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = ink)
        Text(item.message, fontSize = 14.sp, color = muted)
        val publisher = item.publisherName ?: members.firstOrNull { it.id == item.publisherId }?.name
        if (!publisher.isNullOrBlank()) Text(strings.template("announcement_published_by_template", "name" to publisher),
            fontSize = 12.sp, color = indigo)
        Text(displayDateTime(item.createdOn), fontSize = 12.sp, color = muted)
        TextButton(onClick = onRead) {
            Text(strings.get(if (read) "announcement_read_label" else "announcement_mark_read_button"))
        }
    }
}

@Composable
private fun ChoresCard(details: HouseDetails, strings: LocalizedText, onOpen: (String) -> Unit) {
    val chores = details.chores
    val done = chores.count { it.status == 3 }
    DashboardCard(Modifier.padding(horizontal = 24.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Info, null, Modifier.size(44.dp), tint = indigo)
            Column(Modifier.padding(start = 12.dp)) {
                Text(strings.get("todays_tasks_title"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink)
                if (chores.isNotEmpty()) Text(strings.template("todays_tasks_completed_template",
                    "completed" to done.toString(), "total" to chores.size.toString()), fontSize = 12.sp, color = muted)
            }
        }
        Spacer(Modifier.height(16.dp))
        if (chores.isEmpty()) Column(Modifier.fillMaxWidth().padding(vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Text(strings.get("todays_tasks_empty_title"), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ink)
            Text(strings.get("todays_tasks_empty_subtitle"), fontSize = 14.sp, color = muted)
        } else chores.forEach { chore ->
            Row(Modifier.fillMaxWidth().clickable { onOpen(chore.id) }.padding(vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text(if (chore.status == 3) "✓" else "○", color = if (chore.status == 3) teal else indigo,
                    modifier = Modifier.width(28.dp))
                Text(chore.title, modifier = Modifier.weight(1f), maxLines = 1, color = ink, fontSize = 15.sp)
                Box(Modifier.padding(horizontal = 8.dp)) {
                    MemberAvatar(details.members.firstOrNull { it.id == chore.assignedTo }, 32.dp)
                }
                Text(strings.get(chore.statusKey()), fontSize = 11.sp, color = indigo,
                    modifier = Modifier.background(indigo.copy(alpha = .1f), RoundedCornerShape(8.dp)).padding(5.dp))
                Icon(Icons.Filled.Info, strings.get("chore_detail_task_label"), Modifier.padding(start = 8.dp).size(18.dp), tint = indigo)
            }
        }
    }
}

@Composable
private fun MembersCard(members: List<HouseMember>, strings: LocalizedText) {
    DashboardCard(Modifier.padding(horizontal = 24.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Person, null, Modifier.size(42.dp), tint = teal)
            Text(strings.get("house_members_title"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f).padding(start = 12.dp), color = ink)
            Text(members.size.toString(), color = indigo)
        }
        Spacer(Modifier.height(16.dp))
        if (members.isEmpty()) Text(strings.get("house_members_empty_message"), color = muted)
        else Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            members.forEach { member ->
                Column(Modifier.width(108.dp).height(124.dp).clip(RoundedCornerShape(16.dp))
                    .background(indigo.copy(alpha = .075f)).padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    MemberAvatar(member, 62.dp)
                    Text(member.name, fontSize = 12.sp, maxLines = 2, color = ink, textAlign = TextAlign.Center)
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HomeBar(state: HouseUiState, strings: LocalizedText, onShowSwitcher: () -> Unit,
    onProfile: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp)
        .clip(RoundedCornerShape(28.dp)).background(hero).padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.clickable(onClick = onProfile), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Person, strings.get("tab_profile"), Modifier.size(24.dp),
                tint = Color.White.copy(alpha = .7f))
            Text(strings.get("tab_profile"), fontSize = 12.sp, color = Color.White.copy(alpha = .7f))
        }
        Column(Modifier.combinedClickable(onClick = {}, onLongClick = { if (state.houses.size > 1) onShowSwitcher() })
            .semantics { contentDescription = strings.get("tab_home") }, horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Home, null, Modifier.size(26.dp), tint = Color.White)
            Text(strings.get("tab_home"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
        }
        Text(strings.get("tab_games"), fontSize = 12.sp, color = Color.White.copy(alpha = .55f))
    }
}

@Composable
private fun PopupShell(title: String, busy: Boolean, error: String?, strings: LocalizedText, onDismiss: () -> Unit,
    content: @Composable () -> Unit) {
    Dialog(onDismissRequest = { if (!busy) onDismiss() }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp).clip(RoundedCornerShape(24.dp)).background(page)) {
            Row(Modifier.fillMaxWidth().background(hero).padding(horizontal = 20.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text(title, fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Color.White,
                    modifier = Modifier.weight(1f))
                TextButton(onClick = onDismiss, enabled = !busy) {
                    Icon(Icons.Filled.Close, strings.get("common_close"), tint = Color.White)
                }
            }
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)) {
                if (error != null) Text(error, color = Color(0xFFB43E45))
                content()
            }
        }
    }
}

@Composable
private fun AnnouncementPopup(strings: LocalizedText, busy: Boolean, error: String?, onDismiss: () -> Unit,
    onPublish: (String, String) -> Unit) {
    var title by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    PopupShell(strings.get("new_announcement_title"), busy, error, strings, onDismiss) {
        Text(strings.get("new_announcement_subtitle"), color = muted, textAlign = TextAlign.Center)
        OutlinedTextField(title, { title = it.take(30) }, label = { Text(strings.get("new_announcement_title_label")) },
            placeholder = { Text(strings.get("new_announcement_title_placeholder")) }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(message, { message = it.take(150) }, label = { Text(strings.get("new_announcement_message_label")) },
            placeholder = { Text(strings.get("new_announcement_message_placeholder")) },
            minLines = 4, modifier = Modifier.fillMaxWidth())
        Button(onClick = { onPublish(title.trim(), message.trim()) },
            enabled = !busy && title.isNotBlank() && message.isNotBlank(), modifier = Modifier.fillMaxWidth()) {
            Text(strings.get("new_announcement_publish_button"))
        }
        TextButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
            Text(strings.get("common_cancel"))
        }
    }
}

@Composable
private fun NewChorePopup(details: HouseDetails, strings: LocalizedText, busy: Boolean, error: String?, onDismiss: () -> Unit,
    onCreate: (ChoreInput) -> Unit) {
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var memberId by remember(details.id) { mutableStateOf(details.members.firstOrNull()?.id.orEmpty()) }
    var level by remember { mutableIntStateOf(10) }
    var dueDate by remember { mutableStateOf(LocalDate.now()) }
    var datePicker by remember { mutableStateOf(false) }
    var recurring by remember { mutableStateOf(false) }
    var interval by remember { mutableStateOf("7") }
    PopupShell(strings.get("new_chore_title"), busy, error, strings, onDismiss) {
        OutlinedTextField(title, { title = it }, label = { Text(strings.get("new_chore_task_name_label")) },
            placeholder = { Text(strings.get("new_chore_task_name_placeholder")) }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(description, { description = it }, label = { Text(strings.get("new_chore_description_label")) },
            placeholder = { Text(strings.get("new_chore_description_placeholder")) }, modifier = Modifier.fillMaxWidth())
        Text(strings.get("new_chore_assign_to_label"), color = ink, fontWeight = FontWeight.SemiBold)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            details.members.forEach { member ->
                Text(member.name, Modifier.clip(RoundedCornerShape(18.dp))
                    .background(if (memberId == member.id) indigo else Color.White)
                    .clickable { memberId = member.id }.padding(horizontal = 14.dp, vertical = 10.dp),
                    color = if (memberId == member.id) Color.White else ink)
            }
        }
        Text(strings.get("new_chore_difficulty_label"), color = ink, fontWeight = FontWeight.SemiBold)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(10, 20, 30).forEach { value ->
                val key = when (value) { 20 -> "chore_level_medium"; 30 -> "chore_level_hard"; else -> "chore_level_easy" }
                Text(strings.get(key), Modifier.clip(RoundedCornerShape(14.dp))
                    .background(if (level == value) orange else Color.White)
                    .clickable { level = value }.padding(10.dp), color = if (level == value) Color.White else ink)
            }
        }
        Text(strings.get("new_chore_due_date_label"), color = ink, fontWeight = FontWeight.SemiBold)
        TextButton(onClick = { datePicker = true }) { Text(dueDate.toString()) }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(strings.get("new_chore_recurring_label"), modifier = Modifier.weight(1f))
            Switch(checked = recurring, onCheckedChange = { recurring = it })
        }
        if (recurring) Row(verticalAlignment = Alignment.CenterVertically) {
            Text(strings.get("new_chore_every_label"))
            OutlinedTextField(interval, { interval = it.filter(Char::isDigit).take(3) },
                modifier = Modifier.width(86.dp).padding(horizontal = 4.dp), singleLine = true)
            Text(strings.get("new_chore_days_label"))
        }
        Button(onClick = {
            val local = dueDate.atStartOfDay(ZoneId.systemDefault()).toOffsetDateTime()
            onCreate(ChoreInput(details.id, memberId, title.trim(), description,
                DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(local), recurring, level,
                if (recurring) interval.toIntOrNull() ?: 7 else 0))
        }, enabled = !busy && title.isNotBlank() && memberId.isNotBlank() && dueDate >= LocalDate.now(),
            modifier = Modifier.fillMaxWidth()) {
            Text(strings.get("common_create"))
        }
        TextButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
            Text(strings.get("common_cancel"))
        }
    }
    if (datePicker) {
        val picker = rememberDatePickerState(initialSelectedDateMillis =
            dueDate.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
        DatePickerDialog(onDismissRequest = { datePicker = false }, confirmButton = {
            TextButton(onClick = {
                picker.selectedDateMillis?.let {
                    val selected = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()
                    if (selected >= LocalDate.now()) dueDate = selected
                }
                datePicker = false
            }) { Text(strings.get("common_continue")) }
        }, dismissButton = { TextButton(onClick = { datePicker = false }) { Text(strings.get("common_cancel")) } }) {
            DatePicker(state = picker)
        }
    }
}

@Composable
private fun ChorePopup(chore: HouseChore, details: HouseDetails, userId: String, strings: LocalizedText,
    busy: Boolean, error: String?, onDismiss: () -> Unit, onStatus: (String, Int) -> Unit,
    onReview: (String, Boolean) -> Unit) {
    val isAssignee = chore.assignedTo == userId
    val currentVote = chore.reviewVotes.firstOrNull { it.reviewRound == chore.reviewRound && it.reviewerId == userId }
    PopupShell(chore.title, busy, error, strings, onDismiss) {
        Text(strings.get("chore_detail_status_label"), fontWeight = FontWeight.SemiBold, color = orange)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            (0..3).forEach { status -> Text(strings.get(status.statusKey()),
                fontSize = 10.sp, color = if (status <= chore.status) indigo else muted) }
        }
        Text(strings.get("chore_detail_task_label"), fontWeight = FontWeight.SemiBold, color = orange)
        Text(chore.title, fontWeight = FontWeight.SemiBold, color = ink)
        Text(chore.description, color = muted)
        Text(strings.get("chore_detail_assigned_to_label") + ": " +
            (details.members.firstOrNull { it.id == chore.assignedTo }?.name ?: strings.get("common_unassigned")), color = muted)
        Text(strings.get("chore_detail_due_label") + ": " + displayDate(chore.dueDate), color = muted)
        if (isAssignee && chore.status in 0..1) {
            val next = chore.status + 1
            Text(strings.get("chore_detail_update_status_description"), color = muted)
            Button(onClick = { onStatus(chore.id, next) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                Text(strings.template("chore_detail_move_to_status_template", "status" to strings.get(next.statusKey())))
            }
        }
        if (chore.reviewRound > 0 || chore.reviewVotes.isNotEmpty()) {
            Text(strings.get("chore_detail_review_rounds_label"), fontWeight = FontWeight.SemiBold, color = orange)
            chore.reviewVotes.groupBy { it.reviewRound }.toSortedMap(reverseOrder()).forEach { (round, votes) ->
                Text(strings.template("chore_detail_round_template", "round" to round.toString()), color = ink)
                Text(votes.joinToString(" · ") { vote ->
                    val member = details.members.firstOrNull { it.id == vote.reviewerId }?.name ?: vote.reviewerId
                    "$member: ${strings.get(if (vote.isApproved) "chore_detail_review_approved" else "chore_detail_review_rejected")}" },
                    color = muted, fontSize = 12.sp)
            }
        }
        if (chore.status == 2) {
            when {
                isAssignee -> Text(strings.get("chore_detail_assignee_no_vote_message"), color = muted)
                currentVote != null -> Text(strings.get(if (currentVote.isApproved) "chore_detail_you_approved_message"
                    else "chore_detail_you_rejected_message"), color = muted)
                userId.isNotBlank() -> {
                    Text(strings.get("chore_detail_review_prompt"), color = muted)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(onClick = { onReview(chore.id, false) }, enabled = !busy,
                            modifier = Modifier.weight(1f)) { Text(strings.get("chore_detail_reject_button")) }
                        Button(onClick = { onReview(chore.id, true) }, enabled = !busy,
                            modifier = Modifier.weight(1f)) { Text(strings.get("chore_detail_approve_button")) }
                    }
                }
            }
        }
        TextButton(onClick = onDismiss, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
            Text(strings.get("common_close"))
        }
    }
}

private fun Int.statusKey(): String = when (this) {
    1 -> "chore_status_in_progress"
    2 -> "chore_status_in_review"
    3 -> "chore_status_completed"
    else -> "chore_status_draft"
}
private fun HouseChore.statusKey() = status.statusKey()

private fun displayDateTime(value: String): String = runCatching {
    OffsetDateTime.parse(value).atZoneSameInstant(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT))
}.getOrDefault(value)

private fun displayDate(value: String): String = runCatching {
    OffsetDateTime.parse(value).atZoneSameInstant(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
}.getOrDefault(value)

private class AnnouncementReadStore(context: Context) {
    private val prefs = context.getSharedPreferences("houseflow.read-announcements", Context.MODE_PRIVATE)
    private fun key(houseId: String, userId: String) = "$userId:$houseId"
    fun load(houseId: String, userId: String): Set<String> = prefs.getStringSet(key(houseId, userId), emptySet())?.toSet() ?: emptySet()
    fun save(houseId: String, userId: String, ids: Set<String>) {
        prefs.edit().putStringSet(key(houseId, userId), ids.toSet()).apply()
    }
}
