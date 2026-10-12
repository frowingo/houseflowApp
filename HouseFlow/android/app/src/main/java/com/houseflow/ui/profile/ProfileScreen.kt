package com.houseflow.ui.profile

import android.graphics.Bitmap
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.houseflow.platform.AuthProfile
import com.houseflow.platform.HouseSummary
import com.houseflow.platform.LocalizedText
import com.houseflow.platform.ProfileChange
import com.houseflow.ui.dashboard.MemberAvatar
import com.houseflow.ui.dashboard.AvatarImages
import com.houseflow.platform.HouseMember
import com.houseflow.viewmodel.HouseUiState
import com.houseflow.viewmodel.ProfileUiState
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

internal val profilePage = Color(0xFFF7F7FA)
internal val profileInk = Color(0xFF1C1C1E)
internal val profileMuted = Color(0xFF6B6B73)
internal val profileOrange = Color(0xFFFF7A26)
internal val profilePurple = Color(0xFF6B45AB)
internal val profileTeal = Color(0xFF338186)
internal val profileHero = Brush.linearGradient(listOf(Color(0xFFF59E59), Color(0xFFED7D40), Color(0xFF75304D)))

/** iOS ProfileView fallbacks for keys absent from the supplied 415-key EN snapshot. */
internal fun LocalizedText.profileValue(key: String): String = values[key] ?: PROFILE_FALLBACKS[key] ?: key

private val PROFILE_FALLBACKS = mapOf(
    "common_loading" to "Loading…",
    "common_retry" to "Retry",
    "house_info_images_empty" to "No house images are available.",
    "house_info_invite_expiration_template" to "Expires in {duration}",
    "house_info_invite_generate_button" to "Create invite code",
    "house_info_invite_generating" to "Creating code…",
    "house_info_invite_refresh_button" to "New code",
    "house_info_invite_title" to "Invite housemates",
    "house_info_leave_button" to "Leave house",
    "house_info_leave_confirmation_title" to "Leave this house?",
    "house_info_loading" to "Loading house information…",
    "house_info_member_limit_label" to "Member limit",
    "house_info_members_label" to "Members",
    "house_info_members_title" to "Members",
    "house_info_name_label" to "House name",
    "house_info_owner_badge" to "Owner",
    "house_info_profile_image_title" to "House profile image",
    "house_info_remove_confirmation_title" to "Remove this member?",
    "house_info_remove_member_button" to "Remove member",
    "house_info_title" to "House Information",
    "house_info_type_label" to "House type",
    "house_info_type_unknown" to "House",
    "profile_house_information_empty" to "No houses are connected to this account.",
    "profile_house_information_title" to "House Informations",
    "profile_house_information_view_button" to "View",
    "profile_house_join_code_accessibility_label" to "House invite code",
    "profile_house_join_code_hint" to "Letters and numbers only",
    "profile_house_join_prompt" to "Enter the 8-character invite code shared with you.",
    "profile_house_join_row_subtitle" to "Enter an 8-character invite code",
    "profile_house_join_subtitle" to "Use an invitation code",
    "profile_house_join_title" to "Join a house",
)

private sealed interface ProfilePopup {
    data object Edit : ProfilePopup
    data object Avatar : ProfilePopup
    data object Language : ProfilePopup
    data object About : ProfilePopup
    data object Phone : ProfilePopup
    data object Logout : ProfilePopup
    data object Join : ProfilePopup
    data class House(val id: String) : ProfilePopup
}

