package com.houseflow.ui.profile

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.AuthProfile
import com.houseflow.platform.HouseInfoMember
import com.houseflow.platform.HouseMember
import com.houseflow.platform.LocalizedText
import com.houseflow.platform.ProfileChange
import com.houseflow.ui.components.UserAvatar
import com.houseflow.ui.auth.OtpField
import com.houseflow.viewmodel.HouseUiState
import com.houseflow.viewmodel.ProfileUiState
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@Composable
internal fun EditProfileDialog(user: AuthProfile, state: ProfileUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onSave: (ProfileChange) -> Unit) {
    var first by remember(user.userId) { mutableStateOf(user.firstName) }
    var last by remember(user.userId) { mutableStateOf(user.lastName) }
    var birthday by remember(user.userId) { mutableStateOf(user.birthDay.take(10)) }
    var picker by remember { mutableStateOf(false) }
    val changed = first.trim() != user.firstName || last.trim() != user.lastName ||
        (birthday.isNotBlank() && birthday != user.birthDay.take(10))
    ProfileDialog(strings.profileValue("profile_edit_button"), state.busy, onDismiss) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedTextField(first, { first = it }, label = { Text(strings.profileValue("profile_first_name_label")) },
                modifier = Modifier.fillMaxWidth(), singleLine = true)
            OutlinedTextField(last, { last = it }, label = { Text(strings.profileValue("profile_last_name_label")) },
                modifier = Modifier.fillMaxWidth(), singleLine = true)
            TextButton(onClick = { picker = true }) {
                Text("${strings.profileValue("profile_birthdate_label")}: ${birthday.ifBlank { "—" }}")
            }
        }
        ProfileError(state.error)
        ProfileFooter(strings.profileValue(if (state.busy) "common_saving" else "common_save_changes"),
            changed && first.isNotBlank() && last.isNotBlank() && !state.busy) {
            onSave(ProfileChange(
                firstName = first.trim().takeIf { it != user.firstName },
                lastName = last.trim().takeIf { it != user.lastName },
                birthDay = birthday.takeIf { it.isNotBlank() && it != user.birthDay.take(10) }
                    ?.let { "${it}T00:00:00Z" },
            ))
        }
        ProfileSecondaryFooter(strings.profileValue("common_cancel"), !state.busy, onDismiss)
    }
    if (picker) {
        val selected = runCatching { LocalDate.parse(birthday) }.getOrNull()
        val dateState = rememberDatePickerState(initialSelectedDateMillis = selected
            ?.atStartOfDay(ZoneOffset.UTC)?.toInstant()?.toEpochMilli(),
            yearRange = 1900..LocalDate.now().year)
        DatePickerDialog(onDismissRequest = { picker = false },
            confirmButton = { TextButton(onClick = {
                dateState.selectedDateMillis?.let { birthday = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString() }
                picker = false
            }) { Text(strings.profileValue("common_save_changes")) } },
            dismissButton = { TextButton(onClick = { picker = false }) { Text(strings.profileValue("common_cancel")) } }) {
            DatePicker(dateState)
        }
    }
}

@Composable
internal fun AvatarDialog(user: AuthProfile, state: ProfileUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onSave: (ProfileChange) -> Unit) {
    var selected by remember(user.userId) { mutableStateOf(user.imageUrl) }
    ProfileDialog(strings.profileValue("profile_avatar_choose_title"), state.busy, onDismiss) {
        Text(strings.profileValue("profile_avatar_choose_subtitle"), modifier = Modifier.padding(20.dp),
            color = profileMuted)
        if (state.loadingImages) Text(strings.profileValue("common_loading"), modifier = Modifier.padding(20.dp))
        else if (state.images.isEmpty()) Text(strings.profileValue("profile_avatar_empty_message"),
            modifier = Modifier.padding(20.dp), color = profileMuted)
        else LazyVerticalGrid(GridCells.Fixed(3), modifier = Modifier.heightIn(max = 340.dp)
            .padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(state.images, key = { it.publicId }) { image ->
                Box(Modifier.size(86.dp).clip(RoundedCornerShape(14.dp))
                    .background(if (image.url == selected) profileOrange.copy(alpha = .25f) else Color.White)
                    .clickable { selected = image.url }, contentAlignment = Alignment.Center) {
                    ProfileRemoteImage(image.url, 76.dp, RoundedCornerShape(12.dp))
                }
            }
        }
        ProfileError(state.error)
        ProfileFooter(strings.profileValue(if (state.busy) "common_saving" else "common_save_changes"),
            selected.isNotBlank() && !state.busy) { onSave(ProfileChange(imageUrl = selected)) }
        ProfileSecondaryFooter(strings.profileValue("common_cancel"), !state.busy, onDismiss)
    }
}

