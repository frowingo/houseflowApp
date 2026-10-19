package com.houseflow.ui.onboarding

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.BackHand
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.SportsEsports
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.LocalizedText
import com.houseflow.ui.components.FausButtonGradient
import com.houseflow.ui.components.FausHouseIcon
import com.houseflow.ui.components.FausIconGradient
import com.houseflow.ui.components.drawFausMark
import com.houseflow.ui.components.fausMarkBrush
import com.houseflow.ui.components.mainScreenBackground
import com.houseflow.ui.theme.HouseFlowColors
import com.houseflow.ui.theme.HouseFlowIcons
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val ink = Color(0xFF1C1C1E)
private val muted = Color(0xFF6B6B70)
private val markBerry = Color(0xFF8A2440)

private enum class OnboardingArt { HOUSE, CREW, GAMES, BELL }

private data class OnboardingPage(
    val titleKey: String,
    val subtitleKey: String,
    val art: OnboardingArt,
    val fallbackTitle: String? = null,
    val fallbackSubtitle: String? = null,
)

private val pages = listOf(
    OnboardingPage("onboarding_page_1_title", "onboarding_page_1_subtitle", OnboardingArt.HOUSE),
    OnboardingPage("onboarding_page_2_title", "onboarding_page_2_subtitle", OnboardingArt.CREW),
    OnboardingPage("onboarding_page_games_title", "onboarding_page_games_subtitle", OnboardingArt.GAMES,
        "Play together", "Rocket races, tank battles, rock-paper-scissors and more for your crew."),
    OnboardingPage("onboarding_page_3_title", "onboarding_page_3_subtitle", OnboardingArt.BELL),
)

/** `OnboardingView`: four animated brand pages (home, crew, games, notifications); Continue pages forward, Get Started finishes. */
@Composable
internal fun OnboardingScreen(strings: LocalizedText, busy: Boolean, onComplete: () -> Unit) {
    val pager = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()
    val isLastPage = pager.currentPage == pages.lastIndex

    Box(Modifier.fillMaxSize().mainScreenBackground()) {
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Header(Modifier.padding(top = 52.dp))
            Spacer(Modifier.weight(1f))
            HorizontalPager(
                state = pager,
                modifier = Modifier.fillMaxWidth().height(380.dp).testTag("onboarding_pager"),
            ) { index ->
                val page = pages[index]
                PageContent(
                    page,
                    title = page.fallbackTitle?.let { strings.get(page.titleKey, it) } ?: strings.get(page.titleKey),
                    subtitle = page.fallbackSubtitle?.let { strings.get(page.subtitleKey, it) } ?: strings.get(page.subtitleKey),
                    active = pager.currentPage == index,
                )
            }
            Row(
                Modifier.padding(top = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                pages.indices.forEach { index ->
                    val current = pager.currentPage == index
                    val width by animateDpAsState(if (current) 26.dp else 8.dp,
                        spring(dampingRatio = .8f, stiffness = Spring.StiffnessMediumLow), label = "dotWidth")
                    Box(
                        Modifier.padding(vertical = 8.dp).width(width).height(8.dp)
                            .background(if (current) FausButtonGradient else SolidColor(HouseFlowColors.deepBerry.copy(alpha = .18f)),
                                RoundedCornerShape(4.dp))
                            .clickable(role = Role.Tab) { scope.launch { pager.animateScrollToPage(index) } },
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            val label = if (isLastPage) strings.get("onboarding_get_started_button") else strings.get("common_continue", "Continue")
            val shape = RoundedCornerShape(16.dp)
            Row(
                Modifier.padding(horizontal = 24.dp).padding(bottom = 40.dp).fillMaxWidth().height(54.dp)
                    .then(if (isLastPage) Modifier.shadow(12.dp, shape, ambientColor = HouseFlowColors.deepBerry,
                        spotColor = HouseFlowColors.deepBerry) else Modifier)
                    .background(if (isLastPage) FausButtonGradient else SolidColor(Color.White), shape)
                    .border(1.5.dp, if (isLastPage) Color.Transparent else HouseFlowColors.brandOrange.copy(alpha = .45f), shape)
                    .clickable(enabled = !(isLastPage && busy), role = Role.Button) {
                        if (isLastPage) onComplete() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                    }
                    .semantics { contentDescription = label },
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                val content = if (isLastPage) Color.White else HouseFlowColors.accentOrangeInk
                Text(label, color = content, fontSize = 17.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(8.dp))
                Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, Modifier.size(20.dp), tint = content)
            }
        }
    }
}

@Composable
private fun Header(modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Canvas(Modifier.size(36.dp)) { drawFausMark(fausMarkBrush(size.minDimension / 1024f)) }
            // Brand wordmark stays fixed across languages.
            Row(Modifier.semantics(mergeDescendants = true) { contentDescription = "FausCrew" }) {
                Text("Faus", style = TextStyle(brush = FausButtonGradient, fontSize = 28.sp, fontWeight = FontWeight.ExtraBold))
                Text("Crew", color = HouseFlowColors.deepBerry, fontSize = 28.sp, fontWeight = FontWeight.Normal)
            }
        }
        Text("Make living together fun", color = Color(0xFF8E8E93), fontSize = 14.sp)
    }
}

