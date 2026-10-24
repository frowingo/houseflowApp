import Foundation

/// The four authored arenas. Positions are normalized to the arena (y up).
public enum HouseTanksMapCatalog {
    public static let gameplayScale = 0.5
    public static let obstacleBaseScale = 0.72

    public static func definition(for id: HouseTanksMapID) -> HouseTanksMapDefinition {
        switch id {
        case .livingRoom: livingRoom
        case .corridors: corridors
        case .warehouse: warehouse
        case .courtyard: courtyard
        case .basement: basement
        }
    }

    // Spawns stay at or below 0.70 so no tank starts under the top HUD row.
    public static let livingRoom = HouseTanksMapDefinition(
        id: .livingRoom,
        version: 2,
        spawnPoints: [point(0.10, 0.36), point(0.88, 0.22), point(0.88, 0.64), point(0.12, 0.70)],
        obstacles: [
            obstacle(0.50, 0.50, 0.07, 0.28, .divider, .navy),
            obstacle(0.31, 0.30, 0.18, 0.075, .sofa, .teal, rotation: 0.04),
            obstacle(0.69, 0.70, 0.18, 0.075, .sofa, .orange, rotation: -0.04),
            obstacle(0.30, 0.72, 0.12, 0.12, .roundTable, .blue),
            obstacle(0.70, 0.28, 0.10, 0.10, .crate, .wood, rotation: .pi / 12),
            obstacle(0.15, 0.20, 0.12, 0.055, .bookshelf, .navy),
            obstacle(0.85, 0.80, 0.09, 0.09, .planter, .green),
            obstacle(0.40, 0.56, 0.12, 0.12, .crate, .wood),
            obstacle(0.60, 0.40, 0.12, 0.12, .crate, .wood),
            obstacle(0.42, 0.83, 0.12, 0.12, .crate, .wood),
        ],
        floorLines: [
            line(0.10, 0.50, 0.28, 0.50), line(0.28, 0.50, 0.28, 0.78),
            line(0.72, 0.22, 0.72, 0.50), line(0.72, 0.50, 0.90, 0.50),
        ],
        floorMarkers: [point(0.12, 0.20), point(0.88, 0.80), point(0.50, 0.12), point(0.50, 0.88)]
    )

    public static let corridors = HouseTanksMapDefinition(
        id: .corridors,
        version: 2,
        spawnPoints: [point(0.12, 0.24), point(0.88, 0.70), point(0.88, 0.24), point(0.12, 0.70)],
        obstacles: [
            // Three alternating L-shaped walls; both ends have a route around them.
            obstacle(0.30, 0.36, 0.055, 1.25, .divider, .navy),
            obstacle(0.35, 0.14, 0.30, 0.055, .divider, .navy),
            obstacle(0.51, 0.64, 0.055, 1.25, .divider, .blue),
            obstacle(0.56, 0.86, 0.30, 0.055, .divider, .blue),
            obstacle(0.72, 0.36, 0.055, 1.25, .divider, .navy),
            obstacle(0.67, 0.14, 0.30, 0.055, .divider, .navy),
            obstacle(0.30, 0.70, 0.12, 0.12, .crate, .wood),
            obstacle(0.51, 0.28, 0.12, 0.12, .crate, .wood),
            obstacle(0.72, 0.71, 0.12, 0.12, .crate, .wood),
            obstacle(0.40, 0.46, 0.10, 0.10, .crate, .wood),
        ],
        floorLines: [
            line(0.12, 0.34, 0.88, 0.34), line(0.12, 0.66, 0.88, 0.66),
            line(0.50, 0.10, 0.50, 0.90),
        ],
        floorMarkers: [point(0.12, 0.12), point(0.88, 0.12), point(0.12, 0.88), point(0.88, 0.88)]
    )

