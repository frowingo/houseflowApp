package com.fauscrew.ui.dashboard.catalog

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.SearchOff
import androidx.compose.material.icons.rounded.MoveToInbox
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.PriorityHigh
import androidx.compose.material.icons.rounded.WifiOff
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import com.fauscrew.platform.ChoreCatalogFailure
import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCatalogRules
import com.fauscrew.platform.ChoreInput
import com.fauscrew.platform.HouseDetails
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.BackdropSurface
import com.fauscrew.ui.components.brandPopupHeaderBackground
import com.fauscrew.ui.components.mainScreenBackground
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Sizes
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow
import com.fauscrew.viewmodel.ChoreCatalogUiState
import com.fauscrew.viewmodel.ChoreCatalogViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Where the catalog popup opens (iOS `ChoreCatalogEntry`). */
internal sealed interface ChoreCatalogEntry {
    /** The user's Drafts tab. */
    data object Drafts : ChoreCatalogEntry
    /** A category shelf. */
    data class Category(val id: String) : ChoreCatalogEntry
    /** The blank editor, with the catalog behind it. */
    data object Custom : ChoreCatalogEntry
}

/** Summary of a chore created from the catalog, for the confirmation banner. */
internal data class ChoreCatalogCreation(val templateId: String, val title: String, val memberName: String, val repeatDays: Int)

/** What the banner at the bottom of the catalog confirms, or the request that failed (iOS `ChoreCatalogNotice`). */
internal data class ChoreCatalogNotice(val title: String, val kind: Kind, val stamp: Long = System.nanoTime()) {
    sealed interface Kind {
        data class Created(val memberName: String, val repeatDays: Int) : Kind
        data object DraftSaved : Kind
        data object DraftUpdated : Kind
        /** A draft delete the server refused; [message] is the server's localized text. */
        data class DeleteFailed(val message: String?) : Kind
    }
    val isDraft: Boolean get() = kind == Kind.DraftSaved || kind == Kind.DraftUpdated
    val isFailure: Boolean get() = kind is Kind.DeleteFailed
}

/** [template] is the card as it was opened, so a refresh behind the editor does not swap it. */
private data class EditorRoute(val templateId: String, val prefillTitle: String?, val template: ChoreTemplate)

/** What a shelf shows while the list is not there yet. */
private sealed interface ShelfStatus {
    data object Ready : ShelfStatus
    /** Skeleton cards only on the first load; later refreshes keep the list on screen. */
    data object FirstLoad : ShelfStatus
    data class Failed(val failure: ChoreCatalogFailure) : ShelfStatus
}

/** A create request in flight; [started] once `HouseViewModel` reported it busy. */
private data class PendingCreation(
    val creation: ChoreCatalogCreation,
    val startSerial: Long,
    val attempt: Int,
    val started: Boolean = false,
)

private const val DRAFTS_ID = "drafts"
private const val CREATED_KEY = "chore_created_toast"

/**
 * iOS `ChoreCatalogPopup`: the chore catalog as a large popup on the theme header. Picking a card
 * slides the editor in over the catalog; a created chore (or a saved draft) slides back with a
 * confirmation banner so several can be handled in a row. The first tab holds the user's drafts.
 * Shelves and drafts come from the server ([catalog]), fetched each time the popup opens and
 * whenever the app comes back to the foreground while it is open. The house state stays in
 * `HouseViewModel`: creation goes through [onCreate] and its outcome is read from
 * [mutationSerial] / [error].
 */
