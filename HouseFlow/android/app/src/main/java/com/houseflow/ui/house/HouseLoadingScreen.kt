package com.houseflow.ui.house

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.viewmodel.HouseLoadingPhase
import kotlinx.coroutines.delay

/** `HouseLoadingView`: pulsing phase-colored rings, orange accent and the stepping dots. */
@Composable
internal fun HouseLoadingScreen(phase: HouseLoadingPhase, strings: LocalizedText) {
    val (title, subtitle, tint) = when (phase) {
        HouseLoadingPhase.CHECKING_AUTH -> Triple("house_loading_auth_title", "house_loading_auth_subtitle", HouseFlowColors.indigo)
        HouseLoadingPhase.CREATING -> Triple("house_loading_creating_title", "house_loading_creating_subtitle", HouseFlowColors.purple)
        HouseLoadingPhase.JOINING -> Triple("house_loading_joining_title", "house_loading_joining_subtitle", HouseFlowColors.teal)
        HouseLoadingPhase.LOADING_DETAILS -> Triple("house_loading_details_title", "house_loading_details_subtitle", HouseFlowColors.blue)
        HouseLoadingPhase.LOADING_HOUSE -> Triple("house_loading_house_title", "house_loading_house_subtitle", HouseFlowColors.blue)
    }
    val phaseColor by animateColorAsState(tint, Motion.standard(), label = "phaseColor")
    val pulse = rememberInfiniteTransition(label = "loadingPulse")
    val pulseScale by pulse.animateFloat(1f, 1.18f, infiniteRepeatable(tween(1_300, easing = FastOutSlowInEasing),
        RepeatMode.Reverse), label = "pulseScale")
    val ringAlpha by pulse.animateFloat(.08f, .04f, infiniteRepeatable(tween(1_300, easing = FastOutSlowInEasing),
        RepeatMode.Reverse), label = "ringAlpha")
    var activeDot by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(450)
            activeDot = (activeDot + 1) % 3
        }
    }
    Box(
        Modifier.fillMaxSize().mainScreenBackground().drawBehind {
            drawRect(Brush.radialGradient(listOf(phaseColor.copy(alpha = .07f), Color.Transparent),
                radius = 360.dp.toPx()))
        },
    ) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Box(Modifier.size(170.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.size(170.dp).graphicsLayer { scaleX = pulseScale; scaleY = pulseScale }
                    .background(phaseColor.copy(alpha = ringAlpha), CircleShape))
                Box(Modifier.size(120.dp).background(HouseFlowColors.teal.copy(alpha = .085f), CircleShape))
                Box(Modifier.size(88.dp).background(HouseFlowColors.surface, CircleShape).border(1.dp, phaseColor.copy(alpha = .18f), CircleShape))
                Icon(HouseFlowIcons.houseFill, null, Modifier.size(46.dp), tint = phaseColor)
                Box(Modifier.offset(36.dp, (-36).dp).size(10.dp).background(HouseFlowColors.accentOrange, CircleShape))
            }
            Spacer(Modifier.height(32.dp))
            AnimatedContent(title, transitionSpec = {
                (fadeIn(Motion.standard()) + slideInVertically(Motion.standard()) { it / 2 }) togetherWith fadeOut(Motion.standard())
            }, label = "phaseTitle") { key ->
                Text(strings.get(key), style = HouseFlowType.title2, color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center)
            }
            Spacer(Modifier.height(12.dp))
            AnimatedContent(subtitle, transitionSpec = { fadeIn(Motion.standard()) togetherWith fadeOut(Motion.standard()) },
                label = "phaseSubtitle") { key ->
                Text(strings.get(key), Modifier.padding(horizontal = 32.dp), style = HouseFlowType.subheadline,
                    color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
            }
            Row(Modifier.padding(top = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically) {
                repeat(3) { index ->
                    val active = index == activeDot
                    val dotScale by animateFloatAsState(if (active) 1.35f else 1f, Motion.quick(), label = "dotScale")
                    val dotColor by animateColorAsState(if (active) HouseFlowColors.accentOrange else phaseColor.copy(alpha = .3f),
                        Motion.quick(), label = "dotColor")
                    Box(Modifier.size(8.dp).graphicsLayer { scaleX = dotScale; scaleY = dotScale }.background(dotColor, CircleShape))
                }
            }
        }
    }
}
