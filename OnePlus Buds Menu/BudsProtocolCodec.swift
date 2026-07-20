import Foundation

struct BudsProtocolCodec {
    enum Event: Equatable {
        case noiseControlMode(NoiseControlMode)
        case noiseControlAcknowledged
        case battery(BudsBatteryStatus, isTelemetry: Bool)
    }

    static let hello = Data([
        0xAA, 0x07, 0x00, 0x00, 0x00, 0x01, 0x23, 0x00, 0x00, 0x12
    ])
    static let registration = Data([
        0xAA, 0x0C, 0x00, 0x00, 0x00, 0x85, 0x41, 0x05, 0x00, 0x00, 0xB5, 0x50, 0xA0, 0x69
    ])
    static let noiseControlQuery = Data([
        0xAA, 0x09, 0x00, 0x00, 0x04, 0x82, 0x44, 0x02, 0x00, 0x00, 0xF2
    ])
    static let batteryQuery = Data([
        0xAA, 0x07, 0x00, 0x00, 0x06, 0x01, 0x25, 0x00, 0x00
    ])

    static func noiseControlCommand(_ mode: NoiseControlMode) -> Data {
        Data([0xAA, 0x0A, 0x00, 0x00, 0x04, 0x04, 0x42, 0x03, 0x00, 0x01, 0x01, mode.modeByte])
    }

    static func decode(_ data: Data) -> [Event] {
        let bytes = [UInt8](data)
        guard hasValidEnvelope(bytes) else { return [] }

        var events: [Event] = []
        if let battery = batteryStatus(from: bytes) {
            events.append(.battery(battery, isTelemetry: false))
        } else if let battery = batteryTelemetryStatus(from: bytes) {
            events.append(.battery(battery, isTelemetry: true))
        }

        if let mode = reportedNoiseControlMode(from: bytes) {
            events.append(.noiseControlMode(mode))
        }

        if bytes.count >= 6, bytes[4] == 0x04, bytes[5] == 0x84 {
            events.append(.noiseControlAcknowledged)
        }
        return events
    }

    private static func hasValidEnvelope(_ bytes: [UInt8]) -> Bool {
        guard bytes.count >= 6, bytes[0] == 0xAA else { return false }
        // Known firmware families encode the payload length with either a two-
        // or three-byte framing overhead. Reject values that cannot describe
        // the received packet without assuming an undocumented checksum.
        let declaredLength = Int(bytes[1])
        return declaredLength + 2 == bytes.count || declaredLength + 3 == bytes.count
    }

    private static func reportedNoiseControlMode(from bytes: [UInt8]) -> NoiseControlMode? {
        guard bytes.count >= 12, bytes[4] == 0x04 else { return nil }
        guard [0x02, 0x82, 0x84].contains(bytes[5]) else { return nil }
        guard bytes[9] == 0x01, bytes[10] == 0x01 else { return nil }
        return NoiseControlMode.allCases.first { $0.modeByte == bytes[11] }
    }

    private static func batteryStatus(from bytes: [UInt8]) -> BudsBatteryStatus? {
        guard bytes.count >= 12 else { return nil }
        guard bytes[4] == 0x06, bytes[5] == 0x81, bytes[6] == 0x25 else { return nil }

        let pairCount = Int(bytes[10])
        let start = 11
        let requiredCount = start + pairCount * 2

        if (1...3).contains(pairCount), bytes.count >= requiredCount {
            var values: [UInt8: Int] = [:]
            var index = start
            for _ in 0..<pairCount {
                let identifier = bytes[index]
                let value = Int(bytes[index + 1])
                guard [0x01, 0x02, 0x03].contains(identifier), values[identifier] == nil else { return nil }
                guard (0...100).contains(value) else { return nil }
                values[identifier] = value
                index += 2
            }
            return status(from: values)
        }

        // Older firmware can return fixed-position fields.
        if bytes.count >= 16 {
            let left = Int(bytes[12])
            let right = Int(bytes[14])
            let casePercent = Int(bytes[15])
            guard [left, right, casePercent].allSatisfy({ (0...100).contains($0) }) else { return nil }
            return BudsBatteryStatus(
                left: left,
                right: right,
                case: availableCasePercent(casePercent, wasReported: true, left: left, right: right)
            )
        }

        if bytes.count >= 14 {
            let left = Int(bytes[12])
            let casePercent = Int(bytes[13])
            guard [left, casePercent].allSatisfy({ (0...100).contains($0) }) else { return nil }
            return BudsBatteryStatus(
                left: left,
                right: left,
                case: availableCasePercent(casePercent, wasReported: true, left: left, right: left)
            )
        }
        return nil
    }

    private static func batteryTelemetryStatus(from bytes: [UInt8]) -> BudsBatteryStatus? {
        guard bytes.count >= 13 else { return nil }
        guard bytes[4] == 0x04, bytes[5] == 0x02 else { return nil }
        guard bytes[7] == 0x08, bytes[8] == 0x00, bytes[9] == 0x01 else { return nil }

        let pairCount = Int(bytes[10])
        let start = 11
        guard (1...3).contains(pairCount), bytes.count >= start + pairCount * 2 else { return nil }

        var values: [UInt8: Int] = [:]
        var index = start
        for _ in 0..<pairCount {
            let identifier = bytes[index]
            let value = Int(bytes[index + 1])
            guard [0x01, 0x02, 0x03].contains(identifier), values[identifier] == nil else { return nil }
            guard (0...100).contains(value) else { return nil }
            values[identifier] = value
            index += 2
        }
        return status(from: values)
    }

    private static func status(from values: [UInt8: Int]) -> BudsBatteryStatus? {
        let left = values[0x01]
        let right = values[0x02]
        let reportedCase = values[0x03]
        guard left != nil || right != nil || reportedCase != nil else { return nil }
        let casePercent = availableCasePercent(
            reportedCase,
            wasReported: reportedCase != nil,
            left: left,
            right: right
        )
        return BudsBatteryStatus(left: left, right: right, case: casePercent)
    }

    private static func availableCasePercent(
        _ casePercent: Int?,
        wasReported: Bool,
        left: Int?,
        right: Int?
    ) -> Int? {
        if wasReported, casePercent == 0, (left ?? 0) > 5 || (right ?? 0) > 5 {
            return nil
        }
        return casePercent
    }
}

