package com.houseflow.ui.components

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.time.temporal.WeekFields
import java.util.Locale
import kotlin.math.min

/**
 * iOS `.datePickerStyle(.graphical)`: month title with a disclosure chevron (tap for the
 * month/year chooser), previous/next month arrows, locale-ordered weekday row and a day
 * grid where the selection is a tinted disc. Dates outside [range] are disabled.
 */
@Composable
internal fun GraphicalCalendar(
    selected: LocalDate,
    onSelect: (LocalDate) -> Unit,
    range: ClosedRange<LocalDate>,
    tint: Color,
    modifier: Modifier = Modifier,
    locale: Locale = Locale.getDefault(),
    navigationTint: Color = tint,
) {
    var month by remember(selected) { mutableStateOf(YearMonth.from(selected)) }
    var choosingMonth by remember { mutableStateOf(false) }
    val first = YearMonth.from(range.start)
    val last = YearMonth.from(range.endInclusive)
    Column(modifier, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.clip(RoundedCornerShape(Radius.sm)).clickable(role = Role.Button) { choosingMonth = !choosingMonth }
                    .padding(vertical = Spacing.xs),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            ) {
                Text(month.format(DateTimeFormatter.ofPattern("LLLL yyyy", locale)).replaceFirstChar { it.titlecase(locale) },
                    fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = HouseFlowColors.textPrimary)
                val rotation = if (choosingMonth) 90f else 0f
                Icon(HouseFlowIcons.chevronRightSmall, null, Modifier.size(20.dp).graphicsLayer { rotationZ = rotation },
                    tint = tint)
            }
            Spacer(Modifier.weight(1f))
            if (!choosingMonth) {
                MonthArrow(HouseFlowIcons.chevronLeft, month > first, navigationTint, "previous") { month = month.minusMonths(1) }
                Spacer(Modifier.width(Spacing.lg))
                MonthArrow(HouseFlowIcons.chevronRightSmall, month < last, navigationTint, "next") { month = month.plusMonths(1) }
            }
        }
        AnimatedContent(choosingMonth, transitionSpec = { fadeIn(Motion.quick()) togetherWith fadeOut(Motion.quick()) },
            label = "calendarMode") { picking ->
            if (picking) {
                MonthYearChooser(month, first, last, tint, locale) { month = it }
            } else {
                DayGrid(month, selected, range, tint, locale) { onSelect(it) }
            }
        }
    }
}

@Composable
private fun MonthArrow(icon: androidx.compose.ui.graphics.vector.ImageVector, enabled: Boolean, tint: Color,
    description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(32.dp).clip(CircleShape).clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(30.dp), tint = if (enabled) tint else HouseFlowColors.textTertiary.copy(alpha = .5f))
    }
}

@Composable
private fun DayGrid(
    month: YearMonth,
    selected: LocalDate,
    range: ClosedRange<LocalDate>,
    tint: Color,
    locale: Locale,
    onSelect: (LocalDate) -> Unit,
) {
    val firstDayOfWeek = WeekFields.of(locale).firstDayOfWeek
    val weekdays = (0 until 7).map { firstDayOfWeek.plus(it.toLong()) }
    val leading = (month.atDay(1).dayOfWeek.value - firstDayOfWeek.value + 7) % 7
    val days = month.lengthOfMonth()
    val today = LocalDate.now()
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Row(Modifier.fillMaxWidth()) {
            weekdays.forEach { day: DayOfWeek ->
                Text(day.getDisplayName(TextStyle.SHORT, locale).uppercase(locale).trimEnd('.'), Modifier.weight(1f),
                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = HouseFlowColors.textTertiary,
                    textAlign = TextAlign.Center, maxLines = 1)
            }
        }
        (0 until (leading + days + 6) / 7).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                (0 until 7).forEach { column ->
                    val dayNumber = week * 7 + column - leading + 1
                    Box(Modifier.weight(1f).height(48.dp), contentAlignment = Alignment.Center) {
                        if (dayNumber in 1..days) {
                            val date = month.atDay(dayNumber)
                            val isSelected = date == selected
                            val enabled = date in range
                            Box(
                                Modifier.size(42.dp).clip(CircleShape)
                                    .background(if (isSelected) tint.copy(alpha = .12f) else Color.Transparent)
                                    .clickable(enabled = enabled, role = Role.Button) { onSelect(date) }
                                    .semantics { this.selected = isSelected },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(dayNumber.toString(), fontSize = 20.sp,
                                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                    color = when {
                                        !enabled -> HouseFlowColors.textTertiary.copy(alpha = .5f)
                                        isSelected || date == today -> tint
                                        else -> HouseFlowColors.textPrimary
                                    })
                            }
                        }
                    }
                }
            }
        }
    }
}

