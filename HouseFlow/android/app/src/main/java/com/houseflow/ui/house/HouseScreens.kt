package com.houseflow.ui.house

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.InviteCodeBridge
import com.houseflow.platform.LocalizedText
import com.houseflow.viewmodel.HouseLoadingPhase
import com.houseflow.viewmodel.HouseUiState
import kotlin.math.roundToInt

private val indigo = Color(0xFF45579E)
private val deepIndigo = Color(0xFF33407A)
private val teal = Color(0xFF2E9187)
private val blue = Color(0xFF3D7AB8)
private val purple = Color(0xFF7A61AD)
private val orange = Color(0xFFFF7A26)
private val orangeInk = Color(0xFFBA400B)
private val ink = Color(0xFF1C1C1E)
private val muted = Color(0xFF6B6B73)
private val surface = Color.White
private val page = Color(0xFFF7F7FA)
private val disabled = Brush.horizontalGradient(listOf(Color(0xFFD1D1D6), Color(0xFFC2C2C7)))
private val primary = Brush.horizontalGradient(listOf(indigo, deepIndigo))
private val joinGradient = Brush.horizontalGradient(listOf(Color(0xFF28665E), Color(0xFF2E5C96)))

@Composable
private fun HouseBackground(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(Color(0xFFFFFAF6), page, Color(0xFFFAF8FA))))) {
        content()
    }
}

@Composable
internal fun HouseSelectionScreen(strings: LocalizedText, onCreate: () -> Unit, onJoin: () -> Unit) {
    HouseBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Column(Modifier.padding(top = 60.dp, bottom = 32.dp).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(strings.get("house_selection_title"), fontSize = 34.sp, fontWeight = FontWeight.Bold,
                    color = ink, textAlign = TextAlign.Center)
                Text(strings.get("house_selection_subtitle"), fontSize = 15.sp, color = muted, textAlign = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                Box(Modifier.size(width = 34.dp, height = 4.dp).clip(CircleShape).background(orange))
            }
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)) {
                HouseOption(strings.get("house_selection_create_title"), strings.get("house_selection_create_subtitle"),
                    indigo, true, onCreate)
                HouseOption(strings.get("house_selection_join_title"), strings.get("house_selection_join_subtitle"),
                    teal, false, onJoin)
            }
        }
    }
}

@Composable
private fun HouseOption(title: String, subtitle: String, tint: Color, create: Boolean, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().height(220.dp).shadow(14.dp, RoundedCornerShape(24.dp))
        .clip(RoundedCornerShape(24.dp)).background(surface).border(1.dp, tint.copy(alpha = .18f), RoundedCornerShape(24.dp))
        .clickable(onClick = onClick).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Box(Modifier.size(100.dp).background(Brush.linearGradient(listOf(tint, tint.copy(alpha = .72f))), CircleShape),
            contentAlignment = Alignment.Center) {
            Icon(if (create) Icons.Filled.Add else Icons.Filled.Person, null, Modifier.size(60.dp), tint = Color.White)
        }
        Text(title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold, color = ink, textAlign = TextAlign.Center)
        Text(subtitle, fontSize = 15.sp, color = muted, textAlign = TextAlign.Center, maxLines = 3)
    }
}

