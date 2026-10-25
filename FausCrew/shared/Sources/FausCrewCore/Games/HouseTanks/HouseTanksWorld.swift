import Foundation

/// The FauseTanks arena: tanks, crates, shells, rockets and jokers in one deterministic
/// simulation of whole 1/120 s ticks on a fixed 872×400 arena (origin bottom-left, y up).
/// The backend's Go engine (`houseTanks/world.go`) is the reference; every step, timer and
/// event here follows it, and `houseTanksSimulation.json` pins the two together. Renderers
/// fit the arena to their screen; the simulation never sees a viewport.
public struct HouseTanksWorld: Codable, Sendable {
    // Physics contract of houseTanks.v2: arena points, radians counter-clockwise from +x.
    public static let arenaSize = HouseTanksSize.reference
    public static let physicsRate = 120
    public static let fixedStep = 1.0 / Double(physicsRate)
    public static let rotationSpeed = 1.5
    public static let driveForce = 360.0
    public static let tankMass = 1.25
    public static let tankDamping = 1.8
    public static let maxTankSpeed = 245.0
    public static let tankRadius = 9.0
    /// Body length the renderers draw.
    public static let tankLength = 20.0
    /// Against the arena frame and between live tanks.
    public static let tankRestitution = 0.36
    /// Against fixed cover and wrecks.
    public static let obstacleRestitution = 0.2
    public static let crateRestitution = 0.05
    public static let crateMass = 0.45
    public static let crateDamping = 4.0
    public static let shellSpeed = 510.0
    public static let shellRadius = 1.8
    public static let shellMuzzleOffset = 15.0
    public static let rocketSpeed = 400.0
    public static let rocketRadius = 4.0
    public static let rocketLength = 22.0
    public static let rocketMuzzleOffset = 25.0
    public static let tokenRadius = 16.0
    public static let armorPerRound = 5
    public static let contactIterations = 3
    // Timers in whole ticks.
    public static let fireCooldownTicks = 70
    public static let hitProtectionTicks = 44
    public static let shellLifetimeTicks = 336
    public static let rocketLifetimeTicks = 384

    public struct PowerUpEffect: Codable, Equatable, Sendable {
        public let kind: HouseTanksPowerUp
        public let expiresAtTick: Int
    }

    /// One seat's body. `isActive` is false once destroyed: the tank stays on the floor as a
    /// wreck that blocks tanks, crates and shots. A tank that is not controllable is a
    /// stationary target: it neither turns, drives nor fires.
    public struct Tank: Codable, Equatable, Sendable {
        public let id: String
        public let seat: Int
        /// For renderers only.
        public let color: HouseTanksColor
        public var position: HouseTanksVector
        public var velocity: HouseTanksVector = .zero
        public var rotation: Double
        public var rotationDirection: Double
        public var isActive = true
        public var isControllable = true
        public var isDriving = false
        public var driveDirection: HouseTanksVector = .zero
        public var hasFired = false
        public var lastFireTick = 0
        /// Aim joker shots still in flight; the tank holds its heading until they land.
        public var aimLocks = 0
        public var armor = HouseTanksWorld.armorPerRound
        public var protectedUntilTick = 0
        public var powerUp: PowerUpEffect?
    }

    /// The moving part of a map obstacle; its shape comes from the map.
    public struct Obstacle: Codable, Equatable, Sendable {
        public let index: Int
        public let definition: HouseTanksObstacleDefinition
        public let size: HouseTanksSize
        public var position: HouseTanksVector
        public var velocity: HouseTanksVector = .zero
        public var isDestroyed = false

        public var rotation: Double { definition.rotation }
        public var isRound: Bool { definition.style.isRound }
        public var isMovable: Bool { definition.isMovable }
        public var radius: Double { min(size.width, size.height) / 2 }

