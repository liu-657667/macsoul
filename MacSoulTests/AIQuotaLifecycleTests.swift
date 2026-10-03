import XCTest
@testable import MacSoul

private final class ManualQuotaClock: QuotaClock, @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 1_800_000_000
    private var waiting: [UUID: (TimeInterval, CheckedContinuation<Void, Error>)] = [:]
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return Date(timeIntervalSince1970: time) }
    func pending() -> Int { lock.lock(); defer { lock.unlock() }; return waiting.count }
    func advance(_ seconds: TimeInterval) {
        lock.lock(); time += seconds
        let due = waiting.filter { $0.value.0 <= time }
        due.keys.forEach { waiting.removeValue(forKey: $0) }; lock.unlock()
        due.values.forEach { $0.1.resume() }
    }
    private func cancel(_ id: UUID) {
        lock.lock(); let value = waiting.removeValue(forKey: id); lock.unlock()
        value?.1.resume(throwing: CancellationError())
    }
    private func register(_ id: UUID, seconds: TimeInterval, continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if Task.isCancelled { lock.unlock(); continuation.resume(throwing: CancellationError()) }
        else { waiting[id] = (time + seconds, continuation); lock.unlock() }
    }
    func sleep(seconds: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { register(id, seconds: seconds, continuation: $0) }
        } onCancel: { self.cancel(id) }
    }
}
private actor FakeQuotaTransport: CodexQuotaTransport {
    var opens = 0
    var closes = 0
    var sent: [[String: Any]] = []
    var failOpen = false
    var stream: AsyncThrowingStream<Data, Error>.Continuation?
    func counts() -> (Int, Int, Int) { (opens, closes, sent.count) }
    func readIDs() -> [Int] { sent.filter { $0["method"] as? String == "account/rateLimits/read" }.compactMap { $0["id"] as? Int } }
    func methods() -> [String] { sent.compactMap { $0["method"] as? String } }
    func setFailOpen() { failOpen = true }
    func open() throws -> AsyncThrowingStream<Data, Error> {
        opens += 1
        if failOpen { throw CodexTransportError.launchFailed }
        return AsyncThrowingStream { stream = $0 }
    }
    func send(_ data: Data) throws { sent.append(try JSONSerialization.jsonObject(with: data) as! [String: Any]) }
    func close() { if let stream { closes += 1; stream.finish(); self.stream = nil } }
    func emit(_ json: [String: Any]) throws { stream?.yield(try JSONSerialization.data(withJSONObject: json)) }
    func malformed() { stream?.yield(Data("garbage".utf8)) }
    func exit() { stream?.finish(throwing: CodexTransportError.closed); stream = nil }
}
@MainActor private final class FixtureQuotaProvider: LiveQuotaProviding {
    let provider: QuotaProvider
    var item: QuotaItem
    var detail: QuotaProviderDetail
    var onUpdate: ((QuotaItem, QuotaProviderDetail) -> Void)?
    var starts = 0, stops = 0
    init(_ provider: QuotaProvider, item: QuotaItem? = nil) {
        self.provider = provider; self.item = item ?? .unavailable(provider)
        detail = QuotaProviderDetail(provider: provider, connection: item == nil ? .unavailable : .available)
    }
    func start() { starts += 1; onUpdate?(item, detail) }
    func stop() { stops += 1 }
    func waitForStop() async { }
    func update(_ item: QuotaItem) { self.item = item; onUpdate?(item, detail) }
}
private actor VersionOnlyRunner: ShellRunning {
    var calls: [ShellCommand] = []
    var response = "2.1.90 (Claude Code)"
    func commands() -> [ShellCommand] { calls }
    func run(_ command: ShellCommand) async throws -> ShellResult {
        calls.append(command)
        return ShellResult(stdout: response, stderr: "", exitCode: 0, terminationReason: .exit, outputTruncated: false, duration: 0)
    }
}
private struct NoQuotaTestHTTP: NetworkHTTPClient {
    func request(url: URL, method: String, maxBytes: Int) async throws -> NetworkHTTPResponse { throw NetworkFailure.transport }
}

