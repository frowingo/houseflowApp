import Foundation
import FausCrewCore

// Faus Switch demo race. Physics, bots, the camera, robot poses and every overlay rule
// stay in FausCrewCore; Android owns the frame clock, input, audio and drawing. One JNI
// call per rendered frame (`fausSwitchBotStep`) returns the moving state; the course is
// static and read once (`fausSwitchCourse`).
//
// Coordinates: world points are the course drawn the way the iOS scene draws it (each
// straight section rotated into place, bends as arcs), with y up. `camera` maps them to
// the screen: screenX = originX + x * scale, screenY(up) = originY + y * scale; Android
// flips y exactly once (screenHeight - screenY).

final class SwitchMatchRegistry: @unchecked Sendable {
    static let shared = SwitchMatchRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var entries: [Int32: Entry] = [:]

    final class Entry {
        let planner = FausSwitchBotPlanner()
        var match: FausSwitchBotMatch
        var viewport = FausSwitchViewport(screenWidth: FausSwitchMetrics.viewportWidth,
                                          screenHeight: FausSwitchMetrics.worldHeight)
        var render = FausSwitchFrameJSON.RenderState()
        var started = false
        init() { match = FausSwitchBotMatch(planner: planner) }
    }

    func create() -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let handle = nextHandle
        nextHandle = nextHandle == Int32.max ? 1 : nextHandle + 1
        entries[handle] = Entry()
        return handle
    }

    func destroy(_ handle: Int32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return entries.removeValue(forKey: handle) != nil
    }

    func with<T>(_ handle: Int32, _ body: (Entry) -> T) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[handle] else { return nil }
        return body(entry)
    }
}

public func fausSwitchBotCreate() -> Int32 {
    SwitchMatchRegistry.shared.create()
}

public func fausSwitchBotDestroy(_ handle: Int32) -> Bool {
    SwitchMatchRegistry.shared.destroy(handle)
}

/// The playfield's size in screen points; the next frame resends platforms and the lost zone.
public func fausSwitchBotViewport(_ handle: Int32, _ width: Double, _ height: Double) -> String {
    switchFrame(handle) { entry in
        guard isUsable(width, height) else { return ["changed": false] }
        entry.viewport = FausSwitchViewport(screenWidth: width, screenHeight: height)
        entry.render = .init()
        return ["changed": true]
    }
}

/// Starts (or replaces) a race against `botCount` bots (clamped to the demo's range);
/// the countdown starts at 3. An unknown color is rejected.
public func fausSwitchBotStart(_ handle: Int32, _ color: String, _ botCount: Int32) -> String {
    guard let color = FausSwitchColor(rawValue: color) else {
        return bridgeJSON(["ok": false, "message": "Unknown Faus Switch color"])
    }
    return switchFrame(handle) { entry in
        entry.match.start(configuration: FausSwitchMatchConfiguration(humanColor: color, botCount: Int(botCount)))
        entry.render = .init()
        entry.started = true
        return [:]
    }
}

/// Feeds `delta` real seconds (countdown, then fixed 120 Hz steps). One call per rendered
/// frame; `events` drive haptics and sounds.
public func fausSwitchBotStep(_ handle: Int32, _ delta: Double) -> String {
    switchFrame(handle) { entry in
        let events = entry.match.advance(by: delta)
        return ["events": events.map(FausSwitchFrameJSON.event)]
    }
}

/// The player's tap: flips only from a surface while running. `gravity` is the robot's
/// gravity after the tap (the flip sound's direction).
public func fausSwitchBotFlip(_ handle: Int32) -> String {
    switchFrame(handle) { entry in
        let outcome = entry.match.flipHuman()
        return [
            "flip": FausSwitchFrameJSON.flipOutcome(outcome),
            "gravity": entry.match.human?.state.gravity.rawValue ?? NSNull(),
        ]
    }
}

public func fausSwitchBotPause(_ handle: Int32) -> String {
    switchFrame(handle) { entry in
        let before = entry.match.phase
        entry.match.pause()
        return ["changed": entry.match.phase != before]
    }
}

public func fausSwitchBotResume(_ handle: Int32) -> String {
    switchFrame(handle) { entry in
        let before = entry.match.phase
        entry.match.resume()
        return ["changed": entry.match.phase != before]
    }
}

/// The same picks with a new seed.
public func fausSwitchBotRestart(_ handle: Int32) -> String {
    switchFrame(handle) { entry in
        guard entry.started else { return ["changed": false] }
        entry.match.restart()
        entry.render = .init()
        return ["changed": true]
    }
}