@Composable
internal fun CreateHouseScreen(state: HouseUiState, strings: LocalizedText, onBack: () -> Unit,
    onCreate: (String, Int, Int) -> Unit) {
    var name by remember { mutableStateOf("") }
    var type by remember { mutableIntStateOf(1) }
    var count by remember { mutableIntStateOf(3) }
    var showSummary by remember { mutableStateOf(false) }
    val valid = name.isNotBlank()
    HouseBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Column(Modifier.fillMaxWidth().padding(top = 32.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                HouseBack(onBack)
                Text(strings.get("create_house_title"), fontSize = 34.sp, fontWeight = FontWeight.Bold, color = ink)
                Text(strings.get("create_house_subtitle"), fontSize = 15.sp, color = muted, textAlign = TextAlign.Center)
            }
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp)) {
                Text(strings.get("create_house_name_label"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink)
                BasicTextField(name, { name = it.take(30) }, Modifier.fillMaxWidth().height(56.dp)
                    .clip(RoundedCornerShape(12.dp)).background(surface)
                    .border(if (name.isEmpty()) 1.dp else 2.dp, if (name.isEmpty()) indigo.copy(alpha = .10f) else orange,
                        RoundedCornerShape(12.dp)).padding(horizontal = 16.dp, vertical = 14.dp)
                    .semantics { contentDescription = strings.get("create_house_name_label") },
                    textStyle = TextStyle(fontSize = 17.sp, color = ink), cursorBrush = SolidColor(indigo),
                    singleLine = true, keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    decorationBox = { inner -> Box(contentAlignment = Alignment.CenterStart) {
                        if (name.isEmpty()) Text(strings.get("create_house_name_placeholder"), color = muted, fontSize = 17.sp)
                        inner()
                    } })
                if (name.isNotEmpty()) Text(strings.get("create_house_name_count_template").replace("{count}", "${name.length}"),
                    fontSize = 12.sp, color = muted)
                Text(strings.get("create_house_type_label"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    listOf(Triple(1, "create_house_type_student", purple), Triple(2, "create_house_type_shared", teal),
                        Triple(3, "create_house_type_dorm", blue)).forEach { (value, key, tint) ->
                        Column(Modifier.weight(1f).height(90.dp).clip(RoundedCornerShape(16.dp))
                            .background(if (type == value) tint.copy(alpha = .15f) else surface)
                            .border(if (type == value) 2.dp else 1.dp,
                                if (type == value) orange else tint.copy(alpha = .12f), RoundedCornerShape(16.dp))
                            .clickable { type = value }.padding(6.dp), horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center) {
                            Icon(Icons.Filled.Home, null, Modifier.size(20.dp), tint = tint)
                            Text(strings.get(key), fontSize = 12.sp, color = ink, textAlign = TextAlign.Center, maxLines = 2)
                        }
                    }
                }
                Text(strings.get("create_house_member_count_label"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink)
                Text("$count", Modifier.fillMaxWidth(), fontSize = 18.sp, fontWeight = FontWeight.Bold,
                    color = indigo, textAlign = TextAlign.Center)
                Slider(value = count.toFloat(), onValueChange = { count = it.roundToInt().coerceIn(2, 8) },
                    valueRange = 2f..8f, steps = 5)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(strings.get("common_min"), fontSize = 12.sp, color = muted)
                    Text(strings.get("common_max"), fontSize = 12.sp, color = muted)
                }
                state.error?.let { Text(it, color = Color(0xFFD1444F), fontSize = 15.sp) }
            }
            HouseButton(strings.get("create_house_submit_button"), valid, primary) { showSummary = true }
            Spacer(Modifier.height(24.dp))
        }
    }
    if (showSummary) AlertDialog(onDismissRequest = { showSummary = false },
        title = { Text(strings.get("house_summary_title")) },
        text = { Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(strings.get("house_summary_subtitle"))
            Text("${strings.get("house_summary_name_label")}: $name")
            Text("${strings.get("house_summary_type_label")}: ${strings.get(listOf("create_house_type_student", "create_house_type_shared", "create_house_type_dorm")[type - 1])}")
            Text("${strings.get("house_summary_person_count_label")}: $count")
        } },
        confirmButton = { TextButton(onClick = { showSummary = false; onCreate(name, type, count) }) {
            Text(strings.get("house_summary_create_button")) } },
        dismissButton = { TextButton(onClick = { showSummary = false }) { Text(strings.get("common_edit")) } })
}

