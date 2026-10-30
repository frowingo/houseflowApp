package com.fauscrew.ui.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausBadge
import com.fauscrew.ui.components.FausButtonGradient
import com.fauscrew.ui.components.FausGradientIcon
import com.fauscrew.ui.components.GraphicalCalendar
import com.fauscrew.ui.components.fausHeroBackground
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow
import com.fauscrew.viewmodel.AuthUiState
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

private val accentOrange: Color @Composable @ReadOnlyComposable get() = FausCrewColors.accentOrange
private val accentInk: Color @Composable @ReadOnlyComposable get() = FausCrewColors.accentOrangeInk
private val confettiPeach = Color(0xFFFFD3A8)

/** `BirthdaySetupView`: orange → berry hero with confetti, graphical calendar card and Save and continue. */
@Composable
internal fun BirthdaySetupScreen(state: AuthUiState, strings: LocalizedText, onDate: (LocalDate) -> Unit, onSave: () -> Unit) {
    val today = remember { LocalDate.now() }
    val range = remember(today) { today.minusYears(120)..today }
    val locale = remember(strings.prefix) { strings.prefix?.let(Locale::forLanguageTag) ?: Locale.getDefault() }
    Column(
        Modifier.fillMaxSize().background(FausCrewColors.pageBackground).verticalScroll(rememberScrollState())
            .navigationBarsPadding(),
    ) {
        BirthdayHero(strings)
        Column(
            Modifier.fillMaxWidth().offset(y = (-28).dp).padding(horizontal = Spacing.xl)
                .softShadow(FausCrewColors.deepBerry.copy(alpha = .12f), 22.dp, y = 10.dp, shape = RoundedCornerShape(Radius.xxl))
                .clip(RoundedCornerShape(Radius.xxl)).background(FausCrewColors.background).padding(Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.xl),
        ) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    FausGradientIcon(FausCrewIcons.calendar, 20.dp)
                    Text(strings.get("birthday_setup_date_label", "Date of birth"), fontSize = 17.sp,
                        fontWeight = FontWeight.Bold, color = FausCrewColors.textPrimary)
                }
                Text(state.birthday.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)),
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = accentInk)
            }
            GraphicalCalendar(state.birthday, onDate, range, accentOrange, Modifier.fillMaxWidth(), locale)
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(accentOrange.copy(alpha = .08f))
                    .padding(Spacing.md),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Icon(FausCrewIcons.lockShield, null, Modifier.size(18.dp), tint = accentInk)
                Text(strings.get("birthday_setup_privacy_note", "Your birthday is saved securely as part of your profile."),
                    Modifier.weight(1f), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = FausCrewColors.textSecondary)
            }
            AnimatedVisibility(state.error != null, enter = fadeIn() + slideInVertically(), exit = fadeOut()) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(FausCrewColors.error.copy(alpha = .09f))
                        .padding(Spacing.md),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Icon(FausCrewIcons.exclamationmarkTriangleFill, null, Modifier.size(18.dp), tint = FausCrewColors.error)
                    val message = state.error.orEmpty()
                    Text(strings.values[message] ?: message, Modifier.weight(1f), fontSize = 13.sp,
                        fontWeight = FontWeight.Medium, color = FausCrewColors.error)
                }
            }
            SaveButton(strings, state.busy, onSave)
        }
    }
}

@Composable
private fun BirthdayHero(strings: LocalizedText) {
    BoxWithConstraints(Modifier.fillMaxWidth().fausHeroBackground().statusBarsPadding().heightIn(min = 280.dp)) {
        val width = maxWidth
        Confetti(width * .13f, 58.dp, 12.dp, .32f)
        Confetti(width * .82f, 50.dp, 7.dp, .7f, confettiPeach)
        Confetti(width * .91f, 154.dp, 16.dp, .18f)
        Sparkle(FausCrewIcons.sparkles, width * .18f, 178.dp, 22.dp, .34f)
        Sparkle(FausCrewIcons.starFill, width * .78f, 210.dp, 14.dp, .55f, confettiPeach)
        Column(
            Modifier.fillMaxWidth().padding(top = Spacing.xl, bottom = 58.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            FausBadge(80.dp) { FausGradientIcon(FausCrewIcons.birthdayCakeFill, 40.dp) }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text(strings.get("birthday_setup_title", "When is your birthday?"), Modifier.padding(horizontal = Spacing.xl),
                    fontSize = 27.sp, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
                Text(strings.get("birthday_setup_subtitle", "Add your date of birth to complete your profile."),
                    Modifier.padding(horizontal = Spacing.xxxl), fontSize = 15.sp, fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = .82f), textAlign = TextAlign.Center)
            }
        }
    }
}

@Composable
private fun Confetti(x: Dp, y: Dp, size: Dp, alpha: Float, color: Color = Color.White) {
    Box(Modifier.offset(x - size / 2, y - size / 2).size(size).background(color.copy(alpha = alpha), CircleShape))
}

@Composable
private fun Sparkle(icon: ImageVector, x: Dp, y: Dp, size: Dp, alpha: Float, color: Color = Color.White) {
    Icon(icon, null, Modifier.offset(x - size / 2, y - size / 2).size(size), tint = color.copy(alpha = alpha))
}

@Composable
private fun SaveButton(strings: LocalizedText, busy: Boolean, onSave: () -> Unit) {
    val shape = RoundedCornerShape(Radius.xl)
    Box(
        Modifier.fillMaxWidth().height(54.dp)
            .softShadow(if (busy) Color.Transparent else FausCrewColors.deepBerry.copy(alpha = .28f), 12.dp, y = 6.dp, shape = shape)
            .clip(shape).background(if (busy) SolidColor(FausCrewColors.systemGray4) else FausButtonGradient)
            .clickable(enabled = !busy, role = Role.Button, onClick = onSave),
        contentAlignment = Alignment.Center,
    ) {
        if (busy) {
            CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.dp)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text(strings.get("birthday_setup_continue_button", "Save and continue"), fontSize = 17.sp,
                    fontWeight = FontWeight.Bold, color = Color.White)
                Icon(FausCrewIcons.arrowRight, null, Modifier.size(20.dp), tint = Color.White)
            }
        }
    }
}
