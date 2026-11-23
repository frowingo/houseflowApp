import XCTest
import FausCrewCore
@testable import FausCrewAndroidBridge

final class InviteCodeBridgeTests: XCTestCase {
    func testVersionAndCoreRule() {
        XCTAssertEqual(bridgeVersion(), 21)
        XCTAssertEqual(normalizeInviteCode("ab-12 cd34xyz"), "AB12CD34")
        XCTAssertEqual(normalizeInviteCode(""), "")
        XCTAssertEqual(normalizeInviteCode("１２３４５６７８ 12345678"), "12345678")
    }

    func testAuthWireFacadePreservesCoreLoginAndFailureRules() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(loginRequestBody("ada@example.com", "s3cret").utf8)) as? [String: String])
        XCTAssertEqual(body["email"], "ada@example.com")
        XCTAssertEqual(body["password"], "s3cret")

        let token = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(loginResponse(200, #"{"token":"abc"}"#).utf8)) as? [String: Any])
        XCTAssertEqual(token["ok"] as? Bool, true)
        XCTAssertEqual(token["token"] as? String, "abc")

        let failure = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(loginResponse(401, #"{"message":"Invalid credentials"}"#).utf8)) as? [String: Any])
        XCTAssertEqual(failure["ok"] as? Bool, false)
        XCTAssertEqual(failure["message"] as? String, "Invalid credentials")
    }

    func testAdditionalAuthFacadeUsesCoreDtosAndActions() throws {
        let signup = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(signupRequestBody("ada@example.com", "secret", "Ada", "A").utf8)) as? [String: String])
        XCTAssertEqual(signup["lastName"], "A")
        let reset = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(resetPasswordRequestBody("ada@example.com", "123456", "new").utf8)) as? [String: String])
        XCTAssertEqual(reset["newPassword"], "new")
        let success = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(authActionResponse("verifyEmail", 200, #"{"success":true}"#).utf8)) as? [String: Any])
        XCTAssertEqual(success["ok"] as? Bool, true)
        let invalidCode = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(authActionResponse("verifyEmail", 200, #"{"success":false}"#).utf8)) as? [String: Any])
        XCTAssertEqual(invalidCode["ok"] as? Bool, false)
        XCTAssertEqual(invalidCode["message"] as? String, "The verification code is invalid.")
        let failure = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(authActionResponse("verifyEmail", 400, #"{"message":"Wrong code"}"#).utf8)) as? [String: Any])
        XCTAssertEqual(failure["message"] as? String, "Wrong code")
    }

    func testHouseFacadeValidatesCreateAndDetailsBeforeAndroidRoute() throws {
        let create = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            houseRequestBody("create", "", "", "Home", "", 2, 5, "", false).utf8
        )) as? [String: Any])
        XCTAssertEqual(create["name"] as? String, "Home")
        let join = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            houseRequestBody("join", "", "", "", "ab-12 cd34", 0, 0, "", false).utf8
        )) as? [String: Any])
        XCTAssertEqual(join["inviteCode"] as? String, "AB12CD34")
        let validHouse = #"{"success":true,"data":{"id":"h","name":"Home","inviteCode":null,"maxMemberCount":4,"memberIds":[],"ownerId":"u","profileImage":"","type":1,"createdOn":"2026-01-01","updatedOn":"2026-01-02"}}"#
        XCTAssertEqual(houseResponse("create", 200, validHouse), validHouse)
        let malformed = #"{"success":true,"data":{"id":"h","name":"Home"}}"#
        let failure = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(houseResponse("details", 200, malformed).utf8)) as? [String: Any])
        XCTAssertEqual(failure["success"] as? Bool, false)
    }

    func testDetailsResponseIsNormalizedByCore() throws {
        let reply = try object(houseResponse("details", 200, Self.details))
        XCTAssertEqual(reply["success"] as? Bool, true)
        let data = try XCTUnwrap(reply["data"] as? [String: Any])
        XCTAssertEqual(data["ownerId"] as? String, "user-1")
        XCTAssertEqual(data["isChoreReviewPhotoRequired"] as? Bool, true)
        let member = try XCTUnwrap((data["members"] as? [[String: Any]])?.first)
        XCTAssertEqual(member["firstName"] as? String, "Ada")
        XCTAssertEqual(member["imageUrl"] as? String, "ada.png")

        let chore = try XCTUnwrap((data["chores"] as? [[String: Any]])?.first)
        XCTAssertEqual(chore["dueDate"] as? String, "2026-10-12T18:30:00Z", "time objects arrive as plain strings")
        XCTAssertEqual(chore["status"] as? Int, 4)
        XCTAssertEqual(chore["failureReason"] as? String, "dueDatePassed")
        XCTAssertEqual(chore["category"] as? Int, 0, "a category this build does not know reads as uncategorized")
        XCTAssertEqual(chore["reviewPhotoRounds"] as? [Int], [1])
        let vote = try XCTUnwrap((chore["reviewVotes"] as? [[String: Any]])?.first)
        XCTAssertEqual(vote["reviewerId"] as? String, "user-2")
        XCTAssertEqual(vote["isApproved"] as? Bool, false)
        XCTAssertNil(chore["statusHistories"])
    }

    func testDetailsAnnouncementResolvesANestedPublisherLikeIos() throws {
        let data = try XCTUnwrap(object(houseResponse("details", 200, Self.details))["data"] as? [String: Any])
        let announcement = try XCTUnwrap((data["announcements"] as? [[String: Any]])?.first)
        let decoded = try JSONDecoder().decode(HouseAnnouncementDTO.self, from: Data(Self.nestedPublisherAnnouncement.utf8))

        XCTAssertEqual(announcement["publisherId"] as? String, "user-1")
        XCTAssertEqual(announcement["publisherName"] as? String, "Ada Lovelace")
        XCTAssertEqual(announcement["publisherId"] as? String, decoded.publisherId)
        XCTAssertEqual(announcement["publisherName"] as? String, decoded.publisherName)
        XCTAssertEqual(announcement["message"] as? String, "Bins go out tonight")
        XCTAssertEqual(announcement["createdOn"] as? String, "2026-09-05T10:00:00Z")
        XCTAssertNil(announcement["houseId"])
    }

    func testDashboardResponsesCarryCoreNormalizedChoresAndAnnouncements() throws {
        let chore = #"{"id":"c","title":"Dishes","description":"","houseId":"h","houseOwnerId":"u","assignedTo":"u","dueDate":"2026-10-12T00:00:00Z","isCompleted":false,"isRecurring":false,"level":20,"recurringInterval":0,"status":2,"createdOn":"2026-10-10T09:00:00Z","completedAt":null,"completedBy":null,"statusHistories":[],"reviewRound":1,"reviewVotes":[],"category":3}"#
        let review = try object(dashboardResponse("review", 200, chore))
        XCTAssertEqual(review["ok"] as? Bool, true)
        let reviewed = try object(try XCTUnwrap(review["data"] as? String))
        XCTAssertEqual(reviewed["category"] as? Int, 3)
        XCTAssertEqual(reviewed["reviewRound"] as? Int, 1)
        XCTAssertNil(reviewed["failureReason"], "only failed chores carry a reason")

        let status = try object(dashboardResponse("status", 200, "[\(chore)]"))
        let chores = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(status["data"] as? String).utf8)) as? [[String: Any]])
        XCTAssertEqual(chores.map { $0["id"] as? String }, ["c"])

        let announced = try object(dashboardResponse("announcement", 200, #"{"success":true,"data":\#(Self.nestedPublisherAnnouncement)}"#))
        let announcement = try object(try XCTUnwrap(announced["data"] as? String))
        XCTAssertEqual(announcement["publisherId"] as? String, "user-1")
        XCTAssertEqual(announcement["publisherName"] as? String, "Ada Lovelace")
    }

    func testDashboardFacadeUsesCoreRequestAndRejectsMalformedResult() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardRequestBody(
            "create", "h", "", "u", "Kitchen", "Dishes", "2026-10-12T00:00:00Z",
            true, 20, 7, 0, false, 2
        ).utf8)) as? [String: Any])
        XCTAssertEqual(body["houseId"] as? String, "h")
        XCTAssertEqual(body["recurringInterval"] as? Int, 7)
        XCTAssertEqual(body["category"] as? Int, 2)
        let update = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardRequestBody(
            "update", "h", "c", "u", "Kitchen", "Dishes", "2026-10-12T00:00:00Z",
            true, 20, 7, 0, false, 0
        ).utf8)) as? [String: Any])
        XCTAssertNil(update["category"], "0 leaves category out, so the chore keeps its category")
        let denied = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardResponse(
            "announcement", 200, #"{"success":false,"error":"Denied"}"#
        ).utf8)) as? [String: Any])
        XCTAssertEqual(denied["ok"] as? Bool, false)
        XCTAssertEqual(denied["message"] as? String, "Denied")
    }

    func testReviewPhotoFacadeSharesCoreWireRules() throws {
        let profile = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            houseRequestBody("profile", "h", "", "Home", "", 1, 4, "", true).utf8
        )) as? [String: Any])
        XCTAssertEqual(profile["isChoreReviewPhotoRequired"] as? Bool, true)
        XCTAssertEqual(
            dashboardRequestBody("statusPhoto", "h", "c", "", "", "", "", false, 0, 0, 2, false, 0),
            #"[{"choreId":"c","status":2}]"#
        )
        let signed = #"{"url":"https://signed.example/p","expiresAt":"2026-10-29T10:20:00Z"}"#
        let ok = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardResponse("reviewPhoto", 200, signed).utf8)) as? [String: Any])
        XCTAssertEqual(ok["ok"] as? Bool, true)
        let missing = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardResponse(
            "reviewPhoto", 404, #"{"success":false,"error":"No photo"}"#
        ).utf8)) as? [String: Any])
        XCTAssertEqual(missing["ok"] as? Bool, false)
        XCTAssertEqual(missing["message"] as? String, "No photo")
    }

    func testProfileFacadeUsesOptionalFieldsAndRejectsMissingPayload() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileUpdateRequestBody("", "", "Ada", "", "", "tr").utf8
        )) as? [String: String])
        XCTAssertEqual(body, ["firstName": "Ada", "language": "tr"])
        let rejected = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileUpdateResponse(200, #"{"success":true,"data":null}"#).utf8
        )) as? [String: Any])
        XCTAssertEqual(rejected["ok"] as? Bool, false)
        let serverError = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileUpdateResponse(200, #"{"success":false,"error":"Denied","data":null}"#).utf8
        )) as? [String: Any])
        XCTAssertEqual(serverError["message"] as? String, "Denied")
        let images = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileImagesResponse(200, #"{"success":true,"data":[]}"#).utf8
        )) as? [String: Any])
        XCTAssertEqual(images["ok"] as? Bool, true)
    }

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private static let nestedPublisherAnnouncement = #"{"id":"a","title":"Bins","content":"Bins go out tonight","createdAt":{"time.Time":"2026-09-05T10:00:00Z"},"createdBy":{"id":"user-1","firstName":"Ada","lastName":"Lovelace"}}"#

    private static let details = """
    {"success":true,"data":{
      "id":"h","name":"Home","maxMemberCount":4,"ownerId":"user-1","profileImage":"","type":1,
      "createdOn":{"time.Time":"2026-09-01T08:00:00Z"},"updatedOn":"2026-09-02T08:00:00Z",
      "isChoreReviewPhotoRequired":true,
      "members":[{"id":"user-1","firstName":"Ada","lastName":"Lovelace","email":"ada@example.com","imageUrl":"ada.png",
        "isActive":true,"isVerifyEmail":true,"isVerifyPhone":false,"phoneNumber":"","birthDay":null,"houseIds":["h"],
        "createdOn":"2026-09-01T08:00:00Z","updatedOn":"2026-09-01T08:00:00Z","lastLogin":{"time.Time":"2026-09-03T08:00:00Z"}}],
      "chores":[{"id":"c","title":"Dishes","description":"Kitchen","houseId":"h","houseOwnerId":"user-1","assignedTo":"user-1",
        "dueDate":{"time.Time":"2026-10-12T18:30:00Z"},"isCompleted":false,"isRecurring":false,"level":10,"recurringInterval":0,
        "status":4,"createdOn":"2026-10-01T09:00:00Z","completedAt":null,"completedBy":null,
        "statusHistories":[{"id":"s","choreId":"c","status":4,"updater":"system","dateTime":"2026-10-12T18:31:00Z"}],
        "reviewRound":1,"reviewPhotoRounds":[1],"category":99,
        "reviewVotes":[{"id":"v","choreId":"c","houseId":"h","reviewRound":1,"reviewerId":"user-2","isApproved":false,"createdOn":"2026-10-11T08:00:00Z"}]}],
      "announcements":[\(nestedPublisherAnnouncement)]
    }}
    """
}
