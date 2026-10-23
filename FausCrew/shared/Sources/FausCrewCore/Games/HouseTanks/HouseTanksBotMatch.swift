import Foundation

/// FauseTanks demo match shared by iOS and Android: one human against three bots, rounds
/// until one tank is left, three round wins for the match. It owns phases, hits, bots and
/// the arena, but no clock: the host calls `advanceCountdown()` every `countdownStepSeconds`
/// while counting down and `advance(by:)` with the real frame delta while playing.
/// Every state change bumps `snapshot.revision`.
public struct HouseTanksBotMatch: Sendable {
    public static let countdownStart = 3
    public static let countdownStepSeconds = 0.72
    /// A tank that was just hit ignores regular shells for this long.
    public static let invulnerabilitySeconds = 0.36

    public private(set) var snapshot: HouseTanksSnapshot?
    public private(set) var configuration = HouseTanksMatchConfiguration.demo
    public private(set) var world: HouseTanksWorld?
    private var random: HouseTanksRandom
    private var viewport = HouseTanksSize.reference
    private var lastSequence: [UUID: Int] = [:]
    private var activePresses = Set<UUID>()
    private var invulnerableUntil: [UUID: Double] = [:]
    private var botDecisionClock = 0.0
    private var botReleaseAt: [UUID: Double] = [:]
    private var events: [HouseTanksWorld.Event] = []

    public init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        random = HouseTanksRandom(seed: seed)
    }

    public var phase: HouseTanksPhase? { snapshot?.phase }

    /// The arena follows the drawing surface; a match keeps its layout across resizes.
    public mutating func setViewport(_ size: HouseTanksSize) {
        guard size.isUsable else { return }
        viewport = size
        world?.resize(to: size)
    }

    public mutating func start(configuration: HouseTanksMatchConfiguration, matchID: UUID = UUID()) {
        self.configuration = configuration
        lastSequence.removeAll()
        activePresses.removeAll()
        invulnerableUntil.removeAll()
        botReleaseAt.removeAll()
        botDecisionClock = 0
        events.removeAll()

        let botColors = HouseTanksColor.allCases.filter { $0 != configuration.humanColor }
        let human = HouseTanksPlayer(id: UUID(), nameKey: HouseTanksMatchConfiguration.humanNameKey, role: .human,
                                     color: configuration.humanColor, armor: configuration.armorPerRound,
                                     roundsWon: 0, isAlive: true)
        let bots = zip(HouseTanksMatchConfiguration.botNameKeys, botColors).map { nameKey, color in
            HouseTanksPlayer(id: UUID(), nameKey: nameKey, role: .bot, color: color,
                             armor: configuration.armorPerRound, roundsWon: 0, isAlive: true)
        }
        let players = [human] + bots
        let map = HouseTanksMapCatalog.definition(for: configuration.mapID)
        world = HouseTanksWorld(map: map, size: viewport, players: players, random: random)
        snapshot = HouseTanksSnapshot(
            matchID: matchID, revision: 1, phase: .countdown, mapID: map.id, mapVersion: map.version,
            players: players, roundNumber: 1, countdown: Self.countdownStart, roundWinnerID: nil, championID: nil
        )
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
            world?.setEnabled(true)
        }
        current.revision += 1
        snapshot = current
        return current.phase == .playing
    }

    /// Advances the arena by the real elapsed time while playing.
    public mutating func advance(by delta: Double) {
        guard snapshot?.phase == .playing, var world else { return }
        let hits = world.step(by: delta)
        self.world = world
        for hit in hits { receive(hit) }
        guard snapshot?.phase == .playing else { collectEvents(); publish(); return }
        driveBots(delta: delta)
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
            world?.beginPress(playerID: playerID)
            collectEvents()
            return true
        case .pressEnded:
            guard let playerID = command.playerID, command.sequence > (lastSequence[playerID] ?? -1) else { return false }
            lastSequence[playerID] = command.sequence
            activePresses.remove(playerID)
            world?.endPress(playerID: playerID)
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

    private mutating func receive(_ hit: HouseTanksWorld.Hit) {
        guard var current = snapshot, current.phase == .playing, let time = world?.time else { return }
        // A rocket lands even inside the short grace window after a regular hit.
        guard hit.isLethal || time >= (invulnerableUntil[hit.targetID] ?? 0) else { return }
        invulnerableUntil[hit.targetID] = time + Self.invulnerabilitySeconds
        current.players = HouseTanksMatchRules.applyingDamage(
            to: current.players, targetID: hit.targetID, amount: hit.isLethal ? configuration.armorPerRound : 1
        )
        snapshot = current
        if current.players.first(where: { $0.id == hit.targetID })?.isAlive == false {
            world?.eliminate(playerID: hit.targetID)
            activePresses.remove(hit.targetID)
            botReleaseAt[hit.targetID] = nil
        }
        switch HouseTanksMatchRules.resolveRound(players: current.players) {
        case .ongoing: return
        case .draw: finishRound(winnerID: nil)
        case .winner(let id): finishRound(winnerID: id)
        }
    }

    private mutating func finishRound(winnerID: UUID?) {
        guard var current = snapshot else { return }
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
        invulnerableUntil.removeAll()
        activePresses.removeAll()
        botReleaseAt.removeAll()
        botDecisionClock = 0
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
        world = HouseTanksWorld(map: previous.map, size: viewport, players: current.players,
                                random: previous.random, jokerBag: previous.jokerBag)
        current.revision += 1
        snapshot = current
    }

    // MARK: - Bots

    private mutating func driveBots(delta: Double) {
        guard let current = snapshot, var world else { return }
        let difficulty = configuration.difficulty
        for (playerID, releaseAt) in botReleaseAt where world.time >= releaseAt {
            world.endPress(playerID: playerID)
            activePresses.remove(playerID)
            botReleaseAt[playerID] = nil
        }
        botDecisionClock += delta
        if botDecisionClock >= HouseTanksBotBrain.decisionDelay(for: difficulty) {
            botDecisionClock = 0
            // Demo only: on hard every bot hunts the player.
            let focusID = difficulty == .hard ? current.humanPlayer.flatMap { $0.isAlive ? $0.id : nil } : nil
            for player in current.players where player.role == .bot && player.isAlive
            && !activePresses.contains(player.id) {
                let observation = world.botObservation(for: player.id, focusing: focusID)
                // Bots draw from the match's generator, so a seeded match decides identically everywhere.
                guard HouseTanksBotBrain.shouldFire(observation: observation, difficulty: difficulty,
                                                    roll: random.unit()) else { continue }
                // Like a human press, a bot drives even when its shot is still cooling down.
                world.beginPress(playerID: player.id)
                guard world.tank(player.id)?.isDriving == true else { continue }
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
            current.players[index].powerUp = world.powerUpStatus(for: current.players[index].id)
        }
        current.revision += 1
        snapshot = current
    }
}
