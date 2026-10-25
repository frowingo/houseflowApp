import Foundation

/// FauseTanks demo match shared by iOS and Android: one human against bots, rounds until
/// one tank is left, three round wins for the match. It owns phases, bots and the arena,
/// but no clock: the host calls `advanceCountdown()` every `countdownStepSeconds` while
/// counting down and `advance(by:)` with the real frame delta while playing; the arena
/// runs in whole ticks. Every state change bumps `snapshot.revision`.
public struct HouseTanksBotMatch: Sendable {
    public static let countdownStart = 3
    public static let countdownStepSeconds = 0.72
    /// A long frame (a hitch, a debugger stop) never runs more than this much arena time.
    private static let maximumFrameDelta = 1.0 / 20.0

    public private(set) var snapshot: HouseTanksSnapshot?
    public private(set) var configuration = HouseTanksMatchConfiguration.demo
    public private(set) var world: HouseTanksWorld?
    /// Bot triggers.
    private var random: HouseTanksRandom
    /// The joker dealer's generator and bag carry across the rounds of a match.
    private var jokerRandom: HouseTanksRandom
    private var jokerBag = HouseTanksJokerBag()
    private var accumulator = 0.0
    private var lastSequence: [UUID: Int] = [:]
    private var activePresses = Set<UUID>()
    private var botDecisionClock = 0.0
    private var botReleaseAt: [UUID: Double] = [:]
    private var events: [HouseTanksWorld.Event] = []