@Composable
internal fun ChoreCatalogPopup(
    entry: ChoreCatalogEntry,
    catalog: ChoreCatalogViewModel,
    details: HouseDetails,
    userId: String,
    strings: LocalizedText,
    busy: Boolean,
    error: String?,
    mutationSerial: Long,
    mutationMessageKey: String?,
    onCreate: (ChoreInput) -> Unit,
    onDismiss: () -> Unit,
) {
    val focus = LocalFocusManager.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val catalogState by catalog.state.collectAsStateWithLifecycle()
    var draftPendingDelete by remember { mutableStateOf<ChoreTemplate?>(null) }
    var selection by remember { mutableStateOf(if (entry is ChoreCatalogEntry.Category) entry.id else DRAFTS_ID) }
    var editor by remember {
        mutableStateOf(if (entry == ChoreCatalogEntry.Custom) {
            EditorRoute(ChoreCatalog.blankTemplate.id, null, ChoreCatalog.blankTemplate)
        } else null)
    }
    var query by remember { mutableStateOf("") }
    val addedCounts = remember { mutableStateMapOf<String, Int>() }
    var notice by remember { mutableStateOf<ChoreCatalogNotice?>(null) }
    var pending by remember { mutableStateOf<PendingCreation?>(null) }
    var editorError by remember { mutableStateOf<String?>(null) }
    var closing by remember { mutableStateOf(false) }
    var attempts by remember { mutableIntStateOf(0) }
    val appear = remember { Animatable(0f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, spring(dampingRatio = .82f, stiffness = 260f)) }
    // Resumed already when the popup opens, so this also runs the first fetch.
    LifecycleResumeEffect(userId) {
        scope.launch { catalog.refresh(userId) }
        onPauseOrDispose {}
    }

    val close: () -> Unit = {
        if (!closing) {
            closing = true
            focus.clearFocus()
            scope.launch {
                appear.animateTo(0f, tween(200))
                onDismiss()
            }
        }
    }
    val closeEditor: () -> Unit = { focus.clearFocus(); editor = null }

    val failedCopy = strings.catalog("chore_catalog_editor_error",
        "İş eklenemedi. Bağlantını kontrol edip tekrar dene.",
        "Couldn't add the chore. Check your connection and try again.")
    // Outcome of the create request the editor sent: a new serial with the created key is a
    // success, an error after the request started is a failure, and a request that ends with
    // neither (the house changed under it) is dropped.
    LaunchedEffect(mutationSerial, error, busy) {
        val request = pending ?: return@LaunchedEffect
        when {
            mutationSerial > request.startSerial && mutationMessageKey == CREATED_KEY -> {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                addedCounts[request.creation.templateId] = (addedCounts[request.creation.templateId] ?: 0) + 1
                pending = null
                editor = null
                notice = ChoreCatalogNotice(request.creation.title,
                    ChoreCatalogNotice.Kind.Created(request.creation.memberName, request.creation.repeatDays))
            }
            busy -> if (!request.started) pending = request.copy(started = true)
            request.started && error != null -> { pending = null; editorError = failedCopy }
            request.started -> pending = null
        }
    }
    // `HouseViewModel` ignores a request it cannot take (e.g. while the house reloads); never
    // leave the editor spinning on one that did not start.
    LaunchedEffect(pending?.attempt) {
        val attempt = pending?.attempt ?: return@LaunchedEffect
        delay(1_000)
        val request = pending
        if (request != null && request.attempt == attempt && !request.started) {
            pending = null
            editorError = failedCopy
        }
    }
    LaunchedEffect(notice) {
        if (notice != null) { delay(5_000); notice = null }
    }
    // Sends the draft; on success it lands on the Drafts tab, which the catalog shows on the way
    // back. A failure goes back to the editor, which stays open and shows it.
    val saveDraft: suspend (ChoreCatalogRecord) -> ChoreCatalogFailure? = save@{ record ->
        val isUpdate = record.id != null
        catalog.save(record)?.let { return@save it }
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        query = ""
        selection = DRAFTS_ID
        closeEditor()
        notice = ChoreCatalogNotice(ChoreCatalogRules.normalized(record.title),
            if (isUpdate) ChoreCatalogNotice.Kind.DraftUpdated else ChoreCatalogNotice.Kind.DraftSaved)
        null
    }
    // The card leaves at once; if the server refuses, it comes back with the reason.
    val deleteDraft: (ChoreTemplate) -> Unit = { template ->
        template.record?.let { record ->
            scope.launch {
                val failure = catalog.delete(record) ?: return@launch
                if (failure.refreshesList) return@launch
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                notice = ChoreCatalogNotice(template.title, ChoreCatalogNotice.Kind.DeleteFailed(failure.message))
            }
        }
    }

    draftPendingDelete?.let { draft ->
        AlertDialog(
            onDismissRequest = { draftPendingDelete = null },
            title = { Text(strings.catalog("chore_catalog_draft_delete_title", "Taslak silinsin mi?", "Delete this draft?")) },
            text = {
                Text(strings.catalog("chore_catalog_draft_delete_message",
                    "“{title}” taslaklarından kaldırılacak. Eklediğin işler etkilenmez.",
                    "“{title}” will be removed from your drafts. Chores you added stay as they are.")
                    .replace("{title}", draft.title))
            },
            confirmButton = {
                TextButton(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    draftPendingDelete = null
                    deleteDraft(draft)
                }) {
                    Text(strings.catalog("chore_catalog_draft_delete_confirm", "Sil", "Delete"), color = FausCrewColors.error,
                        fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { draftPendingDelete = null }) {
                    Text(strings.get("common_cancel", "Cancel"), color = FausCrewColors.textPrimary)
                }
            },
            containerColor = FausCrewColors.elevatedSurface,
            titleContentColor = FausCrewColors.textPrimary,
            textContentColor = FausCrewColors.textSecondary,
        )
    }

    Dialog(
        onDismissRequest = { if (editor != null) closeEditor() else close() },
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        SideEffect {
            window?.setDimAmount(0f)
            @Suppress("DEPRECATION")
            window?.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        }
        val shape = RoundedCornerShape(30.dp)
        Box(
            Modifier.fillMaxSize()
                .graphicsLayer { alpha = appear.value.coerceIn(0f, 1f) }
                .background(FausCrewColors.scrim)
                .clickable(remember { MutableInteractionSource() }, indication = null, onClick = close)
                .systemBarsPadding()
                .imePadding(),
        ) {
            Box(
                Modifier.fillMaxSize()
                    .padding(start = 12.dp, end = 12.dp, top = Spacing.sm, bottom = Spacing.md)
                    .graphicsLayer {
                        val value = appear.value
                        val scale = .92f + .08f * value
                        scaleX = scale; scaleY = scale
                        translationY = (1f - value) * 40.dp.toPx()
                    }
                    .softShadow(FausCrewColors.shadow.copy(alpha = .32f), 32.dp, y = 18.dp, shape = shape)
                    .clip(shape)
                    .mainScreenBackground(BackdropSurface.POPUP)
                    .border(1.dp, Brush.verticalGradient(listOf(Color.White.copy(alpha = .35f), Color.White.copy(alpha = .05f))), shape)
                    // Taps on the card never reach the dismissing backdrop.
                    .clickable(remember { MutableInteractionSource() }, indication = null) { focus.clearFocus() },
            ) {
                val pushed by animateFloatAsState(if (editor == null) 0f else 1f, spring(dampingRatio = .88f, stiffness = 300f), label = "catalogPush")
                CatalogPage(
                    selection = selection,
                    query = query,
                    strings = strings,
                    addedCounts = addedCounts,
                    catalogState = catalogState,
                    notice = notice,
                    onRetry = { scope.launch { catalog.refresh(userId) } },
                    onDeleteDraft = { template -> draftPendingDelete = template },
                    onSelect = { id ->
                        if (id != selection) {
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            selection = id
                        }
                    },
                    onQuery = { query = it },
                    onOpen = { route ->
                        focus.clearFocus()
                        haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        editorError = null
                        editor = route
                    },
                    onClose = close,
                    onDismissNotice = { notice = null },
                    modifier = Modifier.graphicsLayer {
                        translationX = -70.dp.toPx() * pushed
                        alpha = 1f - pushed
                    },
                )

                var shownRoute by remember { mutableStateOf(editor) }
                if (editor != null) shownRoute = editor
                AnimatedVisibility(
                    visible = editor != null,
                    enter = slideInHorizontally(spring(dampingRatio = .88f, stiffness = 300f)) { it },
                    exit = slideOutHorizontally(spring(dampingRatio = .88f, stiffness = 300f)) { it },
                ) {
                    val route = shownRoute ?: return@AnimatedVisibility
                    val template = route.template
                    val category = ChoreCatalog.category(template.categoryId) ?: ChoreCatalog.categories.first()
                    ChoreTemplateEditor(
                        template = template,
                        templateCategory = category,
                        prefillTitle = route.prefillTitle,
                        details = details,
                        userId = userId,
                        strings = strings,
                        submitting = pending != null || busy,
                        errorMessage = editorError,
                        onBack = closeEditor,
                        onClose = close,
                        onSubmit = { input, creation ->
                            editorError = null
                            attempts += 1
                            pending = PendingCreation(creation, mutationSerial, attempts)
                            onCreate(input)
                        },
                        onSaveDraft = saveDraft,
                        modifier = Modifier.fillMaxSize().mainScreenBackground(BackdropSurface.POPUP),
                    )
                }
            }
        }
    }
}

