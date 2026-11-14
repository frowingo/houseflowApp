package com.fauscrew.ui.dashboard.catalog

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AlarmOn
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.EditCalendar
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.fauscrew.platform.ApiLanguage
import com.fauscrew.platform.ChoreCatalogFailure
import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCatalogRules
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.HouseDetails
import com.fauscrew.platform.HouseMember
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.CompactDatePicker
import com.fauscrew.ui.components.UserAvatar
import com.fauscrew.ui.components.brandPopupHeaderBackground
import com.fauscrew.ui.dashboard.ChoreLevelUi
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import java.util.Locale

private enum class DueChoice { TODAY, TOMORROW, WEEKEND, CUSTOM }

private val quickHours = listOf(9, 12, 15, 18, 21)

/** 18:00, or the next full hour when the evening has already started (at most 23:00). */
internal fun defaultDueTime(now: LocalTime = LocalTime.now()): LocalTime =
    LocalTime.of(minOf(maxOf(18, now.hour + 1), 23), 0)

private fun isPast(day: LocalDate, time: LocalTime): Boolean = !LocalDateTime.of(day, time).isAfter(LocalDateTime.now())

private fun timeText(time: LocalTime): String = "%02d:%02d".format(time.hour, time.minute)

private fun isWeekend(day: LocalDate): Boolean = day.dayOfWeek == DayOfWeek.SATURDAY || day.dayOfWeek == DayOfWeek.SUNDAY

/** Today on a weekend, otherwise the coming Saturday. */
private fun weekendDate(today: LocalDate): LocalDate =
    if (isWeekend(today)) today else today.with(TemporalAdjusters.next(DayOfWeek.SATURDAY))

private fun shortDate(day: LocalDate): String =
    day.format(DateTimeFormatter.ofPattern("d MMM", Locale.forLanguageTag(ApiLanguage.code)))

/**
 * iOS `ChoreTemplateEditorView`: the chosen template as an editable theme header, then who,
 * when, how often and how hard. [onSubmit] hands the create request to the popup, which sends
 * it through the regular create-chore flow and reports back via [submitting] / [errorMessage].
 * Any card can be saved as a draft (as it is or tweaked): a system template or the blank card
 * adds a new draft, a draft opened from the Drafts tab is updated. A chore written from scratch,
 * or a draft, also picks its category. [onSaveDraft] sends the record and returns the failure,
 * if any, which is shown here while the editor stays open.
 */