/// Bundled TR/EN Faus Switch copy for one language; remote plaintext still overrides it.
public func fausSwitchCopy(_ language: String) -> String {
    bridgeJSON(FausSwitchLocalization.table(language: language))
}

/// Static values Android needs for the lobby, scheduling and drawing.
public func fausSwitchConstants() -> String {
    bridgeJSON([
        "colors": FausSwitchColor.allCases.map { color -> [String: Any] in
            ["id": color.rawValue, "hex": Int(color.bodyHex), "titleKey": color.titleKey]
        },
        "minimumBots": FausSwitchMatchConfiguration.botRange.lowerBound,
        "maximumBots": FausSwitchMatchConfiguration.botRange.upperBound,
        "defaultBots": 3,
        "botNameKeys": FausSwitchBotMatch.botNameKeys,
        "humanNameKey": "faus_switch_you",
        "countdownSeconds": FausSwitchMetrics.countdownSeconds,
        "physicsRate": FausSwitchMetrics.physicsRate,
        "maximumRunners": FausSwitchStartGrid.maximumRunners,
    ])
}

/// The race course as the iOS scene draws it; read once, it never changes.
public func fausSwitchCourse() -> String {
    bridgeJSON(FausSwitchFrameJSON.course(FausSwitchCourse.standard))
}

