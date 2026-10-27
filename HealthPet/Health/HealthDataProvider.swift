import Foundation
import PetCore

/// A source adapter: reads one vendor's data and returns canonical daily snapshots.
/// Add Health Connect / Oura / Garmin later by adding another conformer.
protocol HealthDataProvider: Sendable {
    var source: DataSource { get }
    func requestAuthorization() async throws
    /// One snapshot per calendar day in `start...end` (days without data may be omitted).
    func snapshots(from start: Date, to end: Date) async throws -> [HealthSnapshot]
}