@Composable
internal fun ChoreTemplateEditor(
    template: ChoreTemplate,
    templateCategory: ChoreCategory,
    prefillTitle: String?,
    details: HouseDetails,
    userId: String,
    strings: LocalizedText,
    submitting: Boolean,
    errorMessage: String?,
    onBack: () -> Unit,
    onClose: () -> Unit,
    onSubmit: (ChoreInput, ChoreCatalogCreation) -> Unit,
    onSaveDraft: suspend (ChoreCatalogRecord) -> ChoreCatalogFailure?,
    modifier: Modifier = Modifier,
) {
    val focus = LocalFocusManager.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val isBlank = template.origin == ChoreTemplate.Origin.BLANK
    /** Written by the user (blank card or draft): the category can be picked. */
    val isCustom = isBlank || template.isDraft
    /** The draft a save updates: only a draft opened from the Drafts tab. System templates are
     *  never updated; saving one adds a new draft. */
    val savedRecord = if (template.isDraft) template.record else null
    val members = details.members
    val today = LocalDate.now()

    var selectedCategoryId by remember(template.id) { mutableStateOf(templateCategory.id) }
    // A custom chore follows the picked category; catalog templates keep their own.
    val category = if (isCustom) ChoreCatalog.category(selectedCategoryId) ?: templateCategory else templateCategory
    val tint = category.tintColor
    var title by remember(template.id) {
        mutableStateOf(prefillTitle ?: if (isBlank) "" else strings.catalogTitle(template))
    }
    var detail by remember(template.id) { mutableStateOf(if (isBlank) "" else strings.catalogDetail(template)) }
    var memberId by remember(template.id) {
        mutableStateOf((members.firstOrNull { it.id == userId } ?: members.firstOrNull())?.id)
    }
    var level by remember(template.id) { mutableStateOf(ChoreLevelUi.of(template.level)) }
    var dueDate by remember(template.id) { mutableStateOf(today) }
    var hasDueTime by remember(template.id) { mutableStateOf(false) }
    var dueTime by remember(template.id) { mutableStateOf(defaultDueTime()) }
    var repeatDays by remember(template.id) { mutableIntStateOf(template.repeatDays) }
    // A custom interval that isn't a preset opens with the stepper.
    var isCustomRepeat by remember(template.id) { mutableStateOf(repeatDays > 0 && repeatDays !in ChoreRepeatPresets.all) }
    val titleFocus = remember { FocusRequester() }
    val detailFocus = remember { FocusRequester() }

    val selectedMember = members.firstOrNull { it.id == memberId }
    val trimmedTitle = title.trim()
    val trimmedDetail = detail.trim()
    var isSavingDraft by remember(template.id) { mutableStateOf(false) }
    var draftError by remember(template.id) { mutableStateOf<String?>(null) }
    // The draft as it would be sent now: the opened draft with its id, or a new record.
    val draftSnapshot = (savedRecord ?: ChoreCatalogRecord(title = "", category = category.kind.raw)).copy(
        title = trimmedTitle, description = trimmedDetail, level = level.raw, recurringInterval = repeatDays,
        category = category.kind.raw)
    // The server's rules, and an update needs a change.
    val canSaveDraft = !submitting && !isSavingDraft && ChoreCatalogRules.isValid(draftSnapshot) &&
        (savedRecord == null || draftSnapshot != savedRecord)
    // Why a typed draft cannot be saved yet; `null` while the title is still empty.
    val draftRuleHint = when {
        trimmedTitle.isNotEmpty() && !ChoreCatalogRules.isValidTitle(trimmedTitle) -> strings.catalog(
            "chore_catalog_editor_draft_title_rule", "Taslak için iş adı 3–200 karakter olmalı.",
            "A draft needs a name of 3–200 characters.")
        !ChoreCatalogRules.isValidDescription(trimmedDetail) -> strings.catalog(
            "chore_catalog_editor_draft_detail_rule", "Not en fazla 1000 karakter olabilir.",
            "The note can be at most 1000 characters.")
        else -> null
    }
    val shownError = draftError ?: errorMessage
    val isDueTimeInPast = hasDueTime && isPast(dueDate, dueTime)
    val canCreate = trimmedTitle.isNotEmpty() && selectedMember != null && details.id.isNotBlank() && !submitting &&
        !isSavingDraft && !isDueTimeInPast
    val weekend = weekendDate(today)
    val dueChoice = when (dueDate) {
        today -> DueChoice.TODAY
        today.plusDays(1) -> DueChoice.TOMORROW
        weekend -> DueChoice.WEEKEND
        else -> DueChoice.CUSTOM
    }
    val meLabel = strings.catalog("chore_catalog_editor_me", "Ben", "Me")
    fun nameOf(member: HouseMember): String = if (member.id == userId) meLabel else member.firstName
    val select: () -> Unit = { haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove) }

    LaunchedEffect(template.id) {
        if (isBlank && prefillTitle == null) {
            delay(450)
            runCatching { titleFocus.requestFocus() }
        }
    }

    val create: () -> Unit = create@{
        val member = selectedMember ?: return@create
        if (!canCreate) return@create
        focus.clearFocus()
        draftError = null
        val input = ChoreInput(
            houseId = details.id,
            assignedTo = member.id,
            title = trimmedTitle,
            description = detail.trim(),
            dueDate = ChoreDueDate.wire(dueDate, if (hasDueTime) dueTime else null),
            isRecurring = repeatDays > 0,
            level = level.raw,
            recurringInterval = repeatDays,
            category = category.kind.raw.takeIf { category.kind.isAssignable },
        )
        onSubmit(input, ChoreCatalogCreation(template.id, trimmedTitle, nameOf(member), repeatDays))
    }

    Column(modifier) {
        // MARK: Header
        Column(
            Modifier.fillMaxWidth().brandPopupHeaderBackground()
                .padding(horizontal = Spacing.lg, vertical = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Row(
                    Modifier.height(32.dp).clip(CircleShape).background(Color.White.copy(alpha = .2f))
                        .catalogPress { focus.clearFocus(); onBack() }
                        .padding(start = 10.dp, end = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(FausCrewIcons.chevronLeft, null, Modifier.size(16.dp), tint = Color.White)
                    Text(strings.catalog("chore_catalog_editor_back", "Katalog", "Catalog"), fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold, color = Color.White)
                }
                Text(
                    (when {
                        template.isDraft -> strings.catalog("chore_catalog_editor_draft_title", "Taslağı düzenle", "Edit draft")
                        isBlank -> strings.catalog("chore_catalog_editor_blank_title", "Yeni iş", "New chore")
                        else -> strings.catalog("chore_catalog_editor_title", "İşi hazırla", "Set up the chore")
                    }).uppercase(),
                    Modifier.weight(1f), fontSize = 13.sp, fontWeight = FontWeight.Bold, letterSpacing = .6.sp,
                    color = Color.White.copy(alpha = .8f), textAlign = TextAlign.Center, maxLines = 1,
                )
                HeaderCircleButton(FausCrewIcons.xmark, strings.get("common_close", "Close")) { focus.clearFocus(); onClose() }
            }

            Row(Modifier.padding(top = Spacing.xs), horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                verticalAlignment = Alignment.CenterVertically) {
                Row(
                    Modifier.clip(CircleShape).background(Color.White).padding(horizontal = 10.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Icon(category.iconVector, null, Modifier.size(13.dp), tint = category.deepColor)
                    Text(strings.catalogName(category), fontSize = 12.sp, fontWeight = FontWeight.Bold,
                        color = category.deepColor, maxLines = 1)
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                EditableBox(
                    label = strings.catalog("chore_catalog_editor_title_label", "İş adı", "Chore name"),
                    value = title,
                    onValueChange = { title = it },
                    placeholder = strings.catalog("chore_catalog_editor_title_placeholder", "İşin adını yaz", "Name the chore"),
                    textStyle = TextStyle(fontSize = 22.sp, lineHeight = 27.sp, fontWeight = FontWeight.Bold, color = Color.White),
                    maxLines = 2,
                    focusRequester = titleFocus,
                    imeAction = ImeAction.Next,
                    onImeAction = { runCatching { detailFocus.requestFocus() } },
                )
                EditableBox(
                    label = strings.catalog("chore_catalog_editor_detail_label", "Not", "Note"),
                    value = detail,
                    onValueChange = { detail = it },
                    placeholder = strings.catalog("chore_catalog_editor_detail_placeholder",
                        "Kısa bir not ekle (isteğe bağlı)", "Add a short note (optional)"),
                    textStyle = TextStyle(fontSize = 15.sp, lineHeight = 20.sp, color = Color.White),
                    maxLines = 3,
                    focusRequester = detailFocus,
                    imeAction = ImeAction.Default,
                    onImeAction = {},
                )
            }
        }

        // MARK: Sections
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState())
                .padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.lg, bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            if (isCustom) {
                EditorSection(Icons.Rounded.GridView, strings.catalog("chore_catalog_editor_category", "Kategori", "Category"), tint) {
                    val listState = rememberLazyListState()
                    LaunchedEffect(Unit) {
                        val index = ChoreCatalog.categories.indexOfFirst { it.id == category.id }.coerceAtLeast(0)
                        listState.scrollToItem((index - 1).coerceAtLeast(0))
                    }
                    LazyRow(
                        Modifier.fillMaxWidth().bleedHorizontally(Spacing.lg),
                        state = listState,
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = 2.dp),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(ChoreCatalog.categories, key = { it.id }) { item ->
                            CategoryChip(item, item.id == category.id, strings) { select(); selectedCategoryId = item.id }
                        }
                    }
                }
            }

            EditorSection(FausCrewIcons.personFill, strings.catalog("chore_catalog_editor_who", "Kim yapacak?", "Who's on it?"), tint) {
                if (members.isEmpty()) {
                    Text(strings.catalog("chore_catalog_editor_no_members", "Evde henüz atanabilecek kimse yok.",
                        "There's no one to assign yet."), style = FausCrewType.subheadline, color = FausCrewColors.textSecondary)
                } else {
                    LazyRow(
                        Modifier.fillMaxWidth().bleedHorizontally(Spacing.lg),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = 2.dp),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(members, key = { it.id }) { member ->
                            MemberButton(member, nameOf(member), member.id == memberId, tint) { select(); memberId = member.id }
                        }
                    }
                }
            }

            EditorSection(FausCrewIcons.calendar, strings.catalog("chore_catalog_editor_when", "Ne zaman?", "When?"), tint) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        DueChip(strings.get("common_today", "Today"), today, dueChoice == DueChoice.TODAY, category) {
                            select(); dueDate = today
                        }
                        DueChip(strings.catalog("chore_catalog_editor_tomorrow", "Yarın", "Tomorrow"), today.plusDays(1),
                            dueChoice == DueChoice.TOMORROW, category) { select(); dueDate = today.plusDays(1) }
                        if (!isWeekend(today)) {
                            DueChip(strings.catalog("chore_catalog_editor_weekend", "Hafta sonu", "Weekend"), weekend,
                                dueChoice == DueChoice.WEEKEND, category) { select(); dueDate = weekend }
                        }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        val custom = dueChoice == DueChoice.CUSTOM
                        val ink = if (custom) tint else FausCrewColors.textSecondary
                        Icon(if (custom) Icons.Rounded.CheckCircle else Icons.Rounded.EditCalendar, null, Modifier.size(18.dp), tint = ink)
                        Text(strings.catalog("chore_catalog_editor_pick_date", "Başka bir gün", "Another day"),
                            Modifier.padding(start = Spacing.sm).weight(1f), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = ink)
                        CompactDatePicker(dueDate, { dueDate = it }, today..today.plusYears(5), tint,
                            description = strings.catalog("chore_catalog_editor_pick_date", "Başka bir gün", "Another day"))
                    }
                    Box(Modifier.fillMaxWidth().padding(vertical = 2.dp).height(.5.dp).background(FausCrewColors.hairline))
                    DueTimePicker(
                        strings = strings,
                        category = category,
                        dueDate = dueDate,
                        hasDueTime = hasDueTime,
                        dueTime = dueTime,
                        isDueTimeInPast = isDueTimeInPast,
                        onModeChange = { timed ->
                            select()
                            if (timed && isPast(dueDate, dueTime)) dueTime = defaultDueTime()
                            hasDueTime = timed
                        },
                        onTime = { dueTime = it },
                    )
                }
            }

            val suggested = if (template.repeatDays > 0 && !isCustom) {
                strings.catalog("chore_catalog_editor_suggested", "Önerilen: {value}", "Suggested: {value}")
                    .replace("{value}", strings.catalogRepeatLabel(template.repeatDays))
            } else null
            EditorSection(FausCrewIcons.arrowClockwise, strings.catalog("chore_catalog_editor_repeat", "Ne sıklıkla?", "How often?"),
                tint, trailing = suggested) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        ChoreRepeatPresets.all.forEach { days ->
                            RepeatChip(strings.catalogRepeatLabel(days), null, !isCustomRepeat && repeatDays == days,
                                !isCustom && days == template.repeatDays, category) {
                                select(); isCustomRepeat = false; repeatDays = days
                            }
                        }
                        RepeatChip(strings.catalog("chore_catalog_repeat_custom", "Özel", "Custom"), FausCrewIcons.sliderHorizontal3,
                            isCustomRepeat, false, category) {
                            select(); isCustomRepeat = true
                            if (repeatDays < 1) repeatDays = 4
                        }
                    }
                    AnimatedVisibility(isCustomRepeat, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(FausCrewColors.secondaryBackground)
                                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(strings.catalogRepeatLabel(repeatDays), Modifier.weight(1f), fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary)
                            IosStepper(repeatDays, 1..90) { repeatDays = it }
                        }
                    }
                }
            }

            EditorSection(FausCrewIcons.flameFill, strings.get("new_chore_difficulty_label", "Difficulty"), tint) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    ChoreLevelUi.entries.forEach { item ->
                        val selected = level == item
                        val shape = RoundedCornerShape(Radius.md)
                        Column(
                            Modifier.weight(1f).height(58.dp).clip(shape)
                                .background(if (selected) item.color else item.color.copy(alpha = .12f))
                                .catalogPress(.96f) { select(); level = item }
                                .semantics { this.selected = selected },
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
                        ) {
                            val ink = if (selected) Color.White else item.color
                            Icon(item.icon, null, Modifier.size(18.dp), tint = ink)
                            Text(strings.get(item.key), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = ink, maxLines = 1)
                        }
                    }
                }
            }

            // Every card can be saved as a draft; a draft opened from the Drafts tab is updated.
            DraftButton(isUpdate = savedRecord != null, enabled = canSaveDraft, saving = isSavingDraft, hint = draftRuleHint,
                category = category, strings = strings) {
                if (!canSaveDraft) return@DraftButton
                focus.clearFocus()
                draftError = null
                isSavingDraft = true
                val record = draftSnapshot
                scope.launch {
                    val failure = try { onSaveDraft(record) } finally { isSavingDraft = false }
                    if (failure != null) {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        draftError = failure.message ?: strings.catalog("chore_catalog_editor_draft_error",
                            "Taslak kaydedilemedi. Bağlantını kontrol edip tekrar dene.",
                            "Couldn't save the draft. Check your connection and try again.")
                    }
                }
            }
        }

        // MARK: Bottom bar
        Column(
            Modifier.fillMaxWidth()
                .softShadow(FausCrewColors.shadow.copy(alpha = .08f), 10.dp, y = (-4).dp)
                .background(FausCrewColors.popupBackground)
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            AnimatedVisibility(shownError != null, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(FausCrewIcons.exclamationmarkTriangleFill, null, Modifier.size(16.dp), tint = FausCrewColors.error)
                    Text(shownError.orEmpty(), fontSize = 13.sp, fontWeight = FontWeight.Medium, color = FausCrewColors.error)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                selectedMember?.let { UserAvatar(it, 34.dp) }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Text(trimmedTitle.ifEmpty { strings.catalog("chore_catalog_editor_untitled", "İsimsiz iş", "Untitled chore") },
                        fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        color = if (trimmedTitle.isEmpty()) FausCrewColors.textTertiary else FausCrewColors.textPrimary)
                    val who = selectedMember?.let(::nameOf) ?: strings.catalog("chore_catalog_editor_nobody", "Kişi seç", "Pick someone")
                    val whenText = when (dueChoice) {
                        DueChoice.TODAY -> strings.get("common_today", "Today")
                        DueChoice.TOMORROW -> strings.catalog("chore_catalog_editor_tomorrow", "Yarın", "Tomorrow")
                        else -> shortDate(dueDate)
                    }
                    val time = if (hasDueTime) timeText(dueTime) else "00:00"
                    Text(listOf(who, "$whenText $time", strings.catalogRepeatLabel(repeatDays)).joinToString(" · "),
                        style = FausCrewType.caption, color = FausCrewColors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Spacer(Modifier.width(Spacing.sm))
                val active = canCreate || submitting
                Row(
                    Modifier.height(48.dp)
                        .softShadow(if (canCreate) category.deepColor.copy(alpha = .35f) else Color.Transparent, 8.dp, y = 4.dp, shape = CircleShape)
                        .clip(CircleShape)
                        .background(if (active) category.gradient else SolidColor(FausCrewColors.textTertiary.copy(alpha = .45f)))
                        .catalogPress(.95f, enabled = canCreate, onClick = create)
                        .padding(horizontal = Spacing.xl),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (submitting) {
                        CircularProgressIndicator(Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
                    } else {
                        Icon(FausCrewIcons.plus, null, Modifier.size(18.dp), tint = Color.White)
                    }
                    Text(strings.catalog("chore_catalog_editor_create", "Ekle", "Add"), fontSize = 16.sp,
                        fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
        }
    }
}

// MARK: - Header field

/** Glassy, clearly editable box: uppercase label with a pencil, the field, and a border that turns solid while typing. */
@Composable
private fun EditableBox(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    textStyle: TextStyle,
    maxLines: Int,
    focusRequester: FocusRequester,
    imeAction: ImeAction,
    onImeAction: () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(14.dp)
    val fill by animateFloatAsState(if (focused) .24f else .14f, tween(200), label = "editFill")
    Column(
        Modifier.fillMaxWidth().clip(shape).background(Color.White.copy(alpha = fill))
            .then(if (focused) Modifier.border(1.5.dp, Color.White.copy(alpha = .85f), shape)
                else Modifier.dashedBorder(Color.White.copy(alpha = .4f), 14.dp, 1.dp, 5f, 4f))
            .clickable(remember { MutableInteractionSource() }, indication = null) { runCatching { focusRequester.requestFocus() } }
            .padding(horizontal = Spacing.md, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            val ink = Color.White.copy(alpha = if (focused) .95f else .75f)
            Text(label.uppercase(), Modifier.weight(1f), fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                letterSpacing = .8.sp, color = ink)
            AnimatedContent(focused, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "editIcon") { isFocused ->
                Icon(if (isFocused) Icons.Rounded.Keyboard else FausCrewIcons.pencil, null, Modifier.size(13.dp), tint = ink)
            }
        }
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth().focusRequester(focusRequester).onFocusChanged { focused = it.isFocused }
                .semantics { contentDescription = label },
            textStyle = textStyle,
            cursorBrush = SolidColor(Color.White),
            maxLines = maxLines,
            keyboardOptions = KeyboardOptions(imeAction = imeAction),
            keyboardActions = KeyboardActions(onNext = { onImeAction() }),
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) Text(placeholder, style = textStyle.copy(color = Color.White.copy(alpha = .55f)), maxLines = 1)
                    inner()
                }
            },
        )
    }
}

