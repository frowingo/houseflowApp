import XCTest
@testable import HouseFlow

@MainActor
final class HouseServiceTests: XCTestCase {
    func testInviteCodeRulesUppercaseFilterAndLimitInput() {
        XCTAssertEqual(InviteCodeRules.normalized("ab-12 cd34xyz"), "AB12CD34")
        XCTAssertTrue(InviteCodeRules.isValid("AB12CD34"))
        XCTAssertFalse(InviteCodeRules.isValid("AB12CD3"))
    }

    func testFetchDetailsDecodesCurrentResponseShape() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(
            #"""
            {
              "data": {
                "announcements": [{
                  "announcedBy": "user-1",
                  "createdOn": { "time.Time": "2026-09-14T10:00:00Z" },
                  "description": "Welcome home",
                  "houseId": "house-1",
                  "id": "announcement-1",
                  "title": "Welcome"
                }],
                "chores": [{
                  "assignedTo": "user-2",
                  "completedAt": { "time.Time": "2026-09-14T12:00:00Z" },
                  "completedBy": "user-2",
                  "createdOn": { "time.Time": "2026-09-14T09:00:00Z" },
                  "description": "Kitchen",
                  "dueDate": { "time.Time": "2026-09-15T18:00:00Z" },
                  "houseId": "house-1",
                  "houseOwnerId": "user-1",
                  "id": "chore-1",
                  "isCompleted": true,
                  "isRecurring": true,
                  "level": 10,
                  "recurringInterval": 7,
                  "reviewRound": 1,
                  "reviewVotes": [{
                    "choreId": "chore-1",
                    "createdOn": { "time.Time": "2026-09-14T12:30:00Z" },
                    "houseId": "house-1",
                    "id": "vote-1",
                    "isApproved": true,
                    "reviewRound": 1,
                    "reviewerId": "user-1"
                  }],
                  "status": 3,
                  "statusHistories": [{
                    "choreId": "chore-1",
                    "dateTime": { "time.Time": "2026-09-14T12:00:00Z" },
                    "id": "history-1",
                    "status": 3,
                    "updater": "user-2"
                  }],
                  "title": "Wash dishes"
                }],
                "createdOn": { "time.Time": "2026-09-01T08:00:00Z" },
                "id": "house-1",
                "maxMemberCount": 4,
                "members": [{
                  "birthDay": { "time.Time": "1990-01-01T00:00:00Z" },
                  "createdOn": { "time.Time": "2026-09-01T08:00:00Z" },
                  "email": "ada@example.com",
                  "firstName": "Ada",
                  "houseIds": ["house-1"],
                  "id": "user-1",
                  "imageUrl": "",
                  "isActive": true,
                  "isVerifyEmail": true,
                  "isVerifyPhone": true,
                  "language": "tr",
                  "lastLogin": { "time.Time": "2026-09-14T08:00:00Z" },
                  "lastName": "Lovelace",
                  "phoneNumber": "",
                  "updatedOn": { "time.Time": "2026-09-14T08:00:00Z" }
                }],
                "name": "City Home",
                "ownerId": "user-1",
                "profileImage": "",
                "type": 1,
                "updatedOn": { "time.Time": "2026-09-14T10:00:00Z" }
              },
              "success": true
            }
            """#.utf8
        )
        let keychain = FakeKeychainStore()
        keychain.authToken = "stored-token"
        let service = HouseService(
            network: NetworkService(
                baseURL: URL(string: "https://example.com/api/v1")!,
                requestExecutor: stub.execute
            ),
            keychain: keychain
        )

        let details = try await service.fetchDetails(houseId: "house-1")

        XCTAssertEqual(details.id, "house-1")
        XCTAssertEqual(details.name, "City Home")
        XCTAssertEqual(details.createdOn, "2026-09-01T08:00:00Z")
        XCTAssertEqual(details.members.first?.birthDate, "1990-01-01T00:00:00Z")
        XCTAssertEqual(details.announcements.first?.message, "Welcome home")
        XCTAssertEqual(details.announcements.first?.publisherId, "user-1")
        XCTAssertEqual(details.chores.first?.completedAt, "2026-09-14T12:00:00Z")
        XCTAssertEqual(details.chores.first?.statusHistories.first?.dateTime, "2026-09-14T12:00:00Z")
        XCTAssertEqual(details.chores.first?.reviewVotes.first?.createdOn, "2026-09-14T12:30:00Z")

        let request = try XCTUnwrap(stub.requests.first)
        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(components.path, "/api/v1/house/details")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "houseId", value: "house-1")])
    }

    func testFetchInfoDecodesMembersAndUsesHouseIdQuery() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = houseInfoResponseData
        let service = makeService(stub: stub)

        let info = try await service.fetchInfo(houseId: "house-1")

        XCTAssertEqual(info.houseName, "City Home")
        XCTAssertEqual(info.houseMemberCount, 2)
        XCTAssertEqual(info.houseMembers.first?.isOwner, true)
        XCTAssertTrue(info.isOwner(userId: "user-1"))

        let request = try XCTUnwrap(stub.requests.first)
        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(components.path, "/api/v1/house/infos")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "houseId", value: "house-1")])
    }

    func testUpdateProfileSendsCompletePayloadAndDecodesUpdatedInfo() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = houseInfoResponseData
        let service = makeService(stub: stub)
        let update = UpdateHouseProfileRequest(
            houseMemberCountLimit: 8,
            houseName: "City Home",
            houseProfileImage: "https://example.com/house.png",
            houseType: 1
        )

        let info = try await service.updateProfile(houseId: "house-1", request: update)

        XCTAssertEqual(info.houseMemberCountLimit, 8)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(components.path, "/api/v1/house/profile")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "houseId", value: "house-1")])
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["houseMemberCountLimit"] as? Int, 8)
        XCTAssertEqual(body["houseName"] as? String, "City Home")
        XCTAssertEqual(body["houseProfileImage"] as? String, "https://example.com/house.png")
        XCTAssertEqual(body["houseType"] as? Int, 1)
    }

    func testRemoveMemberPostsHouseAndUserIds() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"success":true,"error":""}"#.utf8)
        let service = makeService(stub: stub)

        try await service.removeMember(houseId: "house-1", userId: "user-2")

        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/house/exit")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String]
        )
        XCTAssertEqual(body, ["houseId": "house-1", "userId": "user-2"])
    }

    func testCreateInviteCodePostsHouseIdAndDecodesCode() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(
            #"{"data":{"expiresInSeconds":900,"inviteCode":"AB12CD34"},"success":true}"#.utf8
        )
        let service = makeService(stub: stub)

        let result = try await service.createInviteCode(houseId: "house-1")

        XCTAssertEqual(result.inviteCode, "AB12CD34")
        XCTAssertEqual(result.expiresInSeconds, 900)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/house/inviteCode")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String]
        )
        XCTAssertEqual(body, ["houseId": "house-1"])
    }

    func testJoinHouseDecodesResponseWithoutEmbeddedInviteCode() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(
            #"{"data":{"createdOn":{"time.Time":"2026-09-14T10:00:00Z"},"id":"house-2","maxMemberCount":8,"memberIds":["user-1"],"name":"New House","ownerId":"user-2","profileImage":"","type":1,"updatedOn":{"time.Time":"2026-09-14T10:00:00Z"}},"success":true}"#.utf8
        )
        let service = makeService(stub: stub)

        let house = try await service.joinHouse(inviteCode: "AB12CD34")

        XCTAssertEqual(house.id, "house-2")
        XCTAssertNil(house.inviteCode)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/house/join")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String]
        )
        XCTAssertEqual(body, ["inviteCode": "AB12CD34"])
    }

    private func makeService(stub: NetworkRequestStub) -> HouseService {
        let keychain = FakeKeychainStore()
        keychain.authToken = "stored-token"
        return HouseService(
            network: NetworkService(
                baseURL: URL(string: "https://example.com/api/v1")!,
                requestExecutor: stub.execute
            ),
            keychain: keychain
        )
    }

    private var houseInfoResponseData: Data {
        Data(
            #"""
            {
              "data": {
                "houseMemberCount": 2,
                "houseMemberCountLimit": 8,
                "houseMembers": [
                  { "isOwner": true, "name": "Ada", "profileImage": "", "userId": "user-1" },
                  { "isOwner": false, "name": "Grace", "profileImage": "", "userId": "user-2" }
                ],
                "houseName": "City Home",
                "houseProfileImage": "https://example.com/house.png",
                "houseType": 1
              },
              "success": true
            }
            """#.utf8
        )
    }
}