/** Art plus copy; replays its entrance every time the page becomes current. */
@Composable
private fun PageContent(page: OnboardingPage, title: String, subtitle: String, active: Boolean) {
    val disc = remember { Animatable(0f) }
    val icon = remember { Animatable(0f) }
    val titleIn = remember { Animatable(0f) }
    val subtitleIn = remember { Animatable(0f) }
    val chips = remember { List(4) { Animatable(0f) } }
    LaunchedEffect(active) {
        if (!active) return@LaunchedEffect
        (listOf(disc, icon, titleIn, subtitleIn) + chips).forEach { it.snapTo(0f) }
        launch { disc.animateTo(1f, spring(dampingRatio = .6f, stiffness = Spring.StiffnessLow)) }
        launch { delay(150); icon.animateTo(1f, spring(dampingRatio = .55f, stiffness = Spring.StiffnessLow)) }
        launch { delay(120); titleIn.animateTo(1f, tween(500, easing = FastOutSlowInEasing)) }
        launch { delay(220); subtitleIn.animateTo(1f, tween(500, easing = FastOutSlowInEasing)) }
        chips.forEachIndexed { i, chip ->
            launch { delay(350L + i * 80L); chip.animateTo(1f, spring(dampingRatio = .55f, stiffness = Spring.StiffnessMediumLow)) }
        }
    }
    Column(
        Modifier.fillMaxSize().padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
    ) {
        Art(page.art, disc.value, icon.value, chips.map { it.value })
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, Modifier.graphicsLayer { alpha = titleIn.value; translationY = (1 - titleIn.value) * 14.dp.toPx() },
                color = ink, fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text(subtitle, Modifier.graphicsLayer { alpha = subtitleIn.value; translationY = (1 - subtitleIn.value) * 14.dp.toPx() },
                color = muted, fontSize = 15.sp, textAlign = TextAlign.Center, lineHeight = 21.sp)
        }
    }
}

