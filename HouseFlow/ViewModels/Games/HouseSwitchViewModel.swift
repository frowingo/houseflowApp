import Combine
import Foundation
import UIKit

@MainActor
final class HouseSwitchViewModel: ObservableObject {
    @Published private(set) var phase: HouseSwitchPhase = .briefing
    @Published private(set) var progress: Double = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var flipCount = 0
    @Published private(set) var bestTime: TimeInterval?
    @Published private(set) var crashReason: HouseSwitchCrashReason?

    private let bestTimeKey = "house_switch_best_time"
    private let userDefaults: UserDefaults

    lazy var scene: HouseSwitchScene = {
        let scene = HouseSwitchScene(size: CGSize(width: 390, height: 760))
        scene.onProgress = { [weak self] progress, elapsedTime in
            self?.progress = progress
            self?.elapsedTime = elapsedTime
        }
        scene.onFlip = { [weak self] in
            guard let self else { return }
            flipCount += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        scene.onBlockedFlip = {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.55)
        }
        scene.onBoost = {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        scene.onCrash = { [weak self] reason in
            guard let self else { return }
            crashReason = reason
            phase = .crashed
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        scene.onFinish = { [weak self] in
            guard let self else { return }
            phase = .finished
            recordBestTime()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        return scene
    }()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let stored = userDefaults.double(forKey: bestTimeKey)
        bestTime = stored > 0 ? stored : nil
    }

    func startRun() {
        progress = 0
        elapsedTime = 0
        flipCount = 0
        crashReason = nil
        phase = .playing
        scene.startRun()
    }

    func pauseRun() {
        guard phase == .playing else { return }
        scene.pauseRun()
        phase = .paused
    }

    func resumeRun() {
        guard phase == .paused else { return }
        phase = .playing
        scene.resumeRun()
    }

    func stopRun() {
        scene.stopRun()
    }

    func flipGravity() {
        guard phase == .playing else { return }
        scene.flipGravity()
    }

    func setReduceMotion(_ enabled: Bool) {
        scene.reduceMotion = enabled
    }

    var elapsedLabel: String {
        String(format: "%.1f", elapsedTime)
    }

    var bestTimeLabel: String? {
        bestTime.map { String(format: "%.1f", $0) }
    }

    private func recordBestTime() {
        guard elapsedTime > 0 else { return }
        if bestTime.map({ elapsedTime < $0 }) ?? true {
            bestTime = elapsedTime
            userDefaults.set(elapsedTime, forKey: bestTimeKey)
        }
    }
}
