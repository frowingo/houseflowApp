import Foundation

/// The FauseTanks arena: tanks, crates, shells, rockets and jokers in one deterministic,
/// fixed-step simulation. It replaces SpriteKit's physics so iOS, Android and a future
/// server run the same rules. Coordinates are arena points, origin bottom-left, y up.
public struct HouseTanksWorld: Sendable {
    public static let fireCooldown = 0.58
    public static let rotationSpeed = 1.5
    public static let projectileSpeed = 510.0
    public static let rocketSpeed = 400.0
    public static let driveForce = 360.0
    public static let tankMass = 1.25
    public static let tankDamping = 1.8
    public static let maxTankSpeed = 245.0
    /// Tanks collide as circles; SpriteKit used a 20×14 box with rotation locked.
    public static let tankRadius = 9.0
    /// Body length the muzzle is measured from.
    public static let tankLength = 20.0
    public static let shellRadius = 1.8
    public static let shellLifetime = 2.8
    public static let rocketLength = 22.0
    public static let rocketRadius = 4.0
    public static let rocketLifetime = 3.2
    public static let tokenRadius = 16.0
    public static let crateMass = 0.45
    public static let crateDamping = 4.0
    public static let tankRestitution = 0.36
    public static let wallRestitution = 0.2
    /// Physics runs at a fixed rate whatever the display does.
    public static let fixedStep = 1.0 / 120.0
    private static let maximumFrameDelta = 1.0 / 20.0

    public struct Tank: Equatable, Sendable {
        public let id: UUID
        public let color: HouseTanksColor
        public let role: HouseTanksPlayerRole
        public var position: HouseTanksVector
        public var velocity: HouseTanksVector = .zero
        /// Barrel heading in radians, counter-clockwise from +x.
        public var rotation: Double
        public var rotationDirection: Double
        public var isActive: Bool
        public var isDriving = false
        public var driveDirection: HouseTanksVector = .zero
        public var lastFireTime = -Double.greatestFiniteMagnitude
        /// Aim joker shots still in flight; the tank holds its heading until they land.
        public var aimLocks = 0
    }

    public struct Obstacle: Equatable, Sendable {
        public let index: Int
        public let definition: HouseTanksObstacleDefinition
        public var position: HouseTanksVector
        public var size: HouseTanksSize
        public var velocity: HouseTanksVector = .zero
        public var isDestroyed = false

        public var rotation: Double { definition.rotation }
        public var isRound: Bool { definition.style.isRound }
        public var isMovable: Bool { definition.isMovable }
        public var radius: Double { min(size.width, size.height) / 2 }