// MARK: - Catalog page

@Composable
private fun CatalogPage(
    selection: String,
    query: String,
    strings: LocalizedText,
    addedCounts: Map<String, Int>,
    catalogState: ChoreCatalogUiState,
    notice: ChoreCatalogNotice?,
    onRetry: () -> Unit,
    onDeleteDraft: (ChoreTemplate) -> Unit,
    onSelect: (String) -> Unit,
    onQuery: (String) -> Unit,
    onOpen: (EditorRoute) -> Unit,
    onClose: () -> Unit,
    onDismissNotice: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val trimmed = query.trim()
    val systemTemplates = remember(catalogState.records) { catalogState.systemRecords.map(ChoreTemplate::of) }
    val draftTemplates = remember(catalogState.records) { catalogState.userRecords.map(ChoreTemplate::of) }
    val phase = catalogState.phase
    val status = when {
        !catalogState.hasLoaded && phase is ChoreCatalogUiState.Phase.Failed -> ShelfStatus.Failed(phase.failure)
        !catalogState.hasLoaded && (phase == ChoreCatalogUiState.Phase.Loading || phase == ChoreCatalogUiState.Phase.Idle) ->
            ShelfStatus.FirstLoad
        else -> ShelfStatus.Ready
    }
    val retrying = phase == ChoreCatalogUiState.Phase.Loading
    Column(modifier.fillMaxSize()) {
        CatalogHeader(selection, query, trimmed.isEmpty(), strings, onSelect, onQuery, onClose)
        Box(Modifier.weight(1f).fillMaxWidth()) {
            val contentKey = if (trimmed.isNotEmpty()) "search" else selection
            AnimatedContent(
                targetState = contentKey,
                transitionSpec = {
                    (fadeIn(tween(220)) + slideInVertically(tween(260)) { it / 40 }) togetherWith fadeOut(tween(120))
                },
                label = "catalogShelf",
            ) { key ->
                val bottomPadding = if (notice == null) Spacing.xxl else 104.dp
                when (key) {
                    "search" -> SearchResults(trimmed, draftTemplates + systemTemplates, strings, addedCounts, bottomPadding,
                        onOpen, onDeleteDraft)
                    // The user's saved chores; empty until they save one.
                    DRAFTS_ID -> ShelfGrid(draftTemplates, true, status, retrying, strings, addedCounts, bottomPadding, onRetry,
                        onOpen, onDeleteDraft) { DraftsEmptyCard(strings) }
                    else -> {
                        val category = ChoreCatalog.category(key)
                        ShelfGrid(systemTemplates.filter { it.categoryId == key }, false, status, retrying, strings, addedCounts,
                            bottomPadding, onRetry, onOpen, onDeleteDraft) {
                            if (category != null) {
                                CatalogStatusCard(
                                    icon = category.iconVector,
                                    tint = category.tintColor,
                                    title = strings.catalog("chore_catalog_shelf_empty", "Bu rafta henüz hazır iş yok",
                                        "No ready-made chores here yet"),
                                    detail = strings.catalog("chore_catalog_shelf_empty_detail",
                                        "Aşağıdan kendi işini oluşturabilirsin.", "You can create your own chore below."),
                                )
                            }
                        }
                    }
                }
            }
            androidx.compose.animation.AnimatedVisibility(
                visible = notice != null,
                modifier = Modifier.align(Alignment.BottomCenter),
                enter = slideInVertically(spring(dampingRatio = .82f, stiffness = 300f)) { it } + fadeIn(),
                exit = slideOutVertically(tween(220)) { it } + fadeOut(),
            ) {
                var shown by remember { mutableStateOf(notice) }
                if (notice != null) shown = notice
                shown?.let { NoticeBanner(it, strings, onDone = onClose, onDismiss = onDismissNotice) }
            }
        }
    }
}