@Composable
internal fun LanguageDialog(user: AuthProfile, state: ProfileUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onSave: (String) -> Unit) {
    var selected by remember(user.userId) { mutableStateOf(user.language.orEmpty()) }
    LaunchedEffect(state.languages, user.language) {
        if (selected.isBlank()) selected = state.languages.firstOrNull { it.isDefault }?.prefix.orEmpty()
    }
    ProfileDialog(strings.profileValue("language_settings_title"), state.busy, onDismiss) {
        Text(strings.profileValue("language_settings_subtitle"), modifier = Modifier.padding(20.dp), color = profileMuted)
        if (state.loadingLanguages) Text(strings.profileValue("common_loading"), modifier = Modifier.padding(20.dp))
        else if (state.languages.isEmpty()) Text(strings.profileValue("language_settings_empty_message"),
            modifier = Modifier.padding(20.dp), color = profileMuted)
        else LazyVerticalGrid(GridCells.Fixed(3), modifier = Modifier.heightIn(max = 360.dp)
            .padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(state.languages, key = { it.prefix }) { language ->
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                    .background(if (selected.equals(language.prefix, true)) profileOrange.copy(alpha = .15f) else Color.White)
                    .clickable(enabled = language.isActive && !state.busy) { selected = language.prefix }
                    .padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    ProfileRemoteImage(language.image, 70.dp, RoundedCornerShape(14.dp))
                    Text(language.nativeName, maxLines = 1, fontSize = 13.sp,
                        color = if (language.isActive) profileInk else profileMuted)
                    if (!language.isActive) Text(strings.profileValue("language_settings_coming_soon_badge"),
                        fontSize = 10.sp, color = profileMuted)
                }
            }
        }
        ProfileError(state.error)
        ProfileFooter(strings.profileValue(if (state.busy) "common_saving" else "common_save_changes"),
            !state.busy && selected.isNotBlank() && !selected.equals(user.language, true) &&
                state.languages.any { it.prefix.equals(selected, true) && it.isActive }) { onSave(selected) }
        ProfileSecondaryFooter(strings.profileValue("common_cancel"), !state.busy, onDismiss)
    }
}

@Composable
internal fun PhoneManagementDialog(user: AuthProfile, strings: LocalizedText, onDismiss: () -> Unit) {
    var mode by remember { mutableStateOf("update") }
    var number by remember(user.userId) { mutableStateOf(user.phoneNumber) }
    var code by remember { mutableStateOf("") }
    var requested by remember { mutableStateOf(false) }
    var notice by remember { mutableStateOf(false) }
    ProfileDialog(strings.profileValue("profile_phone_management_title"), false, onDismiss) {
        Column(Modifier.heightIn(max = 430.dp).verticalScroll(rememberScrollState()).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("${strings.profileValue("profile_phone_label")}: ${user.phoneNumber.ifBlank { "—" }}", color = profileInk)
            Text(if (user.isVerifyPhone) strings.profileValue("common_verified") else strings.profileValue("common_not_verified"),
                color = if (user.isVerifyPhone) profileTeal else Color(0xFFB43E45))
            Text(strings.profileValue("profile_phone_backend_pending_notice"), color = profileMuted, fontSize = 13.sp)
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White)) {
                TextButton(onClick = { mode = "update" }, modifier = Modifier.weight(1f)) {
                    Text(strings.profileValue("profile_phone_update_tab"), color = if (mode == "update") profileOrange else profileMuted)
                }
                TextButton(onClick = { mode = "verify" }, modifier = Modifier.weight(1f)) {
                    Text(strings.profileValue("profile_phone_verify_tab"), color = if (mode == "verify") profileOrange else profileMuted)
                }
            }
            if (mode == "update") {
                OutlinedTextField(number, { number = it },
                    label = { Text(strings.profileValue("profile_phone_new_number_label")) },
                    modifier = Modifier.fillMaxWidth(), singleLine = true)
                ProfileFooter(strings.profileValue("profile_phone_update_button"),
                    number.trim().isNotEmpty() && number.trim() != user.phoneNumber) { notice = true }
            } else {
                Text(strings.profileValue("profile_phone_verification_instruction"), color = profileMuted)
                if (requested) {
                    OutlinedTextField(code, { code = it.filter(Char::isDigit).take(6) },
                        label = { Text(strings.profileValue("profile_phone_code_placeholder")) },
                        modifier = Modifier.fillMaxWidth(), singleLine = true)
                    ProfileFooter(strings.profileValue("profile_phone_verify_button"), code.length == 6) { notice = true }
                } else ProfileFooter(strings.profileValue("profile_phone_send_code_button"), user.phoneNumber.isNotBlank()) {
                    requested = true; notice = true
                }
            }
            if (notice) Text(strings.profileValue("profile_phone_backend_pending_toast"), color = profileTeal, fontSize = 13.sp)
        }
        ProfileSecondaryFooter(strings.profileValue("common_close"), true, onDismiss)
    }
}