/** White plate, slowly turning dashed ring, orbiting crew dots and the springing brand disc. */
@Composable
private fun Art(art: OnboardingArt, disc: Float, icon: Float, chips: List<Float>) {
    val loop = rememberInfiniteTransition(label = "onboardingLoop")
    val ring by loop.animateFloat(0f, 360f, infiniteRepeatable(tween(18_000, easing = LinearEasing)), label = "ring")
    val orbitFast by loop.animateFloat(0f, 360f, infiniteRepeatable(tween(7_000, easing = LinearEasing)), label = "orbitFast")
    val orbitSlow by loop.animateFloat(0f, -360f, infiniteRepeatable(tween(11_000, easing = LinearEasing)), label = "orbitSlow")
    val float by loop.animateFloat(0f, -5f, infiniteRepeatable(tween(1_600, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "float")
    val wobble by loop.animateFloat(-8f, 8f, infiniteRepeatable(tween(700, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "wobble")

    Box(Modifier.size(200.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(192.dp).background(Color.White, CircleShape)
            .border(1.2.dp, HouseFlowColors.brandOrange.copy(alpha = .35f), CircleShape))
        Canvas(Modifier.size(156.dp).graphicsLayer { rotationZ = ring }) {
            drawCircle(HouseFlowColors.deepBerry.copy(alpha = .12f), style = Stroke(1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 6.dp.toPx()))))
        }
        OrbitDot(12.dp, HouseFlowColors.brandLight.copy(alpha = .75f), 92.dp, -90f + orbitFast)
        OrbitDot(14.dp, markBerry.copy(alpha = .45f), 88.dp, 10f + orbitSlow)
        OrbitDot(8.dp, HouseFlowColors.brandOrange.copy(alpha = .7f), 84.dp, 140f + orbitSlow)

        Box(
            Modifier.size(120.dp).graphicsLayer { scaleX = .4f + .6f * disc; scaleY = .4f + .6f * disc; alpha = disc.coerceIn(0f, 1f) }
                .shadow(12.dp, CircleShape, ambientColor = HouseFlowColors.deepBerry, spotColor = HouseFlowColors.deepBerry)
                .background(FausIconGradient, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier.graphicsLayer {
                    val s = .3f + .7f * icon
                    scaleX = s; scaleY = s; alpha = icon.coerceIn(0f, 1f)
                    rotationZ = -14f * (1 - icon) + if (art == OnboardingArt.BELL) wobble else 0f
                    transformOrigin = if (art == OnboardingArt.BELL) TransformOrigin(.5f, .1f) else TransformOrigin.Center
                    translationY = float.dp.toPx()
                },
            ) {
                when (art) {
                    OnboardingArt.HOUSE -> FausHouseIcon(62.dp, color = Color.White)
                    OnboardingArt.CREW -> Icon(HouseFlowIcons.person2Fill, null, Modifier.size(58.dp), tint = Color.White)
                    OnboardingArt.GAMES -> Icon(Icons.Rounded.SportsEsports, null, Modifier.size(58.dp), tint = Color.White)
                    OnboardingArt.BELL -> Icon(Icons.Rounded.NotificationsActive, null, Modifier.size(54.dp), tint = Color.White)
                }
            }
        }

        if (art == OnboardingArt.GAMES) {
            GameChip(Icons.Rounded.Casino, (-86).dp, (-62).dp, chips[0])
            GameChip(Icons.Rounded.EmojiEvents, 82.dp, (-72).dp, chips[1])
            GameChip(Icons.Rounded.BackHand, 88.dp, 58.dp, chips[2])
            GameChip(Icons.Rounded.Star, (-84).dp, 54.dp, chips[3])
        }
    }
}

@Composable
private fun OrbitDot(size: Dp, color: Color, radius: Dp, angle: Float) {
    Box(Modifier.size(radius * 2).graphicsLayer { rotationZ = angle }, contentAlignment = Alignment.TopCenter) {
        Box(Modifier.offset(y = -size / 2).size(size).background(color, CircleShape))
    }
}

@Composable
private fun GameChip(icon: ImageVector, x: Dp, y: Dp, progress: Float) {
    Box(
        Modifier.offset(x, y).graphicsLayer {
            scaleX = progress; scaleY = progress; alpha = progress.coerceIn(0f, 1f)
            translationY = (1 - progress) * 10.dp.toPx()
        }.size(32.dp).shadow(5.dp, CircleShape, spotColor = HouseFlowColors.deepBerry).background(Color.White, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(17.dp), tint = HouseFlowColors.brandOrange)
    }
}
