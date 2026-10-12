package com.houseflow.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.DialogWindowProvider
import com.houseflow.ui.theme.HouseFlowBrushes
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Sizes
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow

/**
 * Shared shell for the iOS popup family (NewChorePopup, ChoreDetailPopup, profile popups):
 * a dim backdrop that dismisses on tap, a 20dp-inset card on `MainScreenBackground`, a brand
 * header, a height-capped scroll body and an optional white footer. It is a real Dialog so
 * system back, IME insets and accessibility focus behave natively.
 */
@Composable
internal fun HouseFlowPopup(
    onDismiss: () -> Unit,
    dismissEnabled: Boolean = true,
    maxBodyHeight: Dp = 500.dp,
    cornerRadius: Dp = Radius.xl,
    scrimAlpha: Float = .55f,
    horizontalInset: Dp = Spacing.xl,
    borderColor: Color = Color.Transparent,
    header: (@Composable () -> Unit)?,
    footer: (@Composable () -> Unit)? = null,
    busyOverlay: (@Composable BoxScope.() -> Unit)? = null,
    bodyPadding: Dp = Spacing.xl,
    bodySpacing: Dp = Spacing.xl,
    /** False when the body brings its own scrolling/lazy layout. */
    scrollableBody: Boolean = true,
    body: @Composable ColumnScope.() -> Unit,
) {
    val dismiss = { if (dismissEnabled) onDismiss() }
    Dialog(
        onDismissRequest = dismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        // The backdrop below is drawn by the popup itself, so the window dim must stay off.
        val window = (LocalView.current.parent as? DialogWindowProvider)?.window
        SideEffect { window?.setDimAmount(0f) }
        val appear = remember { Animatable(0f) }
        LaunchedEffect(Unit) { appear.animateTo(1f, Motion.standard()) }
        val shape = RoundedCornerShape(cornerRadius)
        Box(
            Modifier.fillMaxSize()
                .graphicsLayer { alpha = appear.value }
                .background(Color.Black.copy(alpha = scrimAlpha))
                .clickable(remember { MutableInteractionSource() }, indication = null, onClick = dismiss)
                .systemBarsPadding()
                .imePadding(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                Modifier.padding(horizontal = horizontalInset)
                    .fillMaxWidth()
                    .graphicsLayer {
                        val scale = .96f + .04f * appear.value
                        scaleX = scale
                        scaleY = scale
                    }
                    .softShadow(Color.Black.copy(alpha = .25f), 30.dp, y = 16.dp, shape = shape)
                    .clip(shape)
                    .mainScreenBackground()
                    .border(1.dp, borderColor, shape)
                    // Taps inside the card never reach the dismissing backdrop.
                    .clickable(remember { MutableInteractionSource() }, indication = null) {},
            ) {
                header?.invoke()
                Column(
                    Modifier.weight(1f, fill = false)
                        .heightIn(max = maxBodyHeight)
                        .then(if (scrollableBody) Modifier.verticalScroll(rememberScrollState()) else Modifier)
                        .padding(bodyPadding),
                    verticalArrangement = Arrangement.spacedBy(bodySpacing),
                    content = body,
                )
                footer?.invoke()
            }
            busyOverlay?.let {
                Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = .25f)),
                    contentAlignment = Alignment.Center, content = it)
            }
        }
    }
}

/** Popup title bar: brand background, faint oversized glyph and the round close control. */
@Composable
internal fun PopupHeader(
    onClose: () -> Unit,
    closeEnabled: Boolean = true,
    closeDescription: String,
    decorativeIcon: ImageVector? = null,
    decorativeIconSize: Dp = 56.dp,
    decorativeIconAlpha: Float = .12f,
    decorativeOffsetX: Dp = 0.dp,
    height: Dp = 52.dp,
    closeSize: Dp = 26.dp,
    closeBackgroundAlpha: Float = .2f,
    spacing: Dp = Spacing.md,
    content: @Composable RowScope.() -> Unit,
) {
    Box(Modifier.fillMaxWidth().height(height).brandPopupHeaderBackground(), contentAlignment = Alignment.Center) {
        decorativeIcon?.let {
            Icon(it, null, Modifier.offset(x = decorativeOffsetX).size(decorativeIconSize),
                tint = Color.White.copy(alpha = decorativeIconAlpha))
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.xl),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(spacing)) {
            content()
            Spacer(Modifier.weight(1f))
            PopupCloseButton(onClose, closeEnabled, closeDescription, closeSize, closeBackgroundAlpha)
        }
    }
}

