package com.fauscrew.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.colorResource
import com.fauscrew.R
import com.fauscrew.ui.theme.FausLaunchHandOff
import com.fauscrew.ui.theme.LocalFausTheme
import com.fauscrew.ui.theme.FausCrewColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.hypot

/**
 * True while [FausSplash] still covers the app: screens underneath skip their own animations
 * (route fades, spinners, intros) so the splash keeps the frame budget, and start them once the
 * splash begins to reveal the app.
 */
internal val LocalFausSplashActive = staticCompositionLocalOf { false }

private const val CENTER_RATIO = .44f
private const val WORDMARK = "FausCrew"

/**
 * `FausSplashView`: cold-start brand intro over the app (~3.2s). The roof-F draws itself, the
 * crew dot pops with two ripples, the mark lifts while "FausCrew" rises letter by letter, the
 * motto fades in, then the gradient closes into a circle and reveals the app. It starts on the
 * launch window's orange (`launch_background`), so the hand-off is seamless; dark themes then
 * condense that orange into the ember behind the mark ([FausLaunchHandOff]).
 */
@Composable
internal fun FausSplash(onReveal: () -> Unit = {}, onFinished: () -> Unit) {
    val gradient = remember { Animatable(0f) }
    val draw = remember { Animatable(0f) }
    val dot = remember { Animatable(0f) }
    val ripple1 = remember { Animatable(0f) }
    val ripple2 = remember { Animatable(0f) }
    val lift = remember { Animatable(0f) }
    val letters = remember { List(WORDMARK.length) { Animatable(0f) } }
    val motto = remember { Animatable(0f) }
    val reveal = remember { Animatable(0f) }
    val splash = LocalFausTheme.current.decor.splash
    val launchColor = colorResource(R.color.launch_background)
    val condenses = splash.launchHandOff == FausLaunchHandOff.CONDENSE

    LaunchedEffect(Unit) {
        if (condenses) {
            launch { gradient.animateTo(1f, tween(650, easing = CubicBezierEasing(.5f, 0f, .25f, 1f))) }
            // The ember-colored mark would vanish against the orange, so it waits for the dark.
            delay(300)
        } else {
            launch { gradient.animateTo(1f, tween(300)) }
        }
        delay(250)
        launch { draw.animateTo(1f, tween(900, easing = CubicBezierEasing(.65f, 0f, .35f, 1f))) }
        delay(800)
        launch { dot.animateTo(1f, spring(dampingRatio = .45f, stiffness = Spring.StiffnessMediumLow)) }
        launch { delay(50); ripple1.animateTo(1f, tween(1_100, easing = LinearOutSlowInEasing)) }
        launch { delay(250); ripple2.animateTo(1f, tween(1_100, easing = LinearOutSlowInEasing)) }
        delay(400)
        // Critically damped spring: no velocity jump at the start or the end of the lift.
        launch { lift.animateTo(1f, spring(dampingRatio = 1f, stiffness = Spring.StiffnessLow)) }
        delay(100)
        letters.forEachIndexed { i, letter ->
            launch { delay(i * 60L); letter.animateTo(1f, tween(450, easing = CubicBezierEasing(.2f, .8f, .2f, 1f))) }
        }
        delay(550)
        launch { motto.animateTo(1f, tween(500, easing = FastOutSlowInEasing)) }
        delay(450)
        onReveal()
        reveal.animateTo(1f, tween(700, easing = CubicBezierEasing(.7f, 0f, .3f, 1f)))
        onFinished()
    }

    BoxWithConstraints(
        Modifier.fillMaxSize()
            // Swallow touches until the reveal is under way.
            .clickable(remember { MutableInteractionSource() }, indication = null, enabled = reveal.value < .5f) {}
            .semantics { contentDescription = "FausCrew" }
            .drawWithContent {
                val center = Offset(size.width / 2, size.height * CENTER_RATIO)
                val radius = hypot(size.width, size.height) * 1.1f * (1 - reveal.value)
                clipPath(Path().apply { addOval(androidx.compose.ui.geometry.Rect(center, radius)) }, ClipOp.Intersect) {
                    this@drawWithContent.drawContent()
                }
                // Lit edge on the closing circle so it reads against a dark app (transparent in light themes).
                if (reveal.value > 0f && reveal.value < 1f && splash.revealRim.alpha > 0f) {
                    drawCircle(splash.revealRim.copy(alpha = splash.revealRim.alpha * .25f), radius, center, style = Stroke(10.dp.toPx()))
                    drawCircle(splash.revealRim, radius, center, style = Stroke(1.5.dp.toPx()))
                }
            },
    ) {
        val centerY = maxHeight * CENTER_RATIO
        Box(Modifier.fillMaxSize().background(launchColor))
        if (condenses) {
            Box(Modifier.fillMaxSize().fausHeroBackground())
            Canvas(Modifier.fillMaxSize()) { drawLaunchCondense(gradient.value, launchColor) }
        } else {
            Box(Modifier.fillMaxSize().graphicsLayer { alpha = gradient.value }.fausHeroBackground())
        }

        // Ripples
        listOf(ripple1, ripple2).forEach { ripple ->
            Canvas(Modifier.fillMaxSize()) {
                if (dot.value <= 0f) return@Canvas
                val progress = ripple.value
                drawCircle(
                    splash.ripple.copy(alpha = splash.ripple.alpha * (1 - progress)),
                    radius = 60.dp.toPx() * (.6f + 2f * progress),
                    center = Offset(size.width / 2, centerY.toPx()),
                    style = Stroke(2.dp.toPx()),
                )
            }
        }

        // Mark
        Canvas(
            Modifier.size(132.dp).align(Alignment.TopCenter)
                .offset(y = centerY - 66.dp)
                .graphicsLayer {
                    val s = 1f - .14f * lift.value
                    scaleX = s; scaleY = s
                    translationY = -34.dp.toPx() * lift.value
                },
        ) {
            val markBrush = if (splash.mark.size > 1) fausMarkBrush(size.minDimension / 1024f, splash.mark)
                else SolidColor(splash.mark.first())
            drawFausMark(markBrush, progress = draw.value, dotScale = dot.value)
        }

        // Wordmark and motto
        Column(
            Modifier.align(Alignment.TopCenter).offset(y = centerY + 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row {
                WORDMARK.forEachIndexed { i, c ->
                    androidx.compose.material3.Text(
                        c.toString(),
                        Modifier.graphicsLayer {
                            alpha = letters[i].value
                            translationY = (1 - letters[i].value) * 12.dp.toPx()
                        },
                        color = if (i < 4) splash.wordmark else splash.wordmarkAccent,
                        fontSize = 34.sp,
                        fontWeight = if (i < 4) FontWeight.ExtraBold else FontWeight.Normal,
                    )
                }
            }
            androidx.compose.material3.Text(
                "Make living together fun",
                Modifier.graphicsLayer { alpha = motto.value; translationY = (1 - motto.value) * 8.dp.toPx() },
                color = splash.motto,
                fontSize = 15.sp,
            )
        }
    }
}

/**
 * The launch window's orange shrinking into a soft disc at the mark, where the dark header's
 * ember glow takes over (iOS `LaunchCondense`): solid to 72% of the radius, then feathered, and
 * fading out over the last quarter so it never ends as a hard dot.
 */
private fun DrawScope.drawLaunchCondense(progress: Float, color: Color) {
    val alpha = ((1 - progress) * 4).coerceAtMost(1f)
    if (alpha <= 0f) return
    val center = Offset(size.width / 2, size.height * CENTER_RATIO)
    val radius = (hypot(size.width, size.height) * .85f * (1 - progress)).coerceAtLeast(1f)
    drawRect(
        Brush.radialGradient(0f to color, .72f to color, 1f to color.copy(alpha = 0f), center = center, radius = radius),
        alpha = alpha,
    )
}
