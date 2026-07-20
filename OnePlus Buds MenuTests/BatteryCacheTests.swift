import XCTest
@testable import OnePlus_Buds_Menu

final class BatteryCacheTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "OnePlusBudsMenu.BatteryCacheTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testReturnsFreshCachedCaseBattery() throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let cache = BatteryCache(defaults: defaults, maxAge: 60, now: { now })
        cache.store(casePercentage: 67)

        XCTAssertEqual(try XCTUnwrap(cache.currentCaseBattery()).percentage, 67)
    }

    func testRejectsStaleCachedCaseBattery() {
        var now = Date(timeIntervalSince1970: 10_000)
        let cache = BatteryCache(defaults: defaults, maxAge: 60, now: { now })
        cache.store(casePercentage: 67)
        now = now.addingTimeInterval(61)

        XCTAssertNil(cache.currentCaseBattery())
    }

    func testRejectsFutureTimestamp() {
        var now = Date(timeIntervalSince1970: 10_000)
        let cache = BatteryCache(defaults: defaults, maxAge: 60, now: { now })
        cache.store(casePercentage: 67)
        now = now.addingTimeInterval(-1)

        XCTAssertNil(cache.currentCaseBattery())
    }

    func testDoesNotStoreInvalidPercentage() {
        let cache = BatteryCache(defaults: defaults)
        cache.store(casePercentage: 101)
        XCTAssertNil(cache.currentCaseBattery())
    }
}
