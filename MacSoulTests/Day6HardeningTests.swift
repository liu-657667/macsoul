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
    private struct Fixture {
        let directory: URL
        var executable: URL { directory.appendingPathComponent("child") }
        var ready: URL { directory.appendingPathComponent("ready") }
    }
    private func fixture() throws -> Fixture {
        let value = Fixture(directory: FileManager.default.temporaryDirectory.appendingPathComponent("MacSoul-held-pipe-" + UUID().uuidString))
        try FileManager.default.createDirectory(at: value.directory, withIntermediateDirectories: false)
        try Data().write(to: value.ready)
        // Only the successfully forked, pipe-owning descendant announces readiness.
        // It exits naturally; the test never terminates a descendant or user PID.
        try """
        #!/usr/bin/perl
        $|=1;
        my $child = fork();
        defined($child) or die "fork failed";
        if ($child == 0) {
            print "ready\\n";
            if ($ARGV[0] ne 'app-server') {
                open(my $ready, '>', $ARGV[0]) or die "ready open failed";
                print $ready "ready";
                close($ready) or die "ready close failed";
            }
            sleep 3;
            exit 0;
        }
        exit 0;
        """.write(to: value.executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: value.executable.path)
        return value
    }
    private func watchReadiness(_ value: Fixture, expectation: XCTestExpectation) throws -> DispatchSourceFileSystemObject {
        let descriptor = open(value.ready.path, O_EVTONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileReadUnknown) }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .extend, queue: .global())
        source.setEventHandler { expectation.fulfill(); source.cancel() }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        return source
    }
    func testShellTimeoutDoesNotWaitForDescendantPipeEOF() async throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.directory) }
        let ready = expectation(description: "descendant owns inherited pipes")
        let watcher = try watchReadiness(value, expectation: ready); defer { watcher.cancel() }
        let finished = expectation(description: "bounded timeout completion")
        let start = ProcessInfo.processInfo.systemUptime
        let task = Task {
            do { _ = try await ShellRunner().run(.init(executableURL: value.executable, arguments: [value.ready.path], timeout: 1)); XCTFail("Expected timeout") }
            catch ShellRunnerError.timeout {} catch { XCTFail("\(error)") }
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
            finished.fulfill()
        }
        defer { task.cancel() }
        await fulfillment(of: [ready, finished], timeout: 4)
        XCTAssertEqual(try String(contentsOf: value.ready, encoding: .utf8), "ready")
    }
    func testShellCancellationDoesNotWaitForDescendantPipeEOF() async throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.directory) }
        let ready = expectation(description: "descendant owns inherited pipes")
        let watcher = try watchReadiness(value, expectation: ready); defer { watcher.cancel() }
        let finished = expectation(description: "bounded cancellation completion")
        let task = Task { try await ShellRunner().run(ShellCommand(executableURL: value.executable, arguments: [value.ready.path])) }
        defer { task.cancel() }
        await fulfillment(of: [ready], timeout: 2)
        // This is the precondition, not an elapsed-time guess or fixed startup delay.
        XCTAssertEqual(try String(contentsOf: value.ready, encoding: .utf8), "ready")
        let start = ProcessInfo.processInfo.systemUptime
        task.cancel()
        Task {
            do { _ = try await task.value; XCTFail("Expected cancellation") }
            catch ShellRunnerError.cancelled {} catch { XCTFail("\(error)") }
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 4)
    }
    func testCodexCloseDoesNotWaitForDescendantPipeEOF() async throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.directory) }
        // Native transport uses fixed app-server arguments; this fixture only needs stdout readiness.
        let transport = NativeCodexQuotaTransport(executable: value.executable)
        let ready = expectation(description: "descendant stdout readiness")
        let stream = try await transport.open()
        let reader = Task {
            var iterator = stream.makeAsyncIterator()
            let line = try await iterator.next()
            XCTAssertEqual(line, Data("ready".utf8))
            ready.fulfill()
        }
        defer { reader.cancel() }
        await fulfillment(of: [ready], timeout: 2)
        let finished = expectation(description: "bounded idempotent close")
        let start = ProcessInfo.processInfo.systemUptime
        Task {
            await transport.close(); await transport.close()
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 4)
    }
}
