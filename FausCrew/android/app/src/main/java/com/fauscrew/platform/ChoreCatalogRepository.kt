package com.fauscrew.platform

import android.content.Context
import com.fauscrew.androidbridge.FausCrewAndroidBridge
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.OffsetDateTime
import kotlin.coroutines.cancellation.CancellationException

/*
 * `GET` / `PUT chore/catalog` (Core `ChoreCatalogWireContract`, iOS `ChoreCatalogService`).
 * Contract: `Documents/choreCatalogBackendContract.md`. The request body, the server's rules and
 * patching the list with a PUT result live in Core and cross the bridge once per request and
 * once per response; [ChoreCatalogRules] only mirrors the rules so the editor can enable its
 * button as the user types.
 */

/** `ChoreCatalogModel` (Core `ChoreCatalogRecord`), with the server's fields kept as sent. */
internal data class ChoreCatalogRecord(
    /** `null` for a record the server has not created yet. */
    val id: String? = null,
    val title: String,
    val description: String = "",
    /** Days between repeats, 0–365; `0` does not repeat. */
    val recurringInterval: Int = 0,
    /** Wire `ChoreLevel` raw value. */
    val level: Int = 10,
    /** `ChoreCategoryKind` raw value, 1–9. */
    val category: Int,
    val isDeleted: Boolean = false,
    /** A system template: read-only for normal users. */
    val isSystem: Boolean = false,
    val userId: String? = null,
    val createdOn: String? = null,
    val updatedOn: String? = null,
) {
    val categoryKind: ChoreCategoryKind get() = ChoreCategoryKind.of(category)

    /** A new copy owned by the user: how a system template is saved as a draft. */
    val asNewUserRecord: ChoreCatalogRecord
        get() = ChoreCatalogRecord(title = title, description = description, recurringInterval = recurringInterval,
            level = level, category = category)

    val markedDeleted: ChoreCatalogRecord get() = copy(isDeleted = true)

    /** `updatedOn` (or `createdOn`), for newest-first lists. */
    val updatedInstant: Instant? get() = parseDate(updatedOn ?: createdOn)

    fun toJson(): JSONObject = JSONObject()
        .put("title", title).put("description", description).put("recurringInterval", recurringInterval)
        .put("level", level).put("category", category).put("isDeleted", isDeleted).put("isSystem", isSystem)
        .apply {
            id?.let { put("id", it) }
            userId?.let { put("userId", it) }
            createdOn?.let { put("createdOn", it) }
            updatedOn?.let { put("updatedOn", it) }
        }

    companion object {
        fun fromJson(json: JSONObject): ChoreCatalogRecord = ChoreCatalogRecord(
            id = json.optStringOrNull("id")?.ifEmpty { null },
            title = json.getString("title"),
            description = json.optStringOrNull("description").orEmpty(),
            recurringInterval = json.optInt("recurringInterval", 0),
            level = json.getInt("level"),
            category = json.optInt("category", 0),
            isDeleted = json.optBoolean("isDeleted", false),
            isSystem = json.optBoolean("isSystem", false),
            userId = json.optStringOrNull("userId"),
            createdOn = json.optStringOrNull("createdOn"),
            updatedOn = json.optStringOrNull("updatedOn"),
        )

        fun encode(records: List<ChoreCatalogRecord>): String = JSONArray(records.map { it.toJson() }).toString()

        fun decode(array: JSONArray): List<ChoreCatalogRecord> = List(array.length()) { fromJson(array.getJSONObject(it)) }

        private fun parseDate(value: String?): Instant? =
            value?.let { runCatching { OffsetDateTime.parse(it).toInstant() }.getOrNull() }
    }
}

private fun JSONObject.optStringOrNull(key: String): String? = if (isNull(key)) null else optString(key)

/** System templates in server order (category, then title). */
internal val List<ChoreCatalogRecord>.systemRecords: List<ChoreCatalogRecord>
    get() = filter { it.isSystem && !it.isDeleted }

/** The user's own records, most recently saved first (stable for equal dates). */
internal val List<ChoreCatalogRecord>.userRecords: List<ChoreCatalogRecord>
    get() = filter { !it.isSystem && !it.isDeleted }
        .sortedByDescending { it.updatedInstant ?: Instant.MIN }

/**
 * The server's rules (Core `ChoreCatalogRules`), for enabling controls as the user types. The
 * bridge checks them again before anything is sent.
 */
internal object ChoreCatalogRules {
    val titleLength = 3..200
    const val DESCRIPTION_MAX_LENGTH = 1000
    val recurringInterval = 0..365

    fun normalized(text: String): String = text.trim()

    private fun String.characters(): Int = codePointCount(0, length)

    fun isValidTitle(title: String): Boolean = normalized(title).characters() in titleLength

    fun isValidDescription(description: String): Boolean = normalized(description).characters() <= DESCRIPTION_MAX_LENGTH

