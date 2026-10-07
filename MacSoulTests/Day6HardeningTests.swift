import XCTest
import ServiceManagement
@testable import MacSoul

@MainActor private final class FakeLoginItemManager: LoginItemManaging {
    var state: LoginItemState = .disabled
    var registrations = 0, removals = 0
    var next: LoginItemState = .enabled
    var fail = false
    func register() throws { registrations += 1; if fail { throw CocoaError(.featureUnsupported) }; state = next }
    func unregister() throws { removals += 1; if fail { throw CocoaError(.featureUnsupported) }; state = .disabled }
}
@MainActor final class LoginItemTests: XCTestCase {
    func testNativeStatusMappingAndConservativeNotFound() {
        XCTAssertEqual(LoginItemState.map(.notRegistered), .disabled)
        XCTAssertEqual(LoginItemState.map(.enabled), .enabled)
        XCTAssertEqual(LoginItemState.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(LoginItemState.map(.notFound), .unavailable)
    }
    func testInitAndRefreshNeverMutateSystem() {
        let fake = FakeLoginItemManager()
        let value = LoginItemController(manager: fake)
        value.refresh()
        XCTAssertEqual(fake.registrations, 0); XCTAssertEqual(fake.removals, 0)
    }
    func testExplicitEnableDisableUsesObservedSystemState() {
        let fake = FakeLoginItemManager()
        let controller = LoginItemController(manager: fake)
        controller.setEnabled(true); controller.setEnabled(true)
        XCTAssertEqual(fake.registrations, 1); XCTAssertEqual(controller.state, .enabled)
        controller.setEnabled(false)
        XCTAssertEqual(fake.removals, 1); XCTAssertEqual(controller.state, .disabled)
    }
    func testRequiresApprovalDoesNotRegisterRepeatedly() {
        let fake = FakeLoginItemManager(); fake.next = .requiresApproval
        let value = LoginItemController(manager: fake)
        value.setEnabled(true); value.refresh(); value.setEnabled(true)
        XCTAssertEqual(value.state, .requiresApproval); XCTAssertEqual(fake.registrations, 1)
        value.setEnabled(false); XCTAssertEqual(value.state, .disabled)
    }
    func testFailedMutationDoesNotOptimisticallyFabricateState() {
        let fake = FakeLoginItemManager(); fake.fail = true
        let value = LoginItemController(manager: fake)
        value.setEnabled(true)
        XCTAssertTrue(value.operationFailed); XCTAssertEqual(value.state, .disabled)
        fake.fail = false; value.setEnabled(true)
        XCTAssertFalse(value.operationFailed); XCTAssertEqual(value.state, .enabled)
    }
    func testUnavailableCannotMutateAndRefreshReflectsExternalChange() {
        let fake = FakeLoginItemManager(); fake.state = .unavailable
        let value = LoginItemController(manager: fake)
        value.setEnabled(true); XCTAssertEqual(fake.registrations, 0)
        fake.state = .enabled; value.refresh(); XCTAssertEqual(value.state, .enabled)
    }
    func testLoginItemStatusBothLanguages() {
        XCTAssertEqual(LoginItemState.requiresApproval.label(.chinese), "需要在系统设置中确认")
        XCTAssertEqual(LoginItemState.requiresApproval.label(.english), "Approval required in System Settings")
        XCTAssertEqual(LoginItemState.unavailable.label(.chinese), "不可用")
    }
}
final class AccessibilityPresentationTests: XCTestCase {
    func testMetricNumericUnknownAbsentAndAttentionMatchVisibleMeaning() {
        XCTAssertEqual(AccessibilityPresentation.metricValue(metric: .init(usedPercent: 0), language: .english), "0%")
        XCTAssertEqual(AccessibilityPresentation.metricValue(metric: .init(usedPercent: nil), language: .chinese), "不可用")
        XCTAssertEqual(AccessibilityPresentation.metricValue(metric: .init(usedPercent: nil), language: .english, override: "No battery"), "No battery")
        XCTAssertEqual(AccessibilityPresentation.metricValue(metric: .init(usedPercent: 8), language: .english, attention: "Low battery"), "8% · Low battery")
    }
    func testQuotaVoiceUsesRemainingNotUsedAndStaleStaysExplicit() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let value = try XCTUnwrap(QuotaWindow(usedPercent: 95, durationMinutes: 10080, resetsAt: nil))
        for (language, remaining) in [(MacSoulLanguage.english, "5% remaining"), (.chinese, "剩余 5%")] {
            let label = AccessibilityPresentation.quotaValue(window: .init(kind: .weekly, state: .fresh(value)), now: now, language: language, presentation: .summary)
            XCTAssertTrue(label.contains(remaining)); XCTAssertFalse(label.contains("95%"))
            let stale = AccessibilityPresentation.quotaValue(window: .init(kind: .weekly, state: .stale(value)), now: now, language: language, presentation: .summary)
            XCTAssertTrue(stale.contains(language.text("Stale"))); XCTAssertTrue(stale.contains(remaining))
        }
    }
    func testNonNumericQuotaVoiceNeverInventsRemaining() {
        for language in MacSoulLanguage.allCases {
            for state in [QuotaDisplayState.unreported, .requestFailed, .providerUnavailable] {
                let label = AccessibilityPresentation.quotaValue(window: .init(kind: .weekly, state: state), now: Date(), language: language, presentation: .summary)
                XCTAssertFalse(label.contains("%")); XCTAssertFalse(label.isEmpty)
            }
        }
    }
}
final class HeldPipeLifecycleTests: XCTestCase {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MacSoul-held-pipe-" + UUID().uuidString)
        // Test-owned short-lived descendant exits naturally; never kill scanned user PIDs.
        try """
        #!/usr/bin/perl
        $|=1;
        print "ready\\n";
        if (fork()==0) { sleep 3; exit 0; }
        exit 0;
        """.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
    func testShellTimeoutDoesNotWaitForDescendantPipeEOF() async throws {
        let url = try fixture(); defer { try? FileManager.default.removeItem(at: url) }
        let start = ProcessInfo.processInfo.systemUptime
        do { _ = try await ShellRunner().run(.init(executableURL: url, arguments: [], timeout: 0.5)); XCTFail() }
        catch ShellRunnerError.timeout {} catch { XCTFail("\(error)") }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
    }
    func testShellCancellationDoesNotWaitForDescendantPipeEOF() async throws {
        let url = try fixture(); defer { try? FileManager.default.removeItem(at: url) }
        let task = Task { try await ShellRunner().run(ShellCommand(executableURL: url, arguments: [])) }
        try await Task.sleep(nanoseconds: 300_000_000)
        let start = ProcessInfo.processInfo.systemUptime; task.cancel()
        do { _ = try await task.value; XCTFail() }
        catch ShellRunnerError.cancelled {} catch { XCTFail("\(error)") }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
    }
    func testCodexCloseDoesNotWaitForDescendantPipeEOF() async throws {
        let url = try fixture(); defer { try? FileManager.default.removeItem(at: url) }
        let transport = NativeCodexQuotaTransport(executable: url)
        let stream = try await transport.open(); var iterator = stream.makeAsyncIterator()
        let line = try await iterator.next(); XCTAssertNotNil(line)
        let start = ProcessInfo.processInfo.systemUptime
        await transport.close(); await transport.close()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
    }
}
