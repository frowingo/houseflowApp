package com.houseflow.ui.house

import androidx.compose.runtime.getValue
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.ui.theme.Radius
import com.houseflow.ui.theme.Spacing
import com.houseflow.ui.theme.softShadow

/** `HouseSelectionView`: title with the orange accent bar and the create / join cards. */
@Composable
internal fun HouseSelectionScreen(strings: LocalizedText, onCreate: () -> Unit, onJoin: () -> Unit) {
    Column(
        Modifier.fillMaxSize().mainScreenBackground().verticalScroll(rememberScrollState())
            .statusBarsPadding().navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xxl),
    ) {
        Column(
            Modifier.padding(top = 60.dp, start = Spacing.xxl, end = Spacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Text(strings.get("house_selection_title"), fontSize = 34.sp, fontWeight = FontWeight.Bold,
                color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center)
            Text(strings.get("house_selection_subtitle"), style = HouseFlowType.subheadline,
                color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
            // The iOS accent bar sits on the header's 32pt bottom padding.
            Spacer(Modifier.height(Spacing.xxxl - 4.dp))
            Box(Modifier.size(34.dp, 4.dp).background(HouseFlowColors.accentOrange, CircleShape))
        }
        Column(Modifier.padding(horizontal = Spacing.xxl), verticalArrangement = Arrangement.spacedBy(Spacing.xl)) {
            HouseOptionCard(strings.get("house_selection_create_title"), strings.get("house_selection_create_subtitle"),
                HouseFlowIcons.plus, HouseFlowColors.indigo, onCreate)
            HouseOptionCard(strings.get("house_selection_join_title"), strings.get("house_selection_join_subtitle"),
                HouseFlowIcons.person2Fill, HouseFlowColors.teal, onJoin)
        }
        Spacer(Modifier.height(60.dp))
    }
}

/** `HouseOptionCard` + `CardButtonStyle` (scales to 0.96 while pressed). */
@Composable
private fun HouseOptionCard(title: String, subtitle: String, icon: ImageVector, tint: Color, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) .96f else 1f, Motion.quick(), label = "optionScale")
    val shape = RoundedCornerShape(Radius.xxl)
    Box(
        Modifier.fillMaxWidth().height(220.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .softShadow(tint.copy(alpha = .13f), 18.dp, y = 8.dp, shape = shape)
            .clip(shape)
            .background(HouseFlowColors.surface)
            .border(1.dp, tint.copy(alpha = .18f), shape)
            .clickable(interaction, indication = null, role = Role.Button, onClick = onClick),
    ) {
        Box(Modifier.align(Alignment.TopEnd).padding(18.dp).size(8.dp).background(HouseFlowColors.accentOrange, CircleShape))
        Column(
            Modifier.fillMaxSize().padding(Spacing.xxl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.xxl, Alignment.CenterVertically),
        ) {
            OptionIcon(icon, tint)
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text(title, style = HouseFlowType.title3, color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center)
                Text(subtitle, style = HouseFlowType.subheadline, color = HouseFlowColors.textSecondary,
                    textAlign = TextAlign.Center, maxLines = 3)
            }
        }
    }
}

/** SF `*.circle.fill` in white on the tinted disc: a white badge with the glyph knocked out in the tint. */
@Composable
private fun OptionIcon(icon: ImageVector, tint: Color) {
    Box(
        Modifier.size(100.dp)
            .softShadow(tint.copy(alpha = .3f), 10.dp, y = 5.dp, shape = CircleShape)
            .background(Brush.linearGradient(listOf(tint, tint.copy(alpha = .72f))), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.size(88.dp).border(1.dp, Color.White.copy(alpha = .30f), CircleShape))
        Box(Modifier.size(52.dp).background(Color.White, CircleShape), contentAlignment = Alignment.Center) {
            Icon(icon, null, Modifier.size(34.dp), tint = tint)
        }
    }
}
