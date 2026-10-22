package com.houseflow.ui.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.houseflow.platform.AuthProfile
import com.houseflow.platform.LocalizedText
import com.houseflow.platform.ProfileChange
import com.houseflow.platform.SocialProvider
import com.houseflow.ui.auth.social
import com.houseflow.viewmodel.AccountUiState
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.dashboard.displayApiDate
import com.houseflow.ui.main.TabBarClearance
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.entrance
import com.houseflow.ui.theme.rememberEntrance
import com.houseflow.viewmodel.HouseUiState
import com.houseflow.viewmodel.ProfileUiState

/** iOS ProfileView fallbacks for keys absent from the supplied 415-key EN snapshot. */
internal fun LocalizedText.profileValue(key: String): String = values[key] ?: PROFILE_FALLBACKS[key] ?: key

private val PROFILE_FALLBACKS = mapOf(
    "common_loading" to "Loading…",
    "common_retry" to "Retry",
    "common_verified" to "Verified",
    "common_not_verified" to "Not verified",
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
    "profile_account_information_title" to "Account Information",
    "profile_email_label" to "Email",
    "profile_logout_label" to "Log out",
    "profile_phone_manage_accessibility_hint" to "Opens phone update and verification options.",
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
    data object LoginMethods : ProfilePopup
    data object DeleteAccount : ProfilePopup
    data object Join : ProfilePopup
    data class House(val id: String) : ProfilePopup
}

