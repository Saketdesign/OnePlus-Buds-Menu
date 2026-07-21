import Foundation

struct CachedCaseBattery: Equatable {
    let percentage: Int
    let timestamp: Date
}

final class BatteryCache {
    private let defaults: UserDefaults
    private let now: () -> Date
    private let maxAge: TimeInterval

    private let percentKey = "buds.caseBatteryPercent"
    private let timestampKey = "buds.caseBatteryTimestamp"

    init(
        defaults: UserDefaults = .standard,
        maxAge: TimeInterval = 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.maxAge = maxAge
        self.now = now
    }

    func store(casePercentage: Int) {
        guard (0...100).contains(casePercentage) else { return }
        defaults.set(casePercentage, forKey: percentKey)
        defaults.set(now(), forKey: timestampKey)
    }

    func currentCaseBattery() -> CachedCaseBattery? {
        guard
            let percentage = defaults.object(forKey: percentKey) as? Int,
            let timestamp = defaults.object(forKey: timestampKey) as? Date,
            (0...100).contains(percentage)
        else { return nil }

        let age = now().timeIntervalSince(timestamp)
        guard age >= 0, age <= maxAge else { return nil }
        return CachedCaseBattery(percentage: percentage, timestamp: timestamp)
    }
}
