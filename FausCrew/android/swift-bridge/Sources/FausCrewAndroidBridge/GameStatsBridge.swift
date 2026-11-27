import Foundation
import FausCrewCore

// Game stats for Android. JSON in, JSON out; the JWT never crosses (Kotlin adds the Authorization
// header). Core stays the only place that knows the route, the error kinds and the board rules
// (unknown games, former members, leader, the overall sum).

/// Returns `{"ok":true,"path":"…","method":"…","query":[{"name","value"}]}` or
/// `{"ok":false,"kind":"invalidRequest"}`.
public func gameStatsRequest(_ houseId: String) -> String {
    do throws(GameStatsFailure) {
        let request = try GameStatsWireContract.request(houseID: houseId, jwt: "")
        return bridgeJSON([
            "ok": true,
            "path": request.path,
            "method": request.method,
            "query": request.queryItems.map { ["name": $0.name, "value": $0.value ?? ""] },
        ])
    } catch {
        return gameStatsFailureJSON(error)
    }
}

/// `contextJson`: `{"memberIds":[…],"knownGameKeys":[…]}`, members in membership order. Returns
/// `{"ok":true,"games":[section…],"overall"?:section}` where a section is
/// `{"gameKey"?:"…","standings":[{"userId","wins","matchesPlayed","isLeader"}]}`, or
/// `{"ok":false,"kind":"…","message"?:"…"}`. A successful body can be passed again with new members.
public func gameStatsResponse(_ status: Int32, _ body: String, _ contextJson: String) -> String {
    let response = HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8))
    let context = (try? JSONSerialization.jsonObject(with: Data(contextJson.utf8))) as? [String: Any] ?? [:]
    do throws(GameStatsFailure) {
        let board = GameStatsBoard.make(
            stats: try GameStatsWireContract.decode(response),
            memberIDs: context["memberIds"] as? [String] ?? [],
            knownGameKeys: Set(context["knownGameKeys"] as? [String] ?? [])
        )
        var object: [String: Any] = ["ok": true, "games": board.games.map(sectionObject)]
        if let overall = board.overall { object["overall"] = sectionObject(overall) }
        return bridgeJSON(object)
    } catch {
        return gameStatsFailureJSON(error)
    }
}

private func sectionObject(_ section: GameStatsBoard.Section) -> [String: Any] {
    var object: [String: Any] = [
        "standings": section.standings.map { standing -> [String: Any] in
            ["userId": standing.userId, "wins": standing.wins, "matchesPlayed": standing.matchesPlayed,
             "isLeader": standing.isLeader]
        },
    ]
    if let key = section.gameKey { object["gameKey"] = key }
    return object
}

private func gameStatsFailureJSON(_ failure: GameStatsFailure) -> String {
    var object: [String: Any] = ["ok": false, "kind": failure.kind.rawValue]
    if let message = failure.message { object["message"] = message }
    return bridgeJSON(object)
}
