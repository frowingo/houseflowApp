import Foundation

/// The arenas of contract `houseTanks.v2`. The maps themselves are generated from the
/// backend's `houseTanksMaps.json` (see `HouseTanksMapCatalog+Maps.swift`); positions are
/// normalized to the fixed 872×400 arena, y up.
public enum HouseTanksMapCatalog {
    public static let gameplayScale = 0.5
    public static let obstacleBaseScale = 0.72
    public static let minimumPlayers = 2
    public static let maximumPlayers = 8
    /// Every tank keeps this far from cover and from other spawns, scaled with the map.
    public static let spawnClearance = 28.0

    /// The demo's maps: four tanks each. Crowded-match maps (six to eight seats) are online only.
    public static var demoMapIDs: [HouseTanksMapID] {
        HouseTanksMapID.allCases.filter {
            definition(for: $0).minPlayers <= HouseTanksMapDefinition.demoStandardPlayerCount
        }
    }

    public static func definition(for id: HouseTanksMapID) -> HouseTanksMapDefinition {
        switch id {
        case .livingRoom: livingRoom
        case .corridors: corridors
        case .warehouse: warehouse
        case .courtyard: courtyard
        case .basement: basement
        }
    }

    /// The backend's catalog checks, so a map that passes here also passes there.
    public static func validationIssues(for definition: HouseTanksMapDefinition) -> [String] {
        var issues: [String] = []
        let scale = definition.scale
        let arena = HouseTanksWorld.arenaSize

        if definition.version < 1 { issues.append("map version must be positive") }
        if scale <= 0 || scale > 1 { issues.append("map scale must be in (0, 1]") }
        if definition.minPlayers < minimumPlayers || definition.maxPlayers < definition.minPlayers
            || definition.maxPlayers > maximumPlayers {
            issues.append("player range is invalid")
        }
        if definition.spawnPoints.count < definition.maxPlayers {
            issues.append("every seat needs a spawn point")
        }

        let clearance = spawnClearance * scale
        let tankRadius = HouseTanksWorld.tankRadius * scale
        for (index, spawn) in definition.spawnPoints.enumerated() {
            guard isNormalized(spawn) else {
                issues.append("spawn \(index) is outside normalized bounds")
                continue
            }
            let point = spawn.point(in: arena)
            if !HouseTanksWorld.arenaFrame.insetBy(dx: tankRadius, dy: tankRadius).contains(point) {
                issues.append("spawn \(index) touches the wall")
            }
            for (obstacleIndex, obstacle) in definition.obstacles.enumerated()
            where obstacle.clearance(from: point, in: arena, mapScale: scale) < clearance {
                issues.append("spawn \(index) overlaps obstacle \(obstacleIndex) clearance")
            }
            for other in 0..<index where isNormalized(definition.spawnPoints[other])
            && point.distance(to: definition.spawnPoints[other].point(in: arena)) < 2 * clearance {
                issues.append("spawn \(index) is too close to spawn \(other)")
            }
        }

        for (index, obstacle) in definition.obstacles.enumerated() {
            if obstacle.size.width <= 0 || obstacle.size.height <= 0 {
                issues.append("obstacle \(index) must have a positive size and a known style")
            }
            if !HouseTanksRect(size: arena).contains(obstacle.bounds(in: arena, mapScale: scale)) {
                issues.append("obstacle \(index) is outside normalized bounds")
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

    // Builders for the generated catalog.

    static func point(_ x: Double, _ y: Double) -> HouseTanksNormalizedPoint {
        .init(x: x, y: y)
    }

    static func line(_ startX: Double, _ startY: Double, _ endX: Double, _ endY: Double) -> HouseTanksFloorLineDefinition {
        .init(start: point(startX, startY), end: point(endX, endY))
    }

    static func obstacle(
        _ x: Double, _ y: Double, _ width: Double, _ height: Double,
        _ style: HouseTanksObstacleStyle, _ tone: HouseTanksObstacleTone, rotation: Double = 0
    ) -> HouseTanksObstacleDefinition {
        .init(center: point(x, y), size: .init(width: width, height: height), rotation: rotation, style: style, tone: tone)
    }
}
