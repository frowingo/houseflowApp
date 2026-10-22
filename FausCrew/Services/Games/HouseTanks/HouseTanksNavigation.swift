import CoreGraphics
import Foundation

/// A small local grid is sufficient for three tanks; rebuilt from current crate/wreck bounds.
enum HouseTanksNavigation {
    static func waypoint(from start: CGPoint, to goal: CGPoint, arena: CGRect, obstacles: [CGRect]) -> CGPoint {
        let blocks = obstacles.map { $0.insetBy(dx: -14, dy: -14) }
        func isClear(from a: CGPoint, to b: CGPoint) -> Bool {
            !blocks.contains { rect in
                var entry: CGFloat = 0
                var exit: CGFloat = 1
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

        let step: CGFloat = 16
        let columns = Int(arena.width / step)
        let rows = Int(arena.height / step)
        guard columns > 0, rows > 0 else { return goal }
        func point(_ index: Int) -> CGPoint {
            CGPoint(x: arena.minX + (CGFloat(index % columns) + 0.5) * step,
                    y: arena.minY + (CGFloat(index / columns) + 0.5) * step)
        }
        let open = (0..<(columns * rows)).map { index in
            !blocks.contains { $0.contains(point(index)) }
        }
        func nearestCell(to position: CGPoint, requireClearPath: Bool = false) -> Int? {
            func distanceSquared(_ index: Int) -> CGFloat {
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
                let midpoint = CGPoint(x: (point(cell).x + point(next).x) / 2,
                                       y: (point(cell).y + point(next).y) / 2)
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
