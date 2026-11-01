package com.fauscrew.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import com.fauscrew.platform.CHORE_STATUS_FAILED
import com.fauscrew.platform.ChoreFailureReason
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.auth.social
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.gradientForeground
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.Locale

/**
 * `ChoreStatus` presentation (`iconName`, `color`, `localizationKey`) from ChoreDetailPopup.swift,
 * with the built-in Turkish/English copy for when the localization service has no value yet.
 */
internal enum class ChoreStatusUi(val raw: Int, val key: String, val icon: ImageVector, val tr: String, val en: String) {
    DRAFT(0, "chore_status_draft", FausCrewIcons.docFill, "Taslak", "Draft"),
    PROGRESS(1, "chore_status_in_progress", FausCrewIcons.arrowRightCircleFill, "Devam ediyor", "In progress"),
    IN_TEST(2, "chore_status_in_review", FausCrewIcons.magnifyingGlass, "İncelemede", "In review"),
    COMPLETED(3, "chore_status_completed", FausCrewIcons.checkmarkSealFill, "Tamamlandı", "Completed"),
    /** Terminal and backend-owned: a third rejected review round or a missed due date. */
    FAILED(CHORE_STATUS_FAILED, "chore_status_failed", FausCrewIcons.xmarkOctagonFill, "Başarısız", "Failed"),
    /** A status this build does not know; shown read-only and never sent. */
    UNKNOWN(-1, "chore_status_unknown", FausCrewIcons.questionmarkCircleFill, "Bilinmiyor", "Unknown"),
    ;

    val color: Color
        @Composable @ReadOnlyComposable
        get() = when (this) {
            DRAFT -> FausCrewColors.statusDraft
            PROGRESS -> FausCrewColors.statusProgress
            IN_TEST -> FausCrewColors.statusInTest
            COMPLETED -> FausCrewColors.statusCompleted
            FAILED -> FausCrewColors.statusFailed
            UNKNOWN -> FausCrewColors.textTertiary
        }

    /** SF `magnifyingglass.circle.fill` has no Material twin, so it is composed from a disc. */
    val isCircledGlyph: Boolean get() = this == IN_TEST

    /** Lists group chores by status, never by `isCompleted` alone. */
    val group: ChoreListGroup get() = when (this) {
        DRAFT, PROGRESS, IN_TEST -> ChoreListGroup.ACTIVE
        COMPLETED -> ChoreListGroup.COMPLETED
        FAILED -> ChoreListGroup.FAILED
        UNKNOWN -> ChoreListGroup.UNKNOWN
    }

    /** Only active chores take actions (start, advance, send to review, vote). */
    val acceptsActions: Boolean get() = group == ChoreListGroup.ACTIVE

    /** Review decides InTest → Completed and the backend alone decides Failed, so neither is offered. */
    val next: ChoreStatusUi? get() = when (this) {
        DRAFT -> PROGRESS
        PROGRESS -> IN_TEST
        IN_TEST, COMPLETED, FAILED, UNKNOWN -> null
    }

    fun label(strings: LocalizedText): String = strings.social(key, tr, en)

    companion object {
        /** The normal flow, as drawn by the status pipeline. */
        val PIPELINE = listOf(DRAFT, PROGRESS, IN_TEST, COMPLETED)

        fun of(raw: Int): ChoreStatusUi = entries.firstOrNull { it.raw == raw && it != UNKNOWN } ?: UNKNOWN
    }
}

internal enum class ChoreListGroup {
    /** Draft, Progress, InTest. */
    ACTIVE, COMPLETED, FAILED, UNKNOWN;

    /** Completed, Failed and unknown chores share the history part of a list. */
    val isHistory: Boolean get() = this != ACTIVE
}

/** Active chores first, then the history (Completed, Failed, unknown), each in API order. */
internal fun List<HouseChore>.splitByHistory(): Pair<List<HouseChore>, List<HouseChore>> =
    partition { !ChoreStatusUi.of(it.status).group.isHistory }

internal fun ChoreFailureReason?.message(strings: LocalizedText): String = when (this ?: ChoreFailureReason.UNSPECIFIED) {
    ChoreFailureReason.DUE_DATE_PASSED -> strings.social("chore_failed_reason_due_date",
        "Son teslim tarihi geçtiği için başarısız oldu.", "Failed because the due date passed.")
    ChoreFailureReason.UNSPECIFIED -> strings.social("chore_failed_reason_generic", "Görev başarısız oldu.", "The chore failed.")
}

/** `ChoreLevel` presentation from NewChorePopup.swift. */
internal enum class ChoreLevelUi(val raw: Int, val key: String, val color: Color, val icon: ImageVector) {
    EASY(10, "chore_level_easy", Color(0xFF33BF66), FausCrewIcons.leafFill),
    MEDIUM(20, "chore_level_medium", Color(0xFFFF7A26), FausCrewIcons.flameFill),
    HARD(30, "chore_level_hard", Color(0xFFE63340), FausCrewIcons.boltFill);

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

/** `FausCrewDateFormatter.dueLabel`. */
internal enum class DueLabel(val key: String) {
    TODAY("common_today"),
    OVERDUE("common_overdue"),
    THIS_WEEK("common_this_week"),
    UPCOMING("common_upcoming"),
    ;

    val color: Color
        @Composable @ReadOnlyComposable
        get() = when (this) {
            TODAY -> FausCrewColors.warning
            OVERDUE -> FausCrewColors.error
            THIS_WEEK, UPCOMING -> FausCrewColors.primary
        }
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

/** `FausCrewDateFormatter.displayDate`: medium date in the device zone, or null. */
internal fun displayApiDate(value: String?): String? =
    parseApiDate(value)?.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))

/** `date.formatted(date: .abbreviated, time: .shortened)`. */
internal fun displayApiDateTime(value: String): String =
    parseApiDate(value)?.format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)) ?: value

internal fun LocalizedText.dueText(value: String): String =
    displayApiDate(value) ?: get(dueLabel(value).key)
