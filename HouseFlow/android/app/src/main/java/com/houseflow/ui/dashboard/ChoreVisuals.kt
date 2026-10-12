package com.houseflow.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.gradientForeground
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.Locale

/** `ChoreStatus` presentation (`iconName`, `color`, `localizationKey`) from ChoreDetailPopup.swift. */
internal enum class ChoreStatusUi(val raw: Int, val key: String, val color: Color, val icon: ImageVector) {
    DRAFT(0, "chore_status_draft", Color(0xFF8C8C99), HouseFlowIcons.docFill),
    PROGRESS(1, "chore_status_in_progress", Color(0xFFFF7A26), HouseFlowIcons.arrowRightCircleFill),
    IN_TEST(2, "chore_status_in_review", Color(0xFF8033D9), HouseFlowIcons.magnifyingGlass),
    COMPLETED(3, "chore_status_completed", Color(0xFF33BF66), HouseFlowIcons.checkmarkSealFill);

    /** SF `magnifyingglass.circle.fill` has no Material twin, so it is composed from a disc. */
    val isCircledGlyph: Boolean get() = this == IN_TEST

    val next: ChoreStatusUi? get() = when (this) {
        DRAFT -> PROGRESS
        PROGRESS -> IN_TEST
        IN_TEST, COMPLETED -> null
    }

    companion object {
        fun of(raw: Int): ChoreStatusUi = entries.firstOrNull { it.raw == raw } ?: DRAFT
    }
}

/** `ChoreLevel` presentation from NewChorePopup.swift. */
internal enum class ChoreLevelUi(val raw: Int, val key: String, val color: Color, val icon: ImageVector) {
    EASY(10, "chore_level_easy", Color(0xFF33BF66), HouseFlowIcons.leafFill),
    MEDIUM(20, "chore_level_medium", Color(0xFFFF7A26), HouseFlowIcons.flameFill),
    HARD(30, "chore_level_hard", Color(0xFFE63340), HouseFlowIcons.boltFill);

    companion object {
        fun of(raw: Int): ChoreLevelUi = entries.firstOrNull { it.raw == raw } ?: EASY
    }
}

/** Status symbol painted with [brush]; the circled variants keep the SF Symbols silhouette. */
@Composable
internal fun ChoreStatusGlyph(status: ChoreStatusUi, size: Dp, brush: Brush, modifier: Modifier = Modifier) {
    if (status.isCircledGlyph) {
        Box(modifier.size(size * .86f).background(brush, CircleShape), contentAlignment = Alignment.Center) {
            Icon(status.icon, null, Modifier.size(size * .54f), tint = Color.White)
        }
    } else {
        Icon(status.icon, null, modifier.size(size).gradientForeground(brush), tint = Color.White)
    }
}

@Composable
internal fun ChoreStatusGlyph(status: ChoreStatusUi, size: Dp, tint: Color, modifier: Modifier = Modifier) =
    ChoreStatusGlyph(status, size, SolidColor(tint), modifier)

/** `HouseFlowDateFormatter.dueLabel`. */
internal enum class DueLabel(val key: String, val color: Color) {
    TODAY("common_today", HouseFlowColors.warning),
    OVERDUE("common_overdue", HouseFlowColors.error),
    THIS_WEEK("common_this_week", HouseFlowColors.primary),
    UPCOMING("common_upcoming", HouseFlowColors.primary),
}

internal fun parseApiDate(value: String?): ZonedDateTime? = value?.takeIf(String::isNotBlank)?.let {
    runCatching { OffsetDateTime.parse(it).atZoneSameInstant(ZoneId.systemDefault()) }.getOrNull()
}

internal fun dueLabel(value: String, now: ZonedDateTime = ZonedDateTime.now()): DueLabel {
    val date = parseApiDate(value) ?: return DueLabel.UPCOMING
    if (date.toLocalDate() == now.toLocalDate()) return DueLabel.TODAY
    if (date.isBefore(now)) return DueLabel.OVERDUE
    val week = WeekFields.of(Locale.getDefault())
    val sameWeek = date.get(week.weekOfWeekBasedYear()) == now.get(week.weekOfWeekBasedYear()) &&
        ChronoUnit.DAYS.between(now.toLocalDate(), date.toLocalDate()) < 7
    return if (sameWeek) DueLabel.THIS_WEEK else DueLabel.UPCOMING
}

/** `HouseFlowDateFormatter.displayDate`: medium date in the device zone, or null. */
internal fun displayApiDate(value: String?): String? =
    parseApiDate(value)?.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))

/** `date.formatted(date: .abbreviated, time: .shortened)`. */
internal fun displayApiDateTime(value: String): String =
    parseApiDate(value)?.format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)) ?: value

internal fun LocalizedText.dueText(value: String): String =
    displayApiDate(value) ?: get(dueLabel(value).key)
