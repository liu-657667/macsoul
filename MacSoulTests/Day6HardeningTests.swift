import XCTest
import ServiceManagement
@testable import MacSoul

@MainActor private final class FakeLoginItemManager: LoginItemManaging {
    var state: LoginItemState = .disabled
    var eligibility: LoginItemEligibility = .eligible
    var registrations = 0, removals = 0
    var next: LoginItemState = .enabled
    var nextAfterUnregister: LoginItemState = .disabled
    var error: Error?
    var stateAfterFailure: LoginItemState?
    private func failIfNeeded() throws {
        if let error {
            if let stateAfterFailure { state = stateAfterFailure }
            throw error
        }
    }
    func register() throws { registrations += 1; try failIfNeeded(); state = next }
    func unregister() throws { removals += 1; try failIfNeeded(); state = nextAfterUnregister }
}
@MainActor final class LoginItemTests: XCTestCase {
    func testNativeStatusMappingAndConservativeNotFound() {
        XCTAssertEqual(LoginItemState.map(.notRegistered), .disabled)
        XCTAssertEqual(LoginItemState.map(.enabled), .enabled)
        XCTAssertEqual(LoginItemState.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(LoginItemState.map(.notFound), .serviceNotFound)
    }
    func testInitAndRefreshNeverMutateSystem() {
        for state in LoginItemState.allCases {
            for eligibility in LoginItemEligibility.allCases {
                let fake = FakeLoginItemManager(); fake.state = state; fake.eligibility = eligibility
                let value = LoginItemController(manager: fake)
                value.refresh(); value.refresh()
                XCTAssertEqual(value.state, state); XCTAssertEqual(value.eligibility, eligibility)
                XCTAssertEqual(fake.registrations, 0); XCTAssertEqual(fake.removals, 0)
            }
        }
    }
    func testExplicitEnableDisableUsesObservedSystemState() {
        let fake = FakeLoginItemManager()
        let controller = LoginItemController(manager: fake)
        controller.setEnabled(true); controller.setEnabled(true)
        XCTAssertEqual(fake.registrations, 1); XCTAssertEqual(controller.state, .enabled)
        controller.setEnabled(false); controller.setEnabled(false)
        XCTAssertEqual(fake.removals, 1); XCTAssertEqual(controller.state, .disabled)
    }
    func testRequiresApprovalDoesNotRegisterRepeatedly() {
        let fake = FakeLoginItemManager(); fake.next = .requiresApproval
        let value = LoginItemController(manager: fake)
        value.setEnabled(true); value.refresh(); value.setEnabled(true)
        XCTAssertEqual(value.state, .requiresApproval); XCTAssertEqual(fake.registrations, 1)
        XCTAssertTrue(value.state.isRegistered); XCTAssertNotEqual(value.state, .enabled)
        value.setEnabled(false); XCTAssertEqual(value.state, .disabled); XCTAssertEqual(fake.removals, 1)
    }
    func testFailedMutationDoesNotOptimisticallyFabricateState() {
        let fake = FakeLoginItemManager(); fake.error = CocoaError(.featureUnsupported)
        let value = LoginItemController(manager: fake)
        value.setEnabled(true)
        XCTAssertEqual(value.operationError, .unknownFailure); XCTAssertEqual(value.state, .disabled)
        fake.error = nil; value.setEnabled(true)
        XCTAssertNil(value.operationError); XCTAssertEqual(value.state, .enabled)
    }
    func testServiceNotFoundCannotMutateAndRefreshReflectsExternalChange() {
        let fake = FakeLoginItemManager(); fake.state = .serviceNotFound
        let value = LoginItemController(manager: fake)
        value.setEnabled(true); XCTAssertEqual(fake.registrations, 0)
        fake.state = .enabled; value.refresh(); XCTAssertEqual(value.state, .enabled)
    }
    func testLoginItemStatusBothLanguages() {
        XCTAssertEqual(LoginItemState.requiresApproval.label(.chinese), "需要在系统设置中确认")
        XCTAssertEqual(LoginItemState.requiresApproval.label(.english), "Approval required in System Settings")
        XCTAssertEqual(LoginItemState.serviceNotFound.label(.chinese), "未找到登录服务")
        XCTAssertEqual(LoginItemState.serviceNotFound.label(.english), "Login service not found")
        XCTAssertEqual(LoginItemState.disabled.label(.chinese), "未注册")
        XCTAssertEqual(LoginItemState.disabled.label(.english), "Not registered")
        XCTAssertEqual(LoginItemState.enabled.label(.chinese), "已启用")
        XCTAssertEqual(LoginItemState.enabled.label(.english), "Enabled")
        XCTAssertEqual(LoginItemState.unknown.label(.chinese), "未知登录项状态")
        XCTAssertEqual(LoginItemState.unknown.label(.english), "Unknown login-item status")
    }
    func testFutureNativeStatusFailsClosed() throws {
        let status = try XCTUnwrap(SMAppService.Status(rawValue: Int.max))
        XCTAssertEqual(LoginItemState.map(status), .unknown)
        let fake = FakeLoginItemManager(); fake.state = .unknown
        let value = LoginItemController(manager: fake)
        XCTAssertFalse(value.canChangeRegistration)
        value.setEnabled(true); value.setEnabled(false)
        XCTAssertEqual(fake.registrations, 0); XCTAssertEqual(fake.removals, 0)
    }
    func testServiceNotFoundIsNotOrdinaryDisabled() {
        XCTAssertNotEqual(LoginItemState.serviceNotFound, .disabled)
        let fake = FakeLoginItemManager(); fake.state = .serviceNotFound
        let value = LoginItemController(manager: fake)
        XCTAssertFalse(value.state.isRegistered); XCTAssertFalse(value.canChangeRegistration)
        value.setEnabled(true); value.setEnabled(false)
        XCTAssertEqual(fake.registrations, 0); XCTAssertEqual(fake.removals, 0)
        fake.state = .disabled; value.refresh()
        XCTAssertTrue(value.canChangeRegistration)
        value.setEnabled(true); XCTAssertEqual(fake.registrations, 1)
    }
    func testUnverifiedOrIneligibleEnvironmentNeverMutatesAnyState() {
        for eligibility in [LoginItemEligibility.unknown, .ineligible] {
            for state in LoginItemState.allCases {
                let fake = FakeLoginItemManager(); fake.state = state; fake.eligibility = eligibility
                let value = LoginItemController(manager: fake)
                value.setEnabled(true); value.setEnabled(false); value.refresh()
                XCTAssertFalse(value.canChangeRegistration)
                XCTAssertEqual(value.state, state)
                XCTAssertEqual(fake.registrations, 0); XCTAssertEqual(fake.removals, 0)
            }
        }
    }
    func testActionRechecksEnvironmentAndNativeState() {
        let fake = FakeLoginItemManager()
        let value = LoginItemController(manager: fake)
        XCTAssertTrue(value.canChangeRegistration)
        fake.eligibility = .unknown
        value.setEnabled(true); XCTAssertEqual(fake.registrations, 0)
        XCTAssertEqual(value.eligibility, .unknown)
        fake.eligibility = .eligible; fake.state = .unknown
        value.setEnabled(true); XCTAssertEqual(fake.registrations, 0)
        XCTAssertEqual(value.state, .unknown)
    }
    func testUnregisterFailurePreservesObservedRegisteredState() {
        let fake = FakeLoginItemManager(); fake.state = .enabled; fake.error = CocoaError(.featureUnsupported)
        let value = LoginItemController(manager: fake)
        value.setEnabled(false)
        XCTAssertEqual(fake.removals, 1); XCTAssertEqual(fake.registrations, 0)
        XCTAssertEqual(value.state, .enabled); XCTAssertEqual(value.operationError, .unregisterFailed)
        value.refresh(); XCTAssertEqual(value.operationError, .unregisterFailed)
        fake.error = nil; value.setEnabled(false)
        XCTAssertEqual(fake.removals, 2); XCTAssertEqual(value.state, .disabled)
        XCTAssertNil(value.operationError)
    }
    func testSuccessfulRegisterDoesNotInventEnabledState() {
        for observed in [LoginItemState.disabled, .requiresApproval, .serviceNotFound, .unknown] {
            let fake = FakeLoginItemManager(); fake.next = observed
            let value = LoginItemController(manager: fake)
            value.setEnabled(true)
            XCTAssertEqual(fake.registrations, 1)
            XCTAssertEqual(value.state, observed); XCTAssertNotEqual(value.state, .enabled)
            XCTAssertNil(value.operationError)
        }
    }
    func testSuccessfulUnregisterDoesNotInventDisabledState() {
        for observed in [LoginItemState.enabled, .requiresApproval, .serviceNotFound, .unknown] {
            let fake = FakeLoginItemManager(); fake.state = .enabled; fake.nextAfterUnregister = observed
            let value = LoginItemController(manager: fake)
            value.setEnabled(false)
            XCTAssertEqual(fake.removals, 1)
            XCTAssertEqual(value.state, observed); XCTAssertNotEqual(value.state, .disabled)
            XCTAssertNil(value.operationError)
        }
    }
    func testFailedRegisterObservesChangedStateAndRetainsFailureUntilExternalChange() {
        let fake = FakeLoginItemManager(); fake.error = CocoaError(.featureUnsupported)
        fake.stateAfterFailure = .requiresApproval
        let value = LoginItemController(manager: fake)
        value.setEnabled(true)
        XCTAssertEqual(fake.registrations, 1); XCTAssertEqual(value.state, .requiresApproval)
        XCTAssertEqual(value.operationError, .unknownFailure)
        value.refresh(); XCTAssertEqual(value.operationError, .unknownFailure)
        value.setEnabled(true); XCTAssertEqual(fake.registrations, 1)
        XCTAssertEqual(value.operationError, .unknownFailure)
        fake.state = .enabled; value.refresh()
        XCTAssertEqual(value.state, .enabled); XCTAssertNil(value.operationError)
    }
    func testFailedUnregisterObservesChangedStateWithoutHidingFailure() {
        let fake = FakeLoginItemManager(); fake.state = .enabled
        fake.error = CocoaError(.featureUnsupported); fake.stateAfterFailure = .disabled
        let value = LoginItemController(manager: fake)
        value.setEnabled(false)
        XCTAssertEqual(fake.removals, 1); XCTAssertEqual(value.state, .disabled)
        XCTAssertEqual(value.operationError, .unregisterFailed)
        value.refresh(); value.setEnabled(false)
        XCTAssertEqual(fake.removals, 1); XCTAssertEqual(value.operationError, .unregisterFailed)
        fake.state = .serviceNotFound; value.refresh()
        XCTAssertEqual(value.state, .serviceNotFound); XCTAssertNil(value.operationError)
    }
    func testUnchangedRefreshPreservesFailureButExternalStateChangeClearsIt() {
        let fake = FakeLoginItemManager(); fake.error = CocoaError(.featureUnsupported)
        let value = LoginItemController(manager: fake)
        value.setEnabled(true); value.refresh(); value.refresh()
        XCTAssertEqual(value.operationError, .unknownFailure)
        fake.state = .serviceNotFound; value.refresh()
        XCTAssertNil(value.operationError); XCTAssertEqual(value.state, .serviceNotFound)
    }
    func testServiceManagementErrorsUseOfficialConstantsAndDomains() {
        var domains = [kSMErrorDomainFramework as String]
        if #available(macOS 15.0, *) { domains.append(SMAppServiceErrorDomain) }
        let cases: [(Int, LoginItemOperationError)] = [
            (kSMErrorInvalidSignature, .invalidSignature),
            (kSMErrorLaunchDeniedByUser, .approvalDenied),
            (kSMErrorAlreadyRegistered, .alreadyRegistered),
            (kSMErrorJobNotFound, .serviceNotFound)
        ]
        for domain in domains {
            for (code, expected) in cases {
                let error = NSError(domain: domain, code: code)
                for unregistering in [false, true] {
                    XCTAssertEqual(LoginItemOperationError.classify(error, unregistering: unregistering), expected)
                }
            }
        }
    }
    func testForeignDomainsAndUnrecognizedCodesRemainGeneric() {
        for code in [kSMErrorInvalidSignature, kSMErrorLaunchDeniedByUser, kSMErrorAlreadyRegistered, kSMErrorJobNotFound] {
            let error = NSError(domain: NSCocoaErrorDomain, code: code,
                                userInfo: [NSLocalizedDescriptionKey: "SENSITIVE-MOCK-PATH-DO-NOT-DISPLAY"])
            XCTAssertEqual(LoginItemOperationError.classify(error, unregistering: false), .unknownFailure)
            XCTAssertEqual(LoginItemOperationError.classify(error, unregistering: true), .unregisterFailed)
        }
        let unknown = NSError(domain: kSMErrorDomainFramework as String, code: Int.max)
        XCTAssertEqual(LoginItemOperationError.classify(unknown, unregistering: false), .unknownFailure)
        XCTAssertEqual(LoginItemOperationError.classify(unknown, unregistering: true), .unregisterFailed)
    }
    func testRecoveryAndErrorCopyIsLocalizedAndDoesNotInventEnvironmentCause() {
        for state in LoginItemState.allCases {
            XCTAssertFalse(state.explanation(.english).isEmpty); XCTAssertFalse(state.explanation(.chinese).isEmpty)
            XCTAssertNotEqual(state.explanation(.english), state.explanation(.chinese))
        }
        XCTAssertTrue(LoginItemState.serviceNotFound.explanation(.english).contains("cause has not been confirmed"))
        XCTAssertTrue(LoginItemState.serviceNotFound.explanation(.chinese).contains("原因尚未确认"))
        for eligibility in LoginItemEligibility.allCases {
            XCTAssertFalse(eligibility.explanation(.english).isEmpty)
            XCTAssertFalse(eligibility.explanation(.chinese).isEmpty)
            XCTAssertNotEqual(eligibility.explanation(.english), eligibility.explanation(.chinese))
        }
        for error in LoginItemOperationError.allCases {
            for language in MacSoulLanguage.allCases {
                XCTAssertFalse(error.message(language).isEmpty)
                XCTAssertFalse(error.message(language).contains("SENSITIVE-MOCK-PATH-DO-NOT-DISPLAY"))
            }
            XCTAssertNotEqual(error.message(.english), error.message(.chinese))
        }
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