// MARK: - Sections

@Composable
private fun EditorSection(
    icon: ImageVector,
    title: String,
    tint: Color,
    trailing: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        Modifier.fillMaxWidth()
            .softShadow(FausCrewColors.shadow.copy(alpha = .06f), 8.dp, y = 2.dp, shape = shape)
            .clip(shape).background(FausCrewColors.cardBackground)
            .border(.5.dp, FausCrewColors.hairline, shape)
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(Modifier.semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(icon, null, Modifier.size(13.dp), tint = tint)
            Text(title.uppercase(), Modifier.weight(1f), fontSize = 12.sp, fontWeight = FontWeight.Bold,
                letterSpacing = .6.sp, color = FausCrewColors.textSecondary, maxLines = 1)
            trailing?.let { Text(it, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1) }
        }
        content()
    }
}

@Composable
private fun MemberButton(member: HouseMember, label: String, selected: Boolean, tint: Color, onClick: () -> Unit) {
    val scale by animateFloatAsState(if (selected) 1f else .94f, spring(dampingRatio = .75f, stiffness = 420f), label = "memberScale")
    val fill by animateColorAsState(if (selected) tint.copy(alpha = .10f) else Color.Transparent, label = "memberFill")
    Column(
        Modifier.width(66.dp).clip(RoundedCornerShape(Radius.md)).background(fill)
            .catalogPress(onClick = onClick)
            .semantics { contentDescription = member.name; this.selected = selected }
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(contentAlignment = Alignment.BottomEnd) {
            Box(Modifier.scale(scale).border(2.5.dp, if (selected) tint else Color.Transparent, CircleShape).padding(3.dp)) {
                UserAvatar(member, 48.dp)
            }
            androidx.compose.animation.AnimatedVisibility(selected, enter = fadeIn() + androidx.compose.animation.scaleIn(), exit = fadeOut() + androidx.compose.animation.scaleOut()) {
                Box(
                    Modifier.size(20.dp).background(tint, CircleShape).border(2.dp, FausCrewColors.cardBackground, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { Icon(FausCrewIcons.checkmark, null, Modifier.size(11.dp), tint = Color.White) }
            }
        }
        Text(label, fontSize = 12.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium, maxLines = 1,
            overflow = TextOverflow.Ellipsis, color = if (selected) FausCrewColors.textPrimary else FausCrewColors.textSecondary)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.DueChip(
    label: String,
    date: LocalDate,
    selected: Boolean,
    category: ChoreCategory,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.md)
    Column(
        Modifier.weight(1f).height(52.dp).clip(shape)
            .background(if (selected) category.gradient else SolidColor(FausCrewColors.secondaryBackground))
            .catalogPress(.96f, onClick = onClick)
            .semantics { this.selected = selected },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
    ) {
        val ink = if (selected) Color.White else FausCrewColors.textPrimary
        Text(label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink, maxLines = 1)
        Text(shortDate(date), fontSize = 11.sp, fontWeight = FontWeight.Medium, color = ink.copy(alpha = .8f), maxLines = 1)
    }
}

// MARK: - Due time

@Composable
private fun DueTimePicker(
    strings: LocalizedText,
    category: ChoreCategory,
    dueDate: LocalDate,
    hasDueTime: Boolean,
    dueTime: LocalTime,
    isDueTimeInPast: Boolean,
    onModeChange: (Boolean) -> Unit,
    onTime: (LocalTime) -> Unit,
) {
    val haptics = LocalHapticFeedback.current
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        Text(strings.catalog("chore_catalog_editor_due_time", "Bitiş saati", "Due by"), fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold, color = FausCrewColors.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            TimeModeCard(!hasDueTime, Icons.Rounded.Bedtime,
                strings.catalog("chore_catalog_editor_end_of_day", "Gün sonu", "End of day"), "00:00", category) { onModeChange(false) }
            TimeModeCard(hasDueTime, FausCrewIcons.clockFill,
                strings.catalog("chore_catalog_editor_pick_time", "Saat seç", "Pick a time"),
                if (hasDueTime) timeText(dueTime) else "--:--", category) { onModeChange(true) }
        }
        AnimatedContent(hasDueTime, transitionSpec = { (fadeIn() + expandVertically()) togetherWith (fadeOut() + shrinkVertically()) },
            label = "dueTimeMode") { timed ->
            if (timed) {
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        quickHours.forEach { hour ->
                            val selected = dueTime.hour == hour && dueTime.minute == 0
                            val past = isPast(dueDate, LocalTime.of(hour, 0))
                            Box(
                                Modifier.weight(1f).height(34.dp).alpha(if (past) .35f else 1f).clip(CircleShape)
                                    .background(if (selected) category.gradient else SolidColor(FausCrewColors.secondaryBackground))
                                    .catalogPress(.94f, enabled = !past) {
                                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                        onTime(LocalTime.of(hour, 0))
                                    }
                                    .semantics { this.selected = selected },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text("%02d:00".format(hour), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                                    color = if (selected) Color.White else FausCrewColors.textPrimary)
                            }
                        }
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.AlarmOn, null, Modifier.size(18.dp), tint = FausCrewColors.textSecondary)
                        Text(strings.catalog("chore_catalog_editor_exact_time", "Tam saat", "Exact time"),
                            Modifier.padding(start = Spacing.sm).weight(1f), fontSize = 14.sp, fontWeight = FontWeight.Medium,
                            color = FausCrewColors.textSecondary)
                        CompactTimePicker(dueTime, category.tintColor, strings, onTime)
                    }
                    AnimatedVisibility(isDueTimeInPast, enter = fadeIn(), exit = fadeOut()) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Rounded.Error, null, Modifier.size(16.dp), tint = FausCrewColors.error)
                            Text(strings.catalog("chore_catalog_editor_time_past", "Bu saat geçti, ileri bir saat seç.",
                                "That time has passed, pick a later one."), fontSize = 13.sp, fontWeight = FontWeight.Medium,
                                color = FausCrewColors.error)
                        }
                    }
                }
            } else {
                Text(strings.catalog("chore_catalog_editor_end_of_day_hint",
                    "Saat seçmezsen iş, seçtiğin günün sonuna (gece 00:00) kadar açık kalır.",
                    "Without a time, the chore stays open until the end of the chosen day (midnight)."),
                    fontSize = 12.sp, lineHeight = 16.sp, color = FausCrewColors.textTertiary)
            }
        }
    }
}

