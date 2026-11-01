import Foundation

/// Hands out jokers from a shuffled bag: every kind appears once per bag, in a fresh order,
/// and a new bag never starts with the kind the previous one ended on. It carries across
/// the rounds of a match. The draws follow the backend's `JokerBag` exactly.
public struct HouseTanksJokerBag: Codable, Equatable, Sendable {
    public private(set) var queue: [HouseTanksPowerUp] = []
    public private(set) var last: HouseTanksPowerUp?

    public init() {}

    public mutating func next(using random: inout HouseTanksRandom) -> HouseTanksPowerUp {
        if queue.isEmpty {
            var fresh = HouseTanksPowerUp.allCases
            for index in stride(from: fresh.count - 1, to: 0, by: -1) {
                fresh.swapAt(index, random.below(index + 1))
            }
            if fresh[0] == last {
                fresh.swapAt(0, 1 + random.below(fresh.count - 1))
            }
            queue = fresh
        }
        let kind = queue.removeFirst()
        last = kind
        return kind
    }
}

/// A world's joker dealer. The generator and the bag belong to the match and move to the
/// next round's world; the due tick is per round.
public struct HouseTanksJokerSchedule: Codable, Equatable, Sendable {
    public var random: HouseTanksRandom
    public var bag: HouseTanksJokerBag
    public var nextTokenTick: Int

    public init(random: HouseTanksRandom, bag: HouseTanksJokerBag, nextTokenTick: Int) {
        self.random = random
        self.bag = bag
        self.nextTokenTick = nextTokenTick
    }
}

/// Joker contract of `houseTanks.v2`. Timers are whole physics ticks (1/120 s).
public enum HouseTanksPowerUpRules {
    public static let durationTicks = 960
    public static let tokenLifetimeTicks = 1_440
    public static let minimumIntervalTicks = 840
    public static let maximumIntervalTicks = 1_320
    public static let retryTicks = 120
    public static let spawnAttempts = 80
    public static let rapidFireCooldownTicks = 20
    public static let spreadAngles: [Double] = [-0.28, -0.14, 0, 0.14, 0.28]

    /// The same timers in seconds, for countdown rings.
    public static let duration = Double(durationTicks) * HouseTanksWorld.fixedStep
    public static let tokenLifetime = Double(tokenLifetimeTicks) * HouseTanksWorld.fixedStep

    /// Where tokens may appear: clear of the walls and the top HUD row. It does not shrink
    /// with the map scale.
    public static let area = HouseTanksRect(x: 48, y: 44, width: HouseTanksWorld.arenaSize.width - 96,
                                            height: HouseTanksWorld.arenaSize.height - 44 - 80)

    /// Uniform over 7…11 s in whole ticks.
    static func spawnInterval(using random: inout HouseTanksRandom) -> Int {
        minimumIntervalTicks + random.below(maximumIntervalTicks - minimumIntervalTicks + 1)
    }

    /// Keeps a token away from the spawn points, live tanks and the current bounds of cover
    /// (moved crates and wrecks included).
    public static func isValidSpawn(_ point: HouseTanksVector, starts: [HouseTanksVector],
                                    tanks: [HouseTanksVector], cover: [HouseTanksRect]) -> Bool {
        guard area.contains(point) else { return false }
        let startClearance = max(80, area.height * 0.22)
        guard starts.allSatisfy({ $0.distance(to: point) >= startClearance }),
              tanks.allSatisfy({ $0.distance(to: point) >= 50 }) else { return false }
        return cover.allSatisfy { !$0.insetBy(dx: -26, dy: -26).contains(point) }
    }
}