/** The month/year list iOS shows when the title is tapped. */
@Composable
private fun MonthYearChooser(
    month: YearMonth,
    first: YearMonth,
    last: YearMonth,
    tint: Color,
    locale: Locale,
    onChange: (YearMonth) -> Unit,
) {
    val years = (first.year..last.year).toList()
    val yearState = rememberLazyListState(initialFirstVisibleItemIndex = (years.indexOf(month.year) - 2).coerceAtLeast(0))
    val monthState = rememberLazyListState(initialFirstVisibleItemIndex = (month.monthValue - 3).coerceAtLeast(0))
    Row(Modifier.fillMaxWidth().height(232.dp), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        LazyColumn(Modifier.weight(1.4f), state = monthState) {
            items((1..12).toList()) { value ->
                val candidate = YearMonth.of(month.year, value)
                val enabled = candidate in first..last
                ChooserItem(java.time.Month.of(value).getDisplayName(TextStyle.FULL_STANDALONE, locale)
                    .replaceFirstChar { it.titlecase(locale) }, value == month.monthValue, enabled, tint) { onChange(candidate) }
            }
        }
        LazyColumn(Modifier.weight(1f), state = yearState) {
            items(years) { year ->
                ChooserItem(year.toString(), year == month.year, true, tint) {
                    val candidate = YearMonth.of(year, month.monthValue)
                    onChange(if (candidate < first) first else if (candidate > last) last else candidate)
                }
            }
        }
    }
}

@Composable
private fun ChooserItem(text: String, selected: Boolean, enabled: Boolean, tint: Color, onClick: () -> Unit) {
    Text(text, Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.sm))
        .background(if (selected) tint.copy(alpha = .12f) else Color.Transparent)
        .clickable(enabled = enabled, onClick = onClick).padding(vertical = 10.dp),
        fontSize = 19.sp, fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal, textAlign = TextAlign.Center,
        color = when {
            !enabled -> HouseFlowColors.textTertiary.copy(alpha = .5f)
            selected -> tint
            else -> HouseFlowColors.textPrimary
        })
}

/**
 * iOS `.datePickerStyle(.compact)`: the date in a gray pill; tapping opens the graphical
 * calendar in a floating card next to it. Picking a day closes it.
 */
@Composable
internal fun CompactDatePicker(
    date: LocalDate,
    onChange: (LocalDate) -> Unit,
    range: ClosedRange<LocalDate>,
    tint: Color,
    modifier: Modifier = Modifier,
    description: String? = null,
) {
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Text(
            date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)),
            Modifier.clip(RoundedCornerShape(Radius.sm)).background(Color(0x1F767680))
                .clickable(role = Role.Button) { open = true }
                .then(if (description != null) Modifier.semantics { contentDescription = description } else Modifier)
                .padding(horizontal = 11.dp, vertical = 6.dp),
            style = HouseFlowType.body,
            color = if (open) tint else HouseFlowColors.textPrimary,
        )
        if (open) {
            CalendarPopover(onDismiss = { open = false }) {
                GraphicalCalendar(date, { onChange(it); open = false }, range, tint, navigationTint = HouseFlowColors.textPrimary)
            }
        }
    }
}

/** Floating calendar card placed above (or below) its anchor and kept on screen. */
@Composable
private fun CalendarPopover(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    val density = LocalDensity.current
    val provider = remember(density) {
        val gap = with(density) { 8.dp.roundToPx() }
        val margin = with(density) { 12.dp.roundToPx() }
        object : PopupPositionProvider {
            override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection,
                popupContentSize: IntSize): IntOffset {
                val x = ((windowSize.width - popupContentSize.width) / 2).coerceAtLeast(margin)
                val above = anchorBounds.top - popupContentSize.height - gap
                val y = if (above >= margin) above
                    else min(anchorBounds.bottom + gap, windowSize.height - popupContentSize.height - margin).coerceAtLeast(margin)
                return IntOffset(x, y)
            }
        }
    }
    val appear = remember { Animatable(0f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, Motion.spring()) }
    val width = min(330f, LocalConfiguration.current.screenWidthDp - 24f).dp
    val shape = RoundedCornerShape(Radius.xl)
    Popup(popupPositionProvider = provider, onDismissRequest = onDismiss, properties = PopupProperties(focusable = true)) {
        Box(
            Modifier.width(width)
                .graphicsLayer {
                    alpha = appear.value.coerceIn(0f, 1f)
                    scaleX = .92f + .08f * appear.value
                    scaleY = .92f + .08f * appear.value
                    transformOrigin = TransformOrigin(.5f, .5f)
                }
                .softShadow(Color.Black.copy(alpha = .18f), 24.dp, y = 8.dp, shape = shape)
                .clip(shape)
                .background(Color.White.copy(alpha = .97f))
                .padding(Spacing.lg),
        ) { content() }
    }
}