@Composable
internal fun ProfileScreen(
    user: AuthProfile, house: HouseUiState, profile: ProfileUiState,
    strings: LocalizedText, onHome: () -> Unit, onLogout: () -> Unit,
    onUpdateProfile: (ProfileChange) -> Unit, onLoadImages: (String) -> Unit,
    onLoadLanguages: () -> Unit, onSaveLanguage: (String) -> Unit,
    onClearProfileError: () -> Unit, onJoin: (String) -> Unit,
    onOpenHouse: (String) -> Unit, onCloseHouse: () -> Unit,
    onInvite: (String) -> Unit, onUpdateHouse: (String, String, Int, String) -> Unit,
    onRemoveMember: (String, String) -> Unit, onLeave: (String) -> Unit,
    onClearHouseError: () -> Unit,
) {
    var popup by remember { mutableStateOf<ProfilePopup?>(null) }
    var openedAt by remember { androidx.compose.runtime.mutableLongStateOf(0) }
    var houseOpenedAt by remember { androidx.compose.runtime.mutableLongStateOf(0) }
    fun open(next: ProfilePopup) {
        onClearProfileError(); onClearHouseError()
        openedAt = profile.savedSerial
        houseOpenedAt = house.profileActionSerial
        popup = next
        when (next) {
            ProfilePopup.Avatar -> onLoadImages("profile/superhero")
            ProfilePopup.Language -> onLoadLanguages()
            is ProfilePopup.House -> onOpenHouse(next.id)
            else -> Unit
        }
    }
    fun close() {
        if (popup is ProfilePopup.House) onCloseHouse()
        popup = null
    }
    LaunchedEffect(profile.savedSerial) {
        if (profile.savedSerial > openedAt && popup in listOf(ProfilePopup.Edit, ProfilePopup.Avatar)) close()
    }
    LaunchedEffect(house.profileActionSerial) {
        if (house.profileActionSerial > houseOpenedAt) {
            when (popup) {
                ProfilePopup.Join -> close()
                is ProfilePopup.House -> if (house.profileActionKind == "update") close()
                    else houseOpenedAt = house.profileActionSerial
                else -> Unit
            }
        }
    }
    Box(Modifier.fillMaxSize().background(profilePage).statusBarsPadding().navigationBarsPadding()) {
        Column(Modifier.fillMaxSize()) {
            Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp)) {
                ProfileHero(user, onClick = { open(ProfilePopup.Avatar) })
                ProfileCard(strings.profileValue("profile_account_information_title"), profileTeal) {
                    ProfileRow(strings.profileValue("profile_email_label"), user.email,
                        if (user.isVerifyEmail) strings.profileValue("common_verified") else strings.profileValue("common_not_verified"))
                    ProfileRow(strings.profileValue("profile_phone_label"), user.phoneNumber.ifBlank { "—" },
                        if (user.isVerifyPhone) strings.profileValue("common_verified") else strings.profileValue("common_not_verified"),
                        onClick = { open(ProfilePopup.Phone) })
                    ProfileRow(strings.profileValue("profile_member_since_label"), displayProfileDate(user.createdOn))
                }
                ProfileCard(strings.profileValue("profile_house_information_title"), profilePurple) {
                    if (house.houses.isEmpty()) ProfileRow(strings.profileValue("profile_house_information_empty"), "")
                    house.houses.forEach { item ->
                        Row(Modifier.fillMaxWidth().clickable { open(ProfilePopup.House(item.id)) }
                            .padding(horizontal = 16.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
                            ProfileRemoteImage(item.profileImage, 44.dp, RoundedCornerShape(13.dp), true)
                            Text(item.name, modifier = Modifier.weight(1f).padding(start = 12.dp),
                                color = profileInk, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
                            Text(strings.profileValue("profile_house_information_view_button"),
                                color = profilePurple, fontSize = 12.sp)
                        }
                    }
                    ProfileRow(strings.profileValue("profile_house_join_title"),
                        strings.profileValue("profile_house_join_row_subtitle"), onClick = { open(ProfilePopup.Join) })
                }
                ProfileCard(strings.profileValue("profile_personal_info_title"), profileTeal,
                    action = { TextButton(onClick = { open(ProfilePopup.Edit) }) { Text(strings.profileValue("profile_edit_button")) } }) {
                    ProfileRow(strings.profileValue("profile_first_name_label"), user.firstName)
                    ProfileRow(strings.profileValue("profile_last_name_label"), user.lastName)
                    ProfileRow(strings.profileValue("profile_birthdate_label"), displayProfileDate(user.birthDay))
                }
                ProfileCard(strings.profileValue("profile_settings_title"), profileMuted) {
                    ProfileRow(strings.profileValue("profile_notifications_label"), "")
                    ProfileRow(strings.profileValue("profile_privacy_security_label"), "")
                    ProfileRow(strings.profileValue("profile_help_support_label"), "")
                    ProfileRow(strings.profileValue("profile_language_settings_label"), "›", onClick = { open(ProfilePopup.Language) })
                    ProfileRow(strings.profileValue("profile_about_label"), "›", onClick = { open(ProfilePopup.About) })
                    ProfileRow(strings.profileValue("profile_logout_label"), "›", onClick = { open(ProfilePopup.Logout) })
                }
                Spacer(Modifier.height(12.dp))
            }
            ProfileTabBar(strings, onHome)
        }
    }
    when (val shown = popup) {
        ProfilePopup.Edit -> EditProfileDialog(user, profile, strings, ::close, onUpdateProfile)
        ProfilePopup.Avatar -> AvatarDialog(user, profile, strings, ::close, onUpdateProfile)
        ProfilePopup.Language -> LanguageDialog(user, profile, strings, ::close, onSaveLanguage)
        ProfilePopup.About -> ProfileDialog(strings.profileValue("profile_about_label"), false, ::close) {
            Text(strings.profileValue("profile_about_quote"), color = profileOrange, textAlign = TextAlign.Center,
                fontSize = 19.sp, fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth().padding(24.dp))
            Text(strings.profileValue("profile_about_made_with_love"), color = profileMuted,
                modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp), textAlign = TextAlign.Center)
            ProfileFooter(strings.profileValue("profile_about_close_button"), true, ::close)
        }
        ProfilePopup.Phone -> PhoneManagementDialog(user, strings, ::close)
        ProfilePopup.Logout -> AlertDialog(onDismissRequest = ::close,
            title = { Text(strings.profileValue("logout_confirm_title")) },
            text = { Text(strings.profileValue("logout_confirm_message")) },
            confirmButton = { TextButton(onClick = { close(); onLogout() }) { Text(strings.profileValue("logout_confirm_button")) } },
            dismissButton = { TextButton(onClick = ::close) { Text(strings.profileValue("common_cancel")) } })
        ProfilePopup.Join -> JoinHouseDialog(house, strings, ::close, onJoin)
        is ProfilePopup.House -> HouseInfoDialog(shown.id, house, profile, strings, ::close,
            onOpenHouse, onInvite, onLoadImages, onUpdateHouse, onRemoveMember, onLeave)
        null -> Unit
    }
}