@Composable
private fun CatalogHeader(
    selection: String,
    query: String,
    showsChips: Boolean,
    strings: LocalizedText,
    onSelect: (String) -> Unit,
    onQuery: (String) -> Unit,
    onClose: () -> Unit,
) {
    val selectedCategory = ChoreCatalog.categories.firstOrNull { it.id == selection }
    val subtitle = selectedCategory?.let(strings::catalogTagline)
        ?: strings.catalog("chore_catalog_drafts_subtitle", "Kaydettiğin işler, tek dokunuşla hazır", "Your saved chores, one tap away")
    Column(
        Modifier.fillMaxWidth().brandPopupHeaderBackground().padding(top = Spacing.lg, bottom = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Row(Modifier.padding(horizontal = Spacing.lg), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            val tile = RoundedCornerShape(15.dp)
            Box(Modifier.size(46.dp).clip(tile).background(Color.White.copy(alpha = .2f))
                .border(1.dp, Color.White.copy(alpha = .3f), tile), contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.GridView, null, Modifier.size(22.dp), tint = Color.White)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(strings.catalog("chore_catalog_title", "İş Kataloğu", "Chore Catalog"), fontSize = 22.sp,
                    fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1)
                // Fixed line box: a longer tagline truncates instead of resizing the header.
                Text(subtitle, Modifier.height(18.dp), fontSize = 13.sp, fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = .85f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            HeaderCircleButton(FausCrewIcons.xmark, strings.get("common_close", "Close"), onClose)
        }
        CatalogSearchField(query, strings, onQuery, Modifier.padding(horizontal = Spacing.lg))
        AnimatedVisibility(showsChips, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
            ChipRail(selection, strings, onSelect)
        }
    }
}

@Composable
internal fun HeaderCircleButton(icon: ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier.size(32.dp).clip(CircleShape).background(Color.White.copy(alpha = .2f))
            .catalogPress(onClick = onClick).semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(15.dp), tint = Color.White)
    }
}

