package com.fauscrew.ui.games

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
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
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fauscrew.platform.HouseRocketsNative
import com.fauscrew.platform.HouseTanksNative
import com.fauscrew.ui.games.tanks.HouseTanksArenaTank
import com.fauscrew.ui.games.tanks.HouseTanksMapBackdrop
import com.fauscrew.ui.games.tanks.HouseTanksPalette
import com.fauscrew.ui.games.tanks.TanksCopy
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.components.BrandHeroCard
import com.fauscrew.ui.components.mainScreenBackground
import com.fauscrew.ui.games.rockets.HouseRocketsPalette
import com.fauscrew.ui.games.rockets.HouseRocketsRocketMark
import com.fauscrew.ui.games.rockets.HouseRocketsTopography
import com.fauscrew.ui.games.rockets.RocketsCopy
import com.fauscrew.ui.theme.FausCrewColors
import com.fauscrew.ui.theme.FausCrewIcons
import com.fauscrew.ui.theme.FausCrewType
import com.fauscrew.ui.theme.Radius
import com.fauscrew.ui.theme.Spacing
import com.fauscrew.ui.theme.entrance
import com.fauscrew.ui.theme.rememberEntrance
import com.fauscrew.ui.theme.scaleButton
import com.fauscrew.ui.theme.softShadow

/**
 * `GamesHubView`. Android offers only the games that run on the shared Core, so the grid
 * holds House Rockets and FauseTanks in the same two-column layout as iOS.
 */
@Composable
internal fun GamesHubScreen(
    strings: LocalizedText,
    onOpenHouseRockets: () -> Unit,
    onOpenHouseTanks: () -> Unit = {},
    bundledCopy: (String?) -> Map<String, String> = HouseRocketsNative::copy,
    tanksCopy: (String?) -> Map<String, String> = HouseTanksNative::copy,
) {
    val rocketsCopy = remember(strings) { RocketsCopy(strings, bundledCopy(strings.prefix)) }
    val fauseTanksCopy = remember(strings) { TanksCopy(strings, tanksCopy(strings.prefix)) }
    val header = rememberEntrance(50)
    val firstCard = rememberEntrance(100)
    val secondCard = rememberEntrance(180)
    Box(Modifier.fillMaxSize().mainScreenBackground()) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
                .padding(start = Spacing.lg, end = Spacing.lg, bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(Spacing.xl),
        ) {
            BrandHeroCard(
                Modifier.padding(top = Spacing.xl).fillMaxWidth().height(112.dp).entrance(header, 12.dp),
                contentAlignment = Alignment.BottomStart,
            ) {
                Icon(FausCrewIcons.gameControllerFill, null,
                    Modifier.offset(x = 230.dp, y = (-28).dp).size(58.dp).rotate(-8f),
                    tint = Color.White.copy(alpha = .16f))
                Column(
                    Modifier.fillMaxHeight().padding(horizontal = Spacing.xl),
                    verticalArrangement = Arrangement.spacedBy(Spacing.xs, Alignment.CenterVertically),
                ) {
                    Text(strings.get("games_hub_title"),
                        style = TextStyle(fontSize = 23.sp, fontWeight = FontWeight.Bold), color = Color.White)
                    Text(strings.get("games_hub_subtitle"), style = FausCrewType.subheadline,
                        color = Color.White.copy(alpha = .82f))
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
                HouseRocketsCard(rocketsCopy, Modifier.weight(1f).entrance(firstCard, 24.dp), onOpenHouseRockets)
                HouseTanksCard(fauseTanksCopy, Modifier.weight(1f).entrance(secondCard, 24.dp), onOpenHouseTanks)
            }
        }
    }
}

/** `HubGameCard` for House Rockets: navy → blue cover with terrain and the rocket. */
@Composable
private fun HouseRocketsCard(copy: RocketsCopy, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.scaleButton(onClick = onClick)
            .softShadow(Color.Black.copy(alpha = .06f), 8.dp, y = 2.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.cardBackground),
    ) {
        BoxWithConstraints(
            Modifier.fillMaxWidth().height(120.dp).clipToBounds()
                .background(Brush.linearGradient(listOf(HouseRocketsPalette.navy, HouseRocketsPalette.blue),
                    start = Offset.Zero, end = Offset.Infinite)),
            contentAlignment = Alignment.Center,
        ) {
            HouseRocketsTopography(Modifier.fillMaxSize())
            HouseRocketsRocketMark(
                Modifier.align(Alignment.TopStart).offset(x = maxWidth / 2 - 47.dp, y = 42.dp - 47.dp).size(94.dp),
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Spacer(Modifier.height(40.dp))
                Text(copy("games_house_rockets_badge"), style = FausCrewType.caption,
                    color = Color.White.copy(alpha = .9f),
                    modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = .2f))
                        .padding(horizontal = Spacing.sm, vertical = 3.dp))
            }
        }
        Column(Modifier.fillMaxWidth().padding(Spacing.md), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(copy("games_house_rockets_title"), style = FausCrewType.headline,
                color = FausCrewColors.textPrimary)
            Text(copy("games_house_rockets_card_description"),
                style = FausCrewType.caption, color = FausCrewColors.textSecondary, maxLines = 3,
                overflow = TextOverflow.Ellipsis)
        }
    }
}

/** `HubGameCard` for FauseTanks: artwork only — one olive arena tank on the field-map sheet. */
@Composable
private fun HouseTanksCard(copy: TanksCopy, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(Radius.xl)
    Column(
        modifier.scaleButton(onClick = onClick)
            .softShadow(Color.Black.copy(alpha = .06f), 8.dp, y = 2.dp, shape = shape)
            .clip(shape)
            .background(FausCrewColors.cardBackground),
    ) {
        Box(
            Modifier.fillMaxWidth().height(120.dp).clipToBounds()
                .background(Brush.linearGradient(listOf(HouseTanksPalette.paper, HouseTanksPalette.sand),
                    start = Offset.Zero, end = Offset.Infinite)),
            contentAlignment = Alignment.Center,
        ) {
            HouseTanksMapBackdrop(Modifier.fillMaxSize())
            HouseTanksArenaTank(TanksColor.OLIVE, Modifier.size(62.dp))
        }
        Column(Modifier.fillMaxWidth().padding(Spacing.md), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            Text(copy("games_house_tanks_title"), style = FausCrewType.headline, color = FausCrewColors.textPrimary)
            Text(copy("games_house_tanks_card_description"), style = FausCrewType.caption,
                color = FausCrewColors.textSecondary, maxLines = 3, overflow = TextOverflow.Ellipsis)
        }
    }
}
