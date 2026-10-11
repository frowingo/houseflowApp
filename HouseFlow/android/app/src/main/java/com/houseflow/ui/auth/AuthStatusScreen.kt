package com.houseflow.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.LocalizedText
import com.houseflow.viewmodel.AuthRoute

/** Loading/error appearance follows the existing iOS HouseLoading/HouseError surfaces. */
@Composable
internal fun AuthStatusScreen(route: AuthRoute, strings: LocalizedText, retry: () -> Unit, logout: () -> Unit) {
    val titleKey = when (route) {
        is AuthRoute.Next -> "house_loading_auth_title"
        is AuthRoute.RestoreError -> "house_error_title"
        else -> "house_loading_auth_title"
    }
    Column(
        Modifier.fillMaxSize().background(Color(0xFFF7FAFC)).padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(Modifier.size(170.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.size(170.dp).background(Color(0xFF5856D6).copy(alpha = .08f), CircleShape))
            Box(Modifier.size(120.dp).background(Color(0xFF00A89F).copy(alpha = .085f), CircleShape))
            Box(Modifier.size(88.dp).background(Color.White, CircleShape))
            Icon(Icons.Filled.Home, null, Modifier.size(40.dp), tint = Color(0xFF5856D6))
        }
        Spacer(Modifier.height(32.dp))
        Text(strings.get(titleKey), fontSize = 22.sp, fontWeight = FontWeight.Bold,
            color = Color(0xFF1C1C1E), textAlign = TextAlign.Center)
        Spacer(Modifier.height(12.dp))
        when (route) {
            AuthRoute.Restoring -> {
                Text(strings.get("house_loading_auth_subtitle"), fontSize = 15.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                CircularProgressIndicator()
            }
            is AuthRoute.RestoreError -> {
                Text(route.message ?: strings.get("house_error_message"), textAlign = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                Action(strings.get("house_error_retry_button"), retry)
                Spacer(Modifier.height(12.dp))
                Action(strings.get("house_error_logout_button"), logout)
            }
            is AuthRoute.Next -> {
                Text(strings.get("house_loading_auth_subtitle"), fontSize = 15.sp, textAlign = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                CircularProgressIndicator()
            }
            AuthRoute.SignIn -> Unit
        }
    }
}

@Composable
private fun Action(label: String, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().height(54.dp).background(Color(0xFF007AFF), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick), contentAlignment = Alignment.Center,
    ) { Text(label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold) }
}