        /// Axis-aligned bounds of the rotated shape where it is now.
        public var bounds: HouseTanksRect {
            let width = abs(cos(rotation)) * size.width + abs(sin(rotation)) * size.height
            let height = abs(sin(rotation)) * size.width + abs(cos(rotation)) * size.height
            return HouseTanksRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height)
        }
    }

    public struct Projectile: Codable, Equatable, Sendable {
        public let id: Int
        public let ownerID: String
        /// For renderers only.
        public let color: HouseTanksColor
        public var position: HouseTanksVector
        public var velocity: HouseTanksVector
        public let isRocket: Bool
        public let holdsAim: Bool
        /// Collision radius, already scaled to the map.
        public let radius: Double
        public var age = 0
        public let spawnTick: Int

        public var rotation: Double { velocity.angle }
        var lifetime: Int { isRocket ? HouseTanksWorld.rocketLifetimeTicks : HouseTanksWorld.shellLifetimeTicks }
    }

    /// The joker lying on the floor; at most one exists.
    public struct Token: Codable, Equatable, Sendable {
        public let kind: HouseTanksPowerUp
        public let position: HouseTanksVector
        public let expiresAtTick: Int
    }

    public enum EventKind: String, Codable, Sendable {
        case fired, hit, shielded, crateBroken, explosion, eliminated, jokerCollected
    }

    /// One effect for renderers, stamped with its tick. Fields beyond `kind` are set only for
    /// the kinds that use them, as on the wire:
    /// fired (player, angle), hit (player = target, source = shooter, armor, lethal),
    /// shielded (player, source), crateBroken (crateIndex, position), explosion (position),
    /// eliminated (player, source, position), jokerCollected (player, powerUp).
    public struct Event: Codable, Equatable, Sendable {
        public var tick: Int
        public var kind: EventKind
        public var playerID: String?
        public var sourceID: String?
        public var position: HouseTanksVector?
        public var angle: Double?
        public var armor: Int?
        public var lethal = false
        public var crateIndex: Int?
        public var powerUp: HouseTanksPowerUp?

        public init(tick: Int, kind: EventKind, playerID: String? = nil, sourceID: String? = nil,
                    position: HouseTanksVector? = nil, angle: Double? = nil, armor: Int? = nil, lethal: Bool = false,
                    crateIndex: Int? = nil, powerUp: HouseTanksPowerUp? = nil) {
            self.tick = tick
            self.kind = kind
            self.playerID = playerID
            self.sourceID = sourceID
            self.position = position
            self.angle = angle
            self.armor = armor
            self.lethal = lethal
            self.crateIndex = crateIndex
            self.powerUp = powerUp
        }
    }

    /// A shot that reached an unshielded live tank. Hits are applied at the end of the tick,
    /// so tanks destroyed on the same tick end a round as a draw.
    public struct Hit: Codable, Equatable, Sendable {
        public let targetID: String
        public let ownerID: String
        /// The giant rocket destroys a tank whatever armor it has left.
        public let isLethal: Bool
    }

    public let map: HouseTanksMapDefinition
    public private(set) var tick: Int
    public private(set) var tanks: [Tank]
    public private(set) var obstacles: [Obstacle]
    public private(set) var projectiles: [Projectile] = []
    public private(set) var token: Token?
    public private(set) var nextProjectileID = 1
    /// Deals tokens while the round plays; nil deals none.
    public private(set) var jokers: HouseTanksJokerSchedule?
    /// Muzzle hits of a press, applied by the next step.
    public private(set) var pendingHits: [Hit] = []
    private var events: [Event] = []

    private enum CodingKeys: String, CodingKey {
        case map, tick, tanks, obstacles, projectiles, token, nextProjectileID, jokers, pendingHits
    }

    /// Seats the players in order on the map's spawn points, every tank facing the middle
    /// of the arena; neighbours sweep in opposite directions. Colors default to seat order.
    public init(map: HouseTanksMapDefinition, playerIDs: [String], colors: [HouseTanksColor]? = nil, tick: Int = 0) {
        precondition(!playerIDs.isEmpty && playerIDs.count <= map.spawnPoints.count && tick >= 0,
                     "a world seats one to \(map.spawnPoints.count) players")
        precondition(Set(playerIDs).count == playerIDs.count, "player ids must be unique")
        self.map = map
        self.tick = tick
        let palette = colors ?? HouseTanksColor.allCases
        let center = HouseTanksVector(x: Self.arenaSize.width / 2, y: Self.arenaSize.height / 2)
        tanks = playerIDs.enumerated().map { seat, id in
            let spawn = map.spawnPoints[seat].point()
            return Tank(id: id, seat: seat, color: palette[seat % palette.count], position: spawn,
                        rotation: (center - spawn).angle, rotationDirection: seat.isMultiple(of: 2) ? 1 : -1)
        }
        obstacles = map.obstacles.enumerated().map { index, definition in
            Obstacle(index: index, definition: definition, size: definition.renderedSize(mapScale: map.scale),
                     position: definition.center.point())
        }
    }

    /// The whole logical arena.
    public static let arenaRect = HouseTanksRect(size: arenaSize)

    /// The playable frame inside the wall; shells and tanks stop here.
    public static let arenaFrame: HouseTanksRect = {
        let inset = max(16, arenaSize.height * 0.035)
        return arenaRect.insetBy(dx: inset, dy: inset)
    }()

    public var size: HouseTanksSize { Self.arenaSize }
    public var arenaFrame: HouseTanksRect { Self.arenaFrame }

    /// Seconds of play this round, for countdown rings and bots.
    public var time: Double { Double(tick) * Self.fixedStep }

    /// The map's scale; every body size below follows it (speeds and timings do not).
    public var scale: Double { map.scale }
    public var bodyRadius: Double { Self.tankRadius * scale }
    public var bodyLength: Double { Self.tankLength * scale }

    public var spawnPositions: [HouseTanksVector] { map.spawnPoints.map { $0.point() } }

    public func tank(_ id: String) -> Tank? { tanks.first { $0.id == id } }

    private func tankIndex(_ id: String) -> Int? { tanks.firstIndex { $0.id == id } }

    private func powerUp(of index: Int) -> HouseTanksPowerUp? {
        guard let effect = tanks[index].powerUp, effect.expiresAtTick > tick else { return nil }
        return effect.kind
    }

    public func powerUpStatus(for playerID: String) -> HouseTanksPowerUpStatus? {
        guard let index = tankIndex(playerID), let kind = powerUp(of: index),
              let expires = tanks[index].powerUp?.expiresAtTick else { return nil }
        return HouseTanksPowerUpStatus(kind: kind, remaining: Double(expires - tick) * Self.fixedStep)
    }

    /// Length of the aim joker's sight line from the tank to the arena wall, or nil without the joker.
    public func aimLength(for playerID: String) -> Double? {
        guard let index = tankIndex(playerID), tanks[index].isActive, powerUp(of: index) == .aim else { return nil }
        return HouseTanksMath.rayLength(from: tanks[index].position, angle: tanks[index].rotation, in: arenaFrame)
    }

    /// Fraction of the floor token's life left, 0…1.
    public var tokenFraction: Double {
        guard let token else { return 0 }
        return max(0, Double(token.expiresAtTick - tick) / Double(HouseTanksPowerUpRules.tokenLifetimeTicks))
    }

    private mutating func emit(_ event: Event) {
        var event = event
        event.tick = tick
        events.append(event)
    }

    /// Returns and forgets the events since the last call.
    public mutating func drainEvents() -> [Event] {
        defer { events.removeAll() }
        return events
    }

    // MARK: - Input

    /// Locks the heading, fires once and starts driving along the barrel. A shot still
    /// cooling down is skipped but the tank drives anyway. Returns whether a shot was fired.
    @discardableResult
    public mutating func press(_ playerID: String) -> Bool {
        guard let index = tankIndex(playerID), tanks[index].isActive, tanks[index].isControllable,
              !tanks[index].isDriving else { return false }
        tanks[index].isDriving = true
        tanks[index].driveDirection = HouseTanksVector(angle: tanks[index].rotation)
        let shot = fire(tankIndex: index)
        pendingHits += shot.hits
        return shot.fired
    }

    /// Stops the tank; it sweeps the other way afterwards.
    public mutating func release(_ playerID: String) {
        guard let index = tankIndex(playerID), tanks[index].isDriving else { return }
        tanks[index].isDriving = false
        tanks[index].driveDirection = .zero
        tanks[index].velocity = .zero
        tanks[index].rotationDirection = HouseTanksMath.oppositeRotationDirection(after: tanks[index].rotationDirection)
    }

    /// Turns a tank into a stationary target or back. Losing control releases the press
    /// without reversing the sweep, stops the tank and clears its aim lock; the body, armor
    /// and joker stay.
    public mutating func setControllable(_ playerID: String, _ controllable: Bool) {
        guard let index = tankIndex(playerID), tanks[index].isControllable != controllable else { return }
        tanks[index].isControllable = controllable
        if !controllable {
            tanks[index].isDriving = false
            tanks[index].driveDirection = .zero
            tanks[index].velocity = .zero
            tanks[index].aimLocks = 0
        }
    }

    /// Turns an idle tank to a given heading (online lag compensation).
    @discardableResult
    public mutating func setRotation(_ playerID: String, _ rotation: Double) -> Bool {
        guard let index = tankIndex(playerID), tanks[index].isActive, !tanks[index].isDriving,
              rotation.isFinite else { return false }
        tanks[index].rotation = rotation
        return true
    }

    /// Gives a live tank a joker effect from now, replacing any other.
    @discardableResult
    public mutating func grant(_ kind: HouseTanksPowerUp, to playerID: String) -> Bool {
        guard let index = tankIndex(playerID), tanks[index].isActive else { return false }
        tanks[index].powerUp = PowerUpEffect(kind: kind, expiresAtTick: tick + HouseTanksPowerUpRules.durationTicks)
        return true
    }

    /// Stops the arena at a round's end: no shots, motion, presses, aim locks or jokers.
    /// A frozen world is shown but not stepped again.
    public mutating func freeze() {
        projectiles.removeAll()
        pendingHits.removeAll()
        token = nil
        jokers = nil
        for index in tanks.indices {
            tanks[index].velocity = .zero
            tanks[index].isDriving = false
            tanks[index].aimLocks = 0
            tanks[index].powerUp = nil
        }
        for index in obstacles.indices { obstacles[index].velocity = .zero }
    }

    /// Lays a joker on the floor unless one is already there.
    @discardableResult
    public mutating func placeToken(_ kind: HouseTanksPowerUp, at position: HouseTanksVector) -> Bool {
        guard token == nil, Self.arenaRect.contains(position) else { return false }
        token = Token(kind: kind, position: position, expiresAtTick: tick + HouseTanksPowerUpRules.tokenLifetimeTicks)
        return true
    }

    /// Deals jokers in this world from the match's generator and bag; the first one is due
    /// 7–11 s after now.
    public mutating func startJokers(random: HouseTanksRandom, bag: HouseTanksJokerBag) {
        var schedule = HouseTanksJokerSchedule(random: random, bag: bag, nextTokenTick: 0)
        schedule.nextTokenTick = tick + HouseTanksPowerUpRules.spawnInterval(using: &schedule.random)
        jokers = schedule
    }

    // MARK: - Bots

    /// What a bot sees: aim error toward its next waypoint and the distance to it.
    /// `focusID` pins every bot on one tank (the demo's hard mode); otherwise the nearest tank is engaged.
    public func botObservation(for playerID: String, focusing focusID: String? = nil) -> HouseTanksBotObservation {
        guard let tank = tank(playerID), tank.isActive else { return .none }
        let candidates = tanks.filter { $0.isActive && $0.id != playerID }.map { (id: $0.id, position: $0.position) }
        guard let targetID = HouseTanksBotBrain.target(from: tank.position, among: candidates, focus: focusID),
              let target = self.tank(targetID) else { return .none }
        let inset = arenaFrame.minX + 16 * scale
        let goal = token.map { token in
            tank.position.distance(to: token.position) < 220 ? token.position : target.position
        } ?? target.position
        let waypoint = HouseTanksNavigation.waypoint(
            from: tank.position, to: goal, arena: Self.arenaRect.insetBy(dx: inset, dy: inset),
            obstacles: coverBounds, padding: 14 * scale, step: 16 * scale
        )
        let aimError = abs(HouseTanksMath.normalizedAngle((waypoint - tank.position).angle - tank.rotation))
        return HouseTanksBotObservation(aimError: aimError, targetDistance: tank.position.distance(to: waypoint),
                                        hasTarget: true)
    }

    /// Everything a token or a route keeps clear of: standing furniture and crates where
    /// they are now, and wrecks.
    private var coverBounds: [HouseTanksRect] {
        obstacles.filter { !$0.isDestroyed }.map(\.bounds) + tanks.filter { !$0.isActive }.map { tank in
            HouseTanksRect(x: tank.position.x - bodyRadius, y: tank.position.y - bodyRadius,
                           width: bodyRadius * 2, height: bodyRadius * 2)
        }
    }

    // MARK: - Simulation

    /// Advances the arena by one tick in the reference order: expiry, joker dealing, tank
    /// motion, crate motion, three contact passes, joker pickup, shots, hits.
    public mutating func step() {
        tick += 1
        expirePowerUps()
        dealJoker()
        var hits: [Hit] = []
        let dt = Self.fixedStep
        for index in tanks.indices where tanks[index].isActive {
            if tanks[index].isDriving {
                tanks[index].velocity += tanks[index].driveDirection * (Self.driveForce / Self.tankMass * dt)
                if powerUp(of: index) == .rapidFire { hits += fire(tankIndex: index).hits }
            } else if tanks[index].aimLocks == 0 && tanks[index].isControllable {
                tanks[index].rotation += Self.rotationSpeed * tanks[index].rotationDirection * dt
            }
            tanks[index].velocity = tanks[index].velocity * (1 / (1 + dt * Self.tankDamping))
            let speed = tanks[index].velocity.length
            if speed > Self.maxTankSpeed { tanks[index].velocity = tanks[index].velocity * (Self.maxTankSpeed / speed) }
            tanks[index].position += tanks[index].velocity * dt
        }
        for index in obstacles.indices where obstacles[index].isMovable && !obstacles[index].isDestroyed {
            obstacles[index].velocity = obstacles[index].velocity * (1 / (1 + dt * Self.crateDamping))
            obstacles[index].position += obstacles[index].velocity * dt
        }
        for _ in 0..<Self.contactIterations { resolveContacts() }
        collectToken()
        hits += advanceProjectiles()
        apply(hits)
    }

    private mutating func expirePowerUps() {
        if let token, tick >= token.expiresAtTick { self.token = nil }
        for index in tanks.indices {
            if let effect = tanks[index].powerUp, tick >= effect.expiresAtTick { tanks[index].powerUp = nil }
        }
    }

    // MARK: Firing

    /// Launches one shot, or a spread-shot volley, unless the barrel is still cooling down.
    /// A muzzle already touching cover or a tank hits it at once.
    private mutating func fire(tankIndex index: Int) -> (hits: [Hit], fired: Bool) {
        let tank = tanks[index]
        let power = powerUp(of: index)
        let cooldown = power == .rapidFire ? HouseTanksPowerUpRules.rapidFireCooldownTicks : Self.fireCooldownTicks
        if tank.hasFired && tick - tank.lastFireTick < cooldown { return ([], false) }
        tanks[index].hasFired = true
        tanks[index].lastFireTick = tick

        var hits: [Hit] = []
        let isRocket = power == .rocket
        let offsets = power == .spreadShot ? HouseTanksPowerUpRules.spreadAngles : [0]
        for offset in offsets {
            let direction = HouseTanksVector(angle: tank.rotation + offset)
            let muzzle = isRocket ? Self.rocketMuzzleOffset : Self.shellMuzzleOffset
            let start = tank.position + direction * (muzzle * scale)
            let projectile = Projectile(
                id: nextProjectileID, ownerID: tank.id, color: tank.color, position: start,
                velocity: direction * (isRocket ? Self.rocketSpeed : Self.shellSpeed),
                isRocket: isRocket, holdsAim: power == .aim,
                radius: (isRocket ? Self.rocketRadius : Self.shellRadius) * scale, spawnTick: tick
            )
            nextProjectileID += 1
            if projectile.holdsAim { tanks[index].aimLocks += 1 }
            // The muzzle may touch a pushed crate or a thin wall; never spawn a shot on the
            // far side of that cover.
            if let blocker = firstContact(from: tank.position, to: start, radius: projectile.radius, ownerID: tank.id) {
                hits += impact(of: projectile, on: blocker.body, at: start)
            } else {
                projectiles.append(projectile)
            }
        }
        emit(Event(tick: tick, kind: .fired, playerID: tank.id, angle: tank.rotation))
        return (hits, true)
    }

    private enum Body: Equatable {
        case wall
        case tank(Int)
        case obstacle(Int)
    }

    /// The first wall, tank (live or wreck, never the owner) or standing obstacle the swept
    /// shot touches.
    private func firstContact(from start: HouseTanksVector, to end: HouseTanksVector, radius: Double,
                              ownerID: String) -> (body: Body, fraction: Double)? {
        var best: (body: Body, fraction: Double)?
        func consider(_ body: Body, _ fraction: Double?) {
            guard let fraction, fraction >= 0, fraction <= 1, fraction < (best?.fraction ?? .infinity) else { return }
            best = (body, fraction)
        }
        consider(.wall, Self.exitFraction(from: start, to: end, inside: arenaFrame.insetBy(dx: radius, dy: radius)))
        for (index, tank) in tanks.enumerated() where tank.id != ownerID {
            consider(.tank(index), Self.segmentCircle(from: start, to: end, center: tank.position,
                                                      radius: bodyRadius + radius))
        }
        for (index, obstacle) in obstacles.enumerated() where !obstacle.isDestroyed {
            let fraction = obstacle.isRound
                ? Self.segmentCircle(from: start, to: end, center: obstacle.position, radius: obstacle.radius + radius)
                : Self.segmentBox(from: start, to: end, center: obstacle.position,
                                  half: .init(width: obstacle.size.width / 2 + radius, height: obstacle.size.height / 2 + radius),
                                  rotation: obstacle.rotation)
            consider(.obstacle(index), fraction)
        }
        return best
    }

    private mutating func advanceProjectiles() -> [Hit] {
        var hits = pendingHits
        pendingHits.removeAll()
        var survivors: [Projectile] = []
        for var projectile in projectiles {
            projectile.age += 1
            let start = projectile.position
            let end = start + projectile.velocity * Self.fixedStep
            if let contact = firstContact(from: start, to: end, radius: projectile.radius, ownerID: projectile.ownerID) {
                let point = start + (end - start) * contact.fraction
                hits += impact(of: projectile, on: contact.body, at: point)
                continue
            }
            projectile.position = end
            if projectile.age >= projectile.lifetime {
                releaseAim(of: projectile)
                continue
            }
            survivors.append(projectile)
        }
        projectiles = survivors
        return hits
    }

    /// Ends a shot: a crate breaks, a shield absorbs the shot, a live tank is hit. Walls,
    /// furniture and wrecks only stop it.
    private mutating func impact(of projectile: Projectile, on body: Body, at point: HouseTanksVector) -> [Hit] {
        releaseAim(of: projectile)
        if projectile.isRocket { emit(Event(tick: tick, kind: .explosion, position: point)) }
        switch body {
        case .wall:
            return []
        case .obstacle(let index):
            guard obstacles[index].definition.breaksOnHit else { return [] }
            obstacles[index].isDestroyed = true
            emit(Event(tick: tick, kind: .crateBroken, position: obstacles[index].position, crateIndex: index))
            return []
        case .tank(let index):
            let target = tanks[index]
            guard target.isActive else { return [] }
            if powerUp(of: index) == .shield {
                emit(Event(tick: tick, kind: .shielded, playerID: target.id, sourceID: projectile.ownerID))
                return []
            }
            return [Hit(targetID: target.id, ownerID: projectile.ownerID, isLethal: projectile.isRocket)]
        }
    }

    /// Lets the owner turn again once its last aimed shot has landed.
    private mutating func releaseAim(of projectile: Projectile) {
        guard projectile.holdsAim, let index = tankIndex(projectile.ownerID), tanks[index].aimLocks > 0 else { return }
        tanks[index].aimLocks -= 1
    }

    /// Takes armor in order. A regular shot right after a hit is ignored for
    /// `hitProtectionTicks`; a rocket destroys whatever armor is left.
    private mutating func apply(_ hits: [Hit]) {
        for hit in hits {
            guard let index = tankIndex(hit.targetID), tanks[index].isActive else { continue }
            if !hit.isLethal && tick < tanks[index].protectedUntilTick { continue }
            tanks[index].protectedUntilTick = tick + Self.hitProtectionTicks
            if hit.isLethal { tanks[index].armor = 0 } else { tanks[index].armor -= 1 }
            emit(Event(tick: tick, kind: .hit, playerID: tanks[index].id, sourceID: hit.ownerID,
                       armor: tanks[index].armor, lethal: hit.isLethal))
            if tanks[index].armor == 0 { eliminate(index, sourceID: hit.ownerID) }
        }
    }

    private mutating func eliminate(_ index: Int, sourceID: String) {
        tanks[index].isActive = false
        tanks[index].velocity = .zero
        tanks[index].isDriving = false
        tanks[index].driveDirection = .zero
        tanks[index].aimLocks = 0
        tanks[index].powerUp = nil
        emit(Event(tick: tick, kind: .eliminated, playerID: tanks[index].id, sourceID: sourceID,
                   position: tanks[index].position))
    }

    // MARK: Jokers

    /// Places the joker that is due, replacing one still on the floor: up to 80 sampled
    /// spots, else a retry one second later rather than an unfair spot.
    private mutating func dealJoker() {
        guard var schedule = jokers, tick >= schedule.nextTokenTick else { return }
        let starts = spawnPositions
        let live = tanks.filter(\.isActive).map(\.position)
        let cover = coverBounds
        let area = HouseTanksPowerUpRules.area
        defer { jokers = schedule }
        for _ in 0..<HouseTanksPowerUpRules.spawnAttempts {
            let x = schedule.random.between(area.minX, area.maxX)
            let point = HouseTanksVector(x: x, y: schedule.random.between(area.minY, area.maxY))
            guard HouseTanksPowerUpRules.isValidSpawn(point, starts: starts, tanks: live, cover: cover) else { continue }
            let kind = schedule.bag.next(using: &schedule.random)
            token = Token(kind: kind, position: point, expiresAtTick: tick + HouseTanksPowerUpRules.tokenLifetimeTicks)
            schedule.nextTokenTick = tick + HouseTanksPowerUpRules.spawnInterval(using: &schedule.random)
            return
        }
        schedule.nextTokenTick = tick + HouseTanksPowerUpRules.retryTicks
    }

    /// Gives the floor joker to the first live tank over it.
    private mutating func collectToken() {
        guard let token else { return }
        let reach = (Self.tokenRadius + Self.tankRadius) * scale
        for index in tanks.indices where tanks[index].isActive && tanks[index].position.distance(to: token.position) < reach {
            self.token = nil
            tanks[index].powerUp = PowerUpEffect(kind: token.kind, expiresAtTick: tick + HouseTanksPowerUpRules.durationTicks)
            emit(Event(tick: tick, kind: .jokerCollected, playerID: tanks[index].id, powerUp: token.kind))
            return
        }
    }

    // MARK: Contacts

    private mutating func resolveContacts() {
        let frame = arenaFrame
        let radius = bodyRadius
        // Tanks against the frame, furniture, wrecks, crates and each other.
        for a in tanks.indices where tanks[a].isActive {
            confine(tank: a, in: frame)
            for o in obstacles.indices where !obstacles[o].isDestroyed {
                guard let contact = Self.circleContact(center: tanks[a].position, radius: radius,
                                                       obstacle: obstacles[o]) else { continue }
                if obstacles[o].isMovable {
                    push(tank: a, crate: o, normal: contact.normal, depth: contact.depth)
                } else {
                    tanks[a].position += contact.normal * contact.depth
                    tanks[a].velocity = Self.reflect(tanks[a].velocity, normal: contact.normal,
                                                     restitution: Self.obstacleRestitution)
                }
            }
            for b in tanks.indices where b != a {
                let offset = tanks[a].position - tanks[b].position
                let distance = offset.length
                let minimum = radius * 2
                guard distance < minimum else { continue }
                let normal = distance > 0.0001 ? offset * (1 / distance) : HouseTanksVector(x: 1, y: 0)
                let depth = minimum - distance
                if !tanks[b].isActive {
                    tanks[a].position += normal * depth
                    tanks[a].velocity = Self.reflect(tanks[a].velocity, normal: normal, restitution: Self.obstacleRestitution)
                    continue
                }
                if b < a { continue } // each live pair once
                tanks[a].position += normal * (depth / 2)
                tanks[b].position -= normal * (depth / 2)
                let relative = (tanks[a].velocity - tanks[b].velocity).dot(normal)
                if relative < 0 {
                    let impulse = -(1 + Self.tankRestitution) * relative / 2
                    tanks[a].velocity += normal * impulse
                    tanks[b].velocity -= normal * impulse
                }
            }
        }
        // Crates against the frame, fixed cover, wrecks and each other.
        for c in obstacles.indices where obstacles[c].isMovable && !obstacles[c].isDestroyed {
            let bounds = obstacles[c].bounds
            var shift = HouseTanksVector.zero
            if bounds.minX < frame.minX { shift.x = frame.minX - bounds.minX }
            if bounds.maxX > frame.maxX { shift.x = frame.maxX - bounds.maxX }
            if bounds.minY < frame.minY { shift.y = frame.minY - bounds.minY }
            if bounds.maxY > frame.maxY { shift.y = frame.maxY - bounds.maxY }
            if shift != .zero {
                obstacles[c].position += shift
                obstacles[c].velocity = Self.reflect(obstacles[c].velocity, normal: shift.normalized,
                                                     restitution: Self.crateRestitution)
            }
            let crateRadius = obstacles[c].radius * 1.05
            for o in obstacles.indices where o != c && !obstacles[o].isDestroyed {
                guard let contact = Self.circleContact(center: obstacles[c].position, radius: crateRadius,
                                                       obstacle: obstacles[o]) else { continue }
                if obstacles[o].isMovable {
                    guard o > c else { continue }
                    obstacles[c].position += contact.normal * (contact.depth / 2)
                    obstacles[o].position -= contact.normal * (contact.depth / 2)
                } else {
                    obstacles[c].position += contact.normal * contact.depth
                    obstacles[c].velocity = Self.reflect(obstacles[c].velocity, normal: contact.normal,
                                                         restitution: Self.crateRestitution)
                }
            }
            for tank in tanks where !tank.isActive {
                let offset = obstacles[c].position - tank.position
                let distance = offset.length
                let minimum = crateRadius + radius
                guard distance < minimum, distance > 0.0001 else { continue }
                obstacles[c].position += offset * ((minimum - distance) / distance)
            }
        }
    }

    private mutating func confine(tank index: Int, in frame: HouseTanksRect) {
        let r = bodyRadius
        var position = tanks[index].position
        var velocity = tanks[index].velocity
        if position.x < frame.minX + r { position.x = frame.minX + r; if velocity.x < 0 { velocity.x *= -Self.tankRestitution } }
        if position.x > frame.maxX - r { position.x = frame.maxX - r; if velocity.x > 0 { velocity.x *= -Self.tankRestitution } }
        if position.y < frame.minY + r { position.y = frame.minY + r; if velocity.y < 0 { velocity.y *= -Self.tankRestitution } }
        if position.y > frame.maxY - r { position.y = frame.maxY - r; if velocity.y > 0 { velocity.y *= -Self.tankRestitution } }
        tanks[index].position = position
        tanks[index].velocity = velocity
    }

    /// Splits the overlap by inverse mass, so a tank shoves a light crate ahead of it.
    private mutating func push(tank a: Int, crate o: Int, normal: HouseTanksVector, depth: Double) {
        let inverseTank = 1 / Self.tankMass
        let inverseCrate = 1 / Self.crateMass
        let total = inverseTank + inverseCrate
        tanks[a].position += normal * (depth * inverseTank / total)
        obstacles[o].position -= normal * (depth * inverseCrate / total)
        let relative = (tanks[a].velocity - obstacles[o].velocity).dot(normal)
        guard relative < 0 else { return }
        let impulse = -(1 + Self.crateRestitution) * relative / total
        tanks[a].velocity += normal * (impulse * inverseTank)
        obstacles[o].velocity -= normal * (impulse * inverseCrate)
    }

    // MARK: Test hooks

    mutating func debugSet(tank index: Int, _ change: (inout Tank) -> Void) {
        change(&tanks[index])
    }

    // MARK: Geometry

    private static func reflect(_ velocity: HouseTanksVector, normal: HouseTanksVector,
                                restitution: Double) -> HouseTanksVector {
        let along = velocity.dot(normal)
        guard along < 0 else { return velocity }
        return velocity - normal * ((1 + restitution) * along)
    }

    /// Push-out direction and depth for a circle overlapping an obstacle.
    static func circleContact(center: HouseTanksVector, radius: Double,
                              obstacle: Obstacle) -> (normal: HouseTanksVector, depth: Double)? {
        if obstacle.isRound {
            let offset = center - obstacle.position
            let distance = offset.length
            let minimum = radius + obstacle.radius
            guard distance < minimum else { return nil }
            let normal = distance > 0.0001 ? offset * (1 / distance) : HouseTanksVector(x: 1, y: 0)
            return (normal, minimum - distance)
        }
        let local = (center - obstacle.position).rotated(by: -obstacle.rotation)
        let halfWidth = obstacle.size.width / 2
        let halfHeight = obstacle.size.height / 2
        let closest = HouseTanksVector(x: min(max(local.x, -halfWidth), halfWidth),
                                       y: min(max(local.y, -halfHeight), halfHeight))
        let offset = local - closest
        let distance = offset.length
        if distance > 0.0001 {
            guard distance < radius else { return nil }
            return ((offset * (1 / distance)).rotated(by: obstacle.rotation), radius - distance)
        }
        // The center is inside the box: leave through the nearest face.
        let pushX = halfWidth - abs(local.x)
        let pushY = halfHeight - abs(local.y)
        let normal = pushX < pushY
            ? HouseTanksVector(x: local.x >= 0 ? 1 : -1, y: 0)
            : HouseTanksVector(x: 0, y: local.y >= 0 ? 1 : -1)
        return (normal.rotated(by: obstacle.rotation), min(pushX, pushY) + radius)
    }

    /// Fraction along the segment where it first enters the circle, 0 when it starts inside.
    static func segmentCircle(from start: HouseTanksVector, to end: HouseTanksVector,
                              center: HouseTanksVector, radius: Double) -> Double? {
        let direction = end - start
        let offset = start - center
        if offset.length <= radius { return 0 }
        let a = direction.dot(direction)
        guard a > 0 else { return nil }
        let b = 2 * offset.dot(direction)
        let c = offset.dot(offset) - radius * radius
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let fraction = (-b - sqrt(discriminant)) / (2 * a)
        return (0...1).contains(fraction) ? fraction : nil
    }

    /// Fraction along the segment where it first enters a rotated box (slab test in box space).
    static func segmentBox(from start: HouseTanksVector, to end: HouseTanksVector, center: HouseTanksVector,
                           half: HouseTanksSize, rotation: Double) -> Double? {
        let a = (start - center).rotated(by: -rotation)
        let b = (end - center).rotated(by: -rotation)
        var entry = 0.0
        var exit = 1.0
        for (origin, delta, extent) in [(a.x, b.x - a.x, half.width), (a.y, b.y - a.y, half.height)] {
            if abs(delta) < 1e-9 {
                if abs(origin) > extent { return nil }
            } else {
                let first = (-extent - origin) / delta
                let second = (extent - origin) / delta
                entry = max(entry, min(first, second))
                exit = min(exit, max(first, second))
                if entry > exit { return nil }
            }
        }
        return entry
    }

    /// Fraction along the segment where it leaves `bounds`, or nil while it stays inside.
    static func exitFraction(from start: HouseTanksVector, to end: HouseTanksVector,
                             inside bounds: HouseTanksRect) -> Double? {
        guard !bounds.contains(end) else { return nil }
        guard bounds.contains(start) else { return 0 }
        let direction = end - start
        var fraction = 1.0
        if direction.x > 0 { fraction = min(fraction, (bounds.maxX - start.x) / direction.x) }
        if direction.x < 0 { fraction = min(fraction, (bounds.minX - start.x) / direction.x) }
        if direction.y > 0 { fraction = min(fraction, (bounds.maxY - start.y) / direction.y) }
        if direction.y < 0 { fraction = min(fraction, (bounds.minY - start.y) / direction.y) }
        return max(0, fraction)
    }
}
