package com.houseflow.ui.house

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.FausButtonGradient
import com.houseflow.ui.components.FausGradientIcon
import com.houseflow.ui.components.FausHouseIcon
import com.houseflow.ui.components.FausIconGradient
import androidx.compose.ui.graphics.lerp
import com.houseflow.ui.components.HouseFlowPopup
import com.houseflow.ui.components.PlaceholderColor
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow
import kotlin.math.roundToInt

private const val NAME_LIMIT = 30
private const val MIN_MEMBERS = 2
private const val MAX_MEMBERS = 8

/** `HouseTypeCard.HouseType`: API value, copy key, SF icon and tint. */
internal enum class HouseTypeUi(val apiValue: Int, val key: String, val icon: ImageVector, val tint: Color) {
    STUDENT(1, "create_house_type_student", HouseFlowIcons.graduationcapFill, HouseFlowColors.purple),
    SHARED(2, "create_house_type_shared", HouseFlowIcons.houseFill, HouseFlowColors.teal),
    DORM(3, "create_house_type_dorm", HouseFlowIcons.building2Fill, HouseFlowColors.blue);

    companion object {
        fun of(apiValue: Int): HouseTypeUi? = entries.firstOrNull { it.apiValue == apiValue }
    }
}

/** `CreateHouseView`: name, type and member count, then the summary confirmation. */
@Composable
internal fun CreateHouseScreen(
    state: com.houseflow.viewmodel.HouseUiState,
    strings: LocalizedText,
    onBack: () -> Unit,
    onCreate: (String, Int, Int) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf("") }
    var type by rememberSaveable { mutableStateOf(HouseTypeUi.STUDENT) }
    var count by rememberSaveable { mutableIntStateOf(3) }
    var showSummary by rememberSaveable { mutableStateOf(false) }
    val valid = name.isNotBlank()

    Column(
        Modifier.fillMaxSize().mainScreenBackground().statusBarsPadding().navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xxl),
    ) {
        Column(Modifier.fillMaxWidth().padding(top = Spacing.xxxl), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            HouseBackButton(strings.get("common_back", "Back"), onBack)
            Text(strings.get("create_house_title"), fontSize = 34.sp, fontWeight = FontWeight.Bold,
                color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center)
            Text(strings.get("create_house_subtitle"), Modifier.padding(horizontal = Spacing.xxl),
                style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
            Box(Modifier.padding(top = Spacing.xs).size(34.dp, 4.dp).background(FausIconGradient, CircleShape))
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = Spacing.xxl),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxl),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                Text(strings.get("create_house_name_label"), style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
                Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    HouseNameField(name, { name = it.take(NAME_LIMIT) }, strings)
                    AnimatedVisibility(name.isNotEmpty(), enter = fadeIn() + expandVertically(),
                        exit = fadeOut() + shrinkVertically()) {
                        Text(strings.template("create_house_name_count_template", "count" to name.length.toString()),
                            style = HouseFlowType.caption2, color = HouseFlowColors.textSecondary)
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
                Text(strings.get("create_house_type_label"), style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                    HouseTypeUi.entries.forEach { option ->
                        HouseTypeCard(option, option == type, strings, Modifier.weight(1f)) { type = option }
                    }
                }
            }
            MemberCountPicker(count, strings) { count = it }
            state.error?.let { Text(it, style = HouseFlowType.subheadline, color = HouseFlowColors.errorRed) }
            Spacer(Modifier.height(Spacing.xxxl))
        }
        HouseJourneyButton(strings.get("create_house_submit_button"), valid, FausButtonGradient,
            Modifier.padding(start = Spacing.xxl, end = Spacing.xxl, bottom = 50.dp), glow = HouseFlowColors.deepBerry) { showSummary = true }
    }

    if (showSummary) {
        HouseSummaryPopup(
            name = name, type = strings.get(type.key), memberCount = count, strings = strings,
            onConfirm = { showSummary = false; onCreate(name, type.apiValue, count) },
            onCancel = { showSummary = false },
        )
    }
}