@Composable
private fun CatalogSearchField(query: String, strings: LocalizedText, onQuery: (String) -> Unit, modifier: Modifier) {
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val shape = RoundedCornerShape(14.dp)
    BasicTextField(
        value = query,
        onValueChange = onQuery,
        modifier = modifier.fillMaxWidth(),
        singleLine = true,
        textStyle = TextStyle(color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium),
        cursorBrush = SolidColor(Color.White),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search, autoCorrectEnabled = false),
        interactionSource = interaction,
        decorationBox = { inner ->
            Row(
                Modifier.fillMaxWidth().height(42.dp).clip(shape)
                    .background(Color.White.copy(alpha = if (focused) .26f else .18f))
                    .border(1.dp, Color.White.copy(alpha = if (focused) .55f else .22f), shape)
                    .padding(horizontal = Spacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Icon(FausCrewIcons.magnifyingGlass, null, Modifier.size(18.dp), tint = Color.White.copy(alpha = .8f))
                Box(Modifier.weight(1f)) {
                    if (query.isEmpty()) {
                        Text(strings.catalog("chore_catalog_search_placeholder", "İş ara: bulaşık, köpek, çöp…", "Search: dishes, dog, trash…"),
                            fontSize = 15.sp, fontWeight = FontWeight.Medium, color = Color.White.copy(alpha = .62f), maxLines = 1)
                    }
                    inner()
                }
                if (query.isNotEmpty()) {
                    val clear = strings.catalog("chore_catalog_search_clear", "Aramayı temizle", "Clear search")
                    Icon(FausCrewIcons.xmarkCircleFill, null,
                        Modifier.size(18.dp).clip(CircleShape).clickable(role = Role.Button) { onQuery("") }
                            .semantics { contentDescription = clear },
                        tint = Color.White.copy(alpha = .8f))
                }
            }
        },
    )
}

