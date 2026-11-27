package com.fauscrew.ui.dashboard

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.animation.core.LinearEasing
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
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

/** The dashboard header's content height (66dp house image in a 3dp frame); with the same vertical padding both cards stand equally tall. */
private val ContentHeight = 72.dp

/** Above this many chores the dots get too thin; a plain bar takes their place. */
private const val MaxDots = 12

/**
 * iOS `ChoreProgressCard`: what share of the listed chores is completed. A tap squishes the card,
 * spins the ring, pops the percentage, wiggles the badge, waves the chore dots and throws a burst of
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
    val badgeScale = remember { Animatable(1f) }
    /** 0 → 1 drives a damped wiggle; resting at 1 means no tilt. */
    val wiggle = remember { Animatable(1f) }
    val dotLifts = remember(total) { List(if (total in 1..MaxDots) total else 0) { Animatable(0f) } }
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
        scope.launch {
            badgeScale.animateTo(1.25f, tween(110))
            badgeScale.animateTo(1f, spring(dampingRatio = .4f, stiffness = 500f))
        }
        scope.launch { wiggle.snapTo(0f); wiggle.animateTo(1f, tween(450, easing = LinearEasing)) }
        dotLifts.forEachIndexed { index, lift ->
            scope.launch {
                delay(45L * index)
                lift.animateTo(-6f, tween(130))
                lift.animateTo(0f, spring(dampingRatio = .4f, stiffness = 500f))
            }
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

    val shape = RoundedCornerShape(Radius.xl)
    val glow = FausCrewColors.accentOrange.copy(alpha = .06f)
    // The chrome sits in its own clipped layer so the sparks can fly past the card's edge, as on iOS.
    Box(
        modifier.fillMaxWidth()
            .catalogPress(.965f) { celebrate() }
            .semantics { contentDescription = "$title, $message"; stateDescription = percentText }
            .softShadow(FausCrewColors.deepIndigo.copy(alpha = .09f), 14.dp, y = 6.dp, shape = shape),
    ) {
        Box(
            Modifier.matchParentSize().clip(shape)
                .background(FausCrewColors.surface)
                .fausCardSheen()
                .background(Brush.linearGradient(listOf(
                    FausCrewColors.teal.copy(alpha = .07f), FausCrewColors.indigo.copy(alpha = .04f), Color.Transparent,
                )))
                .drawBehind {
                    drawCircle(glow, 70.dp.toPx(), Offset(size.width / 2 + 150.dp.toPx(), size.height / 2 + 50.dp.toPx()))
                }
                .border(1.dp, Brush.linearGradient(listOf(
                    FausCrewColors.teal.copy(alpha = .22f), FausCrewColors.indigo.copy(alpha = .12f),
                )), shape),
        )
        Row(
            Modifier.fillMaxWidth().clearAndSetSemantics {}
                .padding(horizontal = Spacing.lg, vertical = Spacing.xl).height(ContentHeight),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            ProgressRing(shown, spin.value, pop.value, percentText, sparks)
            Column(Modifier.weight(1f).fillMaxHeight()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(title.uppercase(), Modifier.weight(1f), fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                        letterSpacing = .6.sp, color = FausCrewColors.textTertiary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    TierBadge(tier.icon, badgeScale.value, wiggleAngle(wiggle.value))
                }
                Spacer(Modifier.weight(1f))
                BasicText(message,
                    style = TextStyle(color = FausCrewColors.textPrimary, fontSize = 15.sp, fontWeight = FontWeight.Bold),
                    maxLines = 1, autoSize = TextAutoSize.StepBased(minFontSize = 11.sp, maxFontSize = 15.sp))
                Text(subtitle, fontSize = 12.sp, color = FausCrewColors.textSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.weight(1f))
                when {
                    dotLifts.isNotEmpty() -> ChoreDots(completed, dotLifts)
                    total > 0 -> ProgressBar(shown)
                }
            }
        }
    }
}

/** Damped shake: -18° swinging back to rest over the tap's 450ms; 0 at both ends. */
private fun wiggleAngle(t: Float): Float =
    if (t <= 0f || t >= 1f) 0f else (-18f * sin(t * 4f * PI.toFloat()) * (1f - t))

@Composable
private fun ProgressRing(shown: Float, spin: Float, pop: Float, percentText: String, sparks: List<ProgressSpark>) {
    val track = FausCrewColors.indigo.copy(alpha = .12f)
    val arc = Brush.linearGradient(listOf(FausCrewColors.teal, FausCrewColors.indigo))
    Box(Modifier.size(ContentHeight), contentAlignment = Alignment.Center) {
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

@Composable
private fun TierBadge(icon: ImageVector, scale: Float, angle: Float) {
    Box(
        Modifier.size(22.dp)
            .graphicsLayer { scaleX = scale; scaleY = scale; rotationZ = angle }
            .background(Brush.linearGradient(listOf(FausCrewColors.accentOrange, FausCrewColors.accentOrangeDeep)), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, null, Modifier.size(13.dp), tint = Color.White)
    }
}

/** One dot per chore, completed ones first; they wave left to right on a tap. */
@Composable
private fun ChoreDots(completed: Int, lifts: List<Animatable<Float, AnimationVector1D>>) {
    val done = Brush.horizontalGradient(listOf(FausCrewColors.teal, FausCrewColors.indigo))
    val open = FausCrewColors.indigo.copy(alpha = .14f)
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        lifts.forEachIndexed { index, lift ->
            val dot = Modifier.weight(1f).height(6.dp).graphicsLayer { translationY = lift.value.dp.toPx() }
            Box(if (index < completed) dot.background(done, CircleShape) else dot.background(open, CircleShape))
        }
    }
}

@Composable
private fun ProgressBar(shown: Float) {
    Box(Modifier.fillMaxWidth().height(6.dp).background(FausCrewColors.indigo.copy(alpha = .14f), CircleShape)) {
        Box(Modifier.fillMaxHeight().fillMaxWidth(shown.coerceIn(0f, 1f))
            .background(Brush.horizontalGradient(listOf(FausCrewColors.teal, FausCrewColors.indigo)), CircleShape))
    }
}

private enum class ProgressTier(val icon: ImageVector) {
    EMPTY(FausCrewIcons.sparkles),
    START(FausCrewIcons.checklistUnchecked),
    WARMING(FausCrewIcons.flameFill),
    CLOSING(FausCrewIcons.boltFill),
    DONE(FausCrewIcons.trophyFill);

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