@Composable
private fun HouseNameField(value: String, onChange: (String) -> Unit, strings: LocalizedText) {
    val focus = LocalFocusManager.current
    val empty = value.isEmpty()
    val shape = RoundedCornerShape(Radius.md)
    val border by animateColorAsState(if (empty) HouseFlowColors.brandOrange.copy(alpha = .18f) else HouseFlowColors.brandOrange,
        Motion.quick(), label = "nameBorder")
    val label = strings.get("create_house_name_label")
    BasicTextField(
        value = value,
        onValueChange = onChange,
        modifier = Modifier.fillMaxWidth()
            .softShadow(if (empty) Color.Black.copy(alpha = .03f) else HouseFlowColors.accentOrange.copy(alpha = .10f),
                8.dp, y = 3.dp, shape = shape)
            .semantics { contentDescription = label },
        textStyle = HouseFlowType.body.copy(color = HouseFlowColors.textPrimary),
        singleLine = true,
        cursorBrush = SolidColor(HouseFlowColors.brandOrange),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Done),
        keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { focus.clearFocus() }),
        decorationBox = { inner ->
            Box(
                Modifier.fillMaxWidth().clip(shape).background(HouseFlowColors.surface)
                    .border(if (empty) 1.dp else 2.dp, border, shape)
                    .padding(horizontal = Spacing.lg, vertical = Spacing.md),
            ) {
                if (empty) Text(strings.get("create_house_name_placeholder"), style = HouseFlowType.body, color = PlaceholderColor)
                inner()
            }
        },
    )
}

/** `HouseTypeCard`. */
@Composable
private fun HouseTypeCard(type: HouseTypeUi, selected: Boolean, strings: LocalizedText, modifier: Modifier, onClick: () -> Unit) {
    val scale by animateFloatAsState(if (selected) 1.05f else 1f, Motion.quick(), label = "typeScale")
    val shape = RoundedCornerShape(Radius.lg)
    Column(
        modifier.height(90.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(shape)
            .background(if (selected) HouseFlowColors.brandOrange.copy(alpha = .08f) else HouseFlowColors.surface)
            .border(if (selected) 2.dp else 1.dp, if (selected) HouseFlowColors.brandOrange else Color(0xFFE5E5EA), shape)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = Spacing.xs),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
    ) {
        // Shared house uses the custom glyph so it reads the same on iOS and Android.
        if (type == HouseTypeUi.SHARED) FausHouseIcon(28.dp) else FausGradientIcon(type.icon, 24.dp)
        Text(strings.get(type.key), style = HouseFlowType.caption, textAlign = TextAlign.Center, maxLines = 2,
            color = if (selected) HouseFlowColors.textPrimary else HouseFlowColors.textSecondary)
    }
}

/**
 * `MemberCountPicker`: "train track" rail with one stop per allowed count and a floating
 * indigo bubble; tap or drag anywhere on the track to pick.
 */
@Composable
private fun MemberCountPicker(count: Int, strings: LocalizedText, onChange: (Int) -> Unit) {
    val currentCount by rememberUpdatedState(count)
    val update by rememberUpdatedState(onChange)
    val label = strings.get("create_house_member_count_label")
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xl)) {
        Text(label, style = HouseFlowType.headline, color = HouseFlowColors.textPrimary)
        Column(Modifier.padding(vertical = Spacing.lg), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            BoxWithConstraints(Modifier.fillMaxWidth().height(70.dp)) {
                val edge = 22.dp
                val sliderWidth = maxWidth - edge * 2
                val stops = MAX_MEMBERS - MIN_MEMBERS + 1
                val stopWidth = sliderWidth / stops
                fun pick(x: Float, widthPx: Float, edgePx: Float) {
                    val clamped = x.coerceIn(edgePx, widthPx - edgePx)
                    val normalized = (clamped - edgePx) / (widthPx - edgePx * 2)
                    val next = ((normalized * (MAX_MEMBERS - MIN_MEMBERS)).roundToInt() + MIN_MEMBERS)
                        .coerceIn(MIN_MEMBERS, MAX_MEMBERS)
                    if (next != currentCount) update(next)
                }
                val track = Modifier.fillMaxSize()
                    .pointerInput(Unit) {
                        detectTapGestures { pick(it.x, size.width.toFloat(), edge.toPx()) }
                    }
                    .pointerInput(Unit) {
                        detectDragGestures { change, _ -> pick(change.position.x, size.width.toFloat(), edge.toPx()) }
                    }
                    .semantics { contentDescription = label; stateDescription = currentCount.toString() }
                Canvas(track) {
                    val left = edge.toPx()
                    val width = size.width - left * 2
                    val centerY = size.height / 2
                    val rail = 6.dp.toPx()
                    drawRoundRect(HouseFlowColors.systemGray4, Offset(left, centerY - rail / 2), Size(width, rail),
                        CornerRadius(3.dp.toPx()))
                    val slot = width / stops
                    // Each stop is a 16pt tick over a 10pt dot, centered on the rail like the iOS VStack.
                    val stackTop = centerY - 13.dp.toPx()
                    for (index in 0 until stops) {
                        val x = left + slot * (index + .5f)
                        drawRoundRect(HouseFlowColors.systemGray3, Offset(x - 1.5.dp.toPx(), stackTop),
                            Size(3.dp.toPx(), 16.dp.toPx()), CornerRadius(1.5.dp.toPx()))
                        drawCircle(if (currentCount >= MIN_MEMBERS + index) memberStopColor(index, stops) else HouseFlowColors.systemGray4,
                            5.dp.toPx(), Offset(x, stackTop + 21.dp.toPx()))
                    }
                }
                val bubbleX by animateDpAsState(edge + stopWidth * ((count - MIN_MEMBERS) + .5f), Motion.spring(), label = "bubble")
                MemberBubble(count, Modifier.offset(x = bubbleX - 22.dp, y = 15.dp - 27.dp))
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = Spacing.xs)) {
                Text(strings.get("common_min"), style = HouseFlowType.caption2, color = HouseFlowColors.textSecondary)
                Spacer(Modifier.weight(1f))
                Text(strings.get("common_max"), style = HouseFlowType.caption2, color = HouseFlowColors.textSecondary)
            }
        }
    }
}