    public static let warehouse = HouseTanksMapDefinition(
        id: .warehouse,
        version: 2,
        spawnPoints: [point(0.10, 0.36), point(0.90, 0.64), point(0.90, 0.24), point(0.10, 0.70)],
        obstacles: [
            obstacle(0.28, 0.24, 0.10, 0.10, .crate, .wood, rotation: 0.10),
            obstacle(0.38, 0.30, 0.08, 0.08, .crate, .wood, rotation: -0.06),
            obstacle(0.30, 0.72, 0.08, 0.08, .crate, .wood),
            obstacle(0.40, 0.66, 0.11, 0.11, .crate, .orange, rotation: 0.08),
            // Offset shelf rows leave an open central lane and side shortcuts.
            obstacle(0.35, 0.18, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.65, 0.36, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.35, 0.82, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.65, 0.64, 0.72, 0.08, .bookshelf, .navy),
            obstacle(0.72, 0.46, 0.12, 0.12, .crate, .wood),
            obstacle(0.76, 0.76, 0.12, 0.12, .crate, .wood, rotation: 0.12),
            obstacle(0.20, 0.14, 0.075, 0.075, .pillar, .teal),
            obstacle(0.20, 0.86, 0.075, 0.075, .pillar, .teal),
            obstacle(0.88, 0.50, 0.08, 0.08, .planter, .green),
            obstacle(0.48, 0.38, 0.07, 0.07, .crate, .orange),
            obstacle(0.48, 0.62, 0.07, 0.07, .crate, .orange),
        ],
        floorLines: [
            line(0.12, 0.16, 0.88, 0.16), line(0.12, 0.84, 0.88, 0.84),
            line(0.18, 0.50, 0.82, 0.50),
        ],
        floorMarkers: [point(0.10, 0.30), point(0.10, 0.70), point(0.90, 0.30), point(0.90, 0.70)]
    )

    public static let courtyard = HouseTanksMapDefinition(
        id: .courtyard,
        version: 2,
        spawnPoints: [point(0.12, 0.36), point(0.88, 0.64), point(0.86, 0.22), point(0.14, 0.70)],
        obstacles: [
            // A broken garden ring: four entrances, a central island and a wide outer route.
            obstacle(0.50, 0.50, 0.18, 0.18, .roundTable, .teal),
            obstacle(0.50, 0.26, 0.70, 0.07, .divider, .green),
            obstacle(0.50, 0.74, 0.70, 0.07, .divider, .green),
            obstacle(0.32, 0.50, 0.045, 0.70, .divider, .green),
            obstacle(0.68, 0.50, 0.045, 0.70, .divider, .green),
            obstacle(0.50, 0.16, 0.10, 0.10, .planter, .green),
            obstacle(0.50, 0.84, 0.10, 0.10, .planter, .green),
            obstacle(0.16, 0.18, 0.11, 0.055, .sofa, .blue, rotation: 0.08),
            obstacle(0.84, 0.50, 0.11, 0.055, .sofa, .orange, rotation: .pi / 2),
            obstacle(0.38, 0.38, 0.12, 0.12, .crate, .wood),
            obstacle(0.62, 0.62, 0.12, 0.12, .crate, .wood),
            obstacle(0.51, 0.60, 0.10, 0.10, .crate, .wood),
        ],
        floorLines: [
            line(0.18, 0.50, 0.38, 0.50), line(0.62, 0.50, 0.88, 0.50),
            line(0.50, 0.12, 0.50, 0.38), line(0.50, 0.62, 0.50, 0.88),
        ],
        floorMarkers: [point(0.18, 0.18), point(0.82, 0.18), point(0.18, 0.82), point(0.82, 0.82)]
    )