    public init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        random = HouseTanksRandom(seed: seed)
        jokerRandom = HouseTanksRandom(seed: random.next())
    }

    public var phase: HouseTanksPhase? { snapshot?.phase }

    public mutating func start(configuration: HouseTanksMatchConfiguration, matchID: UUID = UUID()) {
        self.configuration = configuration
        lastSequence.removeAll()
        activePresses.removeAll()
        botReleaseAt.removeAll()
        botDecisionClock = 0
        accumulator = 0
        events.removeAll()
        jokerRandom = HouseTanksRandom(seed: random.next())
        jokerBag = HouseTanksJokerBag()

        let botColors = HouseTanksColor.allCases.filter { $0 != configuration.humanColor }
        let human = HouseTanksPlayer(id: UUID(), nameKey: HouseTanksMatchConfiguration.humanNameKey, role: .human,
                                     color: configuration.humanColor, armor: configuration.armorPerRound,
                                     roundsWon: 0, isAlive: true)
        let seats = configuration.playerCount - 1
        let bots = zip(HouseTanksMatchConfiguration.botNameKeys.prefix(seats), botColors).map { nameKey, color in
            HouseTanksPlayer(id: UUID(), nameKey: nameKey, role: .bot, color: color,
                             armor: configuration.armorPerRound, roundsWon: 0, isAlive: true)
        }
        let players = [human] + bots
        let map = HouseTanksMapCatalog.definition(for: configuration.mapID)
        world = Self.arena(map: map, players: players)
        snapshot = HouseTanksSnapshot(
            matchID: matchID, revision: 1, phase: .countdown, mapID: map.id, mapVersion: map.version,
            players: players, roundNumber: 1, countdown: Self.countdownStart, roundWinnerID: nil, championID: nil
        )
    }

    /// The arena's id for a demo player.
    public static func tankID(_ playerID: UUID) -> String { playerID.uuidString }

    private static func arena(map: HouseTanksMapDefinition, players: [HouseTanksPlayer]) -> HouseTanksWorld {
        HouseTanksWorld(map: map, playerIDs: players.map { tankID($0.id) }, colors: players.map(\.color))
    }

    /// One countdown step. Returns `true` when the round switched to playing.
    @discardableResult
    public mutating func advanceCountdown() -> Bool {
        guard var current = snapshot, current.phase == .countdown else { return false }
        let value = current.countdown ?? Self.countdownStart
        if value > 1 {
            current.countdown = value - 1
        } else {
            current.phase = .playing
            current.countdown = nil
            accumulator = 0
            world?.startJokers(random: jokerRandom, bag: jokerBag)
        }
        current.revision += 1
        snapshot = current
        return current.phase == .playing
    }

    /// Advances the arena by the real elapsed time while playing, in whole ticks. A round
    /// ends on the tick its last tanks fall; the rest of the frame is dropped.
    public mutating func advance(by delta: Double) {
        guard snapshot?.phase == .playing, var world else { return }
        accumulator += min(Self.maximumFrameDelta, max(0, delta))
        var outcome = HouseTanksRoundResolution.ongoing
        while accumulator >= HouseTanksWorld.fixedStep {
            accumulator -= HouseTanksWorld.fixedStep
            world.step()
            outcome = Self.resolution(of: world)
            guard outcome == .ongoing else { break }
        }
        self.world = world
        syncPlayers()
        switch outcome {
        case .ongoing: driveBots(delta: delta)
        case .draw: finishRound(winnerID: nil)
        case .winner(let id): finishRound(winnerID: id)
        }
        collectEvents()
        publish()
    }

    /// Applies a command. Presses come from the human; `nextRound` and `restartMatch` from the host.
    @discardableResult
    public mutating func send(_ command: HouseTanksCommand) -> Bool {
        guard let current = snapshot, current.matchID == command.matchID else { return false }
        switch command.action {
        case .pressStarted:
            guard current.phase == .playing, let playerID = command.playerID,
                  current.players.contains(where: { $0.id == playerID && $0.isAlive }),
                  !activePresses.contains(playerID),
                  command.sequence > (lastSequence[playerID] ?? -1) else { return false }
            lastSequence[playerID] = command.sequence
            activePresses.insert(playerID)
            world?.press(Self.tankID(playerID))
            collectEvents()
            return true
        case .pressEnded:
            guard let playerID = command.playerID, command.sequence > (lastSequence[playerID] ?? -1) else { return false }
            lastSequence[playerID] = command.sequence
            activePresses.remove(playerID)
            world?.release(Self.tankID(playerID))
            return true
        case .nextRound:
            guard current.phase == .roundEnded else { return false }
            beginNextRound()
            return true
        case .restartMatch:
            guard current.phase == .matchEnded || current.phase == .roundEnded else { return false }
            start(configuration: configuration)
            return true
        }
    }

    @discardableResult
    public mutating func pause() -> Bool {
        guard var current = snapshot, current.phase == .playing else { return false }
        current.phase = .paused
        current.revision += 1
        snapshot = current
        return true
    }

    @discardableResult
    public mutating func resume() -> Bool {
        guard var current = snapshot, current.phase == .paused else { return false }
        current.phase = .playing
        current.revision += 1
        snapshot = current
        accumulator = 0
        return true
    }

    public mutating func reset() {
        snapshot = nil
        world = nil
        activePresses.removeAll()
        botReleaseAt.removeAll()
        events.removeAll()
    }

    /// Effects since the last call, for the renderer.
    public mutating func drainEvents() -> [HouseTanksWorld.Event] {
        collectEvents()
        defer { events.removeAll() }
        return events
    }

    // MARK: - Rounds

    /// Rounds have no clock: they last until one tank is left, or none (a draw when the last
    /// tanks fall on the same tick).
    private static func resolution(of world: HouseTanksWorld) -> HouseTanksRoundResolution {
        let alive = world.tanks.filter(\.isActive)
        guard alive.count <= 1 else { return .ongoing }
        return alive.first.flatMap { UUID(uuidString: $0.id) }.map(HouseTanksRoundResolution.winner) ?? .draw
    }

    /// Armor and life live in the arena; the snapshot mirrors them seat by seat.
    private mutating func syncPlayers() {
        guard var current = snapshot, let world else { return }
        for index in current.players.indices {
            guard let tank = world.tank(Self.tankID(current.players[index].id)) else { continue }
            current.players[index].armor = tank.armor
            current.players[index].isAlive = tank.isActive
            if !tank.isActive {
                activePresses.remove(current.players[index].id)
                botReleaseAt[current.players[index].id] = nil
            }
        }
        snapshot = current
    }

    private mutating func finishRound(winnerID: UUID?) {
        guard var current = snapshot else { return }
        if let jokers = world?.jokers {
            jokerRandom = jokers.random
            jokerBag = jokers.bag
        }
        world?.freeze()
        activePresses.removeAll()
        botReleaseAt.removeAll()
        current.players = HouseTanksMatchRules.awardingRound(to: winnerID, players: current.players)
        current.roundWinnerID = winnerID
        current.championID = HouseTanksMatchRules.champion(in: current.players, winsNeeded: configuration.roundWinsNeeded)
        current.phase = current.championID == nil ? .roundEnded : .matchEnded
        snapshot = current
    }

    private mutating func beginNextRound() {
        guard var current = snapshot, let previous = world else { return }
        activePresses.removeAll()
        botReleaseAt.removeAll()
        botDecisionClock = 0
        accumulator = 0
        current.roundNumber += 1
        current.roundWinnerID = nil
        current.countdown = Self.countdownStart
        current.phase = .countdown
        current.players = current.players.map { player in
            var reset = player
            reset.armor = configuration.armorPerRound
            reset.isAlive = true
            reset.powerUp = nil
            return reset
        }
        // A fresh arena restores crates; the joker order carries on across rounds.
        world = Self.arena(map: previous.map, players: current.players)
        current.revision += 1
        snapshot = current
    }

    // MARK: - Bots

    private mutating func driveBots(delta: Double) {
        guard let current = snapshot, var world else { return }
        let difficulty = configuration.difficulty
        for (playerID, releaseAt) in botReleaseAt where world.time >= releaseAt {
            world.release(Self.tankID(playerID))
            activePresses.remove(playerID)
            botReleaseAt[playerID] = nil
        }
        botDecisionClock += delta
        if botDecisionClock >= HouseTanksBotBrain.decisionDelay(for: difficulty) {
            botDecisionClock = 0
            // Demo only: on hard every bot hunts the player.
            let focusID = difficulty == .hard ? current.humanPlayer.flatMap { $0.isAlive ? Self.tankID($0.id) : nil } : nil
            for player in current.players where player.role == .bot && player.isAlive
            && !activePresses.contains(player.id) {
                let id = Self.tankID(player.id)
                let observation = world.botObservation(for: id, focusing: focusID)
                // Bots draw from the match's generator, so a seeded match decides identically everywhere.
                guard HouseTanksBotBrain.shouldFire(observation: observation, difficulty: difficulty,
                                                    roll: random.unit()) else { continue }
                // Like a human press, a bot drives even when its shot is still cooling down.
                world.press(id)
                guard world.tank(id)?.isDriving == true else { continue }
                activePresses.insert(player.id)
                botReleaseAt[player.id] = world.time + HouseTanksBotBrain.holdDuration(
                    for: difficulty, travelDistance: observation.targetDistance
                )
            }
        }
        self.world = world
    }

    // MARK: - Publishing

    private mutating func collectEvents() {
        guard var world else { return }
        events += world.drainEvents()
        self.world = world
    }

    private mutating func publish() {
        guard var current = snapshot, let world else { return }
        for index in current.players.indices {
            current.players[index].powerUp = world.powerUpStatus(for: Self.tankID(current.players[index].id))
        }
        current.revision += 1
        snapshot = current
    }
}
