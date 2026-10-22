import XCTest
import ServiceManagement
import Darwin
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

// Every launchctl action below is a Fake. Native file tests use a private,
// disposable synthetic Home; they never address the real user LaunchAgents.
private final class FakeLaunchAgentFiles: LaunchAgentFiles {
    let directory = URL(fileURLWithPath: "/Users/mock/Library/LaunchAgents")
    var file: LaunchAgentFile?
    var readError: LaunchAgentFailure?, createError: LaunchAgentFailure?, removeError: LaunchAgentFailure?
    var reads = 0, creates = 0, removals = 0
    var invalidApps = Set<String>(), missingApps = Set<String>()
    func read() throws -> LaunchAgentFile? { reads += 1; if let readError { throw readError }; return file }
    func create(_ data: Data) throws {
        creates += 1; if let createError { throw createError }
        guard file == nil else { throw LaunchAgentFailure.conflict }
        file = .init(data: data, identity: UUID().uuidString)
    }
    func remove(_ expected: LaunchAgentFile) throws {
        removals += 1; if let removeError { throw removeError }
        guard file == expected else { throw LaunchAgentFailure.conflict }; file = nil
    }
    func appIsMacSoul(at url: URL) -> Bool? {
        if missingApps.contains(url.path) { return nil }
        return !invalidApps.contains(url.path)
    }
}
private actor LaunchAgentTestGate {
    private var waiters = [CheckedContinuation<Void, Never>]()
    private var released = false
    func wait() async { if !released { await withCheckedContinuation { waiters.append($0) } } }
    func release() { released = true; let current = waiters; waiters.removeAll(); current.forEach { $0.resume() } }
}
private final class FakeLaunchAgentJobs: LaunchAgentJobs {
    var job: LaunchAgentJob?, failure: LaunchAgentFailure?, removalError: LaunchAgentFailure?
    var reads = 0, removals = 0
    var beforeRead: (() -> Void)?
    var gate: LaunchAgentTestGate?
    func read() async throws -> LaunchAgentJob? {
        reads += 1; beforeRead?()
        if let gate { await gate.wait() }
        if let failure { throw failure }; return job
    }
    func bootout() async throws {
        removals += 1; if let removalError { throw removalError }; job = nil
    }
}
private final class FakeLaunchAgentShell: ShellRunning {
    var commands = [ShellCommand]()
    var responses = [Result<ShellResult, Error>]()
    func run(_ command: ShellCommand) async throws -> ShellResult {
        commands.append(command)
        guard !responses.isEmpty else { throw LaunchAgentFailure.observation }
        return try responses.removeFirst().get()
    }
}
@MainActor final class LaunchAgentTests: XCTestCase {
    private let path = "/Users/mock/Applications/MacSoul Special & '名字'.app"
    private func setup(path: String? = nil, bundle: String = "local.macsoul.app") -> (LaunchAgentManager, FakeLaunchAgentFiles, FakeLaunchAgentJobs) {
        let f = FakeLaunchAgentFiles(), j = FakeLaunchAgentJobs()
        let app = LaunchAgentApp(url: URL(fileURLWithPath: path ?? self.path), bundleID: bundle, home: URL(fileURLWithPath: "/Users/mock"))
        return (LaunchAgentManager(app: app, files: f, jobs: j), f, j)
    }
    private func configured(_ f: FakeLaunchAgentFiles, path: String? = nil) throws {
        f.file = .init(data: try LaunchAgentManager.plist(for: path ?? self.path), identity: "approved")
    }
    private func loaded(_ j: FakeLaunchAgentJobs, _ f: FakeLaunchAgentFiles, path: String? = nil) {
        j.job = .init(source: f.directory.appendingPathComponent(LaunchAgentManager.filename).path,
                      program: "/usr/bin/open", arguments: ["/usr/bin/open", "-a", path ?? self.path])
    }
    private func rejects(_ action: () async throws -> Void, _ expected: LaunchAgentFailure, file: StaticString = #filePath, line: UInt = #line) async {
        do { try await action(); XCTFail("Expected rejection", file: file, line: line) }
        catch let error as LaunchAgentFailure { XCTAssertEqual(error, expected, file: file, line: line) }
        catch { XCTFail("Unexpected safe error type: \(type(of: error))", file: file, line: line) }
    }
    func testEnableIsExclusiveAndIdempotentWithLiteralSpecialCharacterPath() async throws {
        let (m, f, j) = setup()
        try await m.enable(); try await m.enable()
        let state = await m.readState(); XCTAssertEqual(state, .configuredForNextLogin)
        XCTAssertEqual(f.creates, 1); XCTAssertEqual(j.removals, 0)
        let data = try XCTUnwrap(f.file?.data)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["ProgramArguments"] as? [String], ["/usr/bin/open", "-a", path])
        XCTAssertEqual(plist["Label"] as? String, "local.macsoul.launchagent")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true); XCTAssertEqual(plist["KeepAlive"] as? Bool, false)
    }
    func testConfiguredAndLoadedAreNotNativeLoginSuccess() async throws {
        let (m, f, j) = setup(); try configured(f)
        var state = await m.readState(); XCTAssertEqual(state, .configuredForNextLogin)
        loaded(j, f); state = await m.readState(); XCTAssertEqual(state, .loaded)
        XCTAssertTrue(state.explanation(.english).contains("does not verify"))
    }
    func testDisableOwnLoadedJobAndRepeatIsIdempotent() async throws {
        let (m, f, j) = setup(); try configured(f); loaded(j, f)
        try await m.disable(); try await m.disable()
        let state = await m.readState(); XCTAssertEqual(state, .disabled)
        XCTAssertEqual(j.removals, 1); XCTAssertEqual(f.removals, 1)
    }
    func testDisableUnloadedConfigurationDoesNotBootout() async throws {
        let (m, f, j) = setup(); try configured(f); try await m.disable()
        XCTAssertEqual(f.removals, 1); XCTAssertEqual(j.removals, 0)
    }
    func testStrictSchemaRejectsForeignLabelExtraKeysNumericBooleansAndBadArguments() async throws {
        let good = try LaunchAgentManager.plist(for: path)
        let base = try XCTUnwrap(PropertyListSerialization.propertyList(from: good, format: nil) as? [String: Any])
        let overrides: [[String: Any]] = [
            ["Label": "local.macsoul.launchagent.poc"], ["EnvironmentVariables": ["X": "value"]],
            ["RunAtLoad": 1], ["KeepAlive": true], ["ProgramArguments": ["/bin/sh", "-c", path]],
            ["ProgramArguments": ["/usr/bin/open", "-b", "local.macsoul.app"]]
        ]
        for change in overrides {
            let (m, f, j) = setup()
            f.file = .init(data: try PropertyListSerialization.data(fromPropertyList: base.merging(change) { _, n in n }, format: .xml, options: 0), identity: "foreign")
            await rejects({ try await m.enable() }, .conflict); await rejects({ try await m.disable() }, .conflict)
            XCTAssertEqual(j.reads, 0); XCTAssertEqual(f.creates + f.removals + j.removals, 0)
        }
    }
    func testMalformedPlistRefusesAtParsingStage() async {
        let (m, f, j) = setup(); f.file = .init(data: Data("invalid".utf8), identity: "bad")
        await rejects({ try await m.disable() }, .conflict)
        XCTAssertEqual(f.reads, 1); XCTAssertEqual(j.reads, 0); XCTAssertEqual(f.removals, 0)
    }
    func testUnsafeFileRefusesBeforeJobProbe() async {
        let (m, f, j) = setup(); f.readError = .unsafeFile
        await rejects({ try await m.enable() }, .unsafeFile)
        XCTAssertEqual(f.reads, 1); XCTAssertEqual(j.reads, 0); XCTAssertEqual(f.creates, 0)
    }
    func testWrongBundleIdentityHasNoFileOrJobAccess() async {
        let (m, f, j) = setup(bundle: "local.macsoul.loginitem.regtest")
        await rejects({ try await m.enable() }, .installation)
        await rejects({ try await m.disable() }, .installation)
        XCTAssertEqual(f.reads + f.creates + f.removals + j.reads + j.removals, 0)
    }
    func testNativeFactoryInTestHostFailsBeforeRealFileOrJobAccess() async {
        let manager = LaunchAgentManager.native()
        let state = await manager.readState(); XCTAssertEqual(state, .unavailable)
        await rejects({ try await manager.enable() }, .installation)
        await rejects({ try await manager.disable() }, .installation)
    }
    func testDerivedDataAndMissingAppCannotEnable() async {
        let (m, f, j) = setup(path: "/tmp/DerivedData/MacSoul.app")
        await rejects({ try await m.enable() }, .installation)
        XCTAssertEqual(f.creates + j.removals, 0)
        let (missing, ff, _) = setup(); ff.missingApps.insert(path)
        await rejects({ try await missing.enable() }, .installation)
        XCTAssertEqual(ff.creates, 0)
    }
    func testMovedAppRequiresExplicitOffThenOn() async throws {
        let (m, f, j) = setup(); let old = "/Applications/Previous MacSoul.app"
        try configured(f, path: old); f.missingApps.insert(old)
        let state = await m.readState(); XCTAssertEqual(state, .stalePath)
        await rejects({ try await m.enable() }, .conflict)
        XCTAssertEqual(f.creates + f.removals, 0)
        try await m.disable(); try await m.enable()
        XCTAssertEqual(f.removals, 1); XCTAssertEqual(f.creates, 1); XCTAssertEqual(j.removals, 0)
    }
    func testForeignExistingOldAppIsConflictNotStaleCleanup() async throws {
        let (m, f, j) = setup(); let other = "/Applications/Other.app"
        try configured(f, path: other); f.invalidApps.insert(other)
        await rejects({ try await m.disable() }, .conflict)
        XCTAssertEqual(j.reads + f.removals, 0)
    }
    func testForeignLoadedJobSourceOrArgumentsNeverBootoutEvenWithOwnFile() async throws {
        for foreign in [LaunchAgentJob(source: "/tmp/foreign.plist", program: "/usr/bin/open", arguments: ["/usr/bin/open", "-a", path]),
                        LaunchAgentJob(source: "/Users/mock/Library/LaunchAgents/local.macsoul.launchagent.plist", program: "/bin/sh", arguments: ["/bin/sh", "-c", path])] {
            let (m, f, j) = setup(); try configured(f); j.job = foreign
            await rejects({ try await m.disable() }, .conflict)
            XCTAssertEqual(j.removals + f.removals, 0)
        }
    }
    func testOrphanForeignLoadedJobNeverBootout() async {
        let (m, f, j) = setup(); j.job = .init(source: "/tmp/unknown", program: "/usr/bin/open", arguments: ["/usr/bin/open", "-a", path])
        await rejects({ try await m.disable() }, .conflict)
        XCTAssertEqual(j.removals + f.removals, 0)
    }
    func testOwnedOrphanJobCanBeDisabledWithoutDeletingAnyFile() async throws {
        let (m, f, j) = setup(); loaded(j, f); try await m.disable()
        XCTAssertEqual(j.removals, 1); XCTAssertEqual(f.removals, 0)
    }
    func testJobProbeFailureNeverCreatesOrDeletes() async {
        let (m, f, j) = setup(); j.failure = .observation
        await rejects({ try await m.enable() }, .observation)
        XCTAssertEqual(j.reads, 1); XCTAssertEqual(f.creates + f.removals, 0)
    }
    func testCreateFailurePreservesObservedDisabledState() async {
        let (m, f, _) = setup(); f.createError = .create
        await rejects({ try await m.enable() }, .create)
        let state = await m.readState(); XCTAssertEqual(state, .disabled)
        XCTAssertEqual(f.creates, 1)
    }
    func testBootoutFailureRetainsFileAndLoadedState() async throws {
        let (m, f, j) = setup(); try configured(f); loaded(j, f); j.removalError = .bootout
        await rejects({ try await m.disable() }, .bootout)
        XCTAssertEqual(f.removals, 0); XCTAssertNotNil(f.file)
        let state = await m.readState(); XCTAssertEqual(state, .loaded)
    }
    func testBootoutSuccessDeleteFailureShowsConfiguredAndFailure() async throws {
        let (m, f, j) = setup(); try configured(f); loaded(j, f); f.removeError = .remove
        let controller = LaunchAgentController(manager: m)
        await controller.setEnabled(false)
        XCTAssertEqual(controller.state, .configuredForNextLogin)
        XCTAssertEqual(controller.operationError, .remove); XCTAssertEqual(j.removals, 1)
        await controller.refresh(); XCTAssertEqual(controller.operationError, .remove)
    }
    func testFileReplacementDuringProbeBlocksBeforeBootout() async throws {
        let (m, f, j) = setup(); try configured(f); loaded(j, f)
        j.beforeRead = { if j.reads == 2, let old = f.file { f.file = .init(data: old.data, identity: "replacement") } }
        await rejects({ try await m.disable() }, .conflict)
        XCTAssertEqual(j.reads, 2); XCTAssertEqual(j.removals + f.removals, 0)
    }
    func testInitAndRefreshNeverMutate() async {
        let (m, f, j) = setup()
        let controller = LaunchAgentController(manager: m)
        XCTAssertEqual(f.reads + j.reads, 0)
        await controller.refresh(); await controller.refresh()
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertEqual(f.creates + f.removals + j.removals, 0)
    }
    func testCancellationBeforeEnableConsumesNoMutation() async {
        let (m, f, j) = setup(); let task = Task { try await m.enable() }; task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("Unexpected error") }
        XCTAssertEqual(f.creates + f.removals + j.removals, 0)
    }
    func testConcurrentMutationIsRejectedByManager() async throws {
        let (m, f, j) = setup(); let gate = LaunchAgentTestGate(); j.gate = gate
        let started = expectation(description: "read-only probe entered")
        j.beforeRead = { started.fulfill() }
        let first = Task { try await m.enable() }; defer { first.cancel() }
        await fulfillment(of: [started], timeout: 2)
        let rejected = expectation(description: "concurrent operation rejected")
        let second = Task { await rejects({ try await m.disable() }, .busy); rejected.fulfill() }
        await fulfillment(of: [rejected], timeout: 2)
        await gate.release(); await second.value; try await first.value
        XCTAssertEqual(f.creates, 1); XCTAssertEqual(j.removals, 0)
    }
    func testCancellationDuringProbeNeverWrites() async {
        let (m, f, j) = setup(); let gate = LaunchAgentTestGate(); j.gate = gate
        let started = expectation(description: "probe suspended")
        j.beforeRead = { started.fulfill() }
        let action = Task { try await m.enable() }
        await fulfillment(of: [started], timeout: 2)
        action.cancel(); await gate.release()
        do { try await action.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("Unexpected error") }
        XCTAssertEqual(f.creates + f.removals + j.removals, 0)
    }
    func testControllerErrorClearsOnlyAfterExternalStateChangesOrSuccess() async throws {
        let (m, f, _) = setup(); f.createError = .create
        let c = LaunchAgentController(manager: m); await c.setEnabled(true)
        XCTAssertEqual(c.operationError, .create); await c.refresh(); XCTAssertEqual(c.operationError, .create)
        f.createError = nil; try configured(f); await c.refresh(); XCTAssertNil(c.operationError)
    }
    func testAllStateAndErrorCopyIsBilingualAndNeverClaimsLoginValidation() {
        for state in LaunchAgentState.allCases {
            XCTAssertFalse(state.label(.english).isEmpty); XCTAssertFalse(state.label(.chinese).isEmpty)
            XCTAssertNotEqual(state.explanation(.english), state.explanation(.chinese))
        }
        for error in LaunchAgentFailure.allCases { XCTAssertNotEqual(error.message(.english), error.message(.chinese)) }
        XCTAssertTrue(LaunchAgentState.configuredForNextLogin.explanation(.english).contains("has not been verified"))
    }
    private func result(_ text: String = "disabled services = {\n}\n") -> ShellResult {
        .init(stdout: text, stderr: "", exitCode: 0, terminationReason: .exit, outputTruncated: false, duration: 0)
    }
    private func jobText(source: String = "/Users/mock/Library/LaunchAgents/local.macsoul.launchagent.plist") -> String {
        "gui/501/local.macsoul.launchagent = {\n\tpath = \(source)\n\tprogram = /usr/bin/open\n\targuments = {\n\t\t/usr/bin/open\n\t\t-a\n\t\t\(path)\n\t}\n}\n"
    }
    func testNativeAdapterParsesOnlyExactJobAndUsesExactBootoutTarget() async throws {
        let shell = FakeLaunchAgentShell(); shell.responses = [.success(result()), .success(result(jobText())), .success(result())]
        let adapter = NativeLaunchAgentJobs(runner: shell, uid: 501)
        let job = try await adapter.read(); XCTAssertEqual(job?.arguments, ["/usr/bin/open", "-a", path])
        try await adapter.bootout()
        XCTAssertEqual(shell.commands.map(\.arguments), [["print-disabled", "gui/501"], ["print", "gui/501/local.macsoul.launchagent"], ["bootout", "gui/501/local.macsoul.launchagent"]])
        XCTAssertTrue(shell.commands.allSatisfy { $0.executableURL.path == "/bin/launchctl" && $0.timeout == 3 })
    }
    func testMissingServiceNeedsExactDiagnosticAndExistingGUI() async throws {
        let shell = FakeLaunchAgentShell(); shell.responses = [.success(result()), .failure(ShellRunnerError.nonZeroExit(113, stdout: "", stderr: "Could not find service \"local.macsoul.launchagent\" in domain")), .success(result())]
        let job = try await NativeLaunchAgentJobs(runner: shell, uid: 501).read(); XCTAssertNil(job)
        XCTAssertEqual(shell.commands.last?.arguments, ["print", "gui/501"])
    }
    func testArbitraryLaunchctlFailureIsNotDisabled() async {
        let shell = FakeLaunchAgentShell(); shell.responses = [.success(result()), .failure(ShellRunnerError.nonZeroExit(5, stdout: "", stderr: "Permission denied"))]
        await rejects({ _ = try await NativeLaunchAgentJobs(runner: shell, uid: 501).read() }, .observation)
        XCTAssertEqual(shell.commands.count, 2)
    }
    func testDisabledOverrideIsFailClosedWithoutAutomaticEnable() async {
        let shell = FakeLaunchAgentShell(); shell.responses = [.success(result("disabled services = {\n\t\"local.macsoul.launchagent\" => true\n}"))]
        await rejects({ _ = try await NativeLaunchAgentJobs(runner: shell, uid: 501).read() }, .observation)
        XCTAssertEqual(shell.commands.map(\.arguments), [["print-disabled", "gui/501"]])
    }
    func testUnknownAndDuplicatePrintFieldsFailClosed() throws {
        for text in ["unknown", String(jobText().dropLast(2)), jobText() + "\tpath = /tmp/foreign\n", jobText().replacingOccurrences(of: "gui/501/", with: "gui/999/")] {
            XCTAssertThrowsError(try NativeLaunchAgentJobs.parse(text, target: "gui/501/local.macsoul.launchagent"))
        }
    }
}