@MainActor final class AIQuotaLifecycleTests: XCTestCase {
    private func wait(_ condition: @escaping () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 { if await condition() { return }; await Task.yield() }
        XCTFail("State did not progress", file: file, line: line)
    }
    private func payload(_ used: Int = 42) -> [String: Any] {
        ["rateLimits": ["limitId": "codex", "primary": ["usedPercent": used, "windowDurationMins": 300, "resetsAt": 1_800_010_000]]]
    }
    private func establish(_ provider: CodexQuotaProvider, _ transport: FakeQuotaTransport) async throws {
        provider.start()
        await wait { await transport.counts().2 >= 1 }
        try await transport.emit(["id": 1, "result": ["userAgent": "test"]])
        await wait { await transport.counts().2 >= 3 }
        try await transport.emit(["id": 2, "result": payload()])
        await wait { provider.detail.connection == .available }
    }
    func testUnauthorizedProviderNeverStartsTransport() async {
        let fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(makeTransport: { fake })
        provider.start(); provider.start()
        XCTAssertEqual(provider.starts, 0); XCTAssertTrue(provider.detail.authorizationRequired)
        XCTAssertTrue(provider.item.entirelyUnavailable)
        let count = await fake.counts().0; XCTAssertEqual(count, 0)
        provider.stop(); await provider.waitForStop()
    }
    func testStartOnceInitialReadAndEventUpdate() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        provider.start(); provider.start()
        XCTAssertEqual(provider.starts, 1)
        let methods = await fake.methods()
        XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(55)])
        await wait { provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent == 55 }
        XCTAssertEqual(provider.item.weekly, .unreported)
        provider.stop(); await provider.waitForStop()
        XCTAssertEqual(provider.detail.connection, .stopped)
        XCTAssertEqual(clock.pending(), 0)
    }
    func testChildExitReconnectsWithNewInitialRead() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        await fake.exit()
        await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        clock.advance(1)
        await wait { await fake.counts().0 == 2 }
        let methods = await fake.methods(); XCTAssertEqual(methods.last, "initialize")
        provider.stop(); await provider.waitForStop()
    }
    func testFallbackReadAt240SecondsRefreshesTimestampAndUsesUniqueIDs() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        await wait { clock.pending() == 1 }
        clock.advance(239)
        let initialIDs = await fake.readIDs(); XCTAssertEqual(initialIDs, [2])
        clock.advance(1)
        await wait { await fake.readIDs() == [2, 3] }
        try await fake.emit(["id": 3, "result": payload(61)])
        await wait { provider.item.sampledAt == clock.now() }
        XCTAssertEqual(provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent, 61)
        await wait { clock.pending() == 1 }
        clock.advance(240)
        await wait { await fake.readIDs() == [2, 3, 4] }
        provider.stop(); await provider.waitForStop()
        XCTAssertEqual(clock.pending(), 0)
    }
    func testEventWhileVerificationPendingDoesNotStartAnotherRead() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        await wait { clock.pending() == 1 }; clock.advance(240)
        await wait { await fake.readIDs() == [2, 3] }
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(73)])
        await wait { provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent == 73 }
        provider.start(); provider.start()
        // An old/duplicate reply cannot complete request 3 or install a fresh baseline.
        try await fake.emit(["id": 2, "result": payload(0)])
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent, 73)
        clock.advance(9)
        let ids = await fake.readIDs(); XCTAssertEqual(ids, [2, 3])
        try await fake.emit(["id": 3, "result": payload(74)])
        await wait { provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent == 74 }
        await wait { clock.pending() == 1 }
        provider.stop(); await provider.waitForStop()
    }
    func testReconnectRetainsNumericSampleWithOriginalTimeAndNaturallyStales() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        let original = provider.item
        await fake.exit()
        await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        XCTAssertEqual(provider.item, original)
        clock.advance(301)
        guard case .stale(let value) = provider.item.displayWindows(now: clock.now())[0].state else {
            provider.stop(); await provider.waitForStop(); return XCTFail("Retained sample must age, not refresh")
        }
        XCTAssertEqual(value.usedPercent, 42); XCTAssertEqual(provider.item.sampledAt, original.sampledAt)
        provider.stop(); await provider.waitForStop()
        XCTAssertTrue(provider.item.entirelyUnavailable)
    }
    func testVerificationTimeoutRetainsSampleAndReconnectsWithoutOverlap() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        let original = provider.item
        await wait { clock.pending() == 1 }; clock.advance(240)
        await wait { await fake.readIDs() == [2, 3] }
        await wait { clock.pending() == 1 }; clock.advance(10)
        await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        XCTAssertEqual(provider.item, original)
        let ids = await fake.readIDs(); XCTAssertEqual(ids, [2, 3])
        provider.stop(); await provider.waitForStop()
    }
    func testStopCancelsVerificationAndWakeRequiresFreshInitialRead() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        await wait { clock.pending() == 1 }
        provider.stop(); await provider.waitForStop()
        clock.advance(600)
        let ids = await fake.readIDs(); XCTAssertEqual(ids, [2])
        XCTAssertTrue(provider.item.entirelyUnavailable); XCTAssertEqual(clock.pending(), 0)
        provider.start(); await wait { await fake.counts().0 == 2 }
        XCTAssertTrue(provider.item.entirelyUnavailable)
        await wait { await fake.methods().count == 4 }
        try await fake.emit(["id": 1, "result": [:]])
        await wait { await fake.readIDs() == [2, 2] }
        try await fake.emit(["id": 2, "result": payload(17)])
        await wait { provider.detail.connection == .available }
        XCTAssertEqual(provider.item.sampledAt, clock.now())
        provider.stop(); await provider.waitForStop()
    }
    func testWeekOnlyEventAndReadShareSameMapping() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        let week: [String: Any] = ["rateLimitsByLimitId": ["codex": ["planType": "pro", "primary": [
            "usedPercent": 38, "windowDurationMins": 10080, "resetsAt": 1_800_010_000]]]]
        try await fake.emit(["method": "account/rateLimits/updated", "params": week])
        await wait { provider.item.fiveHour == .notApplicable }
        let eventItem = provider.item
        await wait { clock.pending() == 1 }; clock.advance(240)
        await wait { await fake.readIDs() == [2, 3] }
        try await fake.emit(["id": 3, "result": week])
        await wait { provider.item.sampledAt == clock.now() }
        XCTAssertEqual(provider.item.fiveHour, eventItem.fiveHour)
        XCTAssertEqual(provider.item.weekly, eventItem.weekly)
        provider.stop(); await provider.waitForStop()
    }
    func testUnverifiedNativeVersionDoesNotOpenTransport() async {
        let fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, versionLookup: { "0.999.0" }, makeTransport: { fake })
        provider.start(); await wait { provider.detail.version == "0.999.0" }
        XCTAssertTrue(provider.item.entirelyUnavailable)
        let opens = await fake.counts().0; XCTAssertEqual(opens, 0)
        provider.stop(); await provider.waitForStop()
    }
    func testNativeFactoryInUnitTestHostCannotReadOwnerAccount() async {
        let provider = CodexQuotaProvider.nativeLive()
        provider.start()
        XCTAssertTrue(provider.detail.authorizationRequired)
        XCTAssertEqual(provider.starts, 0)
        provider.stop(); await provider.waitForStop()
    }
    func testConnectionFailureRemainsProviderUnavailableAndBacksOff() async {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        await fake.setFailOpen()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start()
        await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        XCTAssertTrue(provider.item.entirelyUnavailable)
        clock.advance(0.5); let first = await fake.counts().0; XCTAssertEqual(first, 1)
        clock.advance(0.5); await wait { await fake.counts().0 == 2 }
        await wait { clock.pending() == 1 }; clock.advance(1)
        let second = await fake.counts().0; XCTAssertEqual(second, 2)
        clock.advance(1); await wait { await fake.counts().0 == 3 }
        provider.stop(); await provider.waitForStop(); XCTAssertEqual(clock.pending(), 0)
    }
    func testConnectedReadFailureIsRequestFailed() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start(); await wait { await fake.counts().2 == 1 }
        try await fake.emit(["id": 1, "result": [:]])
        await wait { await fake.counts().2 == 3 }
        try await fake.emit(["id": 2, "error": ["code": -1, "message": "redacted fixture"]])
        await wait { provider.detail.connection == .reconnecting }
        XCTAssertEqual(provider.item.fiveHour, .requestFailed)
        provider.stop(); await provider.waitForStop()
    }
    func testMalformedResponseHasExplicitStateAndDoesNotClamp() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        var states: [QuotaConnectionState] = []
        provider.onUpdate = { _, detail in states.append(detail.connection) }
        try await establish(provider, fake)
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(101)])
        await wait { states.contains(.malformed) }
        XCTAssertEqual(provider.item.fiveHour, .requestFailed)
        provider.stop(); await provider.waitForStop()
    }
    func testHandshakeTimeoutUsesInjectedClockAndClosesChild() async {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start(); await wait { clock.pending() == 1 }
        clock.advance(10)
        await wait { provider.detail.connection == .reconnecting }
        let closes = await fake.counts().1; XCTAssertEqual(closes, 1)
        provider.stop(); await provider.waitForStop()
    }
    func testStopDuringBackoffCancelsAllPendingWork() async {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        await fake.setFailOpen()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start(); await wait { clock.pending() == 1 }
        provider.stop(); await provider.waitForStop(); clock.advance(600)
        let opens = await fake.counts().0; XCTAssertEqual(opens, 1)
        XCTAssertEqual(clock.pending(), 0)
    }
    func testSleepWakeFreshBaselineDoesNotRetainOldWindow() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        provider.stop(); provider.start()
        XCTAssertTrue(provider.item.entirelyUnavailable)
        await wait { await fake.counts().0 == 2 }
        XCTAssertNotEqual(provider.detail.connection, .available)
        provider.stop(); await provider.waitForStop()
    }
    func testUnrelatedNotificationsDoNotBecomeQuotaOrLeakIntoItem() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        let original = provider.item
        try await fake.emit(["method": "thread/started", "params": ["fake": "discard"]])
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(provider.item, original)
        provider.stop(); await provider.waitForStop()
    }
    func testClaudeAbsentMakesNoVersionOrAccountCalls() async {
        let runner = VersionOnlyRunner()
        let provider = ClaudeQuotaProvider(executable: { nil }, runner: runner)
        provider.start(); await wait { provider.detail.claudeCapability == .notInstalled }
        let commands = await runner.commands(); XCTAssertTrue(commands.isEmpty)
        XCTAssertTrue(provider.item.entirelyUnavailable)
        provider.stop(); await provider.waitForStop()
    }
    func testClaudePresentChecksOnlyVersionAndRemainsUnverified() async {
        let runner = VersionOnlyRunner()
        let provider = ClaudeQuotaProvider(executable: { URL(fileURLWithPath: "/fake/claude") }, runner: runner)
        provider.start(); provider.start()
        await wait { provider.detail.claudeCapability == .noVerifiedSource }
        let commands = await runner.commands(); XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.arguments, ["--version"])
        XCTAssertEqual(provider.detail.version, "2.1.90")
        XCTAssertTrue(provider.item.entirelyUnavailable)
        provider.stop(); await provider.waitForStop()
    }
    func testSharedMonitorRejectsOldGenerationAndMockLeakage() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let codexItem = try! CodexQuotaParser.parse(payload(), now: now)
        let codex = FixtureQuotaProvider(.codex, item: codexItem), claude = FixtureQuotaProvider(.claude)
        var latest = AIQuotaSnapshot.stopped
        let monitor = AIQuotaMonitor(codex: codex, claude: claude) { value, _ in latest = value }
        monitor.start(); monitor.start()
        XCTAssertEqual(codex.starts, 1); XCTAssertEqual(claude.starts, 1)
        XCTAssertEqual(latest.items[0], codexItem); XCTAssertTrue(latest.items[1].entirelyUnavailable)
        let old = codex.onUpdate
        monitor.stop(); monitor.start()
        let before = latest
        old?(QuotaItem.unavailable(.codex), codex.detail)
        XCTAssertEqual(latest, before)
        codex.update(MockProvider(fixture: .quota95).snapshot(now: now).quotas[0])
        XCTAssertEqual(latest, before)
        monitor.stop()
    }
    func testAppStoreLivePreviewSleepWakeAndWindowOpenShareOneMonitor() async throws {
        let clock = ManualQuotaClock()
        let item = try CodexQuotaParser.parse(payload(), now: clock.now())
        let codex = FixtureQuotaProvider(.codex, item: item), claude = FixtureQuotaProvider(.claude)
        let store = AppStore(networkPath: FakeNetworkPath(), networkHTTP: NoQuotaTestHTTP(), networkLocal: FakeLocalNetwork(),
                             codexQuota: codex, claudeQuota: claude, quotaClock: clock, now: clock.now())
        store.setSystemMode(.live)
        XCTAssertEqual(store.snapshot.quotas, [item, .unavailable(.claude)])
        XCTAssertEqual(store.snapshot.quotaMode, .live)
        for _ in 0..<5 { let id = UUID(); store.setWindow(id, visible: true, section: .ai); store.setWindow(id, visible: false, section: .ai) }
        XCTAssertEqual(store.quotaStarts, 1); XCTAssertEqual(codex.starts, 1)
        // These are precisely the shared collection consumed by Overview / AI Coding / Menu Bar.
        let overview = store.snapshot.quotas, ai = store.snapshot.quotas, menu = store.snapshot.quotas
        XCTAssertEqual(overview, ai); XCTAssertEqual(menu, ai)
        store.advanceDisplayClock(now: clock.now().addingTimeInterval(301))
        XCTAssertEqual(store.snapshot.quotas[0], item)
        store.suspendForSleep(); XCTAssertTrue(store.snapshot.quotas.allSatisfy(\.entirelyUnavailable))
        store.resumeAfterWake(); XCTAssertEqual(store.quotaStarts, 2)
        store.setSystemMode(.preview)
        XCTAssertTrue(store.snapshot.quotas.allSatisfy { $0.mode == .mock })
        await store.waitForQuotaStop()
    }
}