/** Lets a horizontal rail run to the card's edges, past the section padding (iOS `contentMargins`). */
private fun Modifier.bleedHorizontally(amount: androidx.compose.ui.unit.Dp): Modifier = layout { measurable, constraints ->
    val extra = (amount * 2).roundToPx()
    val placeable = measurable.measure(constraints.copy(minWidth = constraints.minWidth + extra, maxWidth = constraints.maxWidth + extra))
    layout(constraints.maxWidth, placeable.height) { placeable.place(-extra / 2, 0) }
}

/** Places the time card above its anchor, end-aligned, kept on screen. */
private class AboveAnchor(private val gap: Int, private val margin: Int) : PopupPositionProvider {
    override fun calculatePosition(anchorBounds: IntRect, windowSize: IntSize, layoutDirection: LayoutDirection,
        popupContentSize: IntSize): IntOffset {
        val x = (anchorBounds.right - popupContentSize.width).coerceIn(margin, (windowSize.width - popupContentSize.width - margin).coerceAtLeast(margin))
        val above = anchorBounds.top - popupContentSize.height - gap
        val y = if (above >= margin) above else anchorBounds.bottom + gap
        return IntOffset(x, y)
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.TimeModeCard(
    selected: Boolean,
    icon: ImageVector,
    title: String,
    value: String,
    category: ChoreCategory,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(Radius.md)
    Row(
        Modifier.weight(1f).height(58.dp).clip(shape)
            .background(if (selected) category.gradient else SolidColor(FausCrewColors.secondaryBackground))
            .catalogPress(.96f, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(
            Modifier.size(30.dp).background(if (selected) Color.White.copy(alpha = .22f) else category.tintColor.copy(alpha = .12f), CircleShape),
            contentAlignment = Alignment.Center,
        ) { Icon(icon, null, Modifier.size(17.dp), tint = if (selected) Color.White else category.tintColor) }
        Column {
            val ink = if (selected) Color.White else FausCrewColors.textPrimary
            Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(value, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = ink, maxLines = 1)
        }
    }
}

/**
 * iOS compact `DatePicker(.hourAndMinute)`: the time in a gray pill; tapping opens a small card
 * with hour and minute steppers (24-hour clock, like the tr_TR picker).
 */
@Composable
private fun CompactTimePicker(time: LocalTime, tint: Color, strings: LocalizedText, onChange: (LocalTime) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val label = strings.catalog("chore_catalog_editor_exact_time", "Tam saat", "Exact time")
    Box {
        Text(
            timeText(time),
            Modifier.clip(RoundedCornerShape(Radius.sm)).background(Color(0x1F767680))
                .clickable(role = Role.Button) { open = true }
                .semantics { contentDescription = "$label ${timeText(time)}" }
                .padding(horizontal = 11.dp, vertical = 6.dp),
            style = FausCrewType.body,
            color = if (open) tint else FausCrewColors.textPrimary,
        )
        if (open) {
            val density = LocalDensity.current
            val provider = remember(density) { with(density) { AboveAnchor(8.dp.roundToPx(), 12.dp.roundToPx()) } }
            Popup(
                popupPositionProvider = provider,
                onDismissRequest = { open = false },
                properties = PopupProperties(focusable = true),
            ) {
                val shape = RoundedCornerShape(Radius.xl)
                Row(
                    Modifier.softShadow(FausCrewColors.shadow.copy(alpha = .18f), 24.dp, y = 8.dp, shape = shape)
                        .clip(shape).background(FausCrewColors.elevatedSurface)
                        .padding(horizontal = Spacing.lg, vertical = Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                ) {
                    TimeWheel(time.hour, tint) { onChange(time.withHour(Math.floorMod(it, 24))) }
                    Text(":", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = FausCrewColors.textPrimary)
                    TimeWheel(time.minute, tint, step = 5) { onChange(time.withMinute(Math.floorMod(it, 60))) }
                    Box(
                        Modifier.padding(start = Spacing.sm).size(36.dp).background(tint, CircleShape)
                            .catalogPress { open = false }
                            .semantics { contentDescription = strings.get("common_done", "Done") },
                        contentAlignment = Alignment.Center,
                    ) { Icon(FausCrewIcons.checkmark, null, Modifier.size(18.dp), tint = Color.White) }
                }
            }
        }
    }
}

@Composable
private fun TimeWheel(value: Int, tint: Color, step: Int = 1, onChange: (Int) -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(FausCrewIcons.chevronUp, null, Modifier.size(32.dp).clip(CircleShape)
            .clickable(role = Role.Button) { onChange(value + step - value % step) }, tint = tint)
        Text("%02d".format(value), Modifier.widthIn(min = 44.dp), fontSize = 28.sp, fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center, color = FausCrewColors.textPrimary)
        Icon(FausCrewIcons.chevronDown, null, Modifier.size(32.dp).clip(CircleShape)
            .clickable(role = Role.Button) { onChange(if (value % step == 0) value - step else value - value % step) }, tint = tint)
    }
}

// MARK: - Category (custom chores) and draft

@Composable
private fun CategoryChip(item: ChoreCategory, selected: Boolean, strings: LocalizedText, onClick: () -> Unit) {
    Row(
        Modifier.height(36.dp).clip(CircleShape)
            .background(if (selected) item.gradient else SolidColor(FausCrewColors.secondaryBackground))
            .catalogPress(.95f, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(item.iconVector, null, Modifier.size(14.dp), tint = if (selected) Color.White else item.tintColor)
        Text(strings.catalogName(item), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1,
            color = if (selected) Color.White else FausCrewColors.textPrimary)
    }
}

/**
 * "Save as draft" (a new draft), or "Update draft" for a draft opened from the Drafts tab; [hint]
 * says why a typed draft cannot be saved yet.
 */
@Composable
private fun DraftButton(
    isUpdate: Boolean,
    enabled: Boolean,
    saving: Boolean,
    hint: String?,
    category: ChoreCategory,
    strings: LocalizedText,
    onClick: () -> Unit,
) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        DraftButtonPill(isUpdate, enabled, saving, category, strings, onClick)
        AnimatedVisibility(hint != null, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
            var shown by remember { mutableStateOf(hint) }
            if (hint != null) shown = hint
            Text(shown.orEmpty(), style = FausCrewType.caption, color = FausCrewColors.textSecondary, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun DraftButtonPill(
    isUpdate: Boolean,
    enabled: Boolean,
    saving: Boolean,
    category: ChoreCategory,
    strings: LocalizedText,
    onClick: () -> Unit,
) {
    val tint = category.tintColor
    val hint = strings.catalog("chore_catalog_editor_draft_hint",
        "Taslaklar sekmesinde saklanır; istediğin zaman tekrar kullanabilirsin.", "Kept in Drafts so you can reuse it any time.")
    Row(
        Modifier.fillMaxWidth().height(48.dp).clip(CircleShape)
            .background(if (enabled) tint.copy(alpha = .12f) else FausCrewColors.secondaryBackground)
            .then(if (enabled) Modifier.dashedBorder(tint.copy(alpha = .55f), 24.dp, 1.2.dp, 6f, 4f) else Modifier)
            .catalogPress(.97f, enabled = enabled, onClick = onClick)
            .semantics { stateDescription = hint },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
    ) {
        val ink = if (enabled || saving) category.deepColor else FausCrewColors.textTertiary
        if (saving) {
            CircularProgressIndicator(Modifier.size(16.dp), color = ink, strokeWidth = 2.dp)
        } else {
            Icon(if (isUpdate) FausCrewIcons.arrowTriangle2Circlepath else Icons.Rounded.MoveToInbox, null, Modifier.size(18.dp), tint = ink)
        }
        Text(
            if (isUpdate) strings.catalog("chore_catalog_editor_update_draft", "Taslağı güncelle", "Update draft")
            else strings.catalog("chore_catalog_editor_save_draft", "Taslak olarak kaydet", "Save as draft"),
            fontSize = 15.sp, fontWeight = FontWeight.Bold, color = ink,
        )
    }
}

// MARK: - Repeat

@Composable
private fun RepeatChip(
    label: String,
    icon: ImageVector?,
    selected: Boolean,
    suggested: Boolean,
    category: ChoreCategory,
    onClick: () -> Unit,
) {
    val tint = category.tintColor
    Row(
        Modifier.height(34.dp).clip(CircleShape)
            .background(if (selected) category.gradient else SolidColor(FausCrewColors.secondaryBackground))
            .then(if (!selected && suggested) Modifier.border(1.dp, tint.copy(alpha = .45f), CircleShape) else Modifier)
            .catalogPress(.95f, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        val ink = if (selected) Color.White else FausCrewColors.textPrimary
        icon?.let { Icon(it, null, Modifier.size(13.dp), tint = ink) }
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = ink, maxLines = 1)
        if (suggested && !selected) Icon(FausCrewIcons.sparkles, null, Modifier.size(11.dp), tint = tint)
    }
}

/** iOS `Stepper`: a − | + segmented pill. */
@Composable
private fun IosStepper(value: Int, range: IntRange, onChange: (Int) -> Unit) {
    val shape = RoundedCornerShape(Radius.sm)
    Row(Modifier.height(32.dp).clip(shape).background(Color(0x1F767680)), verticalAlignment = Alignment.CenterVertically) {
        StepperHalf(FausCrewIcons.minus, value > range.first, "-") { onChange(value - 1) }
        Box(Modifier.width(1.dp).height(18.dp).background(FausCrewColors.separator))
        StepperHalf(FausCrewIcons.plus, value < range.last, "+") { onChange(value + 1) }
    }
}

@Composable
private fun StepperHalf(icon: ImageVector, enabled: Boolean, description: String, onClick: () -> Unit) {
    Box(
        Modifier.width(47.dp).height(32.dp).clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(18.dp),
            tint = if (enabled) FausCrewColors.textPrimary else FausCrewColors.textTertiary)
    }
}
