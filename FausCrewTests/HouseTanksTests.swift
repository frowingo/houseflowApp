import FausCrewCore
import SpriteKit
import XCTest
@testable import FausCrew

/// iOS host tests. The FauseTanks rules, physics and bots are covered in FausCrewCore
/// (`HouseTanksEngineTests`); these check the session, view model, scene and glyphs.
@MainActor
final class HouseTanksTests: XCTestCase {
    func testDemoSessionPublishesOneHumanAndThreeDistinctBots() async throws {
        let session = DemoHouseTanksGameSession()
        var events = session.events().makeAsyncIterator()
        await session.start(configuration: .init(difficulty: .normal, humanColor: .olive, mapID: .warehouse))
        let received = await events.next()
        let snapshot = try XCTUnwrap(received)
        XCTAssertEqual(snapshot.players.count, 4)
        XCTAssertEqual(snapshot.players.filter { $0.role == .bot }.count, 3)
        XCTAssertEqual(Set(snapshot.players.map(\.color)).count, 4)
        XCTAssertEqual(snapshot.humanPlayer?.color, .olive)
        XCTAssertEqual(snapshot.mapID, .warehouse)
        XCTAssertEqual(snapshot.phase, .countdown)
        session.disconnect()
    }

    func testSceneDrawsEveryTankAndCrateFromTheEngine() throws {
        let scene = HouseTanksScene()
        XCTAssertEqual(scene.scaleMode, .resizeFill, "no letterbox: the scene fills the view")
        scene.size = CGSize(width: 852, height: 393)
        let camera = try XCTUnwrap(scene.camera)
        XCTAssertEqual(camera.xScale, 872 / 852, accuracy: 0.001, "the camera fits the 872×400 arena by width")
        XCTAssertEqual(camera.position, CGPoint(x: 436, y: 200))
        var match = HouseTanksBotMatch(seed: 11)
        match.start(configuration: .init(difficulty: .easy, humanColor: .plum, mapID: .livingRoom))
        let world = try XCTUnwrap(match.world)
        scene.render(world, roundKey: "round-1", events: [], localPlayerID: world.tanks.first?.id)
        XCTAssertEqual(scene.children.filter { $0.name == "tank" }.count, 4)
        XCTAssertEqual(scene.children.filter { $0.name == "crate" }.count, world.obstacles.filter(\.isMovable).count)
        for tank in world.tanks {
            XCTAssertTrue(scene.children.contains {
                $0.name == "tank" && $0.position == CGPoint(x: tank.position.x, y: tank.position.y)
            })
        }
    }

    func testDemoSetupStartsEmptyAndGuidesThroughEveryPick() async {
        let model = HouseTanksViewModel(service: DemoHouseTanksGameSession())
        model.selectMode(.demo)
        XCTAssertNil(model.mapID)
        XCTAssertNil(model.humanColor)
        XCTAssertNil(model.difficulty)
        XCTAssertEqual(model.pendingSetupStep, .map)

        await model.startMatch()
        XCTAssertNil(model.snapshot)

        model.humanColor = .blue
        XCTAssertEqual(model.pendingSetupStep, .map)
        model.mapID = .courtyard
        XCTAssertEqual(model.pendingSetupStep, .difficulty)
        model.difficulty = .hard
        XCTAssertNil(model.pendingSetupStep)
        XCTAssertEqual(model.completedSetupSteps, 3)
        model.stop()
    }

    func testBasementAsksForThePlayerCountBeforeColor() {
        let model = HouseTanksViewModel(service: DemoHouseTanksGameSession())
        model.selectMode(.demo)
        model.mapID = .warehouse
        XCTAssertEqual(model.setupSteps, [.map, .color, .difficulty])
        model.mapID = .basement
        XCTAssertEqual(model.setupSteps, [.map, .players, .color, .difficulty])
        XCTAssertEqual(model.pendingSetupStep, .players)
        model.playerCount = 7
        model.humanColor = .ivory
        model.difficulty = .easy
        XCTAssertNil(model.pendingSetupStep)
        XCTAssertEqual(model.completedSetupSteps, 4)
    }

    func testOnlineRoomDrawsItsMap() {
        let model = HouseTanksViewModel(service: DemoHouseTanksGameSession())
        model.selectMode(.online)
        XCTAssertNotNil(model.onlineMapID)
        XCTAssertEqual(model.matchMapID, model.onlineMapID)
        model.returnToModeSelection()
        XCTAssertNil(model.onlineMapID)
    }

    func testEveryJokerHasATemplateGlyph() {
        for kind in HouseTanksPowerUp.allCases {
            XCTAssertEqual(kind.glyph(pointSize: 18)?.renderingMode, .alwaysTemplate, "\(kind)")
        }
    }
}
