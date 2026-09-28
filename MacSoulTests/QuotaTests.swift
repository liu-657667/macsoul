import XCTest
@testable import MacSoul

final class QuotaTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func testIndependentMissingWindowAndStableIdentity() {
        let item = MockProvider(fixture: .missingWindow).snapshot(now: now).quotas[0]
        XCTAssertEqual(item.id, QuotaProvider.codex.id)
        XCTAssertNil(item.fiveHour)
        XCTAssertEqual(item.weekly?.usedPercent, 31)
    }
    func testCpuTextAndProgressShareValue() {
        let cpu = MockProvider(fixture: .cpuRecovery).snapshot(now: now).cpu
        XCTAssertEqual(cpu.label, "20%")
        XCTAssertEqual(cpu.progress, 0.20)
    }
    func testStaleAndResetExpiryDoNotClearUsage() {
        let item = MockProvider(fixture: .healthy).snapshot(now: now).quotas[0]
        XCTAssertEqual(item.effectiveFreshness(now: now.addingTimeInterval(9000)), .stale)
        XCTAssertEqual(item.fiveHour?.usedPercent, 62)
    }
    func testAllRequiredFixtures() {
        for fixture in MockProvider.Fixture.allCases {
            let snapshot = MockProvider(fixture: fixture).snapshot(now: now)
            XCTAssertEqual(snapshot.quotas.count, 2)
        }
        XCTAssertNil(MockProvider(fixture: .noBattery).snapshot(now: now).battery.progress)
    }
    @MainActor func testStoreUsesInjectedProvider() {
        let store = AppStore(provider: MockProvider(fixture: .cpuRecovery), now: now)
        XCTAssertEqual(store.snapshot.cpu.label, "20%")
        XCTAssertEqual(store.snapshot.mode, .mock)
        let unavailable = UnavailableProvider().snapshot(now: now)
        XCTAssertEqual(unavailable.mode, .live)
        XCTAssertNil(unavailable.quotas[0].fiveHour)
        XCTAssertEqual(unavailable.quotas[0].freshness, .unavailable)
    }
    func testInvalidPercentIsUnavailable() {
        XCTAssertNil(QuotaWindow(usedPercent: .nan, durationMinutes: 300, resetsAt: nil))
        XCTAssertNil(QuotaWindow(usedPercent: 101, durationMinutes: 300, resetsAt: nil))
    }
}