@Composable
private fun ChipRail(selection: String, strings: LocalizedText, onSelect: (String) -> Unit) {
    data class Chip(val id: String, val icon: ImageVector, val title: String, val ink: Color)
    val chips = buildList {
        add(Chip(DRAFTS_ID, Icons.Rounded.Inbox, strings.catalog("chore_catalog_drafts_chip", "Taslaklar", "Drafts"),
            FausCrewColors.accentOrangeDeep))
        ChoreCatalog.categories.forEach { add(Chip(it.id, it.iconVector, strings.catalogName(it), it.deepColor)) }
    }
    val listState = rememberLazyListState()
    LaunchedEffect(selection) {
        val index = chips.indexOfFirst { it.id == selection }.coerceAtLeast(0)
        listState.animateScrollToItem((index - 1).coerceAtLeast(0))
    }
    LazyRow(
        Modifier.fillMaxWidth().height(38.dp),
        state = listState,
        contentPadding = PaddingValues(horizontal = Spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        itemsIndexed(chips, key = { _, chip -> chip.id }) { _, chip ->
            val selected = chip.id == selection
            Row(
                Modifier.height(34.dp)
                    .then(if (selected) Modifier.softShadow(Color.Black.copy(alpha = .18f), 6.dp, y = 3.dp, shape = CircleShape) else Modifier)
                    .clip(CircleShape)
                    .background(if (selected) Color.White else Color.White.copy(alpha = .16f))
                    .border(1.dp, Color.White.copy(alpha = if (selected) 0f else .22f), CircleShape)
                    .catalogPress(.95f, role = Role.Tab) { onSelect(chip.id) }
                    .semantics { this.selected = selected }
                    .padding(horizontal = 13.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                val ink = if (selected) chip.ink else Color.White
                Icon(chip.icon, null, Modifier.size(14.dp), tint = ink)
                Text(chip.title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = ink, maxLines = 1)
            }
        }
    }
}

// MARK: - Shelves

/** Error card, skeleton or the shelf's cards ([empty] when the shelf has none). */
@Composable
private fun ShelfGrid(
    templates: List<ChoreTemplate>,
    showsCategory: Boolean,
    status: ShelfStatus,
    retrying: Boolean,
    strings: LocalizedText,
    addedCounts: Map<String, Int>,
    bottomPadding: androidx.compose.ui.unit.Dp,
    onRetry: () -> Unit,
    onOpen: (EditorRoute) -> Unit,
    onDeleteDraft: (ChoreTemplate) -> Unit,
    empty: @Composable () -> Unit,
) {
    when (status) {
        is ShelfStatus.Failed -> TemplateGrid(emptyList(), showsCategory, strings, addedCounts, bottomPadding, onOpen, onDeleteDraft,
            footer = {
                // The list could not be fetched: the server's message (or a connection hint) and a retry.
                CatalogStatusCard(
                    icon = Icons.Rounded.WifiOff,
                    tint = FausCrewColors.error,
                    title = strings.catalog("chore_catalog_load_failed", "Katalog yüklenemedi", "Couldn't load the catalog"),
                    detail = status.failure.message ?: strings.catalog("chore_catalog_load_failed_detail",
                        "Bağlantını kontrol edip tekrar dene.", "Check your connection and try again."),
                    actionTitle = strings.catalog("chore_catalog_retry", "Tekrar dene", "Try again"),
                    busy = retrying,
                    onAction = onRetry,
                )
            })
        ShelfStatus.FirstLoad -> TemplateGrid(emptyList(), showsCategory, strings, addedCounts, bottomPadding, onOpen, onDeleteDraft,
            skeletons = 4, skeletonDescription = strings.catalog("chore_catalog_loading", "Katalog yükleniyor", "Loading the catalog"))
        ShelfStatus.Ready -> TemplateGrid(templates, showsCategory, strings, addedCounts, bottomPadding, onOpen, onDeleteDraft,
            footer = if (templates.isEmpty()) empty else null)
    }
}

@Composable
private fun TemplateGrid(
    templates: List<ChoreTemplate>,
    showsCategory: Boolean,
    strings: LocalizedText,
    addedCounts: Map<String, Int>,
    bottomPadding: androidx.compose.ui.unit.Dp,
    onOpen: (EditorRoute) -> Unit,
    onDeleteDraft: (ChoreTemplate) -> Unit,
    header: (@Composable () -> Unit)? = null,
    footer: (@Composable () -> Unit)? = null,
    /** Placeholder cards while the first list is on its way. */
    skeletons: Int = 0,
    skeletonDescription: String = "",
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = Spacing.lg, end = Spacing.lg, top = Spacing.lg, bottom = bottomPadding),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        header?.let { content -> item(span = { GridItemSpan(maxLineSpan) }) { content() } }
        items(skeletons, key = { "skeleton.$it" }) {
            ChoreTemplateSkeletonTile(Modifier.semantics { contentDescription = skeletonDescription })
        }
        items(templates, key = { it.id }) { template ->
            val category = ChoreCatalog.category(template.categoryId) ?: return@items
            // Catalog templates and drafts share the grid; a draft card also offers delete, and a
            // system template carries a lock (it is read-only; saving it makes a draft).
            ChoreTemplateTile(template, category, strings, showsCategory, addedCounts[template.id] ?: 0,
                onTap = { onOpen(EditorRoute(template.id, null, template)) },
                onDelete = if (template.isDraft) { { onDeleteDraft(template) } } else null,
                modifier = Modifier.animateItem())
        }
        footer?.let { content -> item(span = { GridItemSpan(maxLineSpan) }) { content() } }
        item(span = { GridItemSpan(maxLineSpan) }) {
            CustomChoreCard(strings, Modifier.padding(top = Spacing.xs)) {
                onOpen(EditorRoute(ChoreCatalog.blankTemplate.id, null, ChoreCatalog.blankTemplate))
            }
        }
    }
}