final class LaunchAgentFileTests: XCTestCase {
    private func fixture() throws -> (URL, NativeLaunchAgentFiles) {
        // Canonicalize only the OS-provided test root; production uses the
        // descriptor walker and does not trust Foundation /var alias rewriting.
        guard let physical = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileReadUnknown) }
        let parent = URL(fileURLWithPath: String(cString: physical), isDirectory: true); free(physical)
        let root = parent.appendingPathComponent("MacSoul-LA-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return (root, NativeLaunchAgentFiles(home: root, uid: getuid()))
    }
    func testPrivateFixtureCreateReadRemoveAndReadNeverCreatesDirectory() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(try fs.read()); XCTAssertFalse(FileManager.default.fileExists(atPath: fs.directory.path))
        try fs.create(Data("safe".utf8)); let snapshot = try XCTUnwrap(fs.read())
        XCTAssertEqual(snapshot.data, Data("safe".utf8)); XCTAssertThrowsError(try fs.create(Data("overwrite".utf8)))
        XCTAssertEqual(try fs.read(), snapshot); try fs.remove(snapshot); XCTAssertNil(try fs.read())
    }
    func testSymlinkFileRefusedAndTargetUnchanged() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try fs.create(Data("own".utf8)); let p = fs.directory.appendingPathComponent(LaunchAgentManager.filename)
        try FileManager.default.removeItem(at: p); let target = root.appendingPathComponent("other"); try Data("other".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: p, withDestinationURL: target)
        XCTAssertThrowsError(try fs.read()); XCTAssertThrowsError(try fs.create(Data()))
        XCTAssertEqual(try Data(contentsOf: target), Data("other".utf8))
    }
    func testSymlinkDirectoryRefusedWithoutFollowing() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let elsewhere = root.appendingPathComponent("other"); try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Library"), withDestinationURL: elsewhere)
        XCTAssertThrowsError(try fs.read()); XCTAssertThrowsError(try fs.create(Data()))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: elsewhere.path).isEmpty)
    }
    func testWrongOwnerOrWritableDirectoryRefusedAtDirectoryGate() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try NativeLaunchAgentFiles(home: root, uid: getuid() + 1).read())
        try FileManager.default.setAttributes([.posixPermissions: 0o770], ofItemAtPath: root.path)
        XCTAssertThrowsError(try fs.create(Data()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fs.directory.path))
    }
    func testWrongFilePermissionsAndHardLinksRefused() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try fs.create(Data("safe".utf8)); let p = fs.directory.appendingPathComponent(LaunchAgentManager.filename)
        try FileManager.default.setAttributes([.posixPermissions: 0o666], ofItemAtPath: p.path)
        XCTAssertThrowsError(try fs.read())
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: p.path)
        try FileManager.default.linkItem(at: p, to: root.appendingPathComponent("hard-link"))
        XCTAssertThrowsError(try fs.read())
    }
    func testFIFORefusedBeforeOpenWithoutBlocking() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try fs.create(Data()); let p = fs.directory.appendingPathComponent(LaunchAgentManager.filename)
        try FileManager.default.removeItem(at: p); XCTAssertEqual(mkfifo(p.path, 0o600), 0)
        XCTAssertThrowsError(try fs.read())
    }
    func testReplacementNeverRemovedUsingOldSnapshot() throws {
        let (root, fs) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try fs.create(Data("before".utf8)); let before = try XCTUnwrap(fs.read()); let p = fs.directory.appendingPathComponent(LaunchAgentManager.filename)
        try FileManager.default.removeItem(at: p); try fs.create(Data("replacement".utf8))
        XCTAssertThrowsError(try fs.remove(before)); XCTAssertEqual(try fs.read()?.data, Data("replacement".utf8))
    }
}
