package com.fauscrew.ui.dashboard.catalog

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.Bed
import androidx.compose.material.icons.rounded.CleaningServices
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Eco
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.Restaurant
import androidx.compose.material.icons.rounded.ShoppingCart
import androidx.compose.material.icons.rounded.Shower
import androidx.compose.material.icons.rounded.Wc
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.fauscrew.platform.ChoreCategoryKind
import com.fauscrew.platform.LocalizedText
import com.fauscrew.ui.auth.social

/**
 * SF Symbol (as named on iOS) → Material icon for the shelves and the blank card; catalog cards
 * use their shelf's icon. `ChoreCatalogTest` checks every shelf in
 * `shared/Fixtures/choreCatalog.json` has an entry here.
 */
internal object ChoreCatalogIcons {
    val bySymbol: Map<String, ImageVector> = mapOf(
        // Categories
        "fork.knife" to Icons.Rounded.Restaurant,
        "shower.fill" to Icons.Rounded.Shower,
        "toilet.fill" to Icons.Rounded.Wc,
        "bed.double.fill" to Icons.Rounded.Bed,
        "bubbles.and.sparkles.fill" to Icons.Rounded.CleaningServices,
        "pawprint.fill" to Icons.Rounded.Pets,
        "trash.fill" to Icons.Rounded.Delete,
        "leaf.fill" to Icons.Rounded.Eco,
        "cart.fill" to Icons.Rounded.ShoppingCart,
        "square.and.pencil" to Icons.Rounded.EditNote,
    )

    fun of(symbol: String): ImageVector = bySymbol[symbol] ?: Icons.Rounded.AutoAwesome
}

// MARK: - Colours

internal val ChoreCategory.tintColor: Color get() = Color(catalogArgb(tint))
internal val ChoreCategory.deepColor: Color get() = Color(catalogArgb(deep))
internal val ChoreCategory.gradient: Brush get() = Brush.linearGradient(listOf(tintColor, deepColor))
internal val ChoreCategory.iconVector: ImageVector get() = ChoreCatalogIcons.of(icon)
internal val ChoreTemplate.iconVector: ImageVector get() = ChoreCatalogIcons.of(icon)

// MARK: - Copy (iOS `AppViewModel.catalog*`)

internal fun LocalizedText.catalog(key: String, tr: String, en: String): String = social(key, tr, en)

internal fun LocalizedText.catalogName(category: ChoreCategory): String =
    social(category.nameKey, category.name.tr, category.name.en)

/** Name of a chore's category, or "Uncategorized" for `0` and values this build does not know. */
internal fun LocalizedText.choreCategoryName(kind: ChoreCategoryKind): String =
    ChoreCatalog.category(kind)?.let(::catalogName) ?: social("chore_category_none", "Kategorisiz", "Uncategorized")

internal fun LocalizedText.catalogTagline(category: ChoreCategory): String =
    social(category.taglineKey, category.tagline.tr, category.tagline.en)

/** Catalog chores come from the server in one language and are shown as they are. */
@Suppress("UnusedReceiverParameter")
internal fun LocalizedText.catalogTitle(template: ChoreTemplate): String = template.title

@Suppress("UnusedReceiverParameter")
internal fun LocalizedText.catalogDetail(template: ChoreTemplate): String = template.detail

/** "Every day", "Every 3 days", "Weekly"… for a repeat interval in days. */
internal fun LocalizedText.catalogRepeatLabel(days: Int): String = when {
    days < 1 -> social("chore_catalog_repeat_once", "Tek sefer", "One-off")
    days == 1 -> social("chore_catalog_repeat_daily", "Her gün", "Every day")
    days == 7 -> social("chore_catalog_repeat_weekly", "Haftada bir", "Weekly")
    days == 14 -> social("chore_catalog_repeat_biweekly", "2 haftada bir", "Every 2 weeks")
    days == 30 -> social("chore_catalog_repeat_monthly", "Ayda bir", "Monthly")
    else -> social("chore_catalog_repeat_every_n_days", "{days} günde bir", "Every {days} days")
        .replace("{days}", days.toString())
}