@Composable
internal fun JoinHouseDialog(state: HouseUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onJoin: (String) -> Unit) {
    var code by remember { mutableStateOf("") }
    ProfileDialog(strings.profileValue("profile_house_join_title"), state.profileActionBusy, onDismiss) {
        Text(strings.profileValue("profile_house_join_subtitle"), modifier = Modifier.padding(20.dp), color = profileMuted)
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
            Text(strings.profileValue("profile_house_join_prompt"), color = profileMuted)
            OtpField(code, { code = it.filter { character -> character.isLetterOrDigit() }
                .uppercase().take(8) }, strings.profileValue("profile_house_join_code_accessibility_label"), false, 8)
            Text("${strings.profileValue("profile_house_join_code_hint")}   ${code.length}/8",
                color = profileMuted, fontSize = 12.sp)
        }
        ProfileError(state.profileError)
        ProfileFooter(strings.profileValue(if (state.profileActionBusy) "common_joining" else "profile_house_join_button"),
            code.matches(Regex("[A-Z0-9]{8}")) && !state.profileActionBusy) { onJoin(code) }
        ProfileSecondaryFooter(strings.profileValue("common_cancel"), !state.profileActionBusy, onDismiss)
    }
}

@Composable
internal fun HouseInfoDialog(
    houseId: String, state: HouseUiState, profile: ProfileUiState, strings: LocalizedText,
    onDismiss: () -> Unit, onRetry: (String) -> Unit, onInvite: (String) -> Unit,
    onLoadImages: (String) -> Unit, onSave: (String, String, Int, String) -> Unit,
    onRemoveMember: (String, String) -> Unit, onLeave: (String) -> Unit,
) {
    val info = state.info.takeIf { state.infoHouseId == houseId }
    val isOwner = info?.ownerId == state.userId
    var name by remember(houseId) { mutableStateOf("") }
    var limit by remember(houseId) { mutableIntStateOf(2) }
    var image by remember(houseId) { mutableStateOf("") }
    var leaveConfirmation by remember { mutableStateOf(false) }
    var removal by remember { mutableStateOf<HouseInfoMember?>(null) }
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    LaunchedEffect(info?.payload) {
        if (info != null) {
            name = info.houseName; limit = maxOf(2, info.houseMemberCount, info.houseMemberCountLimit)
            image = info.houseProfileImage
        }
    }
    LaunchedEffect(info?.ownerId) { if (isOwner) onLoadImages("house") }
    ProfileDialog(strings.profileValue("house_info_title"), state.profileActionBusy, onDismiss) {
        if (state.infoBusy) Text(strings.profileValue("house_info_loading"), modifier = Modifier.padding(24.dp))
        else if (info == null) Column(Modifier.padding(24.dp)) {
            ProfileError(state.profileError)
            ProfileFooter(strings.profileValue("common_retry"), true) { onRetry(houseId) }
        } else {
            Column(Modifier.heightIn(max = 570.dp).verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ProfileRemoteImage(info.houseProfileImage, 72.dp, RoundedCornerShape(20.dp), true)
                    Column(Modifier.padding(start = 14.dp)) {
                        Text(info.houseName, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = profileInk)
                        Text("${info.houseMemberCount} ${strings.profileValue("house_info_members_label")}", color = profileMuted)
                        if (isOwner) Text(strings.profileValue("house_info_owner_badge"), color = profileOrange)
                    }
                }
                if (isOwner) {
                    OutlinedTextField(name, { name = it.take(30) }, label = { Text(strings.profileValue("house_info_name_label")) },
                        modifier = Modifier.fillMaxWidth(), singleLine = true)
                    Text("${strings.profileValue("house_info_member_limit_label")}: $limit", color = profileMuted)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        TextButton(onClick = { if (limit > maxOf(2, info.houseMemberCount)) limit-- }) { Text("−") }
                        TextButton(onClick = { if (limit < maxOf(8, info.houseMemberCount)) limit++ }) { Text("+") }
                    }
                    Text(strings.profileValue("house_info_profile_image_title"), color = profileMuted)
                    if (profile.loadingImages) Text(strings.profileValue("common_loading"), color = profileMuted)
                    else if (profile.images.isEmpty()) Text(strings.profileValue("house_info_images_empty"), color = profileMuted)
                    val choices = (listOf(info.houseProfileImage) + profile.images.map { it.url })
                        .filter(String::isNotBlank).distinct()
                    LazyRow(Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(choices, key = { it }) { option ->
                            Box(Modifier.size(58.dp).clip(RoundedCornerShape(12.dp))
                                .background(if (option == image) profileOrange.copy(alpha = .2f) else Color.White)
                                .clickable { image = option }, contentAlignment = Alignment.Center) {
                                ProfileRemoteImage(option, 50.dp, RoundedCornerShape(10.dp), true)
                            }
                        }
                    }
                } else {
                    val typeKey = when (info.houseType) {
                        1 -> "create_house_type_student"
                        2 -> "create_house_type_shared"
                        3 -> "create_house_type_dorm"
                        else -> "house_info_type_unknown"
                    }
                    Text("${strings.profileValue("house_info_type_label")}: ${strings.profileValue(typeKey)}",
                        color = profileMuted)
                }
                Text(strings.profileValue("house_info_members_title"), fontWeight = FontWeight.Bold, color = profileInk)
                info.members.forEach { member ->
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        UserAvatar(HouseMember(member.userId, member.name, "", member.profileImage), 44.dp)
                        Column(Modifier.weight(1f).padding(start = 10.dp)) {
                            Text(member.name, color = profileInk)
                            if (member.isOwner) Text(strings.profileValue("house_info_owner_badge"), fontSize = 11.sp)
                            else if (member.userId == state.userId) Text(strings.profileValue("common_you"), fontSize = 11.sp)
                        }
                        if (isOwner && !member.isOwner && member.userId != state.userId) {
                            TextButton(onClick = { removal = member }, enabled = !state.profileActionBusy) {
                                Text(strings.profileValue("house_info_remove_member_button"))
                            }
                        }
                    }
                }
                Text(strings.profileValue("house_info_invite_title"), fontWeight = FontWeight.Bold, color = profileInk)
                if (state.invite == null) TextButton(onClick = { onInvite(houseId) }, enabled = !state.inviteBusy) {
                    Text(strings.profileValue(if (state.inviteBusy) "house_info_invite_generating"
                        else "house_info_invite_generate_button"))
                }
                state.invite?.let { invite ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(invite.code, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                        TextButton(onClick = { clipboard.setText(AnnotatedString(invite.code)) }) {
                            Text(strings.profileValue("common_copy"))
                        }
                    }
                    val duration = when {
                        invite.expiresInSeconds >= 3600 -> "${invite.expiresInSeconds / 3600}h ${(invite.expiresInSeconds % 3600) / 60}m"
                        invite.expiresInSeconds >= 60 -> "${invite.expiresInSeconds / 60}m"
                        else -> "${invite.expiresInSeconds.coerceAtLeast(0)}s"
                    }
                    Text(strings.profileValue("house_info_invite_expiration_template").replace("{duration}", duration),
                        color = profileMuted, fontSize = 12.sp)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        TextButton(onClick = { onInvite(houseId) }, enabled = !state.inviteBusy) {
                            Text(strings.profileValue("house_info_invite_refresh_button"))
                        }
                        TextButton(onClick = {
                            val message = strings.profileValue("invite_share_message_template")
                                .replace("{house_name}", info.houseName).replace("{invite_code}", invite.code)
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, message)
                            }
                            context.startActivity(Intent.createChooser(intent, null))
                        }) { Text(strings.profileValue("common_share")) }
                    }
                }
            }
            ProfileError(state.profileError ?: profile.error)
            if (isOwner) ProfileFooter(strings.profileValue(if (state.profileActionBusy) "common_saving" else "common_save_changes"),
                !state.profileActionBusy && name.isNotBlank() && limit >= maxOf(2, info.houseMemberCount) &&
                    (name.trim() != info.houseName || limit != info.houseMemberCountLimit || image != info.houseProfileImage)) {
                onSave(houseId, name, limit, image)
            }
            else if (info.members.any { it.userId == state.userId && !it.isOwner })
                ProfileFooter(strings.profileValue("house_info_leave_button"), !state.profileActionBusy) { leaveConfirmation = true }
        }
        ProfileSecondaryFooter(strings.profileValue("common_close"), !state.profileActionBusy, onDismiss)
    }
    if (leaveConfirmation) AlertDialog(onDismissRequest = { leaveConfirmation = false },
        title = { Text(strings.profileValue("house_info_leave_confirmation_title")) },
        confirmButton = { TextButton(onClick = { leaveConfirmation = false; onLeave(houseId); onDismiss() }) {
            Text(strings.profileValue("house_info_leave_button")) } },
        dismissButton = { TextButton(onClick = { leaveConfirmation = false }) { Text(strings.profileValue("common_cancel")) } })
    removal?.let { member -> AlertDialog(onDismissRequest = { removal = null },
        title = { Text(strings.profileValue("house_info_remove_confirmation_title")) },
        text = { Text(member.name) },
        confirmButton = { TextButton(onClick = { removal = null; onRemoveMember(houseId, member.userId) }) {
            Text(strings.profileValue("house_info_remove_member_button")) } },
        dismissButton = { TextButton(onClick = { removal = null }) { Text(strings.profileValue("common_cancel")) } }) }
}
