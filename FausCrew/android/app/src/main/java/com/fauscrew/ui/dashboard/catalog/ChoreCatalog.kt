package com.fauscrew.ui.dashboard.catalog

import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCategoryKind

import java.text.Normalizer
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/*
 * Chore catalog: shelves on the client, chores from the server. Mirrors iOS
 * `Models/Chore/ChoreCatalog.swift`.
 *
 * The nine shelves (name, tagline, icon and colours) ship with the app in Turkish and English;
 * each piece of copy also has a `chore_catalog_*` localization key so the backend can override
 * it. The chores on the shelves, system templates and the user's drafts alike, come from
 * `GET chore/catalog` (`ChoreCatalogViewModel`) and are shown as the server wrote them. Creating
 * a chore from a card goes through the regular create-chore call. The shelves are checked
 * against `shared/Fixtures/choreCatalog.json` and their API values against
 * `choreCatalogApi.json` (`ChoreCatalogTest` here, `ChoreCatalogTests` on iOS).
 * Icons are iOS SF Symbol names; `ChoreCatalogIcons` maps them to Material icons.
 */

/** Built-in Turkish/English copy for one catalog string. */
internal data class CatalogCopy(val tr: String, val en: String)

/** A catalog card: a server record shaped for the grid and the editor, or the blank card. */
internal data class ChoreTemplate(
    val id: String,
    val categoryId: String,
    val icon: String,
    val title: String,
    val detail: String,
    /** Wire `ChoreLevel` raw value (10 easy, 20 medium, 30 hard). */
    val level: Int,
    /** Suggested repeat interval in days; 0 means a one-off chore. */
    val repeatDays: Int,
    val origin: Origin,
    /** The server record behind the card; `null` for the blank card. */
    val record: ChoreCatalogRecord?,
) {
    enum class Origin {
        /** A system template: read-only, saved as a new draft. */
        SYSTEM,
        /** One of the user's drafts: can be updated and deleted. */
        USER,
        /** "Create your own chore". */
        BLANK,
    }

    val isDraft: Boolean get() = origin == Origin.USER
    val isSystem: Boolean get() = origin == Origin.SYSTEM

    companion object {
        fun of(record: ChoreCatalogRecord): ChoreTemplate {
            val shelf = ChoreCatalog.shelf(record.categoryKind)
            return ChoreTemplate(
                id = record.id.orEmpty(),
                categoryId = shelf.id,
                icon = shelf.icon,
                title = record.title,
                detail = record.description,
                level = record.level.takeIf { it in listOf(10, 20, 30) } ?: 10,
                repeatDays = record.recurringInterval,
                origin = if (record.isSystem) Origin.SYSTEM else Origin.USER,
                record = record,
            )
        }
    }
}

/** A shelf of the catalog (kitchen, bathroom, pets…). Colours are `#RRGGBB`. */
internal data class ChoreCategory(
    val id: String,
    val icon: String,
    val tint: String,
    val deep: String,
    val name: CatalogCopy,
    val tagline: CatalogCopy,
) {
    val nameKey: String get() = "chore_catalog_category_${id}_name"
    val taglineKey: String get() = "chore_catalog_category_${id}_tagline"

    /** The category value the API uses for this shelf. */
    val kind: ChoreCategoryKind get() = ChoreCatalog.kindsByCategoryId[id] ?: ChoreCategoryKind.UNCATEGORIZED
}

/** `#RRGGBB` → opaque ARGB, kept free of `android.graphics` so JVM tests can use it. */
internal fun catalogArgb(hex: String): Long = 0xFF000000L or hex.removePrefix("#").toLong(16)

/** Repeat presets offered by the editor; values are days between occurrences (0 = once). */
internal object ChoreRepeatPresets {
    val all: List<Int> = listOf(0, 1, 2, 3, 7, 14, 30)
}

/**
 * When a catalog chore is due. Without a picked time the chore runs until the end of the chosen
 * day, sent as 23:59:59 local time (00:00 of the next day would be listed under tomorrow, and
 * 00:00 of the same day would already be overdue). iOS: `ChoreDueDate`.
 */
internal object ChoreDueDate {
    val endOfDay: LocalTime = LocalTime.of(23, 59, 59)

    fun resolve(day: LocalDate, time: LocalTime?, zone: ZoneId = ZoneId.systemDefault()): ZonedDateTime =
        day.atTime(time?.withSecond(0)?.withNano(0) ?: endOfDay).atZone(zone)

    /** The ISO-8601 offset string the create-chore request carries. */
    fun wire(day: LocalDate, time: LocalTime?, zone: ZoneId = ZoneId.systemDefault()): String =
        DateTimeFormatter.ISO_OFFSET_DATE_TIME.format(resolve(day, time, zone).toOffsetDateTime())
}

internal object ChoreCatalog {
    /** Shelf preselected for a chore written from scratch; the user can pick another. */
    const val defaultCustomCategoryId = "kitchen"

    /** The blank card behind "create your own chore". */
    val blankTemplate = ChoreTemplate("custom.blank", defaultCustomCategoryId, "square.and.pencil", "", "",
        level = 10, repeatDays = 0, origin = ChoreTemplate.Origin.BLANK, record = null)

