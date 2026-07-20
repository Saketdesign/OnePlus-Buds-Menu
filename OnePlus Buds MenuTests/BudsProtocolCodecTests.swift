import XCTest
@testable import OnePlus_Buds_Menu

final class BudsProtocolCodecTests: XCTestCase {
    func testDecodesCapturedHelloAcknowledgement() {
        let packet = Data([
            0xAA, 0x10, 0x00, 0x00, 0x00, 0x81, 0x23, 0x09, 0x00,
            0x00, 0xFF, 0x77, 0x5A, 0xEA, 0x67, 0x0E, 0x20, 0x07
        ])
        XCTAssertEqual(BudsProtocolCodec.decode(packet), [.helloAcknowledged])
    }

    func testNoiseControlCommandEncoding() {
        XCTAssertEqual(
            BudsProtocolCodec.noiseControlCommand(.transparency),
            Data([0xAA, 0x0A, 0x00, 0x00, 0x04, 0x04, 0x42, 0x03, 0x00, 0x01, 0x01, 0x04])
        )
    }

    func testDecodesNoiseControlMode() {
        let packet = Data([0xAA, 0x09, 0x00, 0x00, 0x04, 0x82, 0x44, 0x02, 0x00, 0x01, 0x01, 0x02])
        XCTAssertEqual(BudsProtocolCodec.decode(packet), [.noiseControlMode(.noiseCancellation)])
    }

    func testDecodesBatteryPairTable() throws {
        let packet = Data([
            0xAA, 0x0E, 0x00, 0x00, 0x06, 0x81, 0x25, 0x00, 0x00, 0x00, 0x03,
            0x01, 80, 0x02, 60, 0x03, 50
        ])
        let event = try XCTUnwrap(BudsProtocolCodec.decode(packet).first)
        guard case .battery(let status, let isTelemetry) = event else {
            return XCTFail("Expected a battery event")
        }
        XCTAssertEqual(status.left, 80)
        XCTAssertEqual(status.right, 60)
        XCTAssertEqual(status.case, 50)
        XCTAssertFalse(isTelemetry)
    }

    func testRejectsDuplicateBatteryIdentifiers() {
        let packet = Data([
            0xAA, 0x0C, 0x00, 0x00, 0x06, 0x81, 0x25, 0x00, 0x00, 0x00, 0x02,
            0x01, 80, 0x01, 60
        ])
        XCTAssertTrue(BudsProtocolCodec.decode(packet).isEmpty)
    }

    func testRejectsInvalidEnvelopeAndPercentage() {
        XCTAssertTrue(BudsProtocolCodec.decode(Data([0x00, 0x04, 0, 0, 0, 0])).isEmpty)

        let invalidPercentage = Data([
            0xAA, 0x0A, 0x00, 0x00, 0x06, 0x81, 0x25, 0x00, 0x00, 0x00, 0x01,
            0x01, 101
        ])
        XCTAssertTrue(BudsProtocolCodec.decode(invalidPercentage).isEmpty)
    }

    func testCaseZeroIsUnavailableWhenChargedBudIsPresent() throws {
        let packet = Data([
            0xAA, 0x0C, 0x00, 0x00, 0x06, 0x81, 0x25, 0x00, 0x00, 0x00, 0x02,
            0x01, 75, 0x03, 0
        ])
        let event = try XCTUnwrap(BudsProtocolCodec.decode(packet).first)
        guard case .battery(let status, _) = event else {
            return XCTFail("Expected a battery event")
        }
        XCTAssertNil(status.case)
    }
}
