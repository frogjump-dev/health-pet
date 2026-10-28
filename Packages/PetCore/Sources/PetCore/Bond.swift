import Foundation

/// Friendship level with the pet, earned by pats, daily treats and days together.
/// It never goes down and never depends on health data, so a bad week costs nothing.
public struct Bond: Codable, Sendable, Equatable {
    public var points: Int

    public init(points: Int = 0) {
        self.points = max(points, 0)
    }

    /// Total points needed to reach `level` (level 1 starts at 0, then 50, 150, 300, 500…).
    public static func points(toReach level: Int) -> Int {
        let n = max(level, 1)
        return 25 * (n - 1) * n
    }

    public var level: Int {
        var level = 1
        while points >= Self.points(toReach: level + 1) { level += 1 }
        return level
    }

    /// Points earned inside the current level and the size of that level, e.g. (200, 350).
    public var progress: (current: Int, needed: Int) {
        let start = Self.points(toReach: level)
        let end = Self.points(toReach: level + 1)
        return (points - start, end - start)
    }

    public mutating func add(_ amount: Int) {
        points += max(amount, 0)
    }
}
