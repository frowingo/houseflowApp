package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

internal interface GameStatsWire {
    fun request(houseId: String): String
    fun response(status: Int, body: String, contextJson: String): String
}

private object NativeGameStatsWire : GameStatsWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun request(houseId: String): String {
        checked
        return FausCrewAndroidBridge.gameStatsRequest(houseId)
    }

    override fun response(status: Int, body: String, contextJson: String): String {
        checked
        return FausCrewAndroidBridge.gameStatsResponse(status, body, contextJson)
    }
}

/** A failed stats request; [kind] is Core's `GameStatsFailure.Kind` raw value. */
internal class GameStatsRequestException(val kind: String, val status: Int?, message: String?) : Exception(message)

internal data class GameStanding(val userId: String, val wins: Int, val matchesPlayed: Int, val isLeader: Boolean) {
    val hasPlayed: Boolean get() = matchesPlayed > 0
}

/** One game's standings in the backend's order; [gameKey] is null for the overall ranking. */
internal data class GameStatsSection(val gameKey: String?, val standings: List<GameStanding>)

/** Core's `GameStatsBoard`: the games this client knows, and the overall sum when there are two or more. */
internal data class GameStatsBoardData(val games: List<GameStatsSection>, val overall: GameStatsSection?) {
    val isEmpty: Boolean get() = games.isEmpty()
}

/** `GET game/stats` for one house. The caller passes the JWT. */
internal class GameStatsRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val wire: GameStatsWire = NativeGameStatsWire,
) {
    /**
     * The successful response body, checked by Core. It is kept by the caller so a change in the
     * member list rebuilds the board with [board] without another request.
     */
    suspend fun fetch(houseId: String, jwt: String): String = withContext(Dispatchers.IO) {
        val request = JSONObject(wire.request(houseId))
        if (!request.optBoolean("ok")) throw GameStatsRequestException(request.optString("kind"), null, null)
        val query = request.optJSONArray("query")
        val response = send(PlatformHttpRequest(
            path = request.getString("path"), method = request.getString("method"),
            queryItems = List(query?.length() ?: 0) { index ->
                query!!.getJSONObject(index).let { PlatformHttpQueryItem(it.getString("name"), it.getString("value")) }
            },
            headers = mapOf("Authorization" to "Bearer $jwt"),
        ))
        val body = response.body.decodeToString()
        val result = JSONObject(wire.response(response.statusCode, body, context(emptyList(), emptySet())))
        if (!result.optBoolean("ok")) {
            throw GameStatsRequestException(result.optString("kind"), response.statusCode, result.optString("message").ifEmpty { null })
        }
        body
    }

    /** The board for a body [fetch] returned, with the current members in membership order. */
    fun board(body: String, memberIds: List<String>, knownGameKeys: Set<String>): GameStatsBoardData {
        val result = JSONObject(wire.response(200, body, context(memberIds, knownGameKeys)))
        if (!result.optBoolean("ok")) throw GameStatsRequestException(result.optString("kind"), 200, null)
        return GameStatsBoardData(
            games = result.getJSONArray("games").sections(),
            overall = result.optJSONObject("overall")?.section(),
        )
    }

    private fun context(memberIds: List<String>, knownGameKeys: Set<String>) = JSONObject()
        .put("memberIds", JSONArray(memberIds))
        .put("knownGameKeys", JSONArray(knownGameKeys.sorted()))
        .toString()

    private fun JSONArray.sections(): List<GameStatsSection> = List(length()) { getJSONObject(it).section() }

    private fun JSONObject.section(): GameStatsSection {
        val standings = getJSONArray("standings")
        return GameStatsSection(
            gameKey = optString("gameKey").ifEmpty { null },
            standings = List(standings.length()) { index ->
                standings.getJSONObject(index).let {
                    GameStanding(it.getString("userId"), it.getInt("wins"), it.getInt("matchesPlayed"), it.optBoolean("isLeader"))
                }
            },
        )
    }

    companion object {
        fun live(http: AndroidHttpAdapter) = GameStatsRepository(http::send)
    }
}