@Composable private fun ProfileHero(user: AuthProfile, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).height(138.dp)
        .clip(RoundedCornerShape(20.dp)).background(profileHero).padding(horizontal = 24.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(Modifier.size(82.dp).clip(CircleShape).background(Color.White).clickable(onClick = onClick),
            contentAlignment = Alignment.Center) {
            MemberAvatar(HouseMember(user.userId, user.firstName, user.lastName, user.imageUrl), 74.dp)
        }
        Text(listOf(user.firstName, user.lastName).filter(String::isNotBlank).joinToString(" "),
            fontSize = 23.sp, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1)
    }
}

@Composable internal fun ProfileRemoteImage(url: String, size: androidx.compose.ui.unit.Dp,
    shape: Shape, isHouse: Boolean = false) {
    var bitmap by remember(url) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(url) {
        bitmap = url.takeIf { it.startsWith("https://") || it.startsWith("http://") }
            ?.let { AvatarImages.load(it) }
    }
    Box(Modifier.size(size).clip(shape).background(profilePurple.copy(alpha = .11f)),
        contentAlignment = Alignment.Center) {
        if (bitmap != null) Image(bitmap!!.asImageBitmap(), null, Modifier.size(size), contentScale = ContentScale.Crop)
        else Icon(if (isHouse) Icons.Filled.Home else Icons.Filled.Person, null,
            tint = profilePurple, modifier = Modifier.size(size / 2))
    }
}

@Composable private fun ProfileCard(title: String, tint: Color, action: (@Composable () -> Unit)? = null,
    content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).clip(RoundedCornerShape(20.dp))
        .background(Color.White)) {
        Row(Modifier.fillMaxWidth().background(tint.copy(alpha = .07f)).padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically) {
            Icon(if (tint == profilePurple) Icons.Filled.Home else Icons.Filled.Person, null,
                tint = tint, modifier = Modifier.size(24.dp))
            Text(title, modifier = Modifier.weight(1f).padding(start = 8.dp),
                fontSize = 11.sp, fontWeight = FontWeight.Bold, color = profileMuted)
            action?.invoke()
        }
        content()
    }
}

@Composable private fun ProfileRow(label: String, value: String, badge: String? = null,
    onClick: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
        .padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label, fontSize = 13.sp, color = profileMuted)
            if (value.isNotBlank()) Text(value, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = profileInk, maxLines = 2)
            if (badge != null) Text(badge, fontSize = 11.sp, color = profileTeal)
        }
        if (onClick != null) Text("›", color = profilePurple, fontSize = 22.sp)
    }
}

@Composable private fun ProfileTabBar(strings: LocalizedText, onHome: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 12.dp)
        .clip(RoundedCornerShape(28.dp)).background(profileHero).padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Person, null, Modifier.size(26.dp), tint = Color.White)
            Text(strings.profileValue("tab_profile"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
        }
        Column(Modifier.clickable(onClick = onHome), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.Home, null, Modifier.size(24.dp), tint = Color.White.copy(alpha = .7f))
            Text(strings.profileValue("tab_home"), fontSize = 12.sp, color = Color.White.copy(alpha = .7f))
        }
        Text(strings.profileValue("tab_games"), fontSize = 12.sp, color = Color.White.copy(alpha = .55f))
    }
}

@Composable internal fun ProfileDialog(title: String, busy: Boolean, onDismiss: () -> Unit,
    content: @Composable () -> Unit) {
    Dialog(onDismissRequest = { if (!busy) onDismiss() },
        properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(24.dp)).background(profilePage)) {
            Row(Modifier.fillMaxWidth().background(profileHero).padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text(title, modifier = Modifier.weight(1f), color = Color.White,
                    fontSize = 15.sp, fontWeight = FontWeight.Bold)
                TextButton(onClick = onDismiss, enabled = !busy) {
                    Icon(Icons.Filled.Close, contentDescription = title, tint = Color.White)
                }
            }
            content()
        }
    }
}

@Composable internal fun ProfileFooter(label: String, enabled: Boolean, onClick: () -> Unit) {
    Button(onClick = onClick, enabled = enabled,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp).height(48.dp),
        shape = RoundedCornerShape(12.dp)) { Text(label) }
}

@Composable internal fun ProfileError(message: String?) {
    if (!message.isNullOrBlank()) Text(message, color = Color(0xFFB43E45), fontSize = 13.sp,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp))
}

internal fun displayProfileDate(value: String): String {
    if (value.isBlank()) return "—"
    return runCatching {
        OffsetDateTime.parse(value).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
    }.getOrDefault(value.take(10))
}