final class CodexNativePipeFixtureTests: XCTestCase {
    // Standalone fake child: no Codex executable, account, shell, or network is used.
    private func executable() throws -> (URL, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacSoulQuotaFixture-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let executable = root.appendingPathComponent("fake-app-server")
        try """
        #!/usr/bin/python3
        import sys, json
        for line in sys.stdin:
            value = json.loads(line)
            if value['method'] == 'initialize':
                print(json.dumps({'id': value['id'], 'result': {}}), flush=True)
            elif value['method'] == 'account/rateLimits/read':
                print(json.dumps({'id': value['id'], 'result': {'rateLimits': None}}), flush=True)
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return (root, executable)
    }
    private func deadline(_ transport: NativeCodexQuotaTransport) -> Task<Void, Never> {
        Task {
            do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
            await transport.close()
        }
    }
    func testNativePipeHandshakeReadAndOwnedChildStop() async throws {
        let (root, executable) = try executable()
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = NativeCodexQuotaTransport(executable: executable)
        let stream = try await transport.open()
        let timeout = deadline(transport)
        defer { timeout.cancel() }
        var iterator = stream.makeAsyncIterator()
        try await transport.send(CodexReadOnlyRPC.message(method: "initialize", id: 1))
        let initialLine = try await iterator.next()
        let initialized = try XCTUnwrap(initialLine)
        XCTAssertTrue(String(decoding: initialized, as: UTF8.self).contains("result"))
        try await transport.send(CodexReadOnlyRPC.message(method: "initialized"))
        try await transport.send(CodexReadOnlyRPC.message(method: "account/rateLimits/read", id: 2))
        let resultLine = try await iterator.next()
        let result = try XCTUnwrap(resultLine)
        XCTAssertTrue(String(decoding: result, as: UTF8.self).contains("rateLimits"))
        await transport.close(); await transport.close()
        do { try await transport.send(CodexReadOnlyRPC.message(method: "initialized")); XCTFail("Closed child should reject writes") }
        catch { }
    }
    func testNativeTransportRejectsPromptRequestBeforeWriting() async throws {
        let (root, executable) = try executable()
        defer { try? FileManager.default.removeItem(at: root) }
        // Cover early-exit/cancellation races without waiting for a handshake or real account.
        for _ in 0..<10 {
            let transport = NativeCodexQuotaTransport(executable: executable)
            _ = try await transport.open()
            do {
                try await transport.send(Data("{\"method\":\"turn/start\",\"prompt\":\"fake\"}".utf8))
                XCTFail("Must reject an unapproved method")
            } catch { }
            await transport.close()
        }
    }
}