private func switchFrame(_ handle: Int32, _ action: (SwitchMatchRegistry.Entry) -> [String: Any]) -> String {
    let result = SwitchMatchRegistry.shared.with(handle) { entry -> [String: Any] in
        var object = action(entry)
        object["ok"] = true
        guard entry.started else { return object }
        let match = entry.match
        let frame = match.frame()
        object["frame"] = FausSwitchFrameJSON.world(frame, viewport: entry.viewport, state: &entry.render)
        let canFlip = match.phase == .playing && match.human?.state.isRunning == true
        object["match"] = FausSwitchFrameJSON.ui(FausSwitchMatchUI.demo(frame, canFlip: canFlip), viewport: entry.viewport)
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// The Android render contract, shared by demo and online frames.
enum FausSwitchFrameJSON {
    /// What the last frame already sent: platforms change with the field, the lost zone
    /// with the camera's trail.
    struct RenderState {
        var platformsKey = ""
        var lostZoneTrail = -Double.infinity
    }

    static let course = FausSwitchCourse.standard

    /// The moving world of one frame.
    static func world(_ frame: FausSwitchRenderFrame, viewport: FausSwitchViewport,
                      state: inout RenderState) -> [String: Any] {
        let track = course.track
        let camera = FausSwitchCamera.view(focus: frame.cameraFocus, track: track, viewport: viewport)
        let origin = camera.worldOrigin
        let focus = track.pose(x: frame.cameraFocus, y: FausSwitchTrack.centerY)
        var object: [String: Any] = [
            "matchId": frame.matchID,
            "tick": frame.tick,
            "time": frame.elapsedSeconds,
            "phase": frame.phase.rawValue,
            "countdown": frame.countdown ?? NSNull(),
            "camera": ["scale": camera.scale, "originX": origin.x, "originY": origin.y,
                       "screenWidth": viewport.screenWidth, "screenHeight": viewport.screenHeight,
                       "viewportScale": viewport.scale],
            "focus": ["x": focus.x, "y": focus.y],
            "cameraFocus": frame.cameraFocus,
            "cameraTrail": frame.cameraTrail,
            "visibleMaxX": frame.cameraFocus + viewport.visibleWorldWidth,
            "runners": frame.runners.map { runner -> [String: Any] in
                let pose = track.pose(x: runner.state.x, y: runner.state.y)
                let state = runner.state
                return [
                    "id": runner.id, "nameKey": runner.nameKey ?? NSNull(), "displayName": runner.displayName ?? NSNull(),
                    "color": runner.color.rawValue, "local": runner.isLocal, "connected": runner.isConnected,
                    "boosted": runner.isBoosted, "rank": runner.rank ?? NSNull(),
                    "status": state.status.rawValue, "gravity": state.gravity.rawValue, "scale": state.scale,
                    "crashReason": (state.status == .crashed ? state.crashReason?.rawValue : nil) ?? NSNull(),
                    "finishedAtTick": (state.status == .finished ? state.finishedAtTick : nil) ?? NSNull(),
                    "trackX": state.x, "trackY": state.y, "x": pose.x, "y": pose.y, "angle": pose.angle,
                    // Lost robots far behind the trail are not drawn.
                    "hidden": !state.isRunning && state.x < frame.cameraTrail - 40,
                ]
            },
        ]
        let platformsKey = frame.runners.map(\.color.rawValue).joined(separator: ",")
            + "@\(frame.runners.first?.state.scale ?? 1)"
        if platformsKey != state.platformsKey {
            state.platformsKey = platformsKey
            object["platforms"] = platforms(frame.runners)
        }
        if abs(frame.cameraTrail - state.lostZoneTrail) > 0.25 {
            state.lostZoneTrail = frame.cameraTrail
            object["lostZone"] = lostZone(trail: frame.cameraTrail)
        }
        return object
    }

    /// One start platform per seat in its robot's color, in the spawn section's track
    /// coordinates (`course.spawnSection`).
    static func platforms(_ runners: [FausSwitchRenderRunner]) -> [[String: Any]] {
        guard !runners.isEmpty else { return [] }
        let scale = runners.first?.state.scale ?? 1
        return zip(FausSwitchStartGrid.lanes(count: runners.count, runnerScale: scale), runners).map { lane, runner in
            ["rect": rect(lane.platform), "gravity": lane.gravity.rawValue, "color": runner.color.rawValue]
        }
    }

    /// The band from the trail back 900 units traced through the track (world points),
    /// and the "left behind" line across it.
    static func lostZone(trail: Double) -> [String: Any] {
        let track = course.track
        let start = trail - 900
        let steps = 45
        var points: [[Double]] = []
        for index in 0...steps {
            let pose = track.pose(x: start + 900 * Double(index) / Double(steps), y: 0)
            points.append([pose.x, pose.y])
        }
        for index in (0...steps).reversed() {
            let pose = track.pose(x: start + 900 * Double(index) / Double(steps), y: FausSwitchMetrics.worldHeight)
            points.append([pose.x, pose.y])
        }
        let low = track.pose(x: trail, y: 0)
        let high = track.pose(x: trail, y: FausSwitchMetrics.worldHeight)
        return ["polygon": points, "line": [low.x, low.y, high.x, high.y]]
    }

    /// The static course. Each straight section is drawn in its own track coordinates:
    /// a point (x, y) of section i is at rotate(angle) · (x - originX, y - centerY) + (poseX,
    /// poseY) in the world. Rails are already cut per section; every other piece names the
    /// section that draws it. Bends are arcs around (centerX, centerY) in world points.
    static func course(_ course: FausSwitchCourse) -> [String: Any] {
        let track = course.track
        let ranges = track.straightRanges(length: course.length)
        func section(at x: Double) -> Int { ranges.firstIndex { x < $0.endX } ?? ranges.count - 1 }
        let groups = course.blockGroups()
        var rails: [[String: Any]] = []
        var blocks: [[String: Any]] = []
        for solid in course.solids {
            if solid.kind == .rail {
                for (index, range) in ranges.enumerated() {
                    let minX = max(solid.rect.minX, range.startX)
                    let maxX = min(solid.rect.maxX, range.endX)
                    guard maxX > minX else { continue }
                    var cut = solid.rect
                    cut.minX = minX
                    cut.maxX = maxX
                    rails.append(["section": index, "rect": rect(cut), "floor": cut.minY <= 0.5])
                }
            } else {
                blocks.append(["id": solid.id, "section": section(at: solid.rect.midX), "group": groups[solid.id] ?? 0,
                               "rect": rect(solid.rect)])
            }
        }
        return [
            "version": course.version,
            "length": course.length,
            "finishX": course.finishX,
            "finishSection": section(at: course.finishX),
            "spawnX": FausSwitchMetrics.spawnX,
            "spawnSection": section(at: FausSwitchMetrics.spawnX),
            "worldHeight": FausSwitchMetrics.worldHeight,
            "viewportWidth": FausSwitchMetrics.viewportWidth,
            "floorSurface": FausSwitchMetrics.floorSurface,
            "ceilingSurface": FausSwitchMetrics.ceilingSurface,
            "railThickness": FausSwitchMetrics.railThickness,
            "runnerWidth": FausSwitchMetrics.runnerWidth,
            "runnerHeight": FausSwitchMetrics.runnerHeight,
            "centerY": FausSwitchTrack.centerY,
            "portalWidth": FausSwitchPortal.width,
            "portalHeight": FausSwitchPortal.height,
            "sections": ranges.enumerated().map { index, range -> [String: Any] in
                ["startX": range.startX, "endX": range.endX, "originX": track.straightStartX(index),
                 "poseX": range.pose.x, "poseY": range.pose.y, "angle": range.pose.angle]
            },
            "turns": track.turns.indices.map { index -> [String: Any] in
                let arc = track.turnArc(index)
                return ["centerX": arc.centerX, "centerY": arc.centerY, "startAngle": arc.startAngle,
                        "isLeft": arc.isLeft, "radius": track.turns[index].radius, "section": index + 1]
            },
            "rails": rails,
            "blocks": blocks,
            "gaps": course.gaps.map { gap -> [String: Any] in
                ["id": gap.id, "minX": gap.minX, "maxX": gap.maxX, "rail": gap.rail.rawValue,
                 "section": section(at: (gap.minX + gap.maxX) / 2)]
            },
            "boosts": course.boosts.map { pad -> [String: Any] in
                ["id": pad.id, "rect": rect(pad.rect), "section": section(at: pad.x)]
            },
            "slows": course.slows.map { pad -> [String: Any] in
                ["id": pad.id, "rect": rect(pad.rect), "section": section(at: pad.x)]
            },
            "portals": course.portals.map { portal -> [String: Any] in
                ["id": portal.id, "x": portal.x, "rail": portal.rail.rawValue, "section": section(at: portal.x),
                 "exitX": portal.exitX, "exitGravity": portal.exitGravity.rawValue, "exitSection": section(at: portal.exitX)]
            },
        ]
    }

    /// The overlays over a frame (`FausSwitchMatchUI`); name tags carry their screen
    /// anchor (y up) for this viewport.
    static func ui(_ ui: FausSwitchMatchUI, viewport: FausSwitchViewport) -> [String: Any] {
        let local = ui.localStatus.map(status)
        let keys = ui.demoResultKeys
        return [
            "phase": ui.phase.rawValue,
            "countdown": ui.countdown ?? NSNull(),
            "standings": ui.standings.map(standing),
            "nameTags": ui.nameTags.map { tag -> [String: Any] in
                let anchor = tag.anchor(track: course.track, viewport: viewport)
                return ["id": tag.id, "nameKey": tag.nameKey ?? NSNull(), "displayName": tag.displayName ?? NSNull(),
                        "color": tag.color.rawValue, "local": tag.isLocal, "x": anchor.x, "y": anchor.y]
            },
            "localStatus": local?.status ?? NSNull(),
            "localCrashReason": local?.reason ?? NSNull(),
            "localRank": ui.localRank ?? NSNull(),
            "localTime": ui.localTime ?? NSNull(),
            "runnerCount": ui.runnerCount,
            "canFlip": ui.canFlip,
            "noticeTitleKey": ui.noticeTitleKey ?? NSNull(),
            "noticeDetailKey": ui.noticeDetailKey ?? NSNull(),
            "noticeIsBlocking": ui.noticeIsBlocking,
            "canRetry": ui.canRetry,
            "canReclaim": ui.canReclaim,
            "showsResult": ui.showsResult,
            "showsRematchRoom": ui.showsRematchRoom,
            "demoOutcome": ui.demoOutcome.rawValue,
            "demoTitleKey": keys.title,
            "demoDetailKey": keys.detail,
        ]
    }

    static func standing(_ standing: FausSwitchStanding) -> [String: Any] {
        let status = status(standing.status)
        return [
            "id": standing.id, "nameKey": standing.nameKey ?? NSNull(), "displayName": standing.displayName ?? NSNull(),
            "color": standing.color.rawValue, "rank": standing.rank ?? NSNull(), "status": status.status,
            "crashReason": status.reason ?? NSNull(), "statusKey": standing.statusKey, "out": standing.isOut,
            "local": standing.isLocal, "connected": standing.isConnected, "time": standing.time ?? NSNull(),
        ]
    }

    static func status(_ status: FausSwitchStanding.Status) -> (status: String, reason: String?) {
        switch status {
        case .running: ("running", nil)
        case .finished: ("finished", nil)
        case .crashed(let reason): ("crashed", reason?.rawValue)
        }
    }

    static func event(_ event: FausSwitchMatchEvent) -> [String: Any] {
        switch event {
        case .countdown(let value): ["type": "countdown", "value": value]
        case .started: ["type": "started"]
        case .humanBoosted: ["type": "humanBoosted"]
        case .humanSlowed: ["type": "humanSlowed"]
        case .humanTeleported: ["type": "humanTeleported"]
        case .humanCrashed(let reason): ["type": "humanCrashed", "reason": reason.rawValue]
        case .humanFinished: ["type": "humanFinished"]
        case .ended: ["type": "ended"]
        }
    }

    static func flipOutcome(_ outcome: FausSwitchPhysics.FlipOutcome) -> String {
        switch outcome {
        case .flipped: "flipped"
        case .unsupported: "unsupported"
        case .notRunning: "ignored"
        }
    }

    static func rect(_ rect: FausSwitchRect) -> [Double] { [rect.minX, rect.minY, rect.maxX, rect.maxY] }
}