    /** Whether the server would accept [record] in a PUT. */
    fun isValid(record: ChoreCatalogRecord): Boolean {
        val id = record.id?.ifEmpty { null }
        return (id == null || id.length == 24) &&
            isValidTitle(record.title) &&
            isValidDescription(record.description) &&
            record.recurringInterval in recurringInterval &&
            record.level in listOf(10, 20, 30) &&
            ChoreCategoryKind.of(record.category).isAssignable &&
            !(record.isDeleted && id == null) &&
            !record.isSystem
    }
}

/** A failed catalog request, with the server's localized message when it sent one. */
internal data class ChoreCatalogFailure(val kind: Kind, val message: String? = null) {
    /** Core `ChoreCatalogFailure.Kind`; [wire] is its raw value on the bridge. */
    enum class Kind(val wire: String) {
        VALIDATION("validation"), UNAUTHORIZED("unauthorized"), FORBIDDEN("forbidden"),
        NOT_FOUND("notFound"), SERVER("server"), INVALID_RESPONSE("invalidResponse");

        companion object {
            fun of(wire: String?): Kind = entries.firstOrNull { it.wire == wire } ?: SERVER
        }
    }

    /** After a 404 the local list is stale: fetch it again. */
    val refreshesList: Boolean get() = kind == Kind.NOT_FOUND

    companion object {
        fun of(kind: Kind, message: String?): ChoreCatalogFailure = ChoreCatalogFailure(kind, message?.ifBlank { null })
    }
}

internal class ChoreCatalogException(val failure: ChoreCatalogFailure) : Exception(failure.message ?: failure.kind.wire)

internal interface ChoreCatalogWire {
    /** `{ok, body}` or `{ok:false, kind, rule, index}`. */
    fun body(recordsJson: String): String
    /** `{ok, records}` or `{ok:false, kind, message}`. */
    fun response(action: String, status: Int, body: String, recordsJson: String, localJson: String): String
}

private object NativeChoreCatalogWire : ChoreCatalogWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun body(recordsJson: String): String {
        checked
        return FausCrewAndroidBridge.choreCatalogRequestBody(recordsJson)
    }

    override fun response(action: String, status: Int, body: String, recordsJson: String, localJson: String): String {
        checked
        return FausCrewAndroidBridge.choreCatalogResponse(action, status, body, recordsJson, localJson)
    }
}

/** iOS `ChoreCatalogService`: failures are thrown as [ChoreCatalogException]. */
internal class ChoreCatalogRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val read: (SessionField) -> SessionReadResult,
    private val wire: ChoreCatalogWire = NativeChoreCatalogWire,
) {
    suspend fun fetch(): List<ChoreCatalogRecord> = withContext(Dispatchers.IO) {
        call("list", "GET", body = null, recordsJson = "", localJson = "")
    }

    /** Sends [records] and returns [local] patched with the result (in request order). */
    suspend fun upsert(records: List<ChoreCatalogRecord>, local: List<ChoreCatalogRecord>): List<ChoreCatalogRecord> =
        withContext(Dispatchers.IO) {
            val recordsJson = ChoreCatalogRecord.encode(records)
            val prepared = JSONObject(wire.body(recordsJson))
            // The UI applies the same rules first, so this is a programming error, not user input.
            if (!prepared.optBoolean("ok")) throw ChoreCatalogException(ChoreCatalogFailure(ChoreCatalogFailure.Kind.VALIDATION))
            call("upsert", "PUT", prepared.getString("body"), recordsJson, ChoreCatalogRecord.encode(local))
        }

    private suspend fun call(
        action: String, method: String, body: String?, recordsJson: String, localJson: String,
    ): List<ChoreCatalogRecord> {
        val token = (read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value
            ?: throw ChoreCatalogException(ChoreCatalogFailure(ChoreCatalogFailure.Kind.UNAUTHORIZED))
        val response = try {
            send(PlatformHttpRequest(path = PATH, method = method,
                headers = mapOf("Authorization" to "Bearer $token") +
                    (if (body != null) mapOf("Content-Type" to "application/json") else emptyMap()),
                body = body?.toByteArray(Charsets.UTF_8)))
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            // No response at all (offline, timeout): the UI shows its own connection message.
            throw ChoreCatalogException(ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER))
        }
        val result = JSONObject(wire.response(action, response.statusCode, response.body.decodeToString(), recordsJson, localJson))
        if (!result.optBoolean("ok")) {
            throw ChoreCatalogException(ChoreCatalogFailure.of(ChoreCatalogFailure.Kind.of(result.optString("kind")),
                if (result.isNull("message")) null else result.optString("message")))
        }
        return ChoreCatalogRecord.decode(result.getJSONArray("records"))
    }

    companion object {
        const val PATH = "chore/catalog"

        fun live(context: Context, http: AndroidHttpAdapter): ChoreCatalogRepository =
            ChoreCatalogRepository(http::send, KeystoreSessionStore(context)::read)
    }
}
