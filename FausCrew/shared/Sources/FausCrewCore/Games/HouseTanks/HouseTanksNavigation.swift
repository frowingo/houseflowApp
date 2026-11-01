import Foundation

/// A small local grid is sufficient for four tanks; rebuilt from current crate/wreck bounds.
public enum HouseTanksNavigation {
    /// `padding` keeps a tank's body clear of cover; `step` is the grid size. Both shrink on
    /// crowded-match maps, where tanks and gaps are smaller.
    public static func waypoint(from start: HouseTanksVector, to goal: HouseTanksVector,
                                arena: HouseTanksRect, obstacles: [HouseTanksRect],
                                padding: Double = 14, step: Double = 16) -> HouseTanksVector {
        let blocks = obstacles.map { $0.insetBy(dx: -padding, dy: -padding) }
        func isClear(from a: HouseTanksVector, to b: HouseTanksVector) -> Bool {
            !blocks.contains { rect in
                var entry = 0.0
                var exit = 1.0
                for (origin, delta, low, high) in [
                    (a.x, b.x - a.x, rect.minX, rect.maxX),
                    (a.y, b.y - a.y, rect.minY, rect.maxY),
                ] {
                    if abs(delta) < 0.0001 {
                        if origin < low || origin > high { return false }
                    } else {
                        let first = (low - origin) / delta
                        let second = (high - origin) / delta
                        entry = max(entry, min(first, second))
                        exit = min(exit, max(first, second))
                        if entry > exit { return false }
                    }
                }
                return true
            }
        }
        if isClear(from: start, to: goal) { return goal }

        let columns = Int(arena.width / step)
        let rows = Int(arena.height / step)
        guard columns > 0, rows > 0 else { return goal }
        func point(_ index: Int) -> HouseTanksVector {
            HouseTanksVector(x: arena.minX + (Double(index % columns) + 0.5) * step,
                             y: arena.minY + (Double(index / columns) + 0.5) * step)
        }
        let open = (0..<(columns * rows)).map { index in
            !blocks.contains { $0.contains(point(index)) }
        }
        func nearestCell(to position: HouseTanksVector, requireClearPath: Bool = false) -> Int? {
            func distanceSquared(_ index: Int) -> Double {
                let p = point(index)
                return (p.x - position.x) * (p.x - position.x) + (p.y - position.y) * (p.y - position.y)
            }
            let candidates = open.indices.filter { open[$0] }
            guard let nearest = candidates.min(by: { distanceSquared($0) < distanceSquared($1) }) else { return nil }
            if !requireClearPath || isClear(from: position, to: point(nearest)) { return nearest }
            return candidates.sorted { distanceSquared($0) < distanceSquared($1) }
                .first { isClear(from: position, to: point($0)) }
        }
        guard let first = nearestCell(to: start, requireClearPath: true),
              let last = nearestCell(to: goal) else { return goal }
        var previous = [Int](repeating: -1, count: open.count)
        previous[first] = first
        var queue = [first]
        var cursor = 0
        while cursor < queue.count, previous[last] == -1 {
            let cell = queue[cursor]
            cursor += 1
            for next in [cell - 1, cell + 1, cell - columns, cell + columns] {
                guard open.indices.contains(next), open[next], previous[next] == -1,
                      abs(next % columns - cell % columns) <= 1 else { continue }
                // Avoid crossing a thin wall that lies between two open grid centers.
                let midpoint = (point(cell) + point(next)) * 0.5
                guard !blocks.contains(where: { $0.contains(midpoint) }) else { continue }
                previous[next] = cell
                queue.append(next)
            }
        }
        guard previous[last] != -1 else { return goal } // A crate may need to be shot open.
        var next = last
        while previous[next] != first, next != first { next = previous[next] }
        // A tank between cells must first reach the anchor if the shortcut cuts a corner.
        return isClear(from: start, to: point(next)) ? point(next) : point(first)
    }
}
