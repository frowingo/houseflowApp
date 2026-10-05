#if canImport(UIKit)
import XCTest
import UIKit
import SwiftUI
import SpriteKit
@testable import HouseFlow

/// Native fixture/render checks; these are not two-device multiplayer acceptance.
@MainActor
final class HouseRocketsNativeAcceptanceTests: XCTestCase {
    func testSceneSamplesProviderAtEachRenderCadence() async throws {
        for fps in [30, 60, 120] {
            let scene = HouseRocketsScene(size: CGSize(width: 852, height: 393))
            let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
            view.preferredFramesPerSecond = fps
            view.presentScene(scene)
            view.isPaused = true
            let frame = try AcceptanceFixture.presentation().frame
            var samples = 0
            var rendered = 0
            scene.frameProvider = { samples += 1; return frame }
            scene.onRenderedFrame = { _, _ in rendered += 1 }
            for tick in 0..<fps { scene.update(Double(tick) / Double(fps)) }
            XCTAssertEqual(samples, fps)
            XCTAssertEqual(rendered, fps)
            scene.reset()
            scene.update(2)
            XCTAssertEqual(rendered, fps)
            view.presentScene(nil)
        }
    }

    func testReduceMotionPreservesShipPositionsAndHidesThrust() async throws {
        let scene = HouseRocketsScene(size: CGSize(width: 852, height: 393))
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.presentScene(scene); view.isPaused = true
        scene.applyFrame(try AcceptanceFixture.presentation().frame)
        let thrust = thrustNodes(in: scene)
        XCTAssertFalse(thrust.isEmpty)
        XCTAssertTrue(thrust.contains { !$0.isHidden })
        let positions = thrust.compactMap { $0.parent?.position }
        scene.setReduceMotion(true)
        XCTAssertTrue(thrust.allSatisfy(\.isHidden))
        XCTAssertEqual(thrust.compactMap { $0.parent?.position }, positions)
        scene.setReduceMotion(false)
        XCTAssertTrue(thrust.contains { !$0.isHidden })
        scene.reset(); view.presentScene(nil)
    }

    func testSceneResizeKeepsWorldPositionsAndClearsOldNodes() async throws {
        let scene = HouseRocketsScene(size: CGSize(width: 852, height: 393))
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        view.presentScene(scene); view.isPaused = true
        scene.applyFrame(try AcceptanceFixture.presentation().frame)
        let positions = thrustNodes(in: scene).compactMap { $0.parent?.position }
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1180, height: 820)] {
            scene.size = size
            XCTAssertEqual(thrustNodes(in: scene).compactMap { $0.parent?.position }, positions)
        }
        scene.reset()
        XCTAssertTrue(thrustNodes(in: scene).isEmpty)
        view.presentScene(nil)
    }

    func testConnectionPanelLandscapeAndAccessibilitySnapshots() async throws {
        let app = makeApp()
        defer { app.cleanup() }
        for (name, size, textSize) in [
            ("PhoneConnection", CGSize(width: 852, height: 393), DynamicTypeSize.large),
            ("PhoneConnectionAX", CGSize(width: 852, height: 393), .accessibility3),
            ("PadConnection", CGSize(width: 1180, height: 820), .large)
        ] {
            var state = HouseRocketsOnlineLobbyState()
            state.connection = .reconnecting
            state.retryNotBefore = ProcessInfo.processInfo.systemUptime + 2
            let root = ZStack {
                HouseRocketsTheme.background.ignoresSafeArea()
                HouseRocketsOnlineConnectionView(state: state, onRetry: {}, onReclaimControl: {})
                    .frame(maxWidth: 430, maxHeight: size.height - 96)
            }
            .environmentObject(app.model).environment(\.dynamicTypeSize, textSize)
            try await capture(root, size: size, name: name)
        }
    }

    func testResultPortraitLandscapeAndAccessibilitySnapshots() async throws {
        let app = makeApp()
        defer { app.cleanup() }
        var state = HouseRocketsOnlineResultState()
        state.phase = .cancelledWithoutRecord
        state.terminalConfirmed = true
        for (name, size, textSize) in [
            ("PhoneResultPortrait", CGSize(width: 393, height: 852), DynamicTypeSize.large),
            ("PhoneResultLandscapeAX", CGSize(width: 852, height: 393), .accessibility3),
            ("PadResultLandscape", CGSize(width: 1180, height: 820), .large)
        ] {
            let root = HouseRocketsOnlineResultView(state: state, localPlayerID: nil, memberNames: [:],
                onRetry: {}, onRematch: {}, onExit: {})
                .environmentObject(app.model).environment(\.dynamicTypeSize, textSize)
            try await capture(root, size: size, name: name)
        }
    }

    func testOfflineModeSelectionAndLocalContextCleanup() async throws {
        let app = makeApp()
        defer { app.cleanup() }
        var onlineConstructions = 0
        let factory = HouseRocketsSessionFactory(makeBotSession: { DemoHouseRocketsSession() },
            makeOnlineSession: { onlineConstructions += 1; preconditionFailure("Offline bot mode must not construct online services") })
        let model = HouseRocketsViewModel(sessionFactory: factory, context: .init(houseID: nil, localPlayerID: nil))
        model.selectMode(.localBots)
        await model.startMatch()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNotNil(model.snapshot)
        XCTAssertEqual(onlineConstructions, 0)
        model.setForeground(false); model.pause()
        for _ in 0..<20 { await Task.yield() }
        model.updateContext(.init(houseID: "another-house", localPlayerID: "another-user"))
        XCTAssertNil(model.snapshot)
        XCTAssertNil(model.selectedMode)
        model.stop(); model.stop()
        XCTAssertEqual(onlineConstructions, 0)
        let root = HouseRocketsView(sessionFactory: .localOnly, context: .init(houseID: nil, localPlayerID: nil))
            .environmentObject(app.model)
        try await capture(root, size: CGSize(width: 393, height: 852), name: "OfflineModeSelection")
    }

    private func thrustNodes(in scene: HouseRocketsScene) -> [SKNode] {
        var nodes: [SKNode] = []
        scene.enumerateChildNodes(withName: "//thrust") { node, _ in nodes.append(node) }
        return nodes
    }

    private func capture<V: View>(_ root: V, size: CGSize, name: String) async throws {
        let controller = UIHostingController(rootView: AnyView(root))
        let window: UIWindow
        let previous = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
        if let scene = previous?.windowScene { window = UIWindow(windowScene: scene) }
        else { window = UIWindow(frame: CGRect(origin: .zero, size: size)) }
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, size)
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
        controller.rootView = AnyView(EmptyView())
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        window.isHidden = true; window.rootViewController = nil
        previous?.makeKeyAndVisible()
    }

    private func makeApp() -> (model: AppViewModel, cleanup: () -> Void) {
        let suite = "HouseRocketsM6-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let dependencies = AppDependencies(keychain: FakeKeychainStore(), authService: FakeAuthService(),
            userService: FakeUserService(), houseService: FakeHouseService(), choreService: FakeChoreService(),
            localizationService: FakeLocalizationService(), userDefaults: defaults,
            localizationCache: LocalizationDiskCache(baseDirectory: directory), houseRocketsSessionFactory: .localOnly)
        return (AppViewModel(dependencies: dependencies), {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        })
    }
}
#endif