    /// Crowded-match map: a smaller scale and dense cover so six to eight tanks have room.
    /// Seats run up both side walls and along the bottom; the top band stays under the HUD.
    public static let basement = HouseTanksMapDefinition(
        id: .basement,
        version: 1,
        spawnPoints: [point(0.07, 0.40), point(0.93, 0.40), point(0.07, 0.68), point(0.93, 0.68),
                      point(0.07, 0.12), point(0.93, 0.12), point(0.36, 0.08), point(0.64, 0.08)],
        obstacles: [
            // Two long walls split the floor into three lanes with gaps at both ends.
            obstacle(0.24, 0.50, 0.05, 0.95, .divider, .navy),
            obstacle(0.76, 0.50, 0.05, 0.95, .divider, .navy),
            obstacle(0.50, 0.80, 0.42, 0.06, .divider, .blue),
            obstacle(0.50, 0.24, 0.30, 0.06, .divider, .blue),
            obstacle(0.38, 0.64, 0.26, 0.06, .bookshelf, .navy),
            obstacle(0.62, 0.36, 0.26, 0.06, .bookshelf, .navy),
            obstacle(0.50, 0.50, 0.14, 0.14, .roundTable, .teal),
            obstacle(0.15, 0.26, 0.07, 0.07, .pillar, .teal),
            obstacle(0.85, 0.26, 0.07, 0.07, .pillar, .teal),
            obstacle(0.15, 0.84, 0.07, 0.07, .pillar, .teal),
            obstacle(0.85, 0.84, 0.07, 0.07, .pillar, .teal),
            obstacle(0.40, 0.90, 0.08, 0.08, .planter, .green),
            obstacle(0.60, 0.90, 0.08, 0.08, .planter, .green),
            obstacle(0.15, 0.55, 0.12, 0.055, .sofa, .orange, rotation: .pi / 2),
            obstacle(0.85, 0.55, 0.12, 0.055, .sofa, .orange, rotation: .pi / 2),
            obstacle(0.38, 0.40, 0.11, 0.11, .crate, .wood),
            obstacle(0.62, 0.60, 0.11, 0.11, .crate, .wood),
            obstacle(0.50, 0.64, 0.10, 0.10, .crate, .wood, rotation: .pi / 12),
            obstacle(0.44, 0.14, 0.10, 0.10, .crate, .wood),
            obstacle(0.56, 0.14, 0.10, 0.10, .crate, .wood),
            obstacle(0.32, 0.88, 0.10, 0.10, .crate, .wood),
            obstacle(0.68, 0.88, 0.10, 0.10, .crate, .wood),
        ],
        floorLines: [
            line(0.10, 0.50, 0.20, 0.50), line(0.80, 0.50, 0.90, 0.50),
            line(0.30, 0.24, 0.30, 0.76), line(0.70, 0.24, 0.70, 0.76),
        ],
        floorMarkers: [point(0.50, 0.08), point(0.50, 0.92), point(0.12, 0.92), point(0.88, 0.92)],
        scale: 0.72,
        minPlayers: 6,
        maxPlayers: 8
    )

    public static func validationIssues(
        for definition: HouseTanksMapDefinition,
        arenaSize: HouseTanksSize = .reference
    ) -> [String] {
        var issues: [String] = []
        let tankClearance = 28.0 * definition.scale
        let scale = definition.scale

        if definition.version < 1 { issues.append("map version must be positive") }
        if definition.minPlayers < 2 || definition.maxPlayers < definition.minPlayers {
            issues.append("player range is invalid")
        }
        if definition.spawnPoints.count < definition.maxPlayers {
            issues.append("every seat needs a spawn point")
        }

        for (index, point) in definition.spawnPoints.enumerated() where !isNormalized(point) {
            issues.append("spawn \(index) is outside normalized bounds")
        }

        for (index, obstacle) in definition.obstacles.enumerated() {
            if obstacle.size.width <= 0 || obstacle.size.height <= 0 {
                issues.append("obstacle \(index) must have a positive size")
            }
            if !HouseTanksRect(size: arenaSize).contains(obstacle.bounds(in: arenaSize, mapScale: scale)) {
                issues.append("obstacle \(index) is outside normalized bounds")
            }
        }

        for (spawnIndex, spawn) in definition.spawnPoints.enumerated() where isNormalized(spawn) {
            let point = spawn.point(in: arenaSize)
            for (obstacleIndex, obstacle) in definition.obstacles.enumerated()
            where obstacle.clearance(from: point, in: arenaSize, mapScale: scale) < tankClearance {
                issues.append("spawn \(spawnIndex) overlaps obstacle \(obstacleIndex) clearance")
            }
        }

        for (index, line) in definition.floorLines.enumerated()
        where !isNormalized(line.start) || !isNormalized(line.end) {
            issues.append("floor line \(index) is outside normalized bounds")
        }

        for (index, marker) in definition.floorMarkers.enumerated() where !isNormalized(marker) {
            issues.append("floor marker \(index) is outside normalized bounds")
        }

        return issues
    }

    private static func isNormalized(_ point: HouseTanksNormalizedPoint) -> Bool {
        (0...1).contains(point.x) && (0...1).contains(point.y)
    }

    private static func point(_ x: Double, _ y: Double) -> HouseTanksNormalizedPoint {
        .init(x: x, y: y)
    }

    private static func line(_ startX: Double, _ startY: Double, _ endX: Double, _ endY: Double) -> HouseTanksFloorLineDefinition {
        .init(start: point(startX, startY), end: point(endX, endY))
    }

    private static func obstacle(
        _ x: Double, _ y: Double, _ width: Double, _ height: Double,
        _ style: HouseTanksObstacleStyle, _ tone: HouseTanksObstacleTone, rotation: Double = 0
    ) -> HouseTanksObstacleDefinition {
        .init(center: point(x, y), size: .init(width: width, height: height), rotation: rotation, style: style, tone: tone)
    }
}