/** Filled stops walk from light orange towards berry as the count grows. */
private fun memberStopColor(index: Int, stops: Int): Color {
    val progress = index / (stops - 1).coerceAtLeast(1).toFloat()
    return if (progress < .5f) lerp(HouseFlowColors.brandLight, HouseFlowColors.brandOrange, progress * 2)
    else lerp(HouseFlowColors.brandOrange, Color(0xFF8A2440), (progress - .5f) * 2)
}

private val BubbleTail = GenericShape { size, _ ->
    moveTo(size.width / 2, size.height)
    lineTo(0f, 0f)
    lineTo(size.width, 0f)
    close()
}

@Composable
private fun MemberBubble(count: Int, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier.size(44.dp)
                .softShadow(HouseFlowColors.deepBerry.copy(alpha = .28f), 10.dp, y = 4.dp, shape = CircleShape)
                .background(FausIconGradient, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(count.toString(), color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }
        Box(Modifier.offset(y = (-1).dp).size(14.dp, 10.dp).background(Color(0xFFB5473A), BubbleTail))
    }
}

/** `SummaryPopup`: house icon, review rows, create CTA and the Edit link. */
@Composable
private fun HouseSummaryPopup(
    name: String,
    type: String,
    memberCount: Int,
    strings: LocalizedText,
    onConfirm: () -> Unit,
    onCancel: () -> Unit,
) {
    HouseFlowPopup(
        onDismiss = onCancel,
        scrimAlpha = .4f,
        horizontalInset = Spacing.xxxl,
        borderColor = HouseFlowColors.indigo.copy(alpha = .13f),
        header = null,
        bodyPadding = Spacing.xxl,
        bodySpacing = Spacing.xxl,
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Box(Modifier.size(54.dp)) {
                Box(Modifier.size(50.dp).align(Alignment.BottomStart).background(HouseFlowColors.indigo, CircleShape),
                    contentAlignment = Alignment.Center) {
                    Icon(HouseFlowIcons.houseFill, null, Modifier.size(28.dp), tint = Color.White)
                }
                Box(Modifier.align(Alignment.TopEnd).size(8.dp).background(HouseFlowColors.accentOrange, CircleShape))
            }
            Text(strings.get("house_summary_title"), style = HouseFlowType.title2, color = HouseFlowColors.textPrimary)
            Text(strings.get("house_summary_subtitle"), style = HouseFlowType.subheadline,
                color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
        }
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radius.md)).background(HouseFlowColors.indigo.copy(alpha = .055f))
                .padding(PaddingValues(horizontal = Spacing.md, vertical = Spacing.lg)),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            SummaryRow(strings.get("house_summary_name_label"), name)
            SummaryRow(strings.get("house_summary_type_label"), type)
            SummaryRow(strings.get("house_summary_person_count_label"),
                strings.template("house_summary_person_count_value_template", "count" to memberCount.toString(),
                    fallback = "{count} persons"))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            Box(
                Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(Radius.md))
                    .background(HouseJourneyBrushes.primaryButton)
                    .border(1.dp, HouseFlowColors.accentOrange.copy(alpha = .32f), RoundedCornerShape(Radius.md))
                    .clickable(role = Role.Button, onClick = onConfirm),
                contentAlignment = Alignment.Center,
            ) {
                Text(strings.get("house_summary_create_button"), style = HouseFlowType.headline, color = Color.White)
            }
            Text(strings.get("common_edit"), Modifier.clickable(role = Role.Button, onClick = onCancel).padding(Spacing.xs),
                style = HouseFlowType.subheadline, color = HouseFlowColors.accentOrangeInk)
        }
    }
}

@Composable
private fun SummaryRow(title: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = Spacing.xs), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary)
        Spacer(Modifier.weight(1f).padding(horizontal = Spacing.sm))
        Text(value, style = HouseFlowType.subheadline, color = HouseFlowColors.textPrimary, textAlign = TextAlign.End, maxLines = 2)
    }
}