/** `ProfileView`: hero, account, houses, personal info and settings cards plus their popups. */
@Composable
internal fun ProfileScreen(
    user: AuthProfile, house: HouseUiState, profile: ProfileUiState,
    strings: LocalizedText, onLogout: () -> Unit,
    onUpdateProfile: (ProfileChange) -> Unit, onLoadImages: (String) -> Unit,
    onLoadLanguages: () -> Unit, onSaveLanguage: (String) -> Unit,
    onClearProfileError: () -> Unit, onJoin: (String) -> Unit,
    onOpenHouse: (String) -> Unit, onCloseHouse: () -> Unit,
    onInvite: (String) -> Unit, onUpdateHouse: (String, String, Int, String) -> Unit,
    onRemoveMember: (String, String) -> Unit, onLeave: (String) -> Unit,
    onClearHouseError: () -> Unit,
    onOverlayChange: (Boolean) -> Unit = {},
    accountState: AccountUiState = AccountUiState(),
    socialProviders: List<SocialProvider> = emptyList(),
    onOpenAccount: () -> Unit = {},
    onLinkProvider: (SocialProvider) -> Unit = {},
    onUnlinkProvider: (SocialProvider) -> Unit = {},
    onRequestPasswordCode: () -> Unit = {},
    onSetPassword: (String, String) -> Unit = { _, _ -> },
    onDeleteAccount: () -> Unit = {},
) {
    var popup by remember { mutableStateOf<ProfilePopup?>(null) }
    var openedAt by remember { mutableLongStateOf(0) }
    var houseOpenedAt by remember { mutableLongStateOf(0) }
    fun open(next: ProfilePopup) {
        onClearProfileError(); onClearHouseError()
        openedAt = profile.savedSerial
        houseOpenedAt = house.profileActionSerial
        popup = next
        when (next) {
            ProfilePopup.Avatar -> onLoadImages("profile/superhero")
            ProfilePopup.Language -> onLoadLanguages()
            is ProfilePopup.House -> onOpenHouse(next.id)
            ProfilePopup.LoginMethods, ProfilePopup.DeleteAccount -> onOpenAccount()
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
    val overlayCallback by rememberUpdatedState(onOverlayChange)
    LaunchedEffect(popup != null) { overlayCallback(popup != null) }
    DisposableEffect(Unit) { onDispose { overlayCallback(false) } }

    val hero = rememberEntrance(50)
    val account = rememberEntrance(120)
    val houses = rememberEntrance(200)
    val personal = rememberEntrance(280)
    val settings = rememberEntrance(360)
    val emptyValue = strings.get("common_empty_value", "—")
    val verified = strings.profileValue("common_verified")
    val notVerified = strings.profileValue("common_not_verified")

    Box(Modifier.fillMaxSize().mainScreenBackground()) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.xl),
        ) {
            ProfileHeroSection(
                imageUrl = user.imageUrl,
                initials = (user.firstName.take(1) + user.lastName.take(1)).uppercase().ifBlank { "?" },
                fullName = listOf(user.firstName, user.lastName).filter(String::isNotBlank).joinToString(" ").ifBlank { emptyValue },
                avatarDescription = strings.get("profile_avatar_choose_title"),
                onAvatarTap = { open(ProfilePopup.Avatar) },
                modifier = Modifier.padding(horizontal = Spacing.lg).entrance(hero, 12.dp),
            )
            Column(Modifier.padding(horizontal = Spacing.lg), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                ProfileModernCard(HouseFlowIcons.personTextRectangleFill, ProfileTints.account,
                    strings.profileValue("profile_account_information_title"),
                    listOf(ProfileTints.account.copy(alpha = .06f), Color.Transparent), Modifier.entrance(account, 24.dp)) {
                    ProfileCommunicationRow(HouseFlowIcons.envelopeFill, ProfileTints.account,
                        strings.profileValue("profile_email_label"), user.email.ifBlank { emptyValue },
                        user.isVerifyEmail, if (user.isVerifyEmail) verified else notVerified)
                    ProfileCardDivider()
                    ProfileCommunicationRow(HouseFlowIcons.phoneFill, ProfileTints.phone,
                        strings.profileValue("profile_phone_label"), user.phoneNumber.ifBlank { emptyValue },
                        user.isVerifyPhone, if (user.isVerifyPhone) verified else notVerified,
                        onVerificationTap = { open(ProfilePopup.Phone) })
                    ProfileCardDivider()
                    ProfileInfoRow(HouseFlowIcons.calendar, ProfileTints.memberSince,
                        strings.profileValue("profile_member_since_label"), displayApiDate(user.createdOn) ?: emptyValue)
                }
                ProfileHouseInformationCard(
                    title = strings.profileValue("profile_house_information_title"),
                    houses = house.houses,
                    emptyMessage = strings.profileValue("profile_house_information_empty"),
                    viewTitle = strings.profileValue("profile_house_information_view_button"),
                    joinTitle = strings.profileValue("profile_house_join_title"),
                    joinSubtitle = strings.profileValue("profile_house_join_row_subtitle"),
                    onSelect = { open(ProfilePopup.House(it.id)) },
                    onJoin = { open(ProfilePopup.Join) },
                    modifier = Modifier.entrance(houses, 24.dp),
                )
                ProfileModernCard(
                    HouseFlowIcons.personCropCircleFill, ProfileTints.personalTeal, strings.profileValue("profile_personal_info_title"),
                    listOf(ProfileTints.personalTeal.copy(alpha = .065f), Color.Transparent, ProfileTints.personalSage.copy(alpha = .04f)),
                    Modifier.entrance(personal, 24.dp), uppercaseTitle = false,
                    borderColors = listOf(ProfileTints.personalTeal.copy(alpha = .3f), ProfileTints.personalSage.copy(alpha = .12f)),
                    trailing = { ProfileEditButton(strings.profileValue("profile_edit_button")) { open(ProfilePopup.Edit) } },
                ) {
                    ProfileInfoRow(HouseFlowIcons.personFill, ProfileTints.personalTeal,
                        strings.profileValue("profile_first_name_label"), user.firstName.ifBlank { emptyValue })
                    ProfileCardDivider()
                    ProfileInfoRow(HouseFlowIcons.personFill, ProfileTints.personalSage,
                        strings.profileValue("profile_last_name_label"), user.lastName.ifBlank { emptyValue })
                    ProfileCardDivider()
                    ProfileInfoRow(HouseFlowIcons.birthdayCakeFill, ProfileTints.personalSlate,
                        strings.profileValue("profile_birthdate_label"), displayApiDate(user.birthDay) ?: emptyValue)
                }
                ProfileModernCard(HouseFlowIcons.gearshapeFill, HouseFlowColors.textTertiary,
                    strings.profileValue("profile_settings_title"), listOf(Color.Gray.copy(alpha = .04f), Color.Transparent),
                    Modifier.entrance(settings, 24.dp)) {
                    ProfileSettingsRow(HouseFlowIcons.bellBadgeFill, ProfileTints.notifications, strings.profileValue("profile_notifications_label"))
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.lockShieldFill, ProfileTints.privacy, strings.profileValue("profile_privacy_security_label"))
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.questionmarkCircleFill, ProfileTints.memberSince, strings.profileValue("profile_help_support_label"))
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.globeFill, ProfileTints.account, strings.profileValue("profile_language_settings_label")) {
                        open(ProfilePopup.Language)
                    }
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.infoCircleFill, HouseFlowColors.textTertiary, strings.profileValue("profile_about_label")) {
                        open(ProfilePopup.About)
                    }
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.lockShieldFill, ProfileTints.personalTeal,
                        strings.social("profile_login_methods_label", "Giriş yöntemleri", "Sign-in methods")) {
                        open(ProfilePopup.LoginMethods)
                    }
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.logout, HouseFlowColors.error, strings.profileValue("profile_logout_label")) {
                        open(ProfilePopup.Logout)
                    }
                    ProfileCardDivider()
                    ProfileSettingsRow(HouseFlowIcons.exclamationmarkTriangleFill, HouseFlowColors.error,
                        strings.social("profile_delete_account_label", "Hesabı sil", "Delete account")) {
                        open(ProfilePopup.DeleteAccount)
                    }
                }
            }
            Spacer(Modifier.navigationBarsPadding().height(TabBarClearance - Spacing.xxxl))
        }
    }

    when (val shown = popup) {
        ProfilePopup.Edit -> EditProfileDialog(user, profile, strings, ::close, onUpdateProfile)
        ProfilePopup.Avatar -> AvatarDialog(user, profile, strings, ::close, onUpdateProfile)
        ProfilePopup.Language -> LanguageDialog(user, profile, strings, ::close, onSaveLanguage)
        ProfilePopup.About -> AboutDialog(strings, ::close)
        ProfilePopup.Phone -> PhoneManagementDialog(user, strings, ::close)
        ProfilePopup.Logout -> LogoutConfirmationPopup(strings, onConfirm = { close(); onLogout() }, onCancel = ::close)
        ProfilePopup.LoginMethods -> LoginMethodsDialog(user, accountState, socialProviders, strings, ::close,
            onLinkProvider, onUnlinkProvider, onRequestPasswordCode, onSetPassword)
        ProfilePopup.DeleteAccount -> DeleteAccountDialog(accountState, strings, ::close, onDeleteAccount)
        ProfilePopup.Join -> JoinHouseDialog(house, strings, ::close, onJoin)
        is ProfilePopup.House -> HouseInfoDialog(shown.id, house, profile, strings, ::close,
            onOpenHouse, onInvite, onLoadImages, onUpdateHouse, onRemoveMember, onLeave)
        null -> Unit
    }
}
