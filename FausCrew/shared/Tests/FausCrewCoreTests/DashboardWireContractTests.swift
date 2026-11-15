import Foundation
import Testing
@testable import FausCrewCore

@Test func dashboardBodiesMatchIosRequests() throws {
    let chore = try #require(JSONSerialization.jsonObject(with: DashboardWireContract.choreBody(
        assignedTo: "u", description: "Dishes", dueDate: "2026-10-12T00:00:00Z", houseId: "h",
        isRecurring: true, level: 20, recurringInterval: 7, title: "Kitchen"
    )) as? [String: Any])
    #expect(chore["isRecurring"] as? Bool == true)
    #expect(chore["recurringInterval"] as? Int == 7)
    #expect(chore["houseId"] as? String == "h")
    let status = try #require(JSONSerialization.jsonObject(with: DashboardWireContract.statusBody(
        choreId: "c", houseId: "h", status: 2
    )) as? [String: Any])
    #expect((status["chores"] as? [[String: Any]])?.first?["status"] as? Int == 2)
    let review = try #require(JSONSerialization.jsonObject(with: DashboardWireContract.reviewBody(
        choreId: "c", isApproved: false
    )) as? [String: Any])
    #expect(review["isApproved"] as? Bool == false)
    let announcement = try #require(JSONSerialization.jsonObject(with: DashboardWireContract.announcementBody(
        title: "Note", description: "Text", houseId: "h"
    )) as? [String: Any])
    #expect(announcement["description"] as? String == "Text")
}

@Test func dashboardRejectsEmptyStatusAndDeniedAnnouncement() throws {
    #expect(throws: DashboardWireError.emptyStatusResult) {
        try DashboardWireContract.validate(action: "status", response: HTTPResponse(
            statusCode: 200, headers: [:], body: Data("[]".utf8)
        ))
    }
    #expect(throws: DashboardWireError.rejected("Denied")) {
        try DashboardWireContract.validate(action: "announcement", response: HTTPResponse(
            statusCode: 200, headers: [:], body: Data(#"{"success":false,"error":"Denied"}"#.utf8)
        ))
    }
}

@Test func dashboardResponsesReturnWhatTheyCarry() throws {
    func reply(_ body: Data) -> HTTPResponse { HTTPResponse(statusCode: 200, headers: [:], body: body) }

    let chore = try DashboardWireContract.validate(
        action: "review", response: reply(ChoreFixtures.responseWithMixedISOStringsAndNullOptionals)
    )
    guard case .chore(let reviewed) = chore else { Issue.record("expected a chore"); return }
    #expect(reviewed.reviewVotes.map(\.reviewerId) == ["user-1"])

    let list = try DashboardWireContract.validate(action: "status", response: reply(
        Data("[".utf8) + ChoreFixtures.responseWithMixedISOStringsAndNullOptionals + Data("]".utf8)
    ))
    guard case .chores(let chores) = list else { Issue.record("expected chores"); return }
    #expect(chores.map(\.id) == ["chore-1"])

    let announcement = try DashboardWireContract.validate(action: "announcement", response: reply(Data("""
    {"success":true,"data":{"announcementId":"a","title":"Note","description":"Hi","createdAt":"2026-10-12T10:00:00Z",
     "createdBy":{"id":"u","name":"Ada"}}}
    """.utf8)))
    guard case .announcement(let note) = announcement else { Issue.record("expected an announcement"); return }
    #expect(note.publisherId == "u")
    #expect(note.publisherName == "Ada")
}