@Composable
internal fun PopupHeaderTitle(text: String) {
    Text(text, style = HouseFlowType.headline, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
}

@Composable
internal fun PopupCloseButton(
    onClick: () -> Unit,
    enabled: Boolean,
    description: String,
    size: Dp = 26.dp,
    backgroundAlpha: Float = .2f,
) {
    Box(
        Modifier.size(size).clip(CircleShape).background(Color.White.copy(alpha = backgroundAlpha))
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(HouseFlowIcons.xmark, null, Modifier.size(15.dp), tint = Color.White.copy(alpha = .9f))
    }
}

/** White action strip under popup bodies, with the upward hairline shadow by default. */
@Composable
internal fun PopupFooter(
    modifier: Modifier = Modifier,
    shadow: Boolean = true,
    padding: PaddingValues = PaddingValues(horizontal = Spacing.xl, vertical = Spacing.lg),
    spacing: Dp = Spacing.md,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier.fillMaxWidth()
            .then(if (shadow) Modifier.softShadow(Color.Black.copy(alpha = .06f), 8.dp, y = (-4).dp) else Modifier)
            .background(HouseFlowColors.background)
            .padding(padding),
        verticalArrangement = Arrangement.spacedBy(spacing),
        content = content,
    )
}

/** Orange uppercase field caption with a leading glyph (`sectionLabel` on iOS). */
@Composable
internal fun PopupSectionLabel(icon: ImageVector, text: String, color: Color = HouseFlowColors.accentOrange) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Icon(icon, null, Modifier.size(13.dp), tint = color)
        Text(text.uppercase(), color = color, fontSize = 11.sp, fontWeight = FontWeight.SemiBold,
            letterSpacing = .5.sp, maxLines = 1)
    }
}

/** Orange gradient call to action; gray when disabled, spinner while [busy]. */
@Composable
internal fun PopupPrimaryButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = HouseFlowIcons.checkmarkCircleFill,
    busy: Boolean = false,
    brush: Brush = HouseFlowBrushes.orangeAction,
    disabledBrush: Brush = HouseFlowBrushes.disabledAction,
    height: Dp = Sizes.buttonHeightSmall,
    cornerRadius: Dp = Radius.md,
) {
    val shape = RoundedCornerShape(cornerRadius)
    Row(
        modifier.height(height).clip(shape).background(if (enabled) brush else disabledBrush)
            .clickable(enabled = enabled && !busy, onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (busy) {
            CircularProgressIndicator(Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
        } else if (icon != null) {
            Icon(icon, null, Modifier.size(18.dp), tint = Color.White)
        }
        if (busy || icon != null) Spacer(Modifier.width(Spacing.sm))
        Text(text, style = HouseFlowType.headline, color = Color.White, maxLines = 1)
    }
}

/** Neutral gray action (Cancel / Close). */
@Composable
internal fun PopupSecondaryButton(
    text: String,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier.height(Sizes.buttonHeightSmall).clip(RoundedCornerShape(Radius.md))
            .background(HouseFlowColors.secondaryBackground)
            .clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = HouseFlowType.headline, color = HouseFlowColors.textSecondary, maxLines = 1)
    }
}

/** Spinner + caption shown while a popup request is in flight. */
@Composable
internal fun PopupBusyIndicator(text: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        CircularProgressIndicator(color = Color.White)
        Text(text, style = HouseFlowType.subheadline, color = Color.White)
    }
}

/** Inline request error inside popup bodies. */
@Composable
internal fun PopupError(message: String?) {
    if (!message.isNullOrBlank()) {
        Text(message, style = HouseFlowType.subheadline, color = HouseFlowColors.error)
    }
}

/**
 * iOS form field: filled `secondaryBackground` rounded rect, gray placeholder and an
 * optional 1.5dp accent outline whose color the caller derives from focus/content.
 */
@Composable
internal fun PopupTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    borderColor: (focused: Boolean) -> Color = { Color.Transparent },
    singleLine: Boolean = true,
    minLines: Int = 1,
    maxLines: Int = if (singleLine) 1 else Int.MAX_VALUE,
    textStyle: TextStyle = HouseFlowType.body,
    textAlign: TextAlign = TextAlign.Start,
    contentPadding: PaddingValues = PaddingValues(Spacing.md),
    cornerRadius: Dp = Radius.md,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    enabled: Boolean = true,
) {
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    val shape = RoundedCornerShape(cornerRadius)
    val style = textStyle.copy(color = HouseFlowColors.textPrimary, textAlign = textAlign)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        enabled = enabled,
        textStyle = style,
        singleLine = singleLine,
        minLines = minLines,
        maxLines = maxLines,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        interactionSource = interaction,
        cursorBrush = SolidColor(HouseFlowColors.primary),
        decorationBox = { inner ->
            Box(
                Modifier.fillMaxWidth().clip(shape).background(HouseFlowColors.secondaryBackground)
                    .border(1.5.dp, borderColor(focused), shape).padding(contentPadding),
            ) {
                if (value.isEmpty()) {
                    Text(placeholder, Modifier.fillMaxWidth(), style = style.copy(color = PlaceholderColor), maxLines = maxLines)
                }
                inner()
            }
        },
    )
}

/** iOS `placeholderText`. */
internal val PlaceholderColor = Color(0x4D3C3C43)