    val categories: List<ChoreCategory> = listOf(
        ChoreCategory(
            id = "kitchen", icon = "fork.knife", tint = "#F07A3A", deep = "#B8461A",
            name = CatalogCopy("Mutfak", "Kitchen"),
            tagline = CatalogCopy("Ortak sofranın, temiz tezgahın işleri.", "Shared meals and clean counters."),
        ),
        ChoreCategory(
            id = "bath_laundry", icon = "shower.fill", tint = "#3A8FD6", deep = "#1D5A99",
            name = CatalogCopy("Banyo & Çamaşır", "Bath & Laundry"),
            tagline = CatalogCopy("Parlayan fayanslar, mis kokulu çamaşırlar.", "Shiny tiles and fresh laundry."),
        ),
        ChoreCategory(
            id = "toilet", icon = "toilet.fill", tint = "#21A79B", deep = "#11695F",
            name = CatalogCopy("Tuvalet", "Toilet"),
            tagline = CatalogCopy("Kimsenin sevmediği ama herkesin istediği temizlik.", "Nobody's favourite, everybody's wish."),
        ),
        ChoreCategory(
            id = "rooms", icon = "bed.double.fill", tint = "#6C63D9", deep = "#3F379A",
            name = CatalogCopy("Odalar", "Rooms"),
            tagline = CatalogCopy("Yatak odası, salon ve ortak alanlar.", "Bedrooms, living room and shared spaces."),
        ),
        ChoreCategory(
            id = "floors", icon = "bubbles.and.sparkles.fill", tint = "#2F9E5B", deep = "#1B6539",
            name = CatalogCopy("Zemin & Genel", "Floors & General"),
            tagline = CatalogCopy("Süpürge, paspas ve evin genel düzeni.", "Vacuuming, mopping and keeping things in order."),
        ),
        ChoreCategory(
            id = "pets", icon = "pawprint.fill", tint = "#D99A2B", deep = "#9A6410",
            name = CatalogCopy("Evcil hayvan", "Pets"),
            tagline = CatalogCopy("Evin tüylü üyeleri de bakım bekliyor.", "The furry housemates need care too."),
        ),
        ChoreCategory(
            id = "trash", icon = "trash.fill", tint = "#6E8A73", deep = "#3F5944",
            name = CatalogCopy("Çöp & Geri dönüşüm", "Trash & Recycling"),
            tagline = CatalogCopy("Çöp kapıda beklemesin.", "Don't let the bags pile up."),
        ),
        ChoreCategory(
            id = "plants", icon = "leaf.fill", tint = "#5FA83A", deep = "#386E1C",
            name = CatalogCopy("Bitki & Balkon", "Plants & Balcony"),
            tagline = CatalogCopy("Yeşil köşeler ve açık alanlar.", "Green corners and outdoor space."),
        ),
        ChoreCategory(
            id = "shopping", icon = "cart.fill", tint = "#E0517A", deep = "#A02A4E",
            name = CatalogCopy("Alışveriş & Ev", "Shopping & Home"),
            tagline = CatalogCopy("Dolap boşalmadan, fatura gecikmeden.", "Before the cupboards empty and bills go late."),
        ),
    )

    fun category(id: String): ChoreCategory? =
        categories.firstOrNull { it.id == id }

    /**
     * Wire value of each shelf (`ChoreCategoryKind`). Checked against
     * `shared/Fixtures/choreCatalogApi.json` on both platforms.
     */
    val kindsByCategoryId: Map<String, ChoreCategoryKind> = mapOf(
        "kitchen" to ChoreCategoryKind.KITCHEN,
        "bath_laundry" to ChoreCategoryKind.BATH_LAUNDRY,
        "toilet" to ChoreCategoryKind.TOILET,
        "rooms" to ChoreCategoryKind.ROOMS,
        "floors" to ChoreCategoryKind.FLOORS_GENERAL,
        "pets" to ChoreCategoryKind.PETS,
        "trash" to ChoreCategoryKind.TRASH_RECYCLING,
        "plants" to ChoreCategoryKind.PLANTS_BALCONY,
        "shopping" to ChoreCategoryKind.SHOPPING_HOME,
    )

    /** The shelf for a wire category; `null` for uncategorized (and unknown) values. */
    fun category(kind: ChoreCategoryKind): ChoreCategory? =
        if (kind.isAssignable) categories.firstOrNull { it.kind == kind } else null

    /** The shelf a catalog record sits on; a value this build does not know lands on the default. */
    fun shelf(kind: ChoreCategoryKind): ChoreCategory =
        category(kind) ?: category(defaultCustomCategoryId) ?: categories.first()

    /** Case- and diacritic-insensitive match on the title and detail. */
    fun search(
        query: String,
        among: List<ChoreTemplate>,
        resolve: (ChoreTemplate) -> Pair<String, String>,
    ): List<ChoreTemplate> {
        val needle = fold(query.trim())
        if (needle.isEmpty()) return emptyList()
        return among.filter { template ->
            val (title, detail) = resolve(template)
            listOf(title, detail).any { fold(it).contains(needle) }
        }
    }

    private val turkish = Locale.forLanguageTag("tr")

    private fun fold(text: String): String =
        Normalizer.normalize(text.lowercase(turkish), Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "")
            .replace('ı', 'i')
}
