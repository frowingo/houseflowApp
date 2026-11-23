import Foundation
import FausCrewCore
import XCTest

final class NotificationWireContractTests: XCTestCase {
    private typealias Contract = NotificationWireContract

    private let sample = #"{"success":true,"data":{"items":[{"id":"6b00c6859c2fe2efb8592007","type":"announcement","houseId":"6b00c6859c2fe2efb8592005","senderUserId":"6b00c6859c2fe2efb8591ffd","title":"T","message":"M","createdAt":"2026-11-20T22:15:33Z"}],"nextCursor":"6b00c6859c2fe2efb8592007"}}"#

    private func response(_ status: Int, _ body: String) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8))
    }

    private func json(_ data: Data?) throws -> [String: String] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(data)) as? [String: String])
    }

    private func failure(_ body: () throws -> Void) -> NotificationFailure? {
        do { try body(); return nil } catch { return error as? NotificationFailure }
    }

    func testRegisterRequest() throws {
        let request = try Contract.registerDeviceRequest(token: "  tok  ", platform: .android, jwt: "jwt")
        XCTAssertEqual(request.path, "notification/devices")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.headers, ["Authorization": "Bearer jwt", "Content-Type": "application/json"])
        XCTAssertEqual(try json(request.body), ["token": "tok", "platform": "android"])
    }

    func testUnregisterRequestCarriesOnlyTheToken() throws {
        let request = try Contract.unregisterDeviceRequest(token: "tok", jwt: "jwt")
        XCTAssertEqual(request.path, "notification/devices")
        XCTAssertEqual(request.method, "DELETE")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(try json(request.body), ["token": "tok"])
    }

    func testTokenLengthIsCheckedBeforeSending() throws {
        XCTAssertNoThrow(try Contract.registerDeviceRequest(token: String(repeating: "a", count: 4096), platform: .ios, jwt: "j"))
        for token in ["", "  \n", String(repeating: "a", count: 4097)] {
            XCTAssertThrowsError(try Contract.registerDeviceRequest(token: token, platform: .ios, jwt: "j")) {
                XCTAssertEqual($0 as? NotificationFailure, NotificationFailure(kind: .invalidRequest, message: nil))
            }
            XCTAssertThrowsError(try Contract.unregisterDeviceRequest(token: token, jwt: "j"))
        }
    }

    func testListRequest() {
        let request = Contract.listRequest(houseID: "h1", before: "c9", limit: 30, jwt: "jwt")
        XCTAssertEqual(request.path, "notification")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers, ["Authorization": "Bearer jwt"])
        XCTAssertNil(request.body)
        XCTAssertEqual(request.queryItems, [
            HTTPQueryItem(name: "houseId", value: "h1"),
            HTTPQueryItem(name: "before", value: "c9"),
            HTTPQueryItem(name: "limit", value: "30"),
        ])
    }

    func testListRequestOmitsWhatIsNotGiven() {
        XCTAssertEqual(Contract.listRequest(houseID: "h1", before: nil, limit: nil, jwt: "j").queryItems,
                       [HTTPQueryItem(name: "houseId", value: "h1")])
        XCTAssertEqual(Contract.listRequest(houseID: "h1", before: " ", limit: nil, jwt: "j").queryItems.count, 1)
    }

    func testListLimitIsClamped() {
        func limit(_ value: Int) -> String? {
            Contract.listRequest(houseID: "h", before: nil, limit: value, jwt: "j").queryItems.last?.value
        }
        XCTAssertEqual(limit(0), "1")
        XCTAssertEqual(limit(-5), "1")
        XCTAssertEqual(limit(1), "1")
        XCTAssertEqual(limit(50), "50")
        XCTAssertEqual(limit(51), "50")
        XCTAssertEqual(Contract.defaultPageSize, 20)
    }

    func testRemindRequestHasNoBody() {
        let request = Contract.remindRequest(choreID: "c1", jwt: "jwt")
        XCTAssertEqual(request.path, "chore/c1/remind")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.headers, ["Authorization": "Bearer jwt"])
        XCTAssertNil(request.body)
    }

    func testPageParsesTheBackendSample() throws {
        let page = try Contract.page(response(200, sample))
        XCTAssertEqual(page.nextCursor, "6b00c6859c2fe2efb8592007")
        let item = try XCTUnwrap(page.items.first)
        XCTAssertEqual(item.id, "6b00c6859c2fe2efb8592007")
        XCTAssertEqual(item.kind, .announcement)
        XCTAssertEqual(item.houseID, "6b00c6859c2fe2efb8592005")
        XCTAssertEqual(item.senderUserID, "6b00c6859c2fe2efb8591ffd")
        XCTAssertNil(item.choreID)
        XCTAssertEqual(item.createdAt, "2026-11-20T22:15:33Z")
        XCTAssertEqual(item.createdDate, Date(timeIntervalSince1970: 1_795_212_933))
    }

    func testPageWithChoreReminderUnknownTypeAndNoCursor() throws {
        let body = #"{"success":true,"data":{"items":[{"id":"1","type":"chore_reminder","houseId":"h","senderUserId":"u","choreId":"c","title":"T","message":"M","createdAt":"2026-11-20T22:15:33.250Z"},{"id":"2","type":"badge","houseId":"h","senderUserId":"u","title":"T","message":"M","createdAt":"2026-11-20T22:15:34Z"}]}}"#
        let page = try Contract.page(response(200, body))
        XCTAssertNil(page.nextCursor)
        XCTAssertEqual(page.items.map(\.kind), [.choreReminder, .unknown("badge")])
        XCTAssertEqual(page.items[0].choreID, "c")
        XCTAssertNotNil(page.items[0].createdDate)
        XCTAssertEqual(NotificationKind.unknown("badge").wire, "badge")
    }

    func testOneMalformedItemIsDroppedNotTheWholePage() throws {
        let good = #"{"id":"1","type":"announcement","houseId":"h","senderUserId":"u","title":"T","message":"M","createdAt":"2026-11-20T22:15:33Z"}"#
        let bad = #"{"id":"2","type":"announcement","houseId":"h","senderUserId":null,"title":null,"message":"M","createdAt":"2026-11-20T22:15:33Z"}"#
        let page = try Contract.page(response(200, #"{"success":true,"data":{"items":[\#(good),\#(bad),\#(good.replacingOccurrences(of: #""id":"1""#, with: #""id":"3""#))],"nextCursor":"3"}}"#))
        XCTAssertEqual(page.items.map(\.id), ["1", "3"])
        XCTAssertEqual(page.nextCursor, "3")
    }

    func testEmptyPageAndBlankCursor() throws {
        let page = try Contract.page(response(200, #"{"success":true,"data":{"items":[],"nextCursor":" "}}"#))
        XCTAssertEqual(page, NotificationPage(items: [], nextCursor: nil))
    }

    func testPageRejectsABodyThatDoesNotMatch() {
        for body in ["garbage", "", #"{"success":true}"#, #"{"success":false,"data":{"items":[]}}"#,
                     #"{"success":true,"data":{"items":null}}"#] {
            XCTAssertEqual(failure { _ = try Contract.page(response(200, body)) }?.kind, .invalidResponse, body)
        }
    }

    func testStatusesMapToKindsWithTheServerMessage() {
        let expected: [(Int, NotificationFailure.Kind)] = [
            (400, .invalidRequest), (401, .unauthorized), (403, .notMember), (404, .notFound),
            (409, .alreadyReminded), (500, .server),
        ]
        for (status, kind) in expected {
            let error = response(status, #"{"success":false,"error":"Nope"}"#)
            XCTAssertEqual(failure { _ = try Contract.page(error) }, NotificationFailure(kind: kind, message: "Nope"), "\(status)")
            XCTAssertEqual(failure { try Contract.reminded(error) }?.kind, kind)
            XCTAssertEqual(failure { try Contract.deviceAccepted(error) }?.kind, kind)
        }
        XCTAssertNil(failure { _ = try Contract.page(response(500, "")) }?.message)
        XCTAssertEqual(NotificationFailure(kind: .server, message: "  ").message, nil)
    }

    func testDeviceAcceptedChecksTheBodyOnlyWhenItDecodes() {
        XCTAssertNil(failure { try Contract.deviceAccepted(response(200, #"{"success":true}"#)) })
        XCTAssertNil(failure { try Contract.deviceAccepted(response(204, "")) })
        XCTAssertEqual(failure { try Contract.deviceAccepted(response(200, #"{"success":false}"#)) }?.kind, .invalidResponse)
    }

    func testRemindedAcceptsAnyTwoHundred() {
        XCTAssertNil(failure { try Contract.reminded(response(200, "")) })
        XCTAssertNil(failure { try Contract.reminded(response(201, #"{"success":true}"#)) })
        XCTAssertNil(failure { try Contract.reminded(response(200, "not json")) })
    }
}
