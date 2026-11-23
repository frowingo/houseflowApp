import XCTest
@testable import FausCrewAndroidBridge

/// The notification facade: Core's request shapes without the JWT, validated responses, and the
/// badge / target / reminder helpers.
final class NotificationBridgeTests: XCTestCase {
    private let page = #"{"success":true,"data":{"items":[{"id":"b","type":"chore_reminder","houseId":"h","senderUserId":"s","choreId":"c","title":"T","message":"M","createdAt":"2026-11-20T10:00:02Z"},{"id":"a","type":"announcement","houseId":"h","senderUserId":"s","title":"T","message":"M","createdAt":"2026-11-20T10:00:01Z"}],"nextCursor":"a"}}"#

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func items(_ response: String) throws -> String {
        let array = try XCTUnwrap(object(response)["items"])
        return String(decoding: try JSONSerialization.data(withJSONObject: array), as: UTF8.self)
    }

    func testRegisterRequest() throws {
        let result = try object(notificationRequest("register", #"{"token":" tok ","platform":"android"}"#))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual(result["path"] as? String, "notification/devices")
        XCTAssertEqual(result["method"] as? String, "POST")
        XCTAssertEqual((result["query"] as? [Any])?.count, 0)
        let body = try object(try XCTUnwrap(result["body"] as? String))
        XCTAssertEqual(body["token"] as? String, "tok")
        XCTAssertEqual(body["platform"] as? String, "android")
        XCTAssertFalse(String(describing: result).contains("Bearer"))
    }

    func testUnregisterListAndRemindRequests() throws {
        let unregister = try object(notificationRequest("unregister", #"{"token":"tok"}"#))
        XCTAssertEqual(unregister["method"] as? String, "DELETE")
        XCTAssertEqual(try object(try XCTUnwrap(unregister["body"] as? String))["token"] as? String, "tok")

        let list = try object(notificationRequest("list", #"{"houseId":"h1","before":"c9","limit":99}"#))
        XCTAssertEqual(list["path"] as? String, "notification")
        XCTAssertEqual(list["method"] as? String, "GET")
        XCTAssertNil(list["body"])
        let query = try XCTUnwrap(list["query"] as? [[String: String]])
        XCTAssertEqual(query, [["name": "houseId", "value": "h1"], ["name": "before", "value": "c9"], ["name": "limit", "value": "50"]])

        let remind = try object(notificationRequest("remind", #"{"choreId":"c1"}"#))
        XCTAssertEqual(remind["path"] as? String, "chore/c1/remind")
        XCTAssertEqual(remind["method"] as? String, "POST")
        XCTAssertNil(remind["body"])
    }

    func testInvalidRequestsAreRefused() throws {
        for (action, fields) in [("register", #"{"token":"","platform":"ios"}"#), ("register", #"{"token":"t","platform":"web"}"#),
                                 ("unregister", "{}"), ("nope", "{}")] {
            let result = try object(notificationRequest(action, fields))
            XCTAssertEqual(result["ok"] as? Bool, false, action)
            XCTAssertEqual(result["kind"] as? String, "invalidRequest", action)
        }
    }

    func testListResponseKeepsTheWireShape() throws {
        let result = try object(notificationResponse("list", 200, page))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual(result["nextCursor"] as? String, "a")
        let items = try XCTUnwrap(result["items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0]["type"] as? String, "chore_reminder")
        XCTAssertEqual(items[0]["choreId"] as? String, "c")
        XCTAssertEqual(items[0]["senderUserId"] as? String, "s")
        XCTAssertNil(items[1]["choreId"])
        let last = try object(notificationResponse("list", 200, #"{"success":true,"data":{"items":[]}}"#))
        XCTAssertNil(last["nextCursor"])
        XCTAssertEqual((last["items"] as? [Any])?.count, 0)
    }

    func testOtherResponsesAndFailures() throws {
        XCTAssertEqual(try object(notificationResponse("register", 200, #"{"success":true}"#))["ok"] as? Bool, true)
        XCTAssertEqual(try object(notificationResponse("unregister", 200, "{}"))["ok"] as? Bool, true)
        XCTAssertEqual(try object(notificationResponse("remind", 201, ""))["ok"] as? Bool, true)
        let conflict = try object(notificationResponse("remind", 409, #"{"success":false,"error":"Already reminded"}"#))
        XCTAssertEqual(conflict["ok"] as? Bool, false)
        XCTAssertEqual(conflict["kind"] as? String, "alreadyReminded")
        XCTAssertEqual(conflict["message"] as? String, "Already reminded")
        XCTAssertEqual(try object(notificationResponse("list", 200, "garbage"))["kind"] as? String, "invalidResponse")
        XCTAssertEqual(try object(notificationResponse("list", 403, ""))["kind"] as? String, "notMember")
        XCTAssertNil(try object(notificationResponse("list", 500, ""))["message"])
        XCTAssertEqual(try object(notificationResponse("nope", 200, ""))["ok"] as? Bool, false)
    }

    func testUnreadCountAndMarkerRoundTripThroughTheListResponse() throws {
        let list = try items(notificationResponse("list", 200, page))
        XCTAssertEqual(notificationUnreadCount(list, ""), 2)
        let marker = notificationSeenMarker(list)
        XCTAssertEqual(try object(marker)["id"] as? String, "b")
        XCTAssertEqual(try object(marker)["createdAt"] as? String, "2026-11-20T10:00:02Z")
        XCTAssertEqual(notificationUnreadCount(list, marker), 0)
        XCTAssertEqual(notificationUnreadCount(list, #"{"createdAt":"2026-11-20T10:00:01Z","id":"a"}"#), 1)
        XCTAssertEqual(notificationUnreadCount(list, "garbage"), 2, "An unreadable marker counts as none")
        XCTAssertEqual(notificationSeenMarker("[]"), "")
        XCTAssertEqual(notificationSeenMarker("garbage"), "")
        XCTAssertEqual(notificationUnreadCount("garbage", ""), 0)
    }

    func testPushTarget() throws {
        let full = try object(notificationPushTarget(#"{"houseId":"h1","choreId":"c1","notificationId":"n1","type":"chore_reminder","google.sent_time":1}"#))
        XCTAssertEqual(full["ok"] as? Bool, true)
        XCTAssertEqual(full["houseId"] as? String, "h1")
        XCTAssertEqual(full["choreId"] as? String, "c1")
        XCTAssertEqual(full["notificationId"] as? String, "n1")
        XCTAssertEqual(full["type"] as? String, "chore_reminder")
        let minimal = try object(notificationPushTarget(#"{"houseId":"h1","choreId":""}"#))
        XCTAssertEqual(minimal["houseId"] as? String, "h1")
        XCTAssertNil(minimal["choreId"])
        XCTAssertEqual(try object(notificationPushTarget(#"{"choreId":"c1"}"#))["ok"] as? Bool, false)
        XCTAssertEqual(try object(notificationPushTarget("nope"))["ok"] as? Bool, false)
    }

    func testPushRoute() throws {
        let target = #"{"ok":true,"houseId":"h1","choreId":"c1","type":"chore_reminder"}"#
        func route(_ context: String) throws -> [String: Any] { try object(notificationPushRoute(target, context)) }
        let ready = #"{"isSignedIn":true,"houseIDs":["h1","h2"],"selectedHouseID":"h1","isSwitchingHouse":false,"isGameOpen":false,"isDashboardShown":true,"loadedChoreIDs":["c1"]}"#
        let open = try route(ready)
        XCTAssertEqual(open["step"] as? String, "openChore")
        XCTAssertEqual(open["id"] as? String, "c1")
        XCTAssertEqual(try route(ready.replacingOccurrences(of: #""selectedHouseID":"h1""#, with: #""selectedHouseID":"h2""#))["id"] as? String, "h1")
        XCTAssertEqual(try route(ready.replacingOccurrences(of: #""houseIDs":["h1","h2"]"#, with: #""houseIDs":null"#))["step"] as? String, "wait")
        XCTAssertEqual(try route(ready.replacingOccurrences(of: #""houseIDs":["h1","h2"]"#, with: #""houseIDs":["h2"]"#))["step"] as? String, "drop")
        XCTAssertEqual(try route(ready.replacingOccurrences(of: #""loadedChoreIDs":["c1"]"#, with: #""loadedChoreIDs":null"#))["step"] as? String, "wait")
        XCTAssertEqual(try route(ready.replacingOccurrences(of: #""isDashboardShown":true"#, with: #""isDashboardShown":false"#))["step"] as? String, "showDashboard")
        XCTAssertEqual(try route(ready.replacingOccurrences(of: #""loadedChoreIDs":["c1"]"#, with: #""loadedChoreIDs":[]"#))["step"] as? String, "finished")
        XCTAssertEqual(try object(notificationPushRoute("nope", ready))["step"] as? String, "drop")
        XCTAssertEqual(try object(notificationPushRoute(target, "nope"))["step"] as? String, "wait")
    }

    func testChoreCanRemind() {
        let due = "2026-11-21T18:00:00Z"
        let start = 1_795_284_000.0 - 12 * 3_600
        XCTAssertTrue(choreCanRemind("u2", "u1", 1, due, start))
        XCTAssertFalse(choreCanRemind("u2", "u1", 1, due, start - 1))
        XCTAssertFalse(choreCanRemind("u2", "u1", 1, due, start + 12 * 3_600))
        XCTAssertFalse(choreCanRemind("u1", "u1", 1, due, start))
        XCTAssertFalse(choreCanRemind("", "u1", 1, due, start))
        XCTAssertFalse(choreCanRemind("u2", "u1", 2, due, start))
        XCTAssertFalse(choreCanRemind("u2", "u1", 1, "", start))
    }

    func testPushTokenRedacted() {
        XCTAssertEqual(pushTokenRedacted("abcdefghijkl"), "abcdefgh…")
    }
}
