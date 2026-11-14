package com.fauscrew.ui.dashboard.catalog

import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCategoryKind
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * The shelves are presentation data mirrored on both platforms; `shared/Fixtures/choreCatalog.json`
 * is the contract. iOS `ChoreCatalogTests` checks the Swift shelves against the same file. The
 * chores on the shelves come from the server (`ChoreCatalogViewModelTest`).
 */
class ChoreCatalogTest {
    private val fixture: JSONObject by lazy {
        val stream = requireNotNull(javaClass.classLoader?.getResourceAsStream("choreCatalog.json"))
        JSONObject(stream.bufferedReader().use { it.readText() })
    }

    private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map(::getJSONObject)
    private fun JSONArray.ints(): List<Int> = (0 until length()).map(::getInt)

    private fun assertCopy(label: String, json: JSONObject, copy: CatalogCopy) {
        assertEquals("$label tr", json.getString("tr"), copy.tr)
        assertEquals("$label en", json.getString("en"), copy.en)
    }

    @Test fun shelvesMapToTheApiCategoryValues() {
        val stream = requireNotNull(javaClass.classLoader?.getResourceAsStream("choreCatalogApi.json"))
        val categories = JSONObject(stream.bufferedReader().use { it.readText() }).getJSONArray("categories").objects()
        assertEquals(ChoreCatalog.categories.map { it.id }, categories.map { it.getString("catalogId") })
        categories.forEach {
            val kind = ChoreCategoryKind.of(it.getInt("value"))
            assertEquals(it.getString("catalogId"), ChoreCatalog.category(kind)?.id)
            assertEquals(kind, ChoreCatalog.category(it.getString("catalogId"))?.kind)
        }
        assertNull(ChoreCatalog.category(ChoreCategoryKind.UNCATEGORIZED))
        assertEquals(ChoreCategoryKind.KITCHEN, ChoreCatalog.blankTemplate.let { ChoreCatalog.category(it.categoryId)?.kind })
    }

    @Test fun categoriesMatchTheSharedFixture() {
        val categories = fixture.getJSONArray("categories").objects()
        assertEquals(categories.map { it.getString("id") }, ChoreCatalog.categories.map { it.id })
        categories.zip(ChoreCatalog.categories).forEach { (json, category) ->
            assertEquals(json.getString("icon"), category.icon)
            assertEquals(json.getString("tint"), category.tint)
            assertEquals(json.getString("deep"), category.deep)
            assertCopy(category.id, json.getJSONObject("name"), category.name)
            assertCopy(category.id, json.getJSONObject("tagline"), category.tagline)
        }
    }

    @Test fun defaultCategoryAndPresetsMatchTheSharedFixture() {
        assertEquals(fixture.getJSONArray("repeatPresets").ints(), ChoreRepeatPresets.all)
        assertEquals(LocalTime.parse(fixture.getString("endOfDay")), ChoreDueDate.endOfDay)
        assertEquals(fixture.getString("defaultCustomCategory"), ChoreCatalog.defaultCustomCategoryId)
        assertEquals(ChoreCatalog.defaultCustomCategoryId, ChoreCatalog.blankTemplate.categoryId)
        assertTrue(ChoreCatalog.category(ChoreCatalog.defaultCustomCategoryId) != null)
    }

    @Test fun bathroomAndLaundryShareOneShelf() {
        assertTrue(ChoreCatalog.category("bath_laundry") != null)
        assertNull(ChoreCatalog.category("bathroom"))
        assertNull(ChoreCatalog.category("laundry"))
    }

    @Test fun localizationKeysAreUnique() {
        val keys = ChoreCatalog.categories.flatMap { listOf(it.nameKey, it.taglineKey) }
        assertEquals(keys.size, keys.toSet().size)
        assertEquals("chore_catalog_category_kitchen_name", ChoreCatalog.category("kitchen")?.nameKey)
    }

    @Test fun everyShelfSymbolHasAMaterialIcon() {
        val symbols = ChoreCatalog.categories.map { it.icon } + ChoreCatalog.blankTemplate.icon
        val missing = symbols.toSet() - ChoreCatalogIcons.bySymbol.keys
        assertTrue("Unmapped symbols: $missing", missing.isEmpty())
    }

    @Test fun recordsBecomeCardsOnTheirShelf() {
        val system = ChoreTemplate.of(ChoreCatalogRecord(id = "6730f1c2a1b2c3d4e5f60701", title = "Bulaşıkları yıka",
            description = "Akşam", recurringInterval = 1, level = 20, category = 7, isSystem = true))
        assertEquals(ChoreTemplate.Origin.SYSTEM, system.origin)
        assertFalse(system.isDraft)
        assertEquals("trash", system.categoryId)
        assertEquals(ChoreCatalog.category("trash")?.icon, system.icon)
        assertEquals(20, system.level)
        assertEquals(1, system.repeatDays)
        assertEquals("Akşam", system.detail)

        // A value this build does not know lands on the default shelf instead of disappearing.
        val draft = ChoreTemplate.of(ChoreCatalogRecord(id = "6730f1c2a1b2c3d4e5f60718", title = "Kendi işim", category = 42))
        assertTrue(draft.isDraft)
        assertEquals(ChoreCatalog.defaultCustomCategoryId, draft.categoryId)
        assertEquals(ChoreTemplate.Origin.BLANK, ChoreCatalog.blankTemplate.origin)
    }

    @Test fun dueDateDefaultsToEndOfDayAndKeepsAPickedTime() {
        val zone = ZoneId.of("Europe/Istanbul")
        val day = LocalDate.of(2026, 11, 12)
        assertEquals("2026-11-12T23:59:59+03:00", ChoreDueDate.wire(day, null, zone))
        assertEquals("2026-11-12T18:30:00+03:00", ChoreDueDate.wire(day, LocalTime.of(18, 30), zone))
        assertEquals("2026-11-12T09:00:00Z", ChoreDueDate.wire(day, LocalTime.of(9, 0), ZoneOffset.UTC))
    }

    @Test fun searchIgnoresCaseAndTurkishDiacritics() {
        val cards = listOf(
            ChoreTemplate.of(ChoreCatalogRecord(id = "a", title = "Bulaşıkları yıka", category = 1, isSystem = true)),
            ChoreTemplate.of(ChoreCatalogRecord(id = "b", title = "Çöpü çıkar", description = "Geri dönüşüm", category = 7)),
        )
        val resolve: (ChoreTemplate) -> Pair<String, String> = { it.title to it.detail }
        assertEquals(listOf("a"), ChoreCatalog.search("BULAŞIK", cards, resolve).map { it.id })
        assertEquals(listOf("b"), ChoreCatalog.search("cop", cards, resolve).map { it.id })
        assertEquals(listOf("b"), ChoreCatalog.search("donusum", cards, resolve).map { it.id })
        assertTrue(ChoreCatalog.search("   ", cards, resolve).isEmpty())
        assertTrue(ChoreCatalog.search("zzzz", cards, resolve).isEmpty())
    }
}
