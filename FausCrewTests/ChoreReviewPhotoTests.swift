import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class ChoreReviewPhotoTests: XCTestCase {
    // MARK: - Camera photo encoding

    func testCameraPhotoIsDownscaledToJPEGUnderLimit() throws {
        let size = CGSize(width: 4032, height: 3024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let photo = UIGraphicsImageRenderer(size: size, format: format).image { context in
            for x in stride(from: 0, to: Int(size.width), by: 16) {
                UIColor(hue: CGFloat(x) / size.width, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 16, height: Int(size.height)))
            }
        }

        let data = try XCTUnwrap(ChoreReviewPhotoEncoder.prepared(from: photo))
        let upload = try ChoreReviewPhotoUpload(data: data)
        XCTAssertEqual(upload.mimeType, "image/jpeg")
        XCTAssertLessThanOrEqual(data.count, ChoreReviewPhotoRules.maxByteCount)
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(max(decoded.size.width, decoded.size.height), ChoreReviewPhotoEncoder.maxPixelDimension)
    }

    // MARK: - Model decoding

    func testHouseDetailsAndInfoDecodeReviewPhotoFlag() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"success":true,"data":\#(Self.houseDetailsJSON(isChoreReviewPhotoRequired: true))}"#.utf8)
        let houseService = HouseService(network: makeNetwork(stub), keychain: makeKeychain())

        let details = try await houseService.fetchDetails(houseId: "house-1")
        XCTAssertTrue(details.isChoreReviewPhotoRequired)
        XCTAssertEqual(details.chores.first?.reviewPhotoRounds, [1])

        stub.responseData = Data(#"{"success":true,"data":\#(Self.houseInfoJSON(isChoreReviewPhotoRequired: true))}"#.utf8)
        let info = try await houseService.fetchInfo(houseId: "house-1")
        XCTAssertTrue(info.isChoreReviewPhotoRequired)
    }

    func testCachedHousePayloadWithoutFlagDefaultsToFalse() throws {
        let legacy = Self.houseDetailsJSON(isChoreReviewPhotoRequired: nil)
        let details = try JSONDecoder().decode(HouseDetailsResponse.self, from: Data(legacy.utf8))

        XCTAssertFalse(details.isChoreReviewPhotoRequired)
    }

    func testChoreResponseDecodesReviewPhotoRoundsAndDefaultsToEmpty() throws {
        let response = try JSONDecoder().decode(
            ChoreResponse.self,
            from: Data(Self.choreJSON(status: 2, reviewRound: 2, reviewPhotoRounds: [1, 2]).utf8)
        )
        let legacy = try JSONDecoder().decode(
            ChoreResponse.self,
            from: Data(Self.choreJSON(status: 2, reviewRound: 2, reviewPhotoRounds: nil).utf8)
        )

        XCTAssertEqual(response.reviewPhotoRounds, [1, 2])
        XCTAssertEqual(legacy.reviewPhotoRounds, [])
    }

    // MARK: - Status requests

    func testJSONStatusRequestIsKeptWhenPhotoIsNotRequired() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data("[\(Self.choreJSON(status: 2, reviewRound: 1, reviewPhotoRounds: nil))]".utf8)
        let store = ChoreStore(choreService: ChoreService(network: makeNetwork(stub), keychain: makeKeychain()))

        let result = try await store.updateStatus(
            choreApiId: "chore-1",
            houseId: "house-1",
            status: .inTest,
            isReviewPhotoRequired: false,
            reviewPhoto: Self.jpeg,
            currentHouseDetails: nil,
            dashboardMembers: []
        )

        XCTAssertTrue(result.didUpdate)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, "/api/v1/chore/status")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any]
        )
        XCTAssertEqual(body["houseId"] as? String, "house-1")
        let chores = try XCTUnwrap(body["chores"] as? [[String: Any]])
        XCTAssertEqual(chores.count, 1)
        XCTAssertEqual(chores.first?["choreId"] as? String, "chore-1")
        XCTAssertEqual(chores.first?["status"] as? Int, 2)
    }

    func testOtherTransitionsStayJSONEvenWhenPhotoIsRequired() async throws {
        let service = FakeChoreService()
        service.updateStatusHandler = { _, _ in
            [try Self.choreResponse(status: 1, reviewRound: 0, reviewPhotoRounds: [])]
        }
        let store = ChoreStore(choreService: service)

        _ = try await store.updateStatus(
            choreApiId: "chore-1",
            houseId: "house-1",
            status: .progress,
            isReviewPhotoRequired: true,
            currentHouseDetails: nil,
            dashboardMembers: []
        )

        XCTAssertEqual(service.updateStatusCallCount, 1)
        XCTAssertEqual(service.updateStatusWithReviewPhotoCallCount, 0)
    }

    func testRequiredPhotoSendsSingleInTestMultipartRequest() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data("[\(Self.choreJSON(status: 2, reviewRound: 1, reviewPhotoRounds: [1]))]".utf8)
        let store = ChoreStore(choreService: ChoreService(network: makeNetwork(stub), keychain: makeKeychain()))

        let result = try await store.updateStatus(
            choreApiId: "chore-1",
            houseId: "house-1",
            status: .inTest,
            isReviewPhotoRequired: true,
            reviewPhoto: Self.jpeg,
            currentHouseDetails: nil,
            dashboardMembers: []
        )

        XCTAssertTrue(result.didUpdate)
        XCTAssertEqual(stub.requests.count, 1)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, "/api/v1/chore/status")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stored-token")

        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        let prefix = "multipart/form-data; boundary="
        XCTAssertTrue(contentType.hasPrefix(prefix))
        let boundary = String(contentType.dropFirst(prefix.count))
        XCTAssertFalse(boundary.isEmpty)

        let parts = try Self.multipartParts(try XCTUnwrap(request.httpBody), boundary: boundary)
        XCTAssertEqual(parts.map(\.name), ["houseId", "chores", "file"])
        XCTAssertEqual(parts[0].body, Data("house-1".utf8))

        let choresField = try XCTUnwrap(String(data: parts[1].body, encoding: .utf8))
        XCTAssertEqual(choresField, #"[{"choreId":"chore-1","status":2}]"#)
        let decoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(choresField.utf8)) as? [[String: Any]]
        )
        XCTAssertEqual(decoded.count, 1)

        XCTAssertEqual(parts[2].fileName, "review-photo.jpg")
        XCTAssertEqual(parts[2].contentType, "image/jpeg")
        XCTAssertEqual(parts[2].body, Self.jpeg)
        XCTAssertEqual(store.chores.first?.reviewPhotoRounds, [1])
    }

    func testOversizedPhotoIsRejectedBeforeAnyRequest() async {
        let stub = NetworkRequestStub()
        let store = ChoreStore(choreService: ChoreService(network: makeNetwork(stub), keychain: makeKeychain()))
        let oversized = Self.jpeg + Data(count: ChoreReviewPhotoRules.maxByteCount)

        do {
            _ = try await store.updateStatus(
                choreApiId: "chore-1",
                houseId: "house-1",
                status: .inTest,
                isReviewPhotoRequired: true,
                reviewPhoto: oversized,
                currentHouseDetails: nil,
                dashboardMembers: []
            )
            XCTFail("Expected the photo to be rejected")
        } catch {
            XCTAssertEqual(error as? ChoreReviewPhotoError, .tooLarge)
        }
        XCTAssertTrue(stub.requests.isEmpty)
    }

    func testMissingPhotoNeverFallsBackToJSONInTest() async {
        let service = FakeChoreService()
        let store = ChoreStore(choreService: service)

        do {
            _ = try await store.updateStatus(
                choreApiId: "chore-1",
                houseId: "house-1",
                status: .inTest,
                isReviewPhotoRequired: true,
                reviewPhoto: nil,
                currentHouseDetails: nil,
                dashboardMembers: []
            )
            XCTFail("Expected a missing photo error")
        } catch {
            XCTAssertEqual(error as? ChoreReviewPhotoError, .missing)
        }
        XCTAssertEqual(service.updateStatusCallCount, 0)
        XCTAssertEqual(service.updateStatusWithReviewPhotoCallCount, 0)
    }

    func testCoordinatorUsesHouseFlagAndAppliesServerChore() async throws {
        let service = FakeChoreService()
        var sentPhoto: ChoreReviewPhotoUpload?
        service.updateStatusWithReviewPhotoHandler = { houseId, choreId, photo in
            XCTAssertEqual(houseId, "house-1")
            XCTAssertEqual(choreId, "chore-1")
            sentPhoto = photo
            return [try Self.choreResponse(status: 2, reviewRound: 3, reviewPhotoRounds: [2, 3])]
        }
        let harness = makeHarness(choreService: service)
        harness.houseStore.applyHouseDetails(try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: Data(Self.houseDetailsJSON(isChoreReviewPhotoRequired: true).utf8)
        ))

        let didUpdate = await harness.coordinator.updateChoreStatus(
            choreApiId: "chore-1",
            houseId: "house-1",
            status: .inTest,
            reviewPhoto: Self.png
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(sentPhoto?.mimeType, "image/png")
        XCTAssertEqual(service.updateStatusCallCount, 0)
        let chore = try XCTUnwrap(harness.houseStore.currentHouseDetails?.chores.first)
        XCTAssertEqual(chore.status, 2)
        XCTAssertEqual(chore.reviewRound, 3)
        XCTAssertEqual(chore.reviewPhotoRounds, [2, 3])
        XCTAssertEqual(harness.coordinator.dashboardChores.first?.reviewPhotoRounds, [2, 3])
        XCTAssertTrue(harness.houseStore.currentHouseDetails?.isChoreReviewPhotoRequired == true)
    }

    func testStatusServerErrorKeepsStateAndShowsMessage() async throws {
        let stub = NetworkRequestStub()
        stub.statusCode = 503
        stub.responseData = Data(#"{"success":false,"error":"Storage is unavailable."}"#.utf8)
        let harness = makeHarness(
            choreService: ChoreService(network: makeNetwork(stub), keychain: makeKeychain())
        )
        let details = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: Data(Self.houseDetailsJSON(isChoreReviewPhotoRequired: true).utf8)
        )
        harness.houseStore.applyHouseDetails(details)

        let didUpdate = await harness.coordinator.updateChoreStatus(
            choreApiId: "chore-1",
            houseId: "house-1",
            status: .inTest,
            reviewPhoto: Self.jpeg
        )

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(harness.toastStore.message, "Storage is unavailable.")
        XCTAssertEqual(harness.houseStore.currentHouseDetails, details)
    }

    // MARK: - Review photo viewing

    func testPresignedURLRequestAndDecoding() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(
            #"{"url":"https://signed.example/photo.jpg?X-Amz-Signature=abc","expiresAt":"2026-10-29T10:20:00Z"}"#.utf8
        )
        let service = ChoreService(network: makeNetwork(stub), keychain: makeKeychain())

        let response = try await service.fetchReviewPhotoURL(choreId: "507f1f77bcf86cd799439013", round: 2)

        XCTAssertEqual(response.url, "https://signed.example/photo.jpg?X-Amz-Signature=abc")
        XCTAssertEqual(response.expiresAt, "2026-10-29T10:20:00Z")
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/v1/chore/507f1f77bcf86cd799439013/review-photo/2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stored-token")
    }

    func testReviewPhotoEndpointErrorsUseServerMessage() async throws {
        for (statusCode, message) in [(403, "Not a member."), (404, "No photo for this round."), (503, "Storage unavailable.")] {
            let stub = NetworkRequestStub()
            stub.statusCode = statusCode
            stub.responseData = Data(#"{"success":false,"error":"\#(message)"}"#.utf8)
            let harness = makeHarness(
                choreService: ChoreService(network: makeNetwork(stub), keychain: makeKeychain())
            )

            let data = await harness.coordinator.loadReviewPhoto(choreApiId: "chore-1", round: 1)

            XCTAssertNil(data)
            XCTAssertEqual(harness.toastStore.message, message, "status \(statusCode)")
            XCTAssertEqual(stub.requests.count, 1, "status \(statusCode) must not retry")
        }
    }

    func testStorage403RefreshesSignedURLExactlyOnce() async throws {
        let service = FakeChoreService()
        var fetchCount = 0
        var downloadedURLs: [URL] = []
        service.fetchReviewPhotoURLHandler = { choreId, round in
            XCTAssertEqual(choreId, "chore-1")
            XCTAssertEqual(round, 2)
            fetchCount += 1
            return ChoreReviewPhotoURLResponse(
                url: "https://signed.example/\(fetchCount)",
                expiresAt: "2099-01-01T00:00:00Z"
            )
        }
        service.downloadReviewPhotoHandler = { url in
            downloadedURLs.append(url)
            if downloadedURLs.count == 1 { throw NetworkError.unknown(403) }
            return Self.jpeg
        }
        let store = ChoreStore(choreService: service)

        let data = try await store.loadReviewPhoto(choreApiId: "chore-1", round: 2)

        XCTAssertEqual(data, Self.jpeg)
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(downloadedURLs.map(\.absoluteString), ["https://signed.example/1", "https://signed.example/2"])
    }

    func testRepeated403StopsAfterSingleRefresh() async {
        let service = FakeChoreService()
        var fetchCount = 0
        var downloadCount = 0
        service.fetchReviewPhotoURLHandler = { _, _ in
            fetchCount += 1
            return ChoreReviewPhotoURLResponse(url: "https://signed.example/p", expiresAt: "2099-01-01T00:00:00Z")
        }
        service.downloadReviewPhotoHandler = { _ in
            downloadCount += 1
            throw NetworkError.unknown(403)
        }
        let store = ChoreStore(choreService: service)

        do {
            _ = try await store.loadReviewPhoto(choreApiId: "chore-1", round: 1)
            XCTFail("Expected the second 403 to surface")
        } catch {
            guard case NetworkError.unknown(403) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(downloadCount, 2)
    }

    func testExpiredSignedURLIsReplacedBeforeDownloadAndUsesTheOnlyRefresh() async {
        let service = FakeChoreService()
        var fetchCount = 0
        var downloadCount = 0
        service.fetchReviewPhotoURLHandler = { _, _ in
            fetchCount += 1
            return ChoreReviewPhotoURLResponse(
                url: "https://signed.example/\(fetchCount)",
                expiresAt: fetchCount == 1 ? "2026-10-29T10:00:00Z" : "2026-10-29T10:20:00Z"
            )
        }
        service.downloadReviewPhotoHandler = { url in
            downloadCount += 1
            XCTAssertEqual(url.absoluteString, "https://signed.example/2")
            throw NetworkError.unknown(403)
        }
        let store = ChoreStore(choreService: service)
        let now = ISO8601DateFormatter().date(from: "2026-10-29T10:10:00Z")!

        do {
            _ = try await store.loadReviewPhoto(choreApiId: "chore-1", round: 1, now: { now })
            XCTFail("Expected the 403 to surface")
        } catch {}
        XCTAssertEqual(fetchCount, 2)
        XCTAssertEqual(downloadCount, 1)
    }

    func testPhotoDownloadSkipsBearerTokenAndCache() async throws {
        var captured: URLRequest?
        let service = ChoreService(
            network: makeNetwork(NetworkRequestStub()),
            keychain: makeKeychain(),
            photoExecutor: { request in
                captured = request
                let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
        )

        do {
            _ = try await service.downloadReviewPhoto(from: URL(string: "https://signed.example/p?sig=1")!)
            XCTFail("Expected 403")
        } catch {
            guard case NetworkError.unknown(403) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let request = try XCTUnwrap(captured)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    // MARK: - House setting

    func testHouseSettingUpdateSendsFlagWithHouseIdQuery() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"success":true,"data":\#(Self.houseInfoJSON(isChoreReviewPhotoRequired: true))}"#.utf8)
        let service = HouseService(network: makeNetwork(stub), keychain: makeKeychain())

        let info = try await service.updateProfile(
            houseId: "house-1",
            request: UpdateHouseProfileRequest(
                houseMemberCountLimit: 4,
                houseName: "City Home",
                houseProfileImage: "",
                houseType: 1,
                isChoreReviewPhotoRequired: true
            )
        )

        XCTAssertTrue(info.isChoreReviewPhotoRequired)
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
        XCTAssertEqual(body["isChoreReviewPhotoRequired"] as? Bool, true)
    }

    func testHouseSettingUsesServerResponseAndSurfacesQuotaError() async throws {
        let houseService = FakeHouseService()
        var sentRequest: UpdateHouseProfileRequest?
        houseService.updateProfileHandler = { _, request in
            sentRequest = request
            // The server is the source of truth, even if it disagrees with the draft.
            return TestFixture.houseInfo(isChoreReviewPhotoRequired: false)
        }
        let houseStore = HouseSessionStore(houseService: houseService)
        houseStore.applyHouseDetails(TestFixture.houseDetails())

        _ = try await houseStore.updateHouseProfile(
            houseId: "house-1",
            request: UpdateHouseProfileRequest(
                houseMemberCountLimit: 4, houseName: "Test House", houseProfileImage: "",
                houseType: 1, isChoreReviewPhotoRequired: true
            )
        )
        XCTAssertEqual(sentRequest?.isChoreReviewPhotoRequired, true)
        XCTAssertEqual(houseStore.currentHouseDetails?.isChoreReviewPhotoRequired, false)

        let stub = NetworkRequestStub()
        stub.statusCode = 429
        stub.responseData = Data(#"{"success":false,"error":"Daily change limit reached."}"#.utf8)
        let service = HouseService(network: makeNetwork(stub), keychain: makeKeychain())
        do {
            _ = try await service.updateProfile(
                houseId: "house-1",
                request: UpdateHouseProfileRequest(
                    houseMemberCountLimit: 4, houseName: "Test House", houseProfileImage: "",
                    houseType: 1, isChoreReviewPhotoRequired: true
                )
            )
            XCTFail("Expected quota error")
        } catch NetworkError.serverError(let message) {
            XCTAssertEqual(message, "Daily change limit reached.")
        }
    }

    // MARK: - Helpers

    static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D])

    private struct Part {
        let name: String
        let fileName: String?
        let contentType: String?
        let body: Data
    }

    private static func multipartParts(_ body: Data, boundary: String) throws -> [Part] {
        let delimiter = Data("--\(boundary)".utf8)
        let headerEnd = Data("\r\n\r\n".utf8)
        var parts: [Part] = []
        var cursor = body.startIndex
        while let start = body.range(of: delimiter, in: cursor..<body.endIndex) {
            let afterDelimiter = start.upperBound
            if body[afterDelimiter..<min(afterDelimiter + 2, body.endIndex)] == Data("--".utf8) { break }
            let headerStart = afterDelimiter + 2
            let headerRange = try XCTUnwrap(body.range(of: headerEnd, in: headerStart..<body.endIndex))
            let next = try XCTUnwrap(body.range(of: delimiter, in: headerRange.upperBound..<body.endIndex))
            let headers = String(decoding: body[headerStart..<headerRange.lowerBound], as: UTF8.self)
            let content = body[headerRange.upperBound..<(next.lowerBound - 2)]
            parts.append(Part(
                name: try XCTUnwrap(value(of: "name", in: headers)),
                fileName: value(of: "filename", in: headers),
                contentType: headers.components(separatedBy: "\r\n")
                    .first { $0.hasPrefix("Content-Type: ") }
                    .map { String($0.dropFirst("Content-Type: ".count)) },
                body: Data(content)
            ))
            cursor = next.lowerBound
        }
        return parts
    }

    private static func value(of attribute: String, in headers: String) -> String? {
        guard let range = headers.range(of: " \(attribute)=\"") else { return nil }
        let rest = headers[range.upperBound...]
        return rest.firstIndex(of: "\"").map { String(rest[..<$0]) }
    }

    private static func choreJSON(status: Int, reviewRound: Int, reviewPhotoRounds: [Int]?) -> String {
        let rounds = reviewPhotoRounds.map { #","reviewPhotoRounds":\#($0)"# } ?? ""
        return """
        {"id":"chore-1","title":"Wash dishes","description":"Kitchen","houseId":"house-1",\
        "houseOwnerId":"user-1","assignedTo":"user-1","dueDate":"2026-10-30T18:00:00Z",\
        "isCompleted":false,"isRecurring":false,"level":10,"recurringInterval":0,"status":\(status),\
        "createdOn":"2026-10-29T08:00:00Z","completedAt":null,"completedBy":null,\
        "statusHistories":[],"reviewRound":\(reviewRound),"reviewVotes":[]\(rounds)}
        """
    }

    private static func choreResponse(status: Int, reviewRound: Int, reviewPhotoRounds: [Int]) throws -> ChoreResponse {
        try JSONDecoder().decode(
            ChoreResponse.self,
            from: Data(choreJSON(status: status, reviewRound: reviewRound, reviewPhotoRounds: reviewPhotoRounds).utf8)
        )
    }

    private static func houseDetailsJSON(isChoreReviewPhotoRequired: Bool?) -> String {
        let flag = isChoreReviewPhotoRequired.map { #","isChoreReviewPhotoRequired":\#($0)"# } ?? ""
        return """
        {"id":"house-1","name":"City Home","maxMemberCount":4,"ownerId":"user-1","profileImage":"",\
        "type":1,"createdOn":"2026-10-01T08:00:00Z","updatedOn":"2026-10-01T08:00:00Z","members":[],\
        "chores":[{"id":"chore-1","title":"Wash dishes","description":"Kitchen","houseId":"house-1",\
        "houseOwnerId":"user-1","assignedTo":"user-1","dueDate":"2026-10-30T18:00:00Z",\
        "isCompleted":false,"isRecurring":false,"level":10,"recurringInterval":0,"status":1,\
        "createdOn":"2026-10-29T08:00:00Z","completedAt":null,"completedBy":null,"statusHistories":[],\
        "reviewRound":1,"reviewVotes":[],"reviewPhotoRounds":[1]}]\(flag)}
        """
    }

    private static func houseInfoJSON(isChoreReviewPhotoRequired: Bool) -> String {
        """
        {"houseMemberCount":1,"houseMemberCountLimit":4,"houseMembers":[{"isOwner":true,"name":"Ada",\
        "profileImage":"","userId":"user-1"}],"houseName":"City Home","houseProfileImage":"",\
        "houseType":1,"isChoreReviewPhotoRequired":\(isChoreReviewPhotoRequired)}
        """
    }

    private func makeNetwork(_ stub: NetworkRequestStub) -> NetworkService {
        NetworkService(baseURL: URL(string: "https://example.com/api/v1")!, requestExecutor: stub.execute)
    }

    private func makeKeychain() -> FakeKeychainStore {
        let keychain = FakeKeychainStore()
        keychain.authToken = "stored-token"
        return keychain
    }

    private func makeHarness(choreService: any ChoreServicing) -> ReviewPhotoHarness {
        let authStore = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            userService: FakeUserService()
        )
        let houseStore = HouseSessionStore(houseService: FakeHouseService())
        let toastStore = ToastStore()
        let localization = TestFixture.localizationStore()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        let coordinator = DashboardCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            dashboardStore: DashboardStore(),
            choreStore: ChoreStore(choreService: choreService),
            localizationStore: localization.store,
            toastStore: toastStore
        )
        return ReviewPhotoHarness(coordinator: coordinator, houseStore: houseStore, toastStore: toastStore)
    }
}

@MainActor
private struct ReviewPhotoHarness {
    let coordinator: DashboardCoordinator
    let houseStore: HouseSessionStore
    let toastStore: ToastStore
}
