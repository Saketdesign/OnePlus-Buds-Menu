import Foundation

enum NoiseControlMode: CaseIterable, Identifiable, Equatable {
    case noiseCancellation
    case transparency
    case off

    var id: Self { self }

    var title: String {
        switch self {
        case .noiseCancellation: "Noise Cancellation"
        case .transparency: "Transparency"
        case .off: "Off"
        }
    }

    var modeByte: UInt8 {
        switch self {
        case .noiseCancellation: 0x02
        case .transparency: 0x04
        case .off: 0x01
        }
    }
}

struct BudsBatteryStatus: Equatable {
    var left: Int?
    var right: Int?
    var `case`: Int?
    var lastUpdated: Date = Date()

    /// OnePlus Buds 4 capacity-weighted total. Callers should only present this
    /// value for that model; other models may use different cell capacities.
    var totalWeightedPercent: Int? {
        let leftCapacity = 58.0
        let rightCapacity = 58.0
        let caseCapacity = 440.0

        var chargedCapacity = 0.0
        var knownCapacity = 0.0

        if let left {
            chargedCapacity += Double(left) / 100 * leftCapacity
            knownCapacity += leftCapacity
        }
        if let right {
            chargedCapacity += Double(right) / 100 * rightCapacity
            knownCapacity += rightCapacity
        }
        if let `case` {
            chargedCapacity += Double(`case`) / 100 * caseCapacity
            knownCapacity += caseCapacity
        }

        guard knownCapacity > 0 else { return nil }
        return Int((chargedCapacity / knownCapacity * 100).rounded(.toNearestOrAwayFromZero))
    }
}

enum BudsConnectionPhase: Equatable {
    case disabled
    case waitingForBluetooth(String)
    case scanning
    case connecting
    case discovering
    case subscribing
    case registering
    case ready
    case failed(String)

    var statusText: String {
        switch self {
        case .disabled: "Disconnected"
        case .waitingForBluetooth(let message): message
        case .scanning: "Looking for earbuds…"
        case .connecting: "Connecting…"
        case .discovering: "Discovering controls…"
        case .subscribing: "Preparing notifications…"
        case .registering: "Preparing controls…"
        case .ready: "Connected"
        case .failed(let message): message
        }
    }

    var isBusy: Bool {
        switch self {
        case .scanning, .connecting, .discovering, .subscribing, .registering:
            true
        default:
            false
        }
    }
}

struct ReconnectPolicy {
    let maximumAttempts: Int
    let maximumDelay: TimeInterval

    init(maximumAttempts: Int = 5, maximumDelay: TimeInterval = 8) {
        self.maximumAttempts = maximumAttempts
        self.maximumDelay = maximumDelay
    }

    func delay(forAttempt attempt: Int) -> TimeInterval? {
        guard attempt >= 0, attempt < maximumAttempts else { return nil }
        return min(pow(2, Double(attempt)), maximumDelay)
    }
}
