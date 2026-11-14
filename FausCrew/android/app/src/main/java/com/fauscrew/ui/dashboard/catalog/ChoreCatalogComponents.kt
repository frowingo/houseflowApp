package com.fauscrew.ui.dashboard.catalog

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.ui.text.style.TextAlign
import com.fauscrew.ui.theme.FausCrewType
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.LooksOne
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow

/** iOS `CatalogPressStyle`: a borderless tap target that springs to [scale] while pressed. */
internal fun Modifier.catalogPress(
    scale: Float = .94f,
    enabled: Boolean = true,
    role: Role = Role.Button,
    onClick: () -> Unit,
): Modifier = composed {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val value by animateFloatAsState(if (pressed) scale else 1f, spring(dampingRatio = .65f, stiffness = 520f), label = "catalogPress")
    graphicsLayer { scaleX = value; scaleY = value }
        .clickable(interaction, indication = null, enabled = enabled, role = role, onClick = onClick)
}

/** Dashed rounded outline (`StrokeStyle(dash:)`). */
internal fun Modifier.dashedBorder(color: Color, radius: Dp, width: Dp = 1.2.dp, dash: Float = 5f, gap: Float = 4f): Modifier =
    drawBehind {
        val stroke = width.toPx()
        drawRoundRect(
            color = color,
            topLeft = androidx.compose.ui.geometry.Offset(stroke / 2, stroke / 2),
            size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke),
            cornerRadius = CornerRadius(radius.toPx()),
            style = Stroke(stroke, pathEffect = PathEffect.dashPathEffect(floatArrayOf(dash.dp.toPx(), gap.dp.toPx()))),
        )
    }

/** `ChoreCategoryGlyph`: rounded tile painted with the category gradient and its symbol. */
@Composable
internal fun ChoreCategoryGlyph(category: ChoreCategory, size: Dp, icon: ImageVector = category.iconVector) {
    val shape = RoundedCornerShape(size * .32f)
    Box(
        Modifier.size(size)
            .softShadow(category.deepColor.copy(alpha = .28f), size * .14f, y = size * .08f, shape = shape)
            .clip(shape)
            .background(category.gradient)
            .background(Brush.verticalGradient(0f to Color.White.copy(alpha = .28f), .5f to Color.White.copy(alpha = 0f))),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(size * .5f), tint = Color.White)
    }
}

/** Small tinted pill for repeat / duration hints. */
@Composable
internal fun ChoreMetaPill(icon: ImageVector, text: String, tint: Color = FausCrewColors.textSecondary) {
    Row(
        Modifier.clip(CircleShape).background(tint.copy(alpha = .11f)).padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(icon, null, Modifier.size(10.dp), tint = tint)
        Text(text, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = tint, maxLines = 1, softWrap = false)
    }
}

/**
 * `ChoreTemplateTile`: glyph, title, detail and the repeat pill on a category-tinted card. A
 * system template carries a small lock on its glyph (read-only; saving it makes a draft), a
 * draft offers delete.
 */
