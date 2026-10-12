package com.houseflow.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.houseflow.platform.LocalizedText

private val blue = Color(0xFF007AFF)
private val gray = Color(0xFF8E8E93)

private data class OnboardingPage(val titleKey: String, val subtitleKey: String, val icon: ImageVector)

private val pages = listOf(
    OnboardingPage("onboarding_page_1_title", "onboarding_page_1_subtitle", Icons.Filled.Home),
    OnboardingPage("onboarding_page_2_title", "onboarding_page_2_subtitle", Icons.Filled.Person),
    OnboardingPage("onboarding_page_3_title", "onboarding_page_3_subtitle", Icons.Filled.Notifications),
)

/** Mirrors the three-page iOS OnboardingView without adding a new entry action. */
@Composable
internal fun OnboardingScreen(strings: LocalizedText, busy: Boolean, onComplete: () -> Unit) {
    val pager = rememberPagerState(pageCount = { pages.size })
    val isLastPage = pager.currentPage == pages.lastIndex

    BoxWithConstraints(
        Modifier.fillMaxSize().background(Color.White).statusBarsPadding().navigationBarsPadding(),
    ) {
        val pageHeight = minOf(320.dp, maxHeight * 0.42f)
        Column(Modifier.fillMaxSize()) {
            Column(
                Modifier.fillMaxWidth().padding(top = 60.dp, bottom = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(strings.get("app_name"), color = blue, fontSize = 34.sp, fontWeight = FontWeight.Bold)
                Text(
                    strings.get("onboarding_app_subtitle"), color = gray, fontSize = 15.sp,
                    textAlign = TextAlign.Center,
                )
            }

            Spacer(Modifier.weight(1f))

            HorizontalPager(
                state = pager,
                modifier = Modifier.fillMaxWidth().height(pageHeight).padding(horizontal = 20.dp)
                    .testTag("onboarding_pager"),
            ) { pageIndex ->
                val page = pages[pageIndex]
                Column(
                    Modifier.fillMaxSize().background(Color(0xFFF5F5F5), RoundedCornerShape(20.dp))
                        .padding(horizontal = 32.dp, vertical = 20.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    if (pageIndex == 1) {
                        Box(Modifier.size(80.dp)) {
                            Icon(page.icon, null, Modifier.size(55.dp).align(Alignment.CenterStart), tint = blue)
                            Icon(page.icon, null, Modifier.size(55.dp).align(Alignment.CenterEnd), tint = blue)
                        }
                    } else {
                        Icon(page.icon, null, Modifier.size(80.dp), tint = blue)
                    }
                    Spacer(Modifier.height(30.dp))
                    Text(
                        strings.get(page.titleKey), fontSize = 22.sp, fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(16.dp))
                    Text(
                        strings.get(page.subtitleKey), color = gray, fontSize = 17.sp,
                        textAlign = TextAlign.Center,
                    )
                }
            }

            Spacer(Modifier.height(30.dp))
            Row(
                Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                pages.indices.forEach { index ->
                    Box(
                        Modifier.width(if (pager.currentPage == index) 24.dp else 8.dp).height(8.dp)
                            .background(if (pager.currentPage == index) blue else Color(0xFFD1D1D6), RoundedCornerShape(4.dp)),
                    )
                }
            }

            Spacer(Modifier.weight(1f))

            Button(
                onClick = onComplete,
                enabled = isLastPage && !busy,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 50.dp)
                    .height(56.dp).semantics { contentDescription = strings.get("onboarding_get_started_button") },
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = blue, contentColor = Color.White,
                    disabledContainerColor = Color(0xFFD1D1D6), disabledContentColor = gray,
                ),
            ) {
                Text(strings.get("onboarding_get_started_button"), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
