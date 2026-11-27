package com.fauscrew.ui.dashboard

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.auth.social
import com.fauscrew.ui.components.fausCardSheen
import com.fauscrew.ui.dashboard.catalog.catalogPress
import com.fauscrew.ui.games.rockets.rememberReduceMotion
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.softShadow
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The ring; the card is a third of the row, so the ring, the title and the count stack in a column. */
private val RingSize = 72.dp

/**
 * iOS `ChoreProgressCard`: what share of the listed chores is completed, a third of the dashboard's
 * metrics row. A tap squishes the card, spins the ring, pops the percentage and throws a burst of
 * sparks; every fifth tap (and any tap at 100%) throws a bigger one.
 */
@Composable
internal fun ChoreProgressCard(chores: List<HouseChore>, strings: LocalizedText, modifier: Modifier = Modifier) {
    val total = chores.size
    val completed = remember(chores) { chores.count { ChoreStatusUi.of(it.status) == ChoreStatusUi.COMPLETED } }
    val progress = if (total == 0) 0f else completed.toFloat() / total
    // Floored so 199 of 200 never reads as 100%.
    val percent = if (total > 0 && completed == total) 100 else (progress * 100).toInt()
    val tier = ProgressTier.of(total, completed)
    val percentText = strings.template("progress_percent_template", "percent" to percent.toString(), fallback = "{percent}%")
    val title = strings.social("chore_progress_title", "İlerleme", "Progress")
    val message = tier.message(strings)
    val subtitle = if (total == 0) {
        strings.social("chore_progress_empty_subtitle", "Görev eklenince ilerleme burada görünecek",
            "Progress shows up here once chores are added")
    } else {
        strings.template("todays_tasks_completed_template", "completed" to completed.toString(),
            "total" to total.toString(), fallback = "{completed}/{total}")
    }

    val reduceMotion = rememberReduceMotion()
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()

    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(350); appeared = true }
    val shown by animateFloatAsState(if (appeared) progress else 0f,
        spring(dampingRatio = .8f, stiffness = Spring.StiffnessLow), label = "progressRing")

    var taps by remember { mutableIntStateOf(0) }
    val spin = remember { Animatable(0f) }
    val pop = remember { Animatable(1f) }
    val sparks = remember { mutableStateListOf<ProgressSpark>() }
    val palette = listOf(FausCrewColors.indigo, FausCrewColors.teal, FausCrewColors.accentOrange,
        FausCrewColors.purple, FausCrewColors.blue)

    fun celebrate() {
        taps += 1
        val big = tier == ProgressTier.DONE || taps % 5 == 0
        haptics.performHapticFeedback(if (big) HapticFeedbackType.LongPress else HapticFeedbackType.TextHandleMove)
        if (reduceMotion) return

        scope.launch { spin.animateTo(spin.value + 360f, spring(dampingRatio = .6f, stiffness = 110f)) }
        scope.launch {
            pop.animateTo(1.28f, tween(140))
            pop.animateTo(.9f, tween(140))
            pop.animateTo(1f, spring(dampingRatio = .4f, stiffness = 420f))
        }
        val count = if (big) 18 else 10
        val start = Random.nextDouble(0.0, 360.0)
        val base = System.nanoTime()
        val batch = List(count) { index ->
            ProgressSpark(
                id = base + index,
                angle = start + index * 360.0 / count + Random.nextDouble(-12.0, 12.0),
                distance = Random.nextDouble(42.0, 74.0).toFloat(),
                icon = SparkIcons.random(),
                color = palette.random(),
                size = Random.nextDouble(6.0, 11.0).toFloat(),
                spin = Random.nextDouble(-240.0, 240.0).toFloat(),
            )
        }
        sparks.addAll(batch)
        val ids = batch.map { it.id }.toSet()
        scope.launch { delay(950); sparks.removeAll { it.id in ids } }
    }

    // The chrome sits in its own clipped layer so the sparks can fly past the card's edge, as on iOS.
    Box(
        modifier.fillMaxSize()
            .catalogPress(.965f) { celebrate() }
            .semantics { contentDescription = "$title, $message, $subtitle"; stateDescription = percentText },
    ) {
        DashboardMetricChrome(DpOffset(45.dp, 70.dp), Modifier.matchParentSize())
        Column(
            Modifier.fillMaxSize().clearAndSetSemantics {}.padding(horizontal = Spacing.sm, vertical = Spacing.md),
            horizontalAlignment = Alignment.CenterHorizontally,
            // Ring and text together always sit in the middle of the card, however long the text.
            verticalArrangement = Arrangement.spacedBy(Spacing.sm, Alignment.CenterVertically),
        ) {
            ProgressRing(shown, spin.value, pop.value, percentText, sparks)
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                BasicText(title.uppercase(),
                    style = TextStyle(color = FausCrewColors.textTertiary, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                        letterSpacing = .6.sp, textAlign = TextAlign.Center),
                    maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 8.sp, maxFontSize = 10.sp))
                BasicText(subtitle,
                    style = TextStyle(color = FausCrewColors.textSecondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center),
                    // The whole text, never cut short; a long one shrinks instead.
                    autoSize = TextAutoSize.StepBased(minFontSize = 7.sp, maxFontSize = 12.sp))
            }
        }
    }
}