        /// Axis-aligned bounds of the rotated shape.
        public var bounds: HouseTanksRect {
            let width = abs(cos(rotation)) * size.width + abs(sin(rotation)) * size.height
            let height = abs(sin(rotation)) * size.width + abs(cos(rotation)) * size.height
            return HouseTanksRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height)
        }
    }

    public struct Projectile: Equatable, Sendable {
        public let id: Int
        public let ownerID: UUID
        public let color: HouseTanksColor
        public var position: HouseTanksVector
        public var velocity: HouseTanksVector
        public let isRocket: Bool
        public let holdsAim: Bool
        public var age = 0.0

        public var rotation: Double { velocity.angle }
        var radius: Double { isRocket ? HouseTanksWorld.rocketRadius : HouseTanksWorld.shellRadius }
        var lifetime: Double { isRocket ? HouseTanksWorld.rocketLifetime : HouseTanksWorld.shellLifetime }
    }

    /// One-off effects for renderers; drained every frame.
    public enum Event: Equatable, Sendable {
        case fired(playerID: UUID, angle: Double)
        case shielded(playerID: UUID)
        case crateBroken(index: Int, position: HouseTanksVector)
        case explosion(position: HouseTanksVector)
        case eliminated(playerID: UUID, position: HouseTanksVector)
        case jokerCollected(playerID: UUID, kind: HouseTanksPowerUp)
    }

    /// A shell or rocket that reached a tank without a shield.
    public struct Hit: Equatable, Sendable {
        public let targetID: UUID
        public let ownerID: UUID
        /// The giant rocket destroys a tank whatever armor it has left.
        public let isLethal: Bool
    }

    public private(set) var size: HouseTanksSize
    public let map: HouseTanksMapDefinition
    public private(set) var tanks: [Tank]
    public private(set) var obstacles: [Obstacle]
    public private(set) var projectiles: [Projectile] = []
    public private(set) var powerUps = HouseTanksPowerUpRules()
    public private(set) var isEnabled = false
    public private(set) var random: HouseTanksRandom
    public private(set) var jokerBag: HouseTanksJokerBag
    private var events: [Event] = []
    private var nextTokenTime: Double
    private var accumulator = 0.0
    private var nextProjectileID = 1

    public var time: Double { powerUps.time }

    public init(map: HouseTanksMapDefinition, size: HouseTanksSize, players: [HouseTanksPlayer],
                random: HouseTanksRandom, jokerBag: HouseTanksJokerBag = HouseTanksJokerBag()) {
        let arena = size.isUsable ? size : .reference
        self.size = arena
        self.map = map
        self.random = random
        self.jokerBag = jokerBag
        obstacles = map.obstacles.enumerated().map { index, definition in
            Obstacle(index: index, definition: definition, position: definition.center.point(in: arena),
                     size: definition.renderedSize(in: arena))
        }
        let spawns = map.spawnPoints.map { $0.point(in: arena) }
        let center = HouseTanksVector(x: arena.width / 2, y: arena.height / 2)
        tanks = players.enumerated().map { index, player in
            let spawn = spawns[min(index, spawns.count - 1)]
            // Every tank starts facing the middle of the arena; neighbors sweep in opposite directions.
            return Tank(id: player.id, color: player.color, role: player.role, position: spawn,
                        rotation: (center - spawn).angle, rotationDirection: index.isMultiple(of: 2) ? 1 : -1,
                        isActive: player.isAlive)
        }
        nextTokenTime = self.random.value(in: HouseTanksPowerUpRules.spawnInterval)
    }

    /// The playable frame inside the arena border; shells and tanks stop here.
    public var arenaFrame: HouseTanksRect {
        let inset = max(16, size.height * 0.035)
        return HouseTanksRect(size: size).insetBy(dx: inset, dy: inset)
    }

    public var spawnPositions: [HouseTanksVector] { map.spawnPoints.map { $0.point(in: size) } }

    public func tank(_ id: UUID) -> Tank? { tanks.first { $0.id == id } }

    public func powerUpStatus(for playerID: UUID) -> HouseTanksPowerUpStatus? { powerUps.status(for: playerID) }

    /// Length of the aim joker's sight line from the tank to the arena wall, or nil without the joker.
    public func aimLength(for playerID: UUID) -> Double? {
        guard let tank = tank(playerID), tank.isActive, powerUps.status(for: playerID)?.kind == .aim else { return nil }
        return HouseTanksMath.rayLength(from: tank.position, angle: tank.rotation, in: arenaFrame)
    }

    // MARK: - Lifecycle

    public mutating func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        accumulator = 0
        if !enabled { clearShots() }
    }

    /// Stops everything at a round's end: no shells, no motion, no joker on the floor.
    public mutating func freeze() {
        isEnabled = false
        clearShots()
        for index in tanks.indices {
            tanks[index].velocity = .zero
            tanks[index].isDriving = false
        }
        for index in obstacles.indices { obstacles[index].velocity = .zero }
        powerUps.removeToken()
    }

    /// Follows a viewport change, keeping every body at the same relative place.
    public mutating func resize(to newSize: HouseTanksSize) {
        guard newSize.isUsable, newSize != size else { return }
        let scaleX = newSize.width / size.width
        let scaleY = newSize.height / size.height
        func scaled(_ point: HouseTanksVector) -> HouseTanksVector { .init(x: point.x * scaleX, y: point.y * scaleY) }
        size = newSize
        for index in tanks.indices { tanks[index].position = scaled(tanks[index].position) }
        for index in obstacles.indices {
            obstacles[index].size = obstacles[index].definition.renderedSize(in: newSize)
            obstacles[index].position = obstacles[index].isMovable
                ? scaled(obstacles[index].position)
                : obstacles[index].definition.center.point(in: newSize)
        }
        for index in projectiles.indices { projectiles[index].position = scaled(projectiles[index].position) }
        if powerUps.token != nil { powerUps.removeToken() }
    }

    public mutating func drainEvents() -> [Event] {
        defer { events.removeAll() }
        return events
    }

    // MARK: - Input

    /// Press: lock the heading, fire once and start driving along the barrel.
    @discardableResult
    public mutating func beginPress(playerID: UUID) -> Bool {
        guard isEnabled, let index = tanks.firstIndex(where: { $0.id == playerID }),
              tanks[index].isActive, !tanks[index].isDriving else { return false }
        tanks[index].isDriving = true
        tanks[index].driveDirection = HouseTanksVector(angle: tanks[index].rotation)
        return fire(tankIndex: index)
    }

    /// Release: stop, and sweep the other way next time.
    public mutating func endPress(playerID: UUID) {
        guard let index = tanks.firstIndex(where: { $0.id == playerID }), tanks[index].isDriving else { return }
        tanks[index].isDriving = false
        tanks[index].driveDirection = .zero
        tanks[index].velocity = .zero
        tanks[index].rotationDirection = HouseTanksMath.oppositeRotationDirection(after: tanks[index].rotationDirection)
    }

    /// A destroyed tank stays on the floor as fixed cover.
    public mutating func eliminate(playerID: UUID) {
        guard let index = tanks.firstIndex(where: { $0.id == playerID }), tanks[index].isActive else { return }
        tanks[index].isActive = false
        tanks[index].velocity = .zero
        tanks[index].isDriving = false
        tanks[index].aimLocks = 0
        powerUps.remove(playerID: playerID)
        events.append(.eliminated(playerID: playerID, position: tanks[index].position))
    }

    // MARK: - Bots

    /// What a bot sees: aim error toward its next waypoint and the distance to it.
    /// `focusID` pins every bot on one tank (the demo's hard mode); otherwise the nearest tank is engaged.
    public func botObservation(for playerID: UUID, focusing focusID: UUID? = nil) -> HouseTanksBotObservation {
        guard let tank = tank(playerID), tank.isActive else { return .none }
        let candidates = tanks.filter { $0.isActive && $0.id != playerID }.map { (id: $0.id, position: $0.position) }
        guard let targetID = HouseTanksBotBrain.target(from: tank.position, among: candidates, focus: focusID),
              let target = self.tank(targetID) else { return .none }
        let inset = max(16, size.height * 0.035) + 16
        let goal = powerUps.token.map { token in
            tank.position.distance(to: token.position) < 220 ? token.position : target.position
        } ?? target.position
        let waypoint = HouseTanksNavigation.waypoint(
            from: tank.position, to: goal, arena: HouseTanksRect(size: size).insetBy(dx: inset, dy: inset),
            obstacles: coverBounds
        )
        let aimError = abs(HouseTanksMath.normalizedAngle((waypoint - tank.position).angle - tank.rotation))
        return HouseTanksBotObservation(aimError: aimError, targetDistance: tank.position.distance(to: waypoint),
                                        hasTarget: true)
    }

    /// Everything that blocks a route: furniture, crates and wrecks.
    private var coverBounds: [HouseTanksRect] {
        obstacles.filter { !$0.isDestroyed }.map(\.bounds) + tanks.filter { !$0.isActive }.map { tank in
            HouseTanksRect(x: tank.position.x - Self.tankRadius, y: tank.position.y - Self.tankRadius,
                           width: Self.tankRadius * 2, height: Self.tankRadius * 2)
        }
    }

    // MARK: - Simulation

    /// Advances by a real frame delta in fixed steps. Returns the tank hits in this frame.
    @discardableResult
    public mutating func step(by delta: Double) -> [Hit] {
        guard isEnabled, delta > 0 else { return [] }
        accumulator += min(Self.maximumFrameDelta, delta)
        var hits: [Hit] = []
        while accumulator >= Self.fixedStep {
            accumulator -= Self.fixedStep
            hits += substep(Self.fixedStep)
            guard isEnabled else { break }
        }
        return hits
    }

    private mutating func substep(_ dt: Double) -> [Hit] {
        powerUps.advance(by: dt)
        updateJokers()
        var hits: [Hit] = []

        for index in tanks.indices where tanks[index].isActive {
            let power = powerUps.status(for: tanks[index].id)?.kind
            if tanks[index].isDriving {
                tanks[index].velocity += tanks[index].driveDirection * (Self.driveForce / Self.tankMass * dt)
                if power == .rapidFire { hits += fireCollectingHits(tankIndex: index) }
            } else if tanks[index].aimLocks == 0 {
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

        for _ in 0..<3 { resolveContacts() }
        collectJokers()
        hits += advanceProjectiles(dt)
        return hits
    }

    // MARK: Firing

    @discardableResult
    private mutating func fire(tankIndex index: Int) -> Bool {
        let hits = fireCollectingHits(tankIndex: index)
        pendingMuzzleHits += hits
        return firedLastAttempt
    }

    /// Muzzle hits from a press arrive outside `step`; the next step reports them.
    private var pendingMuzzleHits: [Hit] = []
    private var firedLastAttempt = false

    private mutating func fireCollectingHits(tankIndex index: Int) -> [Hit] {
        firedLastAttempt = false
        let tank = tanks[index]
        let power = powerUps.status(for: tank.id)?.kind
        let cooldown = power == .rapidFire ? HouseTanksPowerUpRules.rapidFireCooldown : Self.fireCooldown
        guard time - tank.lastFireTime >= cooldown else { return [] }
        tanks[index].lastFireTime = time
        firedLastAttempt = true

        var hits: [Hit] = []
        let isRocket = power == .rocket
        let offsets = power == .spreadShot ? HouseTanksPowerUpRules.spreadAngles : [0]
        for offset in offsets {
            let angle = tank.rotation + offset
            let direction = HouseTanksVector(angle: angle)
            // A rocket is long; launch it clear of its own hull so it does not bounce off it.
            let startDistance = Self.tankLength / 2 + (isRocket ? Self.rocketLength / 2 + 4 : 5)
            let start = tank.position + direction * startDistance
            let projectile = Projectile(
                id: nextProjectileID, ownerID: tank.id, color: tank.color, position: start,
                velocity: direction * (isRocket ? Self.rocketSpeed : Self.projectileSpeed),
                isRocket: isRocket, holdsAim: power == .aim
            )
            nextProjectileID += 1
            if projectile.holdsAim { tanks[index].aimLocks += 1 }
            // The muzzle may touch a pushed crate or a thin wall. Do not spawn a shot
            // on the far side of that cover just because its center is outside the tank.
            if let blocker = firstContact(from: tank.position, to: start, radius: projectile.radius, ownerID: tank.id) {
                hits += impact(of: projectile, on: blocker.body, at: start)
            } else {
                projectiles.append(projectile)
            }
        }
        events.append(.fired(playerID: tank.id, angle: tank.rotation))
        return hits
    }

    private enum Body: Equatable {
        case wall
        case tank(Int)
        case obstacle(Int)
    }

    private func firstContact(from start: HouseTanksVector, to end: HouseTanksVector, radius: Double,
                              ownerID: UUID) -> (body: Body, fraction: Double)? {
        var best: (body: Body, fraction: Double)?
        func consider(_ body: Body, _ fraction: Double?) {
            guard let fraction, fraction >= 0, fraction <= 1, fraction < (best?.fraction ?? .infinity) else { return }
            best = (body, fraction)
        }
        consider(.wall, Self.exitFraction(from: start, to: end, inside: arenaFrame.insetBy(dx: radius, dy: radius)))
        for (index, tank) in tanks.enumerated() where tank.id != ownerID {
            consider(.tank(index), Self.segmentCircle(from: start, to: end, center: tank.position,
                                                      radius: Self.tankRadius + radius))
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

    private mutating func advanceProjectiles(_ dt: Double) -> [Hit] {
        var hits = pendingMuzzleHits
        pendingMuzzleHits.removeAll()
        var survivors: [Projectile] = []
        for var projectile in projectiles {
            projectile.age += dt
            let start = projectile.position
            let end = start + projectile.velocity * dt
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

    private mutating func impact(of projectile: Projectile, on body: Body, at point: HouseTanksVector) -> [Hit] {
        releaseAim(of: projectile)
        if projectile.isRocket { events.append(.explosion(position: point)) }
        switch body {
        case .wall:
            return []
        case .obstacle(let index):
            guard obstacles[index].definition.breaksOnHit else { return [] }
            obstacles[index].isDestroyed = true
            events.append(.crateBroken(index: index, position: obstacles[index].position))
            return []
        case .tank(let index):
            let target = tanks[index]
            guard target.isActive else { return [] }
            if powerUps.status(for: target.id)?.kind == .shield {
                events.append(.shielded(playerID: target.id))
                return []
            }
            return [Hit(targetID: target.id, ownerID: projectile.ownerID, isLethal: projectile.isRocket)]
        }
    }

    /// Lets the owner turn again once its last aimed shot has hit something or expired.
    private mutating func releaseAim(of projectile: Projectile) {
        guard projectile.holdsAim, let index = tanks.firstIndex(where: { $0.id == projectile.ownerID }) else { return }
        tanks[index].aimLocks = max(0, tanks[index].aimLocks - 1)
    }

    private mutating func clearShots() {
        projectiles.removeAll()
        pendingMuzzleHits.removeAll()
        for index in tanks.indices { tanks[index].aimLocks = 0 }
    }

    // MARK: Jokers

    private mutating func updateJokers() {
        guard powerUps.token == nil, time >= nextTokenTime else { return }
        // Keep tokens clear of the top HUD, walls, initial spawns and current actors.
        let spawnArea = HouseTanksRect(x: 48, y: 44, width: size.width - 96, height: size.height - 124)
        guard spawnArea.width > 0, spawnArea.height > 0 else { return }
        let blocked = coverBounds
        let actors = tanks.filter(\.isActive).map(\.position)
        let starts = spawnPositions
        for _ in 0..<80 {
            let point = HouseTanksVector(x: random.value(in: spawnArea.minX...spawnArea.maxX),
                                         y: random.value(in: spawnArea.minY...spawnArea.maxY))
            guard HouseTanksPowerUpRules.isValidSpawn(point, arena: spawnArea, starts: starts, tanks: actors,
                                                      obstacles: blocked) else { continue }
            let kind = jokerBag.next(using: &random)
            powerUps.spawn(kind: kind, at: point)
            nextTokenTime = time + random.value(in: HouseTanksPowerUpRules.spawnInterval)
            return
        }
        // A crowded arena skips this attempt instead of placing a token in an unfair location.
        nextTokenTime = time + 1
    }

    private mutating func collectJokers() {
        guard let token = powerUps.token else { return }
        for tank in tanks where tank.isActive
        && tank.position.distance(to: token.position) < Self.tokenRadius + Self.tankRadius {
            if let kind = powerUps.collect(playerID: tank.id) {
                events.append(.jokerCollected(playerID: tank.id, kind: kind))
            }
            return
        }
    }

    // MARK: Contacts

    private mutating func resolveContacts() {
        let frame = arenaFrame
        // Tanks against the frame, furniture, wrecks, crates and each other.
        for a in tanks.indices where tanks[a].isActive {
            confine(tank: a, in: frame)
            for o in obstacles.indices where !obstacles[o].isDestroyed {
                guard let contact = Self.circleContact(center: tanks[a].position, radius: Self.tankRadius,
                                                       obstacle: obstacles[o]) else { continue }
                if obstacles[o].isMovable {
                    push(tank: a, crate: o, normal: contact.normal, depth: contact.depth)
                } else {
                    tanks[a].position += contact.normal * contact.depth
                    tanks[a].velocity = Self.reflect(tanks[a].velocity, normal: contact.normal,
                                                     restitution: Self.wallRestitution)
                }
            }
            for b in tanks.indices where b != a {
                let offset = tanks[a].position - tanks[b].position
                let distance = offset.length
                let minimum = Self.tankRadius * 2
                guard distance < minimum else { continue }
                let normal = distance > 0.0001 ? offset * (1 / distance) : HouseTanksVector(x: 1, y: 0)
                let depth = minimum - distance
                if tanks[b].isActive {
                    if b < a { continue } // each live pair once
                    tanks[a].position += normal * (depth / 2)
                    tanks[b].position -= normal * (depth / 2)
                    let relative = (tanks[a].velocity - tanks[b].velocity).dot(normal)
                    if relative < 0 {
                        let impulse = -(1 + Self.tankRestitution) * relative / 2
                        tanks[a].velocity += normal * impulse
                        tanks[b].velocity -= normal * impulse
                    }
                } else {
                    tanks[a].position += normal * depth
                    tanks[a].velocity = Self.reflect(tanks[a].velocity, normal: normal, restitution: Self.wallRestitution)
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
                obstacles[c].velocity = Self.reflect(obstacles[c].velocity, normal: shift.normalized, restitution: 0.05)
            }
            let radius = obstacles[c].radius * 1.05
            for o in obstacles.indices where o != c && !obstacles[o].isDestroyed {
                guard let contact = Self.circleContact(center: obstacles[c].position, radius: radius,
                                                       obstacle: obstacles[o]) else { continue }
                if obstacles[o].isMovable {
                    guard o > c else { continue }
                    obstacles[c].position += contact.normal * (contact.depth / 2)
                    obstacles[o].position -= contact.normal * (contact.depth / 2)
                } else {
                    obstacles[c].position += contact.normal * contact.depth
                    obstacles[c].velocity = Self.reflect(obstacles[c].velocity, normal: contact.normal, restitution: 0.05)
                }
            }
            for tank in tanks where !tank.isActive {
                let offset = obstacles[c].position - tank.position
                let distance = offset.length
                let minimum = radius + Self.tankRadius
                guard distance < minimum, distance > 0.0001 else { continue }
                obstacles[c].position += offset * ((minimum - distance) / distance)
            }
        }
    }

    private mutating func confine(tank index: Int, in frame: HouseTanksRect) {
        let r = Self.tankRadius
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
        let impulse = -(1 + 0.05) * relative / total
        tanks[a].velocity += normal * (impulse * inverseTank)
        obstacles[o].velocity -= normal * (impulse * inverseCrate)
    }

    // MARK: Test hooks

    mutating func debugSet(tank index: Int, _ change: (inout Tank) -> Void) {
        change(&tanks[index])
    }

    mutating func debugGrant(_ kind: HouseTanksPowerUp, to playerID: UUID) {
        powerUps.removeToken()
        powerUps.spawn(kind: kind, at: .zero)
        powerUps.collect(playerID: playerID)
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

    /// Fraction along the segment where it first enters the circle.
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