@Composable
private fun SearchResults(
    query: String,
    templates: List<ChoreTemplate>,
    strings: LocalizedText,
    addedCounts: Map<String, Int>,
    bottomPadding: androidx.compose.ui.unit.Dp,
    onOpen: (EditorRoute) -> Unit,
    onDeleteDraft: (ChoreTemplate) -> Unit,
) {
    val results = remember(query, strings, templates) {
        ChoreCatalog.search(query, templates) { strings.catalogTitle(it) to strings.catalogDetail(it) }
    }
    if (results.isEmpty()) {
        Column(
            Modifier.fillMaxSize().padding(horizontal = Spacing.lg, vertical = Spacing.huge),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Icon(Icons.Rounded.SearchOff, null, Modifier.size(44.dp), tint = FausCrewColors.pageTextTertiary)
            Text(strings.catalog("chore_catalog_search_empty", "Katalogda bulamadık", "Not in the catalog"),
                style = FausCrewType.headline, color = FausCrewColors.pageText)
            Text(strings.catalog("chore_catalog_search_empty_detail", "Sorun değil, bu işi kendin oluşturabilirsin.",
                "No problem, you can create this chore yourself."), style = FausCrewType.subheadline,
                color = FausCrewColors.pageTextSecondary, textAlign = TextAlign.Center)
            val create = strings.catalog("chore_catalog_search_create", "“{query}” işini oluştur", "Create “{query}”")
                .replace("{query}", query)
            Row(
                Modifier.padding(top = Spacing.sm).height(Sizes.buttonHeightSmall).clip(CircleShape)
                    .background(Brush.horizontalGradient(LocalFausTheme.current.decor.fabColors))
                    .catalogPress(.97f) { onOpen(EditorRoute(ChoreCatalog.blankTemplate.id, query, ChoreCatalog.blankTemplate)) }
                    .padding(horizontal = Spacing.xl),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(FausCrewIcons.plus, null, Modifier.size(16.dp), tint = FausCrewColors.onAccent)
                Text(create, style = FausCrewType.headline, color = FausCrewColors.onAccent, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    } else {
        val tint = LocalFausTheme.current.decor.accentOnCard ?: FausCrewColors.accentOrangeInk
        TemplateGrid(results, true, strings, addedCounts, bottomPadding, onOpen, onDeleteDraft, header = {
            CatalogSectionHeader(
                strings.catalog("chore_catalog_search_results", "{count} sonuç", "{count} results")
                    .replace("{count}", results.size.toString()),
                tint,
            )
        })
    }
}

@Composable
private fun DraftsEmptyCard(strings: LocalizedText) {
    val tint = LocalFausTheme.current.decor.accentOnCard ?: FausCrewColors.accentOrangeInk
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.lg))
            .background(FausCrewColors.cardBackground.copy(alpha = .7f))
            .semantics(mergeDescendants = true) {}
            .padding(horizontal = Spacing.lg, vertical = Spacing.xxl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(Modifier.size(60.dp).background(tint.copy(alpha = .12f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Rounded.Inbox, null, Modifier.size(28.dp), tint = tint)
        }
        Text(strings.catalog("chore_catalog_drafts_empty", "Henüz taslağın yok", "No drafts yet"),
            style = FausCrewType.headline, color = FausCrewColors.pageText)
        Text(strings.catalog("chore_catalog_drafts_empty_detail",
            "Kategorilerden bir işi aç ve “Taslak olarak kaydet”e dokun; burada seni bekler.",
            "Open a chore from the categories and tap “Save as draft”; it will wait for you here."),
            style = FausCrewType.subheadline, color = FausCrewColors.pageTextSecondary, textAlign = TextAlign.Center)
    }
}

@Composable
private fun CustomChoreCard(strings: LocalizedText, modifier: Modifier, onClick: () -> Unit) {
    val tint = FausCrewColors.pageTextSecondary
    Row(
        modifier.fillMaxWidth().dashedBorder(tint.copy(alpha = .35f), Radius.lg, dash = 6f, gap = 5f)
            .catalogPress(.98f, onClick = onClick)
            .padding(Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(Modifier.size(44.dp).clip(RoundedCornerShape(14.dp)).background(tint.copy(alpha = .12f)), contentAlignment = Alignment.Center) {
            Icon(FausCrewIcons.pencilCircleFill, null, Modifier.size(22.dp), tint = tint)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(strings.catalog("chore_catalog_custom_title", "Aradığın burada yok mu?", "Can't find it here?"),
                style = FausCrewType.headline, color = FausCrewColors.pageText)
            Text(strings.catalog("chore_catalog_custom_subtitle", "Kendi işini sıfırdan oluştur.", "Create your own chore from scratch."),
                style = FausCrewType.caption, color = FausCrewColors.pageTextSecondary)
        }
        Icon(FausCrewIcons.chevronRight, null, Modifier.size(18.dp), tint = FausCrewColors.pageTextTertiary)
    }
}

// MARK: - Confirmation banner

@Composable
private fun NoticeBanner(notice: ChoreCatalogNotice, strings: LocalizedText, onDone: () -> Unit, onDismiss: () -> Unit) {
    val shape = RoundedCornerShape(Radius.xl)
    val accent = if (notice.isFailure) FausCrewColors.error else FausCrewColors.success
    Row(
        Modifier.padding(Spacing.md).fillMaxWidth()
            .softShadow(FausCrewColors.shadow.copy(alpha = .22f), 18.dp, y = 8.dp, shape = shape)
            .clip(shape).background(FausCrewColors.elevatedSurface)
            .border(1.dp, accent.copy(alpha = .35f), shape)
            .padding(start = Spacing.md, end = Spacing.sm, top = Spacing.sm, bottom = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Box(Modifier.size(36.dp).background(accent, CircleShape), contentAlignment = Alignment.Center) {
            val icon = when {
                notice.isFailure -> Icons.Rounded.PriorityHigh
                notice.isDraft -> Icons.Rounded.MoveToInbox
                else -> FausCrewIcons.checkmark
            }
            Icon(icon, null, Modifier.size(18.dp), tint = Color.White)
        }
        val title = when (notice.kind) {
            is ChoreCatalogNotice.Kind.Created ->
                strings.catalog("chore_catalog_created_title", "“{title}” eklendi", "“{title}” added")
            ChoreCatalogNotice.Kind.DraftSaved -> strings.catalog("chore_catalog_draft_saved_title",
                "“{title}” taslak olarak kaydedildi", "“{title}” saved as a draft")
            ChoreCatalogNotice.Kind.DraftUpdated -> strings.catalog("chore_catalog_draft_updated_title",
                "“{title}” taslağı güncellendi", "“{title}” draft updated")
            is ChoreCatalogNotice.Kind.DeleteFailed -> strings.catalog("chore_catalog_draft_delete_failed_title",
                "“{title}” silinemedi", "Couldn't delete “{title}”")
        }.replace("{title}", notice.title)
        val subtitle = when (val kind = notice.kind) {
            is ChoreCatalogNotice.Kind.Created -> "${kind.memberName} · ${strings.catalogRepeatLabel(kind.repeatDays)}"
            is ChoreCatalogNotice.Kind.DeleteFailed -> kind.message ?: strings.catalog("chore_catalog_request_failed_detail",
                "Bağlantını kontrol edip tekrar dene.", "Check your connection and try again.")
            else -> strings.catalog("chore_catalog_draft_saved_detail", "Taslaklar sekmesinde seni bekliyor", "Waiting for you in Drafts")
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = FausCrewColors.textPrimary,
                maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(subtitle, style = FausCrewType.caption,
                color = FausCrewColors.textSecondary, maxLines = if (notice.isFailure) 2 else 1, overflow = TextOverflow.Ellipsis)
        }
        Box(
            Modifier.height(34.dp).clip(CircleShape)
                .background(Brush.horizontalGradient(LocalFausTheme.current.decor.fabColors))
                .catalogPress(onClick = if (notice.isFailure) onDismiss else onDone).padding(horizontal = 14.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(if (notice.isFailure) strings.catalog("chore_catalog_notice_ok", "Tamam", "OK")
                else strings.catalog("chore_catalog_created_done", "Bitti", "Done"), fontSize = 14.sp,
                fontWeight = FontWeight.Bold, color = FausCrewColors.onAccent)
        }
    }
}