/**
 * iOS `dashboardMetricCard`: the metrics row's shared card chrome (surface, sheen, teal wash, an
 * orange glow moved by [glowOffset] from the centre, gradient border and shadow). Laid under the
 * content with `matchParentSize`, so whatever the content draws past the edge is not clipped.
 */
@Composable
internal fun DashboardMetricChrome(glowOffset: DpOffset, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(Radius.xl)
    val glow = FausCrewColors.accentOrange.copy(alpha = .06f)
    Box(
        modifier
            .softShadow(FausCrewColors.deepIndigo.copy(alpha = .09f), 14.dp, y = 6.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.surface)
            .fausCardSheen()
            .background(Brush.linearGradient(listOf(
                FausCrewColors.teal.copy(alpha = .07f), FausCrewColors.indigo.copy(alpha = .04f), Color.Transparent,
            )))
            .drawBehind {
                drawCircle(glow, 70.dp.toPx(),
                    Offset(size.width / 2 + glowOffset.x.toPx(), size.height / 2 + glowOffset.y.toPx()))
            }
            .border(1.dp, Brush.linearGradient(listOf(
                FausCrewColors.teal.copy(alpha = .22f), FausCrewColors.indigo.copy(alpha = .12f),
            )), shape),
    )
}

@Composable
private fun ProgressRing(shown: Float, spin: Float, pop: Float, percentText: String, sparks: List<ProgressSpark>) {
    val track = FausCrewColors.indigo.copy(alpha = .12f)
    val arc = Brush.linearGradient(listOf(FausCrewColors.teal, FausCrewColors.indigo))
    Box(Modifier.size(RingSize), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = 7.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(track, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
            if (shown > 0f) {
                rotate(spin) {
                    drawArc(arc, -90f, 360f * shown.coerceIn(0f, 1f), false, Offset(inset, inset), arcSize,
                        style = Stroke(stroke, cap = StrokeCap.Round))
                }
            }
        }
        AnimatedContent(
            percentText,
            transitionSpec = { (slideInVertically { it / 2 } + fadeIn()) togetherWith (slideOutVertically { -it / 2 } + fadeOut()) },
            label = "percent",
        ) { text ->
            BasicText(text,
                Modifier.padding(horizontal = 8.dp).graphicsLayer { scaleX = pop; scaleY = pop },
                style = TextStyle(color = FausCrewColors.deepIndigo, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold),
                maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 17.sp))
        }
        sparks.forEach { spark -> androidx.compose.runtime.key(spark.id) { SparkView(spark) } }
    }
}

private enum class ProgressTier {
    EMPTY, START, WARMING, CLOSING, DONE;

    fun message(strings: LocalizedText): String = when (this) {
        EMPTY -> strings.social("chore_progress_tier_empty", "Liste boş, sahne senin!", "The list is empty, the stage is yours!")
        START -> strings.social("chore_progress_tier_start", "Hadi ilk görevi kapatalım!", "Let's knock out the first one!")
        WARMING -> strings.social("chore_progress_tier_warming", "Isınıyoruz, devam!", "Warming up, keep going!")
        CLOSING -> strings.social("chore_progress_tier_closing", "Yarıyı geçtik, az kaldı!", "Past halfway, almost there!")
        DONE -> strings.social("chore_progress_tier_done", "Hepsi tamam, harikasınız!", "All done, you rock!")
    }

    companion object {
        fun of(total: Int, completed: Int): ProgressTier = when {
            total == 0 -> EMPTY
            completed == total -> DONE
            completed == 0 -> START
            completed * 2 < total -> WARMING
            else -> CLOSING
        }
    }
}

private val SparkIcons: List<ImageVector> = listOf(
    FausCrewIcons.starFill, FausCrewIcons.sparkles, FausCrewIcons.circleFill, FausCrewIcons.heartFill, FausCrewIcons.triangleFill,
)

private data class ProgressSpark(
    val id: Long,
    val angle: Double,
    val distance: Float,
    val icon: ImageVector,
    val color: Color,
    val size: Float,
    val spin: Float,
)

/** One spark flying out of the ring's centre: it travels and spins first, then fades. */
@Composable
private fun SparkView(spark: ProgressSpark) {
    val travel = remember { Animatable(0f) }
    val fade = remember { Animatable(1f) }
    LaunchedEffect(spark.id) {
        launch { travel.animateTo(1f, tween(700, easing = LinearOutSlowInEasing)) }
        delay(350)
        fade.animateTo(0f, tween(400))
    }
    val radians = spark.angle * PI / 180
    val size: Dp = spark.size.dp
    Icon(spark.icon, null,
        Modifier.size(size).graphicsLayer {
            val t = travel.value
            val reach = spark.distance.dp.toPx() * t
            translationX = (cos(radians) * reach).toFloat()
            translationY = (sin(radians) * reach).toFloat()
            rotationZ = spark.spin * t
            val scale = 1.1f - .55f * t
            scaleX = scale; scaleY = scale
            alpha = fade.value
        },
        tint = spark.color)
}
