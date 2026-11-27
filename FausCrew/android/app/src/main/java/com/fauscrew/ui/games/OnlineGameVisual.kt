package com.fauscrew.ui.games

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.fauscrew.platform.FausSwitchNative
import com.fauscrew.platform.HouseRocketsNative
import com.fauscrew.platform.HouseTanksNative
import com.fauscrew.platform.LocalizedText
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.TanksColor
import com.fauscrew.ui.games.fausswitch.FausSwitchRobot
import com.fauscrew.ui.games.rockets.HouseRocketsRocketMark
import com.fauscrew.ui.games.tanks.HouseTanksArenaTank

/**
 * iOS `OnlineGameVisual`: the online games by their server key, with the hub title and the in-game
 * figure that stands for each. The Games hub and the dashboard stats card read names from here.
 * Keys the server sends that are not listed here are not shown.
 */
internal enum class OnlineGameVisual(
    val gameKey: String,
    val titleKey: String,
    private val bundled: (String?) -> Map<String, String>,
) {
    FAUS_SWITCH("fausSwitch", "games_faus_switch_title", FausSwitchNative::copy),
    HOUSE_ROCKETS("houseRockets", "games_house_rockets_title", HouseRocketsNative::copy),
    HOUSE_TANKS("houseTanks", "games_house_tanks_title", HouseTanksNative::copy);

    /** The server's text, else the game's bundled table, as each game's own screens read it. */
    fun title(strings: LocalizedText): String = strings.values[titleKey] ?: bundled(strings.prefix)[titleKey] ?: titleKey

    /** The olive robot, the rocket mark and the olive arena tank. */
    @Composable
    fun Artwork(modifier: Modifier = Modifier) = when (this) {
        FAUS_SWITCH -> FausSwitchRobot(SwitchColor.OLIVE, modifier)
        HOUSE_ROCKETS -> HouseRocketsRocketMark(modifier)
        HOUSE_TANKS -> HouseTanksArenaTank(TanksColor.OLIVE, modifier)
    }

    companion object {
        val knownGameKeys: Set<String> = entries.map { it.gameKey }.toSet()

        fun of(gameKey: String?): OnlineGameVisual? = entries.firstOrNull { it.gameKey == gameKey }
    }
}