@Composable
internal fun JoinHouseScreen(state: HouseUiState, strings: LocalizedText, onBack: () -> Unit,
    onJoin: (String) -> Unit) {
    var code by remember { mutableStateOf("") }
    HouseBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(20.dp))
            HouseBack(onBack)
            Box(Modifier.padding(top = 16.dp).size(102.dp).background(teal.copy(alpha = .10f), CircleShape),
                contentAlignment = Alignment.Center) { Icon(Icons.Filled.Home, null, Modifier.size(44.dp), tint = indigo) }
            Text(strings.get("join_house_title"), Modifier.padding(top = 16.dp),
                fontSize = 34.sp, fontWeight = FontWeight.Bold, color = ink)
            Text(strings.get("join_house_subtitle"), Modifier.padding(horizontal = 32.dp, vertical = 12.dp),
                fontSize = 15.sp, color = muted, textAlign = TextAlign.Center)
            Column(Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(strings.get("invite_code_label"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink)
                BasicTextField(code, { code = InviteCodeBridge.normalize(it) }, Modifier.fillMaxWidth().height(56.dp)
                    .clip(RoundedCornerShape(12.dp)).background(surface).border(1.dp, indigo.copy(alpha = .12f), RoundedCornerShape(12.dp))
                    .padding(16.dp).semantics { contentDescription = strings.get("invite_code_label") },
                    singleLine = true, cursorBrush = SolidColor(indigo),
                    textStyle = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = ink,
                        fontFamily = FontFamily.Monospace, textAlign = TextAlign.Center),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    decorationBox = { inner -> Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        if (code.isEmpty()) Text(strings.get("join_house_invite_placeholder"), color = muted)
                        inner()
                    } })
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(teal.copy(alpha = .075f))
                    .border(1.dp, teal.copy(alpha = .16f), RoundedCornerShape(12.dp)).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(strings.get("join_house_help_title"), color = indigo, fontSize = 15.sp)
                    (1..3).forEach { step -> Text("$step  ${strings.get("join_house_step_$step")}", fontSize = 14.sp, color = ink) }
                }
                state.error?.let { Text(it, color = Color(0xFFD1444F), fontSize = 15.sp) }
            }
            HouseButton(strings.get("join_house_submit_button"), code.length == 8, joinGradient) { onJoin(code) }
            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun HouseBack(onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp)) {
        Box(Modifier.size(40.dp).clip(CircleShape).background(surface).clickable(onClick = onClick),
            contentAlignment = Alignment.Center) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, null, Modifier.size(20.dp), tint = orangeInk)
        }
    }
}

@Composable
private fun HouseButton(label: String, enabled: Boolean, brush: Brush, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(horizontal = 24.dp).height(54.dp).clip(RoundedCornerShape(16.dp))
        .background(if (enabled) brush else disabled).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center) {
        Text(label, fontSize = 17.sp, fontWeight = FontWeight.SemiBold,
            color = if (enabled) Color.White else muted)
    }
}

@Composable
internal fun HouseLoadingScreen(state: HouseUiState, strings: LocalizedText) {
    val (title, subtitle, tint) = when (state.phase) {
        HouseLoadingPhase.CREATING -> Triple("house_loading_creating_title", "house_loading_creating_subtitle", purple)
        HouseLoadingPhase.JOINING -> Triple("house_loading_joining_title", "house_loading_joining_subtitle", teal)
        HouseLoadingPhase.LOADING_DETAILS -> Triple("house_loading_details_title", "house_loading_details_subtitle", blue)
        HouseLoadingPhase.LOADING_HOUSE -> Triple("house_loading_house_title", "house_loading_house_subtitle", blue)
    }
    HouseBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Box(Modifier.size(170.dp).background(tint.copy(alpha = .08f), CircleShape), contentAlignment = Alignment.Center) {
                Box(Modifier.size(120.dp).background(teal.copy(alpha = .085f), CircleShape))
                Box(Modifier.size(88.dp).background(surface, CircleShape))
                Icon(Icons.Filled.Home, null, Modifier.size(40.dp), tint = tint)
            }
            Spacer(Modifier.height(32.dp))
            Text(strings.get(title), fontSize = 22.sp, fontWeight = FontWeight.Bold, color = ink, textAlign = TextAlign.Center)
            Text(strings.get(subtitle), Modifier.padding(top = 12.dp), fontSize = 15.sp, color = muted, textAlign = TextAlign.Center)
            CircularProgressIndicator(Modifier.padding(top = 24.dp), color = orange)
        }
    }
}

@Composable
internal fun HouseErrorScreen(state: HouseUiState, strings: LocalizedText, retry: () -> Unit, logout: () -> Unit) {
    HouseBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Box(Modifier.size(120.dp).background(Color(0xFFD1444F).copy(alpha = .08f), CircleShape),
                contentAlignment = Alignment.Center) {
                Text("!", fontSize = 48.sp, fontWeight = FontWeight.Bold, color = Color(0xFFD1444F))
            }
            Text(strings.get("house_error_title"), Modifier.padding(top = 32.dp),
                fontSize = 22.sp, fontWeight = FontWeight.Bold, color = ink)
            Text(state.error ?: strings.get("house_error_message"), Modifier.padding(top = 12.dp),
                fontSize = 15.sp, color = muted, textAlign = TextAlign.Center)
            Spacer(Modifier.height(32.dp))
            HouseButton(strings.get("house_error_retry_button"), true, primary, retry)
            Spacer(Modifier.height(16.dp))
            Text(strings.get("house_error_logout_button"), Modifier.clickable(onClick = logout).padding(16.dp),
                color = Color(0xFFD1444F), fontWeight = FontWeight.SemiBold)
        }
    }
}
