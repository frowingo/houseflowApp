package com.fauscrew.ui.house

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
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.FausGradientIcon
import com.fauscrew.ui.components.FausHouseIcon
import com.fauscrew.ui.components.FausIconGradient
import com.fauscrew.ui.components.drawFausMark
import com.fauscrew.ui.components.fausHeroBackground
import com.fauscrew.ui.components.fausMarkBrush
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.draw.shadow
import com.fauscrew.ui.components.mainScreenBackground
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Motion
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow

/** `HouseSelectionView`: brand header card with the F badge, then the create / join cards. */
@Composable
internal fun HouseSelectionScreen(strings: LocalizedText, onCreate: () -> Unit, onJoin: () -> Unit) {
    Column(
        Modifier.fillMaxSize().mainScreenBackground().verticalScroll(rememberScrollState())
            .statusBarsPadding().navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.xxl),
    ) {
        HeaderCard(strings)
        Column(Modifier.padding(horizontal = Spacing.xxl), verticalArrangement = Arrangement.spacedBy(Spacing.xl)) {
            HouseOptionCard(strings.get("house_selection_create_title"), strings.get("house_selection_create_subtitle"),
                OptionKind.CREATE, onCreate)
            HouseOptionCard(strings.get("house_selection_join_title"), strings.get("house_selection_join_subtitle"),
                OptionKind.JOIN, onJoin)
        }
        Spacer(Modifier.height(60.dp))
    }
}

/** Orange → berry header card holding the white F badge, title and subtitle. */
@Composable
private fun HeaderCard(strings: LocalizedText) {
    val shape = RoundedCornerShape(Radius.xxl)
    Row(
        Modifier.padding(top = 60.dp, start = Spacing.xxl, end = Spacing.xxl).fillMaxWidth()
            .softShadow(FausCrewColors.deepBerry.copy(alpha = .28f), 18.dp, y = 8.dp, shape = shape)
            .clip(shape).fausHeroBackground()
            .padding(horizontal = Spacing.xl, vertical = Spacing.xxl),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        Box(Modifier.size(70.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(70.dp).background(Color.White.copy(alpha = .16f), CircleShape))
            Box(Modifier.size(58.dp).shadow(8.dp, CircleShape, ambientColor = FausCrewColors.deepBerry,
                spotColor = FausCrewColors.deepBerry).background(Color.White, CircleShape))
            Canvas(Modifier.size(58.dp)) { drawFausMark(fausMarkBrush(size.minDimension / 1024f)) }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(strings.get("house_selection_title"), fontSize = 24.sp, fontWeight = FontWeight.Bold,
                color = Color.White, maxLines = 2)
            Text(strings.get("house_selection_subtitle"), style = FausCrewType.subheadline,
                color = Color.White.copy(alpha = .82f))
        }
    }
}

private enum class OptionKind { CREATE, JOIN }

/** `HouseOptionCard` + `CardButtonStyle` (scales to 0.96 while pressed). */
@Composable
private fun HouseOptionCard(title: String, subtitle: String, kind: OptionKind, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) .96f else 1f, Motion.quick(), label = "optionScale")
    val shape = RoundedCornerShape(Radius.xxl)
    Row(
        Modifier.fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .softShadow(FausCrewColors.deepBerry.copy(alpha = .08f), 18.dp, y = 8.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.surface)
            .border(1.dp, FausCrewColors.brandOrange.copy(alpha = .18f), shape)
            .clickable(interaction, indication = null, role = Role.Button, onClick = onClick)
            .padding(Spacing.xl),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        OptionIcon(kind)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(title, style = FausCrewType.headline, color = FausCrewColors.textPrimary)
            Text(subtitle, style = FausCrewType.subheadline, color = FausCrewColors.textSecondary, maxLines = 3)
        }
        Icon(FausCrewIcons.chevronRight, null, Modifier.size(20.dp), tint = FausCrewColors.accentOrangeInk)
    }
}

/** Create: white house on the brand disc with a "+" badge. Join: gradient people on a berry tint. */
@Composable
private fun OptionIcon(kind: OptionKind) {
    when (kind) {
        OptionKind.CREATE -> Box(Modifier.size(64.dp)) {
            Box(
                Modifier.size(64.dp)
                    .softShadow(FausCrewColors.deepBerry.copy(alpha = .25f), 6.dp, y = 6.dp, shape = CircleShape)
                    .background(FausIconGradient, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                FausHouseIcon(34.dp, color = Color.White)
            }
            Box(
                Modifier.align(Alignment.BottomEnd).offset(2.dp, 2.dp).size(22.dp)
                    .shadow(2.dp, CircleShape).background(Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(FausCrewIcons.plus, null, Modifier.size(14.dp), tint = FausCrewColors.brandOrange)
            }
        }
        OptionKind.JOIN -> Box(
            Modifier.size(64.dp).background(FausCrewColors.deepBerry.copy(alpha = .09f), CircleShape)
                .border(1.5.dp, FausCrewColors.deepBerry.copy(alpha = .16f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            FausGradientIcon(FausCrewIcons.person2Fill, 30.dp)
        }
    }
}
