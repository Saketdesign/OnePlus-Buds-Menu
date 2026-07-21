import XCTest
@testable import OnePlus_Buds_Menu

final class BatteryStatusTests: XCTestCase {
    func testWeightedTotalWithAllComponentsFull() {
        let status = BudsBatteryStatus(left: 100, right: 100, case: 100)
        XCTAssertEqual(status.totalWeightedPercent, 100)
    }

    func testWeightedTotalExcludesUnknownComponents() {
        let status = BudsBatteryStatus(left: 100, right: 0, case: nil)
        XCTAssertEqual(status.totalWeightedPercent, 50)
    }

    func testWeightedTotalIsNilWhenNoValuesAreKnown() {
        XCTAssertNil(BudsBatteryStatus(left: nil, right: nil, case: nil).totalWeightedPercent)
    }

    func testReconnectPolicyIsBounded() {
        let policy = ReconnectPolicy(maximumAttempts: 5, maximumDelay: 8)
        XCTAssertEqual((0...4).compactMap(policy.delay), [1, 2, 4, 8, 8])
        XCTAssertNil(policy.delay(forAttempt: 5))
        XCTAssertNil(policy.delay(forAttempt: -1))
    }

    func testConnectionPhaseMessagesAreActionable() {
        XCTAssertEqual(
            BudsConnectionPhase.waitingForBluetooth("Bluetooth is turned off").statusText,
            "Bluetooth is turned off"
        )
        XCTAssertEqual(
            BudsConnectionPhase.failed("No compatible earbuds were found").statusText,
            "No compatible earbuds were found"
        )
        XCTAssertTrue(BudsConnectionPhase.connecting.isBusy)
        XCTAssertFalse(BudsConnectionPhase.ready.isBusy)
    }
}
