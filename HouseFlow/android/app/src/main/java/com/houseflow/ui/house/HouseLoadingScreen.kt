package com.houseflow.ui.house

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.FausFramedMark
import com.houseflow.ui.components.FausSpinner
import com.houseflow.ui.components.LocalFausSplashActive
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowType
import com.houseflow.ui.theme.Motion
import com.houseflow.viewmodel.HouseLoadingPhase

/** `HouseLoadingView`: the roof-F draws itself inside its orange circle, the crew dot pops in, and the Faus spinner runs below the phase text. */
@Composable
internal fun HouseLoadingScreen(phase: HouseLoadingPhase, strings: LocalizedText) {
    val (title, subtitle) = when (phase) {
        HouseLoadingPhase.CHECKING_AUTH -> "house_loading_auth_title" to "house_loading_auth_subtitle"
        HouseLoadingPhase.CREATING -> "house_loading_creating_title" to "house_loading_creating_subtitle"
        HouseLoadingPhase.JOINING -> "house_loading_joining_title" to "house_loading_joining_subtitle"
        HouseLoadingPhase.LOADING_DETAILS -> "house_loading_details_title" to "house_loading_details_subtitle"
        HouseLoadingPhase.LOADING_HOUSE -> "house_loading_house_title" to "house_loading_house_subtitle"
    }
    val dotBreath by rememberInfiniteTransition(label = "dotBreath").animateFloat(1f, 1.18f,
        infiniteRepeatable(tween(1_100, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "dotBreath")
    val markProgress = remember { Animatable(0f) }
    val dotPop = remember { Animatable(0f) }
    val splashActive = LocalFausSplashActive.current
    LaunchedEffect(splashActive) {
        // Behind the splash the intro would play unseen; start it when the splash reveals us.
        if (splashActive) return@LaunchedEffect
        markProgress.animateTo(1f, tween(1_000, easing = FastOutSlowInEasing))
        dotPop.animateTo(1f, spring(dampingRatio = .45f, stiffness = Spring.StiffnessMediumLow))
    }
    val settled = !dotPop.isRunning && dotPop.value >= 1f

    Box(Modifier.fillMaxSize().mainScreenBackground()) {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            FausFramedMark(190.dp, progress = markProgress.value,
                dotScale = dotPop.value * if (settled) dotBreath else 1f)
            Spacer(Modifier.height(20.dp))
            AnimatedContent(title, transitionSpec = {
                (fadeIn(Motion.standard()) + slideInVertically(Motion.standard()) { it / 2 }) togetherWith fadeOut(Motion.standard())
            }, label = "phaseTitle") { key ->
                Text(strings.get(key), style = HouseFlowType.title2, color = HouseFlowColors.textPrimary, textAlign = TextAlign.Center)
            }
            Spacer(Modifier.height(8.dp))
            AnimatedContent(subtitle, transitionSpec = { fadeIn(Motion.standard()) togetherWith fadeOut(Motion.standard()) },
                label = "phaseSubtitle") { key ->
                Text(strings.get(key), Modifier.padding(horizontal = 32.dp), style = HouseFlowType.subheadline,
                    color = HouseFlowColors.textSecondary, textAlign = TextAlign.Center)
            }
            FausSpinner(46.dp, Modifier.padding(top = 24.dp))
        }
    }
}