@Composable
internal fun ChoreTemplateTile(
    template: ChoreTemplate,
    category: ChoreCategory,
    strings: LocalizedText,
    showsCategory: Boolean,
    addedCount: Int,
    onTap: () -> Unit,
    /** Set for the user's drafts: shows a delete button in the corner. */
    onDelete: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(Radius.lg)
    val tint = category.tintColor
    val highlighted = addedCount > 0
    val hint = strings.catalog("chore_catalog_template_accessibility_hint", "Düzenlemek ve atamak için aç", "Opens it to adjust and assign")
    val title = strings.catalogTitle(template)
    val systemBadge = if (template.isSystem) {
        ". " + strings.catalog("chore_catalog_system_badge", "Hazır şablon", "Ready-made template")
    } else ""
    Box(modifier.fillMaxWidth().height(if (showsCategory) 204.dp else 190.dp)) {
    Column(
        Modifier.fillMaxSize()
            .softShadow(tint.copy(alpha = .14f), 10.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.cardBackground)
            .background(Brush.linearGradient(listOf(tint.copy(alpha = .09f), Color.Transparent)))
            .border(if (highlighted) 1.5.dp else 1.dp, if (highlighted) FausCrewColors.success.copy(alpha = .55f) else tint.copy(alpha = .18f), shape)
            .catalogPress(.97f, onClick = onTap)
            .semantics { contentDescription = "$title$systemBadge. $hint" }
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Box {
                ChoreCategoryGlyph(category, 40.dp, template.iconVector)
                if (template.isSystem) {
                    Box(
                        Modifier.align(Alignment.BottomEnd).offset(4.dp, 4.dp).size(16.dp).clip(CircleShape)
                            .background(FausCrewColors.cardBackground)
                            .border(1.dp, tint.copy(alpha = .35f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Rounded.Lock, null, Modifier.size(9.dp), tint = category.deepColor)
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            if (highlighted) {
                Row(
                    Modifier.heightIn(min = 26.dp).widthIn(min = 26.dp).clip(CircleShape)
                        .background(FausCrewColors.success).padding(horizontal = 7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterHorizontally),
                ) {
                    Icon(FausCrewIcons.checkmark, null, Modifier.size(12.dp), tint = Color.White)
                    if (addedCount > 1) Text("×$addedCount", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color.White)
                }
            } else if (onDelete == null) {
                Box(Modifier.size(26.dp).clip(CircleShape).background(tint.copy(alpha = .13f)), contentAlignment = Alignment.Center) {
                    Icon(FausCrewIcons.plus, null, Modifier.size(14.dp), tint = tint)
                }
            }
            // Room for the delete button laid over the card.
            if (onDelete != null) Spacer(Modifier.padding(start = 4.dp).size(28.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            if (showsCategory) {
                val line = if (template.isDraft) {
                    strings.catalog("chore_catalog_draft_badge", "Taslak", "Draft") + " · " + strings.catalogName(category)
                } else strings.catalogName(category)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    if (template.isDraft) Icon(FausCrewIcons.pencilCircleFill, null, Modifier.size(11.dp), tint = tint)
                    Text(line.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.Bold,
                        letterSpacing = .4.sp, color = tint, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            Text(title, fontSize = 15.sp, lineHeight = 19.sp, fontWeight = FontWeight.SemiBold,
                color = FausCrewColors.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(strings.catalogDetail(template), fontSize = 12.sp, lineHeight = 15.sp, color = FausCrewColors.textSecondary,
                maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.weight(1f))
        ChoreMetaPill(
            if (template.repeatDays > 0) FausCrewIcons.arrowClockwise else Icons.Rounded.LooksOne,
            strings.catalogRepeatLabel(template.repeatDays),
            if (template.repeatDays > 0) tint else FausCrewColors.textSecondary,
        )
    }
    if (onDelete != null) {
        val description = strings.catalog("chore_catalog_draft_delete", "Taslağı sil", "Delete draft")
        Box(
            Modifier.align(Alignment.TopEnd).padding(Spacing.md).size(28.dp).clip(CircleShape)
                .background(FausCrewColors.error.copy(alpha = .12f))
                .catalogPress(.9f, onClick = onDelete)
                .semantics { contentDescription = description },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.DeleteOutline, null, Modifier.size(16.dp), tint = FausCrewColors.error)
        }
    }
    }
}

/** Placeholder card while the first list is on its way (iOS `ChoreTemplateSkeletonTile`). */
@Composable
internal fun ChoreTemplateSkeletonTile(modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Radius.lg)
    val bar = FausCrewColors.textTertiary.copy(alpha = .16f)
    val pulse = rememberInfiniteTransition(label = "skeleton")
    val alpha by pulse.animateFloat(1f, .55f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "skeletonAlpha")
    Column(
        modifier.fillMaxWidth().height(190.dp)
            .graphicsLayer { this.alpha = alpha }
            .clip(shape).background(FausCrewColors.cardBackground)
            .border(1.dp, FausCrewColors.hairline, shape)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(Modifier.size(40.dp).clip(RoundedCornerShape(13.dp)).background(bar))
        Box(Modifier.fillMaxWidth().height(14.dp).clip(RoundedCornerShape(5.dp)).background(bar))
        Box(Modifier.width(90.dp).height(14.dp).clip(RoundedCornerShape(5.dp)).background(bar))
        Box(Modifier.fillMaxWidth().height(10.dp).clip(RoundedCornerShape(4.dp)).background(bar.copy(alpha = bar.alpha * .7f)))
        Spacer(Modifier.weight(1f))
        Box(Modifier.width(70.dp).height(18.dp).clip(CircleShape).background(bar))
    }
}

/**
 * A full-width message card in the Drafts empty-card style (iOS `CatalogStatusCard`): an empty
 * shelf, or a list that could not be loaded (with a retry).
 */
@Composable
internal fun CatalogStatusCard(
    icon: ImageVector,
    tint: Color,
    title: String,
    detail: String,
    modifier: Modifier = Modifier,
    actionTitle: String? = null,
    busy: Boolean = false,
    onAction: (() -> Unit)? = null,
) {
    Column(
        modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.lg))
            .background(FausCrewColors.cardBackground.copy(alpha = .7f))
            .padding(horizontal = Spacing.lg, vertical = Spacing.xxl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Column(Modifier.semantics(mergeDescendants = true) {}, horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(Modifier.size(60.dp).background(tint.copy(alpha = .12f), CircleShape), contentAlignment = Alignment.Center) {
                Icon(icon, null, Modifier.size(26.dp), tint = tint)
            }
            Text(title, style = FausCrewType.headline, color = FausCrewColors.pageText, textAlign = TextAlign.Center)
            Text(detail, style = FausCrewType.subheadline, color = FausCrewColors.pageTextSecondary, textAlign = TextAlign.Center)
        }
        if (actionTitle != null && onAction != null) {
            Row(
                Modifier.padding(top = Spacing.xs).height(36.dp).clip(CircleShape)
                    .background(tint.copy(alpha = .12f))
                    .catalogPress(.96f, enabled = !busy, onClick = onAction)
                    .padding(horizontal = Spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                if (busy) {
                    CircularProgressIndicator(Modifier.size(14.dp), color = tint, strokeWidth = 2.dp)
                } else {
                    Icon(FausCrewIcons.arrowClockwise, null, Modifier.size(14.dp), tint = tint)
                }
                Text(actionTitle, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = tint)
            }
        }
    }
}

/** Uppercase section caption (`CatalogSectionHeader`). */
@Composable
internal fun CatalogSectionHeader(title: String, tint: Color) {
    Text(title.uppercase(), Modifier.fillMaxWidth().semantics { heading() }, fontSize = 12.sp,
        fontWeight = FontWeight.Bold, letterSpacing = .6.sp, color = tint)
}

/**
 * `ChoreCatalogMosaicButton`: the small catalog entry in the corner of Today's tasks, a 2×2
 * mosaic of category colours with a plus badge.
 */
@Composable
internal fun ChoreCatalogMosaicButton(strings: LocalizedText, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val haptics = LocalHapticFeedback.current
    var tick by remember { mutableIntStateOf(0) }
    val pulse = remember { Animatable(1f) }
    LaunchedEffect(tick) {
        if (tick > 0) { pulse.snapTo(1.3f); pulse.animateTo(1f, spring(dampingRatio = .4f, stiffness = 400f)) }
    }
    val description = strings.catalog("chore_catalog_open_accessibility", "İş kataloğunu aç", "Open the chore catalog")
    val tileShape = RoundedCornerShape(13.dp)
    val mosaic = ChoreCatalog.categories.take(4)
    Box(
        modifier.padding(end = 6.dp, bottom = 6.dp)
            .catalogPress(.9f) {
                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                tick++
                onClick()
            }
            .semantics { contentDescription = description },
    ) {
        Column(
            Modifier.size(42.dp)
                .softShadow(FausCrewColors.shadow.copy(alpha = .10f), 6.dp, y = 3.dp, shape = tileShape)
                .clip(tileShape).background(FausCrewColors.background)
                .border(1.dp, FausCrewColors.hairline, tileShape)
                .padding(7.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            mosaic.chunked(2).forEach { row ->
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    row.forEach { category ->
                        Box(Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(4.dp)).background(category.gradient),
                            contentAlignment = Alignment.Center) {
                            Icon(category.iconVector, null, Modifier.size(8.dp), tint = Color.White.copy(alpha = .9f))
                        }
                    }
                }
            }
        }
        Box(
            Modifier.align(Alignment.BottomEnd).offset(6.dp, 6.dp).size(20.dp)
                .graphicsLayer { scaleX = pulse.value; scaleY = pulse.value }
                .background(FausCrewColors.cardBackground, CircleShape).padding(2.dp)
                .background(Brush.linearGradient(LocalFausTheme.current.decor.fabColors), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(FausCrewIcons.plus, null, Modifier.size(12.dp), tint = FausCrewColors.onAccent)
        }
    }
}
