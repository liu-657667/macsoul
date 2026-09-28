import XCTest
import AppKit
@testable import MacSoul

final class QuotaTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func testWeeklyOnlyAndUnreportedAreDistinctForBothProviders() {
        let codex = MockProvider(fixture: .codexWeeklyOnly).snapshot(now: now).quotas[0]
        XCTAssertEqual(codex.id, QuotaProvider.codex.id)
        XCTAssertEqual(codex.displayWindows(now: now).map(\.kind), [.weekly])
        XCTAssertEqual(codex.notApplicableLabels(), ["5h"])

        let unknown = MockProvider(fixture: .codexUnreported).snapshot(now: now).quotas[0]
        XCTAssertEqual(unknown.displayWindows(now: now).map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(unknown.displayWindows(now: now)[0].state, .unreported)
        XCTAssertNil(unknown.displayWindows(now: now)[0].state.value)

        let claude = MockProvider(fixture: .claudeWeeklyOnly).snapshot(now: now).quotas[1]
        XCTAssertEqual(claude.displayWindows(now: now).map(\.kind), [.weekly])
        XCTAssertEqual(MockProvider(fixture: .claudeUnreported).snapshot(now: now).quotas[1]
            .displayWindows(now: now)[1].state, .unreported)
    }
    func testCpuTextAndProgressShareValue() {
        let cpu = MockProvider(fixture: .cpuRecovery).snapshot(now: now).cpu
        XCTAssertEqual(cpu.label, "20%")
        XCTAssertEqual(cpu.progress, 0.20)
    }
    func testStaleDataKeepsLastUsageAndSuppressesAlerts() {
        let item = MockProvider(fixture: .staleOffline).snapshot(now: now).quotas[0]
        guard case .stale(let value) = item.displayWindows(now: now)[0].state else {
            XCTFail("Expected stale 5h value")
            return
        }
        XCTAssertEqual(value.usedPercent, 62)
        XCTAssertTrue(item.alertEligibleWindows(now: now).isEmpty)
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
        XCTAssertEqual(unavailable.quotas[0].fiveHour, .providerUnavailable)
        XCTAssertEqual(unavailable.quotas[0].freshness, .unavailable)
    }
    func testInvalidPercentIsUnavailable() {
        XCTAssertNil(QuotaWindow(usedPercent: .nan, durationMinutes: 300, resetsAt: nil))
        XCTAssertNil(QuotaWindow(usedPercent: 101, durationMinutes: 300, resetsAt: nil))
    }
    func testSoulFixturesHaveDistinctBundledArtwork() {
        let expected: [(MockProvider.Fixture, SoulVisual)] = [
            (.healthy, .normal), (.busy, .busy), (.cpuCritical, .overload),
            (.memoryPressure, .bloated), (.lowBattery, .lowBattery), (.sleeping, .sleeping)
        ]
        for (fixture, visual) in expected {
            XCTAssertEqual(MockProvider(fixture: fixture).snapshot(now: now).soulVisual, visual)
            XCTAssertNotNil(NSImage(named: NSImage.Name(visual.assetName)), visual.assetName)
        }
        XCTAssertEqual(MockProvider(fixture: .memoryPressure).snapshot(now: now).memoryPressure, "Critical · Mock")
        XCTAssertEqual(MockProvider(fixture: .lowBattery).snapshot(now: now).battery.label, "4%")
    }
    func testMenuBarDraftAssetLoadsAsTemplate() {
        let image = NSImage(named: NSImage.Name("MacSoulMenuTemplateDraft"))
        XCTAssertNotNil(image)
        XCTAssertTrue(image?.isTemplate == true)
    }
    @MainActor func testPreviewFixtureReplacesSharedMockSnapshot() {
        let store = AppStore(now: now)
        store.selectPreviewFixture(.codexWeeklyOnly, now: now)
        XCTAssertEqual(store.previewFixture, .codexWeeklyOnly)
        XCTAssertEqual(store.snapshot.quotas.count, 2)
        XCTAssertEqual(store.snapshot.quotas[0].displayWindows(now: now).map(\.kind), [.weekly])
    }
    func testValidZeroAndRequestFailureAreNotMissingOrUnlimited() {
        let zero = MockProvider(fixture: .zeroUsage).snapshot(now: now)
        XCTAssertEqual(zero.quotas[0].displayWindows(now: now)[0].state.value?.usedPercent, 0)
        XCTAssertEqual(zero.quotas[1].displayWindows(now: now)[1].state.value?.usedPercent, 0)
        XCTAssertTrue(zero.quotas[0].alertEligibleWindows(now: now).isEmpty)

        for quota in MockProvider(fixture: .requestFailed).snapshot(now: now).quotas {
            XCTAssertEqual(quota.displayWindows(now: now).map(\.state), [.requestFailed, .requestFailed])
            XCTAssertTrue(quota.alertEligibleWindows(now: now).isEmpty)
        }
    }
    func testAlertsRequireFreshApplicableWindowForBothProviders() {
        let quotas = MockProvider(fixture: .quota95).snapshot(now: now).quotas
        XCTAssertEqual(quotas[0].alertEligibleWindows(now: now), [.fiveHour])
        XCTAssertEqual(quotas[1].alertEligibleWindows(now: now), [.weekly])
        let stale = MockProvider(fixture: .staleOffline).snapshot(now: now).quotas
        XCTAssertTrue(stale.allSatisfy { $0.alertEligibleWindows(now: now).isEmpty })
        let weekOnly = MockProvider(fixture: .codexWeeklyOnly).snapshot(now: now).quotas[0]
        XCTAssertFalse(weekOnly.alertEligibleWindows(now: now).contains(.fiveHour))
    }
    func testResetExpiryStalesOnlyThatWindowWithoutZeroingIt() {
        let fiveHour = QuotaWindow(usedPercent: 96, durationMinutes: 300, resetsAt: now.addingTimeInterval(30))!
        let weekly = QuotaWindow(usedPercent: 31, durationMinutes: 10080, resetsAt: now.addingTimeInterval(1000))!
        let item = QuotaItem(provider: .codex, fiveHour: .available(fiveHour), weekly: .available(weekly),
            sampledAt: now, source: "Test fixture", freshness: .fresh, mode: .mock)
        let states = item.displayWindows(now: now.addingTimeInterval(31))
        XCTAssertEqual(states[0].state, .stale(fiveHour))
        XCTAssertEqual(states[0].state.value?.usedPercent, 96)
        XCTAssertEqual(states[1].state, .fresh(weekly))
        XCTAssertTrue(item.alertEligibleWindows(now: now.addingTimeInterval(31)).isEmpty)
    }
}
