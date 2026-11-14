package com.fauscrew.platform

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/** `shared/Fixtures/choreCatalogApi.json`; the Core `ChoreCatalogTests` read the same file. */
class ChoreCategoryTest {
    private val fixture: JSONObject by lazy {
        val stream = requireNotNull(javaClass.classLoader?.getResourceAsStream("choreCatalogApi.json"))
        JSONObject(stream.bufferedReader().use { it.readText() })
    }

    private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map(::getJSONObject)

    private val chore = JSONObject("""{"id":"c","houseId":"h","title":"Dishes","assignedTo":"u","dueDate":"2026-10-12T00:00:00Z","status":0,"level":20,"reviewVotes":[]}""")

    @Test fun categoryValuesMatchTheContract() {
        assertEquals(fixture.getJSONArray("categories").objects().map { it.getInt("value") },
            ChoreCategoryKind.assignable.map { it.raw })
        assertFalse(ChoreCategoryKind.UNCATEGORIZED.isAssignable)
        fixture.getJSONArray("choreCategoryValues").objects().forEach {
            assertEquals("raw ${it.getInt("raw")}", it.getInt("kind"), ChoreCategoryKind.of(it.getInt("raw")).raw)
        }
        assertEquals(ChoreCategoryKind.UNCATEGORIZED, ChoreCategoryKind.of(null))
    }

    @Test fun choresReadTheCategoryAndDefaultToUncategorized() {
        assertEquals(0, JSONObject(chore.toString()).toHouseChore().category)
        assertEquals(0, JSONObject(chore.toString()).put("category", JSONObject.NULL).toHouseChore().category)
        assertEquals(ChoreCategoryKind.PETS, JSONObject(chore.toString()).put("category", 6).toHouseChore().categoryKind)
        val unknown = JSONObject(chore.toString()).put("category", 42).toHouseChore()
        assertEquals(42, unknown.category)
        assertEquals(ChoreCategoryKind.UNCATEGORIZED, unknown.categoryKind)
    }
}
