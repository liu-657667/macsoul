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
    var retiredStreams: [AsyncThrowingStream<Data, Error>.Continuation] = []
    private var holdClose = false
    private var closeEntries = 0
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []
    func suspendClose() { holdClose = true }
    func closeEntryCount() -> Int { closeEntries }
    func pendingCloseCount() -> Int { closeWaiters.count }
    func releaseClose() {
        holdClose = false
        let pending = closeWaiters; closeWaiters.removeAll()
        pending.forEach { $0.resume() }
    }
    func counts() -> (Int, Int, Int) { (opens, closes, sent.count) }
    func readIDs() -> [Int] { sent.filter { $0["method"] as? String == "account/rateLimits/read" }.compactMap { $0["id"] as? Int } }
    func methods() -> [String] { sent.compactMap { $0["method"] as? String } }
    func setFailOpen() { failOpen = true }
    func open() throws -> AsyncThrowingStream<Data, Error> {
        opens += 1
        if failOpen { throw CodexTransportError.launchFailed }
        return AsyncThrowingStream { stream = $0; retiredStreams.append($0) }
    }
    func send(_ data: Data) throws { sent.append(try JSONSerialization.jsonObject(with: data) as! [String: Any]) }
    func close() async {
        closeEntries += 1
        // Both watchdog and run-loop cleanup can enter close; one release drains every waiter.
        if holdClose { await withCheckedContinuation { closeWaiters.append($0) } }
        if let stream { closes += 1; stream.finish(); self.stream = nil }
    }
    func emit(_ json: [String: Any]) throws { stream?.yield(try JSONSerialization.data(withJSONObject: json)) }
    func emitFromFirstConnection(_ json: [String: Any]) throws {
        retiredStreams.first?.yield(try JSONSerialization.data(withJSONObject: json))
    }
    func malformed() { stream?.yield(Data("garbage".utf8)) }
    func exit() { stream?.finish(throwing: CodexTransportError.closed); stream = nil }
}
// Explicitly held metadata result lets cancellation be tested before a transport exists.
private actor QuotaVersionGate {
    private var continuation: CheckedContinuation<String?, Never>?
    func hasEntered() -> Bool { continuation != nil }
    func read() async -> String? {
        await withCheckedContinuation { continuation = $0 }
    }
    func release(_ value: String?) { continuation?.resume(returning: value); continuation = nil }
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
        // Real time is only a failure bound; progress depends on the named observable condition.
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        while ProcessInfo.processInfo.systemUptime < deadline {
            if await condition() { return }
            await Task.yield()
        }
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
    private func whileCloseIsHeld(_ provider: CodexQuotaProvider, _ transport: FakeQuotaTransport,
                                  body: () async throws -> Void) async throws {
        await transport.suspendClose()
        do { try await body() }
        catch {
            await transport.releaseClose()
            provider.stop(); await provider.waitForStop()
            throw error
        }
        // Release before awaiting stop, including when an assertion in body has failed.
        await transport.releaseClose()
        provider.stop(); await provider.waitForStop()
        let pending = await transport.pendingCloseCount()
        XCTAssertEqual(pending, 0)
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
        var barrierSeen = false
        provider.onUpdate = { item, _ in
            if item.displayWindows(now: clock.now()).first?.state.value?.usedPercent == 73 { barrierSeen = true }
        }
        try await fake.emit(["id": 2, "result": payload(0)])
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(73)])
        await wait { barrierSeen }
        XCTAssertEqual(provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent, 73)
        clock.advance(9)
        let ids = await fake.readIDs(); XCTAssertEqual(ids, [2, 3])
        try await fake.emit(["id": 3, "result": payload(74)])
        await wait { provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent == 74 }
        await wait { clock.pending() == 1 }
        provider.stop(); await provider.waitForStop()
    }
    func testReconnectImmediatelyStalesNumericSampleWithOriginalTime() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        let original = provider.item
        await fake.exit()
        await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        XCTAssertEqual(provider.item.fiveHour, original.fiveHour)
        XCTAssertEqual(provider.item.weekly, original.weekly)
        XCTAssertEqual(provider.item.sampledAt, original.sampledAt)
        XCTAssertEqual(provider.item.freshness, .stale)
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
        XCTAssertEqual(provider.item.fiveHour, original.fiveHour)
        XCTAssertEqual(provider.item.sampledAt, original.sampledAt)
        XCTAssertEqual(provider.item.freshness, .stale)
        XCTAssertEqual(provider.detail.codexSession, .requestTimeout)
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
        try await fake.emit(["id": 1, "result": ["userAgent": "test"]])
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
    func testHistoricalCodex01600RequiresCurrentHandshakeAndRead() async throws { try await assertSessionVersion("0.160.0") }
    func testHistoricalCodex01601RequiresCurrentHandshakeAndRead() async throws { try await assertSessionVersion("0.160.1") }
    func testHistoricalCodex01620Alpha2RequiresCurrentHandshakeAndRead() async throws { try await assertSessionVersion("0.162.0-alpha.2") }
    func testUnknownVersionUsesCurrentCompatibleSession() async throws { try await assertSessionVersion("0.999.0") }
    func testHistoricalUpgradeFailureVersionUsesCurrentCompatibleSession() async throws { try await assertSessionVersion("0.162.0-alpha.17.2") }
    func testMissingVersionMetadataStillRequiresCurrentProtocol() async throws { try await assertSessionVersion(nil) }
    private func assertSessionVersion(_ version: String?) async throws {
        let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock,
                                         versionLookup: { version }, makeTransport: { fake })
        try await establish(provider, fake)
        XCTAssertEqual(provider.detail.version, version)
        XCTAssertEqual(provider.detail.codexSession, .available)
        XCTAssertFalse(provider.item.entirelyUnavailable)
        let methods = await fake.methods(), counts = await fake.counts()
        XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
        XCTAssertEqual(counts.0, 1)
        provider.stop(); await provider.waitForStop()
    }
    func testKnownAndUnknownVersionsBothRejectUnsupportedReadMethod() async throws {
        for version in ["0.160.0", "0.999.0"] {
            let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
            let provider = CodexQuotaProvider(approved: true, clock: clock, versionLookup: { version }, makeTransport: { fake })
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
            await wait { await fake.readIDs() == [2] }
            try await fake.emit(["id": 2, "error": ["code": -32601, "message": "fake method unavailable"]])
            await wait { await fake.counts().1 == 1 }
            XCTAssertEqual(provider.detail.codexSession, .methodUnsupported)
            XCTAssertEqual(clock.pending(), 0)
            XCTAssertNil(provider.item.sampledAt)
            let methods = await fake.methods()
            XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
            provider.stop(); await provider.waitForStop()
        }
    }
    func testTerminalProtocolRejectionCanStartAgainWithoutStop() async throws {
        let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start(); await wait { await fake.methods() == ["initialize"] }
        try await fake.emit(["id": 1, "result": ["rateLimits": NSNull()]])
        await wait { await fake.counts().1 == 1 }
        XCTAssertEqual(provider.detail.codexSession, .invalidResponse)
        XCTAssertNil(provider.item.sampledAt)
        await wait { provider.start(); return provider.starts == 2 }
        await wait { await fake.methods() == ["initialize", "initialize"] }
        try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
        await wait { await fake.readIDs() == [2] }
        try await fake.emit(["id": 2, "result": payload()])
        await wait { provider.detail.codexSession == .available }
        let opens = await fake.counts().0; XCTAssertEqual(opens, 2)
        provider.stop(); await provider.waitForStop()
    }
    func testNullOrEmptyWindowsAreConnectedWithoutInventedQuota() async throws {
        for limits: [String: Any] in [["rateLimits": NSNull()], ["rateLimits": [:]], ["rateLimits": ["primary": NSNull(), "secondary": NSNull()]]] {
            let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
            let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
            await wait { await fake.readIDs() == [2] }
            try await fake.emit(["id": 2, "result": limits])
            await wait { provider.detail.codexSession == .quotaUnavailable }
            XCTAssertEqual(provider.item.fiveHour, .unreported)
            XCTAssertEqual(provider.item.weekly, .unreported)
            XCTAssertTrue(provider.item.displayWindows(now: clock.now()).allSatisfy { $0.state.value == nil })
            provider.stop(); await provider.waitForStop()
        }
    }
    func testOptionalExtensionsAreIgnoredAndWindowsFollowDuration() async throws {
        let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start(); await wait { await fake.methods() == ["initialize"] }
        try await fake.emit(["id": 1, "result": ["userAgent": "fixture", "future": ["enabled": true]]])
        await wait { await fake.readIDs() == [2] }
        try await fake.emit(["id": 2, "result": ["extension": "ignored", "rateLimits": [
            "primary": ["usedPercent": 20, "windowDurationMins": 10080, "resetsAt": NSNull(), "extra": true],
            "secondary": ["usedPercent": 0, "windowDurationMins": 300, "resetsAt": 1_800_010_000]]]])
        await wait { provider.detail.codexSession == .available }
        let rows = provider.item.displayWindows(now: clock.now())
        XCTAssertEqual(rows.map { $0.state.value?.usedPercent }, [0, 20])
        XCTAssertNil(rows.last?.state.value?.resetsAt)
        XCTAssertEqual(rows.map { $0.state.value?.remainingPercent }, [100, 80])
        provider.stop(); await provider.waitForStop()
    }
    func testWrongDuplicateAndPrematureResponsesNeverPublishQuota() async throws {
        let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        var published: [Double] = []
        provider.onUpdate = { item, _ in
            if let used = item.displayWindows(now: clock.now()).first?.state.value?.usedPercent { published.append(used) }
        }
        provider.start(); await wait { await fake.methods() == ["initialize"] }
        try await fake.emit(["id": 2, "result": payload(1)]) // Quota cannot serve as initialization.
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(2)]) // No baseline yet.
        try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
        await wait { await fake.readIDs() == [2] }
        try await fake.emit(["id": 99, "result": payload(3)])
        try await fake.emit(["id": 1, "result": payload(4)])
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(5)])
        try await fake.emit(["id": 2, "result": payload(42)])
        await wait { provider.detail.codexSession == .available }
        try await fake.emit(["id": 2, "result": payload(6)])
        // An accepted notification is the ordered stream barrier after the duplicate response.
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload(43)])
        await wait { published.last == 43 }
        XCTAssertEqual(published, [42, 43])
        let methods = await fake.methods()
        XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
        provider.stop(); await provider.waitForStop()
    }
    func testOldConnectionEventsCannotCompleteReconnectedFirstRead() async throws {
        let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await establish(provider, fake)
        provider.stop(); await provider.waitForStop()
        var published: [Double] = []
        provider.onUpdate = { item, _ in
            if let used = item.displayWindows(now: clock.now()).first?.state.value?.usedPercent { published.append(used) }
        }
        provider.start(); await wait { await fake.methods().count == 4 }
        try await fake.emitFromFirstConnection(["id": 1, "result": ["userAgent": "old"]])
        try await fake.emitFromFirstConnection(["id": 2, "result": payload(1)])
        try await fake.emit(["id": 1, "result": ["userAgent": "new"]])
        await wait { await fake.readIDs() == [2, 2] }
        try await fake.emit(["id": 2, "result": payload(51)])
        await wait { provider.detail.codexSession == .available }
        XCTAssertEqual(published, [51])
        let opens = await fake.counts().0; XCTAssertEqual(opens, 2)
        provider.stop(); await provider.waitForStop()
    }
    func testInvalidConsumedFieldsFailSessionForKnownAndUnknownVersions() async throws {
        let badValues: [Any] = [true, "42", -1, 101]
        for version in ["0.160.0", "0.999.0"] {
            for value in badValues {
                let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
                let provider = CodexQuotaProvider(approved: true, clock: clock, versionLookup: { version }, makeTransport: { fake })
                provider.start(); await wait { await fake.methods() == ["initialize"] }
                try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
                await wait { await fake.readIDs() == [2] }
                try await fake.emit(["id": 2, "result": ["rateLimits": ["primary": [
                    "usedPercent": value, "windowDurationMins": 300, "resetsAt": NSNull()]]]])
                await wait { await fake.counts().1 == 1 }
                XCTAssertEqual(provider.detail.codexSession, .invalidResponse)
                XCTAssertNil(provider.item.sampledAt)
                XCTAssertEqual(clock.pending(), 0)
                provider.stop(); await provider.waitForStop()
            }
        }
    }
    func testBooleanResponseIDAndAmbiguousEnvelopeAreRejected() async throws {
        for response: [String: Any] in [
            ["id": true, "result": ["userAgent": "fixture"]],
            ["id": 1, "result": ["userAgent": "fixture"], "error": ["code": -1, "message": "fake"]],
            ["id": 1, "result": ["userAgent": false]],
            ["id": 1, "result": ["userAgent": ""]]
        ] {
            let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
            let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            try await fake.emit(response)
            await wait { await fake.counts().1 == 1 }
            XCTAssertEqual(provider.detail.codexSession, .invalidResponse)
            XCTAssertNil(provider.item.sampledAt)
            let methods = await fake.methods(); XCTAssertEqual(methods, ["initialize"])
            provider.stop(); await provider.waitForStop()
        }
    }
    func testTransientHandshakeAndReadFailureRecoverOnlyAfterNewBaseline() async throws {
        for failHandshake in [true, false] {
            let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
            let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            if !failHandshake {
                try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
                await wait { await fake.readIDs() == [2] }
            }
            try await fake.emit(["id": failHandshake ? 1 : 2, "error": ["code": -1, "message": "fixture transient failure"]])
            await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
            XCTAssertEqual(provider.detail.codexSession, failHandshake ? .handshakeFailed : .quotaRequestFailed)
            XCTAssertNil(provider.item.sampledAt)
            clock.advance(1)
            await wait { await fake.methods().filter { $0 == "initialize" }.count == 2 }
            XCTAssertNil(provider.item.sampledAt)
            try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
            await wait { await fake.readIDs().count == (failHandshake ? 1 : 2) }
            try await fake.emit(["id": 2, "result": payload(27)])
            await wait { provider.detail.codexSession == .available }
            XCTAssertEqual(provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent, 27)
            XCTAssertEqual(provider.item.freshness, .fresh)
            let counts = await fake.counts(); XCTAssertEqual(counts.0, 2)
            provider.stop(); await provider.waitForStop()
        }
    }
    func testMissingExecutableReportsCLIUnavailableWithoutOwnerProcess() async {
        let clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock,
                                         makeTransport: { NativeCodexQuotaTransport(executable: nil) })
        provider.start()
        await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        XCTAssertEqual(provider.detail.codexSession, .cliUnavailable)
        XCTAssertTrue(provider.item.entirelyUnavailable)
        provider.stop(); await provider.waitForStop()
        XCTAssertEqual(clock.pending(), 0)
    }
    func testStopDuringHandshakeAndFirstReadClosesWithoutPublishingLateResponses() async throws {
        for stopAfterHandshake in [false, true] {
            let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
            let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            if stopAfterHandshake {
                try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
                await wait { await fake.readIDs() == [2] }
            }
            provider.stop(); await provider.waitForStop()
            try await fake.emitFromFirstConnection(["id": 2, "result": payload(1)])
            XCTAssertEqual(provider.detail.codexSession, .stopped)
            XCTAssertTrue(provider.item.entirelyUnavailable)
            XCTAssertEqual(clock.pending(), 0)
            let counts = await fake.counts(); XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
        }
    }
    func testStopFromFirstReadPublicationCannotInstallVerificationTimer() async throws {
        let fake = FakeQuotaTransport(), clock = ManualQuotaClock()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        var receivedBaseline = false
        provider.onUpdate = { [weak provider] _, detail in
            if detail.codexSession == .available { receivedBaseline = true; provider?.stop() }
        }
        provider.start(); await wait { await fake.methods() == ["initialize"] }
        try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
        await wait { await fake.readIDs() == [2] }
        try await fake.emit(["id": 2, "result": payload()])
        await wait { receivedBaseline }
        await provider.waitForStop()
        XCTAssertEqual(provider.detail.codexSession, .stopped)
        XCTAssertEqual(clock.pending(), 0)
        let methods = await fake.methods(), counts = await fake.counts()
        XCTAssertEqual(methods, ["initialize", "initialized", "account/rateLimits/read"])
        XCTAssertEqual(counts.1, 1)
        XCTAssertTrue(provider.item.entirelyUnavailable)
    }
    func testStopDuringVersionLookupCannotLaunchTransportAfterLateResult() async {
        let fake = FakeQuotaTransport(), gate = QuotaVersionGate()
        let provider = CodexQuotaProvider(approved: true, versionLookup: { await gate.read() }, makeTransport: { fake })
        provider.start(); await wait { await gate.hasEntered() }
        provider.stop()
        await gate.release("0.999.0")
        await provider.waitForStop()
        let counts = await fake.counts(); XCTAssertEqual(counts.0, 0)
        XCTAssertEqual(provider.detail.codexSession, .stopped)
        XCTAssertNil(provider.detail.version)
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
        XCTAssertEqual(provider.detail.codexSession, .cliUnavailable)
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
        try await fake.emit(["id": 1, "result": ["userAgent": "test"]])
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
        XCTAssertEqual(provider.detail.codexSession, .invalidResponse)
        XCTAssertEqual(provider.item.freshness, .stale)
        XCTAssertEqual(provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent, 42)
        provider.stop(); await provider.waitForStop()
    }
    func testHandshakeTimeoutUsesInjectedClockAndClosesChild() async {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        provider.start(); await wait { clock.pending() == 1 }
        clock.advance(10)
        await wait { provider.detail.connection == .reconnecting }
        XCTAssertEqual(provider.detail.codexSession, .handshakeTimeout)
        let closes = await fake.counts().1; XCTAssertEqual(closes, 1)
        provider.stop(); await provider.waitForStop()
    }
    func testHandshakeTimeoutPublishesBeforeHeldCloseWithoutAnotherEvent() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await whileCloseIsHeld(provider, fake) {
            provider.start(); await wait { clock.pending() == 1 }
            clock.advance(10)
            await wait { await fake.closeEntryCount() >= 1 }
            // No stream event or close completion has occurred after the deadline.
            XCTAssertEqual(provider.detail.codexSession, .handshakeTimeout)
            XCTAssertEqual(provider.detail.connection, .unavailable)
            XCTAssertEqual(provider.item, .unavailable(.codex))
            let counts = await fake.counts()
            XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 0)
        }
        XCTAssertEqual(provider.detail.codexSession, .stopped)
        XCTAssertEqual(clock.pending(), 0)
        let counts = await fake.counts()
        XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
    }
    func testFirstReadTimeoutPublishesBeforeHeldCloseWithoutAnotherEvent() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await whileCloseIsHeld(provider, fake) {
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
            await wait { await fake.readIDs() == [2] }
            await wait { clock.pending() == 1 }; clock.advance(10)
            await wait { await fake.closeEntryCount() >= 1 }
            XCTAssertEqual(provider.detail.codexSession, .requestTimeout)
            XCTAssertEqual(provider.detail.connection, .unavailable)
            XCTAssertEqual(provider.item, .unavailable(.codex, failed: true))
            XCTAssertNil(provider.item.sampledAt)
            let counts = await fake.counts()
            XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 0)
        }
        XCTAssertEqual(clock.pending(), 0)
        let counts = await fake.counts()
        XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
    }
    func testVerificationTimeoutStalesBaselineBeforeHeldCloseWithoutAnotherEvent() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        try await whileCloseIsHeld(provider, fake) {
            try await establish(provider, fake)
            let original = provider.item
            await wait { clock.pending() == 1 }; clock.advance(240)
            await wait { await fake.readIDs() == [2, 3] }
            await wait { clock.pending() == 1 }; clock.advance(10)
            await wait { await fake.closeEntryCount() >= 1 }
            XCTAssertEqual(provider.detail.codexSession, .requestTimeout)
            XCTAssertEqual(provider.detail.connection, .unavailable)
            XCTAssertEqual(provider.item.freshness, .stale)
            XCTAssertEqual(provider.item.fiveHour, original.fiveHour)
            XCTAssertEqual(provider.item.weekly, original.weekly)
            XCTAssertEqual(provider.item.source, original.source)
            XCTAssertEqual(provider.item.sampledAt, original.sampledAt)
            let counts = await fake.counts(), ids = await fake.readIDs()
            XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 0)
            XCTAssertEqual(ids, [2, 3])
        }
        XCTAssertEqual(clock.pending(), 0)
        let counts = await fake.counts()
        XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
    }
    func testTimeoutPublicationCanStopAndRestartWithoutOldCleanupOverwritingNewSession() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport(), replacement = FakeQuotaTransport()
        var transportsMade = 0
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: {
            transportsMade += 1
            return transportsMade == 1 ? fake : replacement
        })
        var timeoutSeen = false
        var freshAfterTimeout = 0
        provider.onUpdate = { item, detail in
            if timeoutSeen && detail.codexSession == .available { freshAfterTimeout += 1 }
            if detail.codexSession == .requestTimeout && !timeoutSeen {
                timeoutSeen = true
                XCTAssertEqual(item.fiveHour, .requestFailed)
                provider.stop()
                provider.start()
            }
        }
        try await whileCloseIsHeld(provider, fake) {
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
            await wait { await fake.readIDs() == [2] }
            await wait { clock.pending() == 1 }; clock.advance(10)
            await wait { await fake.closeEntryCount() >= 1 }
            XCTAssertTrue(timeoutSeen)
            XCTAssertEqual(provider.detail.codexSession, .stopped)
            XCTAssertEqual(freshAfterTimeout, 0)
            XCTAssertEqual(clock.pending(), 0)
            let heldCounts = await fake.counts()
            XCTAssertEqual(heldCounts.0, 1); XCTAssertEqual(heldCounts.1, 0)
            await fake.releaseClose()
            await wait { await replacement.methods() == ["initialize"] }
            XCTAssertEqual(provider.detail.codexSession, .handshaking)
            try await replacement.emit(["id": 1, "result": ["userAgent": "new fixture"]])
            await wait { await replacement.readIDs() == [2] }
            try await replacement.emit(["id": 2, "result": payload(17)])
            await wait { provider.detail.codexSession == .available && clock.pending() == 1 }
            XCTAssertEqual(provider.item.freshness, .fresh)
            XCTAssertEqual(provider.item.displayWindows(now: clock.now()).first?.state.value?.usedPercent, 17)
            XCTAssertEqual(freshAfterTimeout, 1)
            let counts = await fake.counts()
            XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
            let newCounts = await replacement.counts()
            XCTAssertEqual(newCounts.0, 1); XCTAssertEqual(newCounts.1, 0)
            XCTAssertEqual(transportsMade, 2)
        }
        XCTAssertEqual(provider.detail.codexSession, .stopped)
        XCTAssertEqual(clock.pending(), 0)
        let counts = await fake.counts()
        XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
        let newCounts = await replacement.counts()
        XCTAssertEqual(newCounts.0, 1); XCTAssertEqual(newCounts.1, 1)
        XCTAssertEqual(transportsMade, 2)
    }
    func testExpiredFirstReadRejectsLateResponseWhileTransportCloseIsHeld() async throws {
        let clock = ManualQuotaClock(), fake = FakeQuotaTransport()
        let provider = CodexQuotaProvider(approved: true, clock: clock, makeTransport: { fake })
        var availablePublications = 0
        provider.onUpdate = { _, detail in
            if detail.codexSession == .available { availablePublications += 1 }
        }
        try await whileCloseIsHeld(provider, fake) {
            provider.start(); await wait { await fake.methods() == ["initialize"] }
            try await fake.emit(["id": 1, "result": ["userAgent": "fixture"]])
            await wait { await fake.readIDs() == [2] }
            await wait { clock.pending() == 1 }
            clock.advance(10)
            await wait { await fake.closeEntryCount() == 1 }
            // The watchdog has expired but the child/stream deliberately remains open.
            XCTAssertEqual(provider.detail.codexSession, .requestTimeout)
            XCTAssertEqual(provider.detail.connection, .unavailable)
            XCTAssertEqual(provider.item, .unavailable(.codex, failed: true))
            try await fake.emit(["id": 2, "result": payload(91)])
            // The late event must leave the stream and enter run-loop cleanup, not publish a baseline.
            await wait { await fake.closeEntryCount() == 2 }
            XCTAssertEqual(provider.detail.codexSession, .requestTimeout)
            XCTAssertEqual(availablePublications, 0)
            XCTAssertNil(provider.item.sampledAt)
            XCTAssertEqual(provider.item.fiveHour, .requestFailed)
            await fake.releaseClose()
            await wait { provider.detail.connection == .reconnecting && clock.pending() == 1 }
        }
        XCTAssertEqual(clock.pending(), 0)
        let counts = await fake.counts()
        XCTAssertEqual(counts.0, 1); XCTAssertEqual(counts.1, 1)
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
        var barrierSeen = false
        var published: [QuotaItem] = []
        provider.onUpdate = { item, _ in published.append(item); barrierSeen = true }
        try await fake.emit(["method": "thread/started", "params": ["fake": "discard"]])
        try await fake.emit(["method": "account/rateLimits/updated", "params": payload()])
        await wait { barrierSeen }
        XCTAssertEqual(published, [original])
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

private actor HardeningSystemSampler: SystemSampling {
    private(set) var active = 0
    private(set) var maximumActive = 0
    func start() { active += 1; maximumActive = max(maximumActive, active) }
    func stop() { active -= 1 }
    func sample() -> SystemReading { SystemReading(cpuPercent: nil, memory: nil, pressure: .unknown) }
}
private actor HardeningDetailSampler: SystemDetailSampling {
    func start() { }
    func stop() { }
    func sampleDisk(now: Date) -> DiskReading { .unavailable(sampledAt: now) }
    func sampleBattery(now: Date) -> BatteryReading { .notPresent(sampledAt: now) }
    func sampleProcesses(now: Date, uptime: TimeInterval) -> ProcessReading { .available([], sampledAt: now) }
}
private actor HardeningDevRunner: ShellRunning {
    var failPorts = false
    func fail() { failPorts = true }
    func run(_ command: ShellCommand) throws -> ShellResult {
        if command.executableURL.lastPathComponent == "lsof", failPorts { throw ShellRunnerError.timeout }
        return ShellResult(stdout: "", stderr: "", exitCode: 0, terminationReason: .exit, outputTruncated: false, duration: 0)
    }
}
@MainActor final class PerformanceLifecycleIntegrationTests: XCTestCase {
    private func store(path: FakeNetworkPath? = nil,
                       sampler: HardeningSystemSampler = HardeningSystemSampler(),
                       runner: HardeningDevRunner = HardeningDevRunner(),
                       codex: FixtureQuotaProvider? = nil,
                       scanner: CleanerScanner = CleanerScanner()) -> AppStore {
        // AppStore currently reads standard defaults directly. Override only the process-local
        // argument domain during synchronous construction; never write the owner's preferences.
        let defaults = UserDefaults.standard
        let previous = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        var fixture = previous
        fixture["macsoul.connectivityEnabled"] = true
        defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(previous, forName: UserDefaults.argumentDomain) }
        return AppStore(sampler: sampler, details: HardeningDetailSampler(),
                 devRuntimes: RuntimeDetector(runner: runner, environment: [:], home: URL(fileURLWithPath: "/MacSoul-Test-No-Home")),
                 devPorts: PortDetector(runner: runner), networkPath: path ?? FakeNetworkPath(),
                 networkHTTP: NoQuotaTestHTTP(), networkLocal: FakeLocalNetwork(),
                 cleanerScanner: scanner, codexQuota: codex ?? FixtureQuotaProvider(.codex), claudeQuota: FixtureQuotaProvider(.claude))
    }
    private func wait(_ condition: @escaping () -> Bool) async {
        for _ in 0..<10_000 { if condition() { return }; await Task.yield() }
        XCTFail("Injected work did not complete")
    }
    func testSystemBackgroundMenuAndReopenPolicyWithoutExtraCollectors() async {
        let store = store(), id = UUID()
        store.setSystemMode(.live)
        XCTAssertEqual(store.sensorInterval, 10)
        for _ in 0..<10 {
            store.setWindow(id, visible: true, section: .system)
            XCTAssertEqual(store.sensorInterval, 1)
            store.setWindowSection(id, section: .overview)
            XCTAssertEqual(store.sensorInterval, 5)
            store.setWindow(id, visible: false, section: .overview)
            XCTAssertEqual(store.sensorInterval, 10)
        }
        XCTAssertEqual(store.sensorStarts, 1); XCTAssertEqual(store.devStarts, 1)
        XCTAssertEqual(store.networkStarts, 1); XCTAssertEqual(store.quotaStarts, 1)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
    }
    func testMultipleMainWindowsResolveRelevantPolicyAndHiddenWindowCannotPromote() async {
        let store = store(), first = UUID(), second = UUID()
        store.setWindow(first, visible: true, section: .overview)
        store.setWindow(second, visible: true, section: .system)
        XCTAssertEqual(store.systemSamplingTier, .foregroundRelevant)
        store.setWindow(second, visible: true, section: .dev)
        XCTAssertEqual(store.systemSamplingTier, .foregroundBackground)
        XCTAssertEqual(store.devSamplingTier, .foregroundRelevant)
        store.setWindow(second, visible: false, section: .system)
        XCTAssertEqual(store.systemSamplingTier, .foregroundBackground)
        XCTAssertEqual(store.devSamplingTier, .foregroundBackground)
        store.setWindowSection(second, section: .system)
        XCTAssertEqual(store.systemSamplingTier, .foregroundBackground)
        store.setWindow(first, visible: false, section: .overview)
        XCTAssertEqual(store.systemSamplingTier, .menuBarOnly)
        await store.stopQuotaForTermination()
    }
    func testDevPageFastPortsMenuBackgroundAndAIIntervalUnchanged() async {
        let store = store(), id = UUID()
        store.setSystemMode(.live)
        store.setWindow(id, visible: true, section: .dev)
        XCTAssertEqual(store.devPortInterval, 10)
        XCTAssertEqual(store.sensorInterval, 5)
        store.setWindowSection(id, section: .ai)
        XCTAssertEqual(store.devPortInterval, 60)
        XCTAssertEqual(CodexQuotaProvider.verificationInterval, 240)
        store.setWindow(id, visible: false, section: .ai)
        XCTAssertEqual(store.devPortInterval, 60)
        XCTAssertEqual(store.devSamplingTier, .menuBarOnly)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
    }
    func testLivePreviewRoundTripSingleActiveSourceNoCleanerAutoScan() async {
        let sampler = HardeningSystemSampler(), scanner = CleanerScanner()
        let store = store(sampler: sampler, scanner: scanner), id = UUID()
        for _ in 0..<3 {
            store.setSystemMode(.live); store.setSystemMode(.live)
            store.setWindow(id, visible: true, section: .cleaner)
            XCTAssertEqual(store.snapshot.cleaner.state, .notRun)
            XCTAssertFalse(store.cleanerRunning); XCTAssertFalse(store.cleanerPreviewRunning)
            store.setSystemMode(.preview)
            await store.waitForCollectorsToStop()
            XCTAssertTrue(store.snapshot.quotas.allSatisfy { $0.mode == .mock })
            XCTAssertFalse(store.collectorsRunning.system); XCTAssertFalse(store.collectorsRunning.dev)
            XCTAssertFalse(store.collectorsRunning.network); XCTAssertFalse(store.collectorsRunning.quota)
        }
        XCTAssertEqual(store.sensorStarts, 3); XCTAssertEqual(store.devStarts, 3)
        XCTAssertEqual(store.networkStarts, 3); XCTAssertEqual(store.quotaStarts, 3)
        let maximum = await sampler.maximumActive, scans = await scanner.starts
        XCTAssertLessThanOrEqual(maximum, 1); XCTAssertEqual(scans, 0)
    }
    func testSleepStopsEverythingWakeStartsOncePreviewWakeDoesNothing() async {
        let store = store()
        store.setSystemMode(.live)
        store.suspendForSleep(); store.suspendForSleep()
        await store.waitForCollectorsToStop()
        XCTAssertFalse(store.collectorsRunning.system); XCTAssertFalse(store.collectorsRunning.dev)
        XCTAssertFalse(store.collectorsRunning.network); XCTAssertFalse(store.collectorsRunning.quota)
        XCTAssertTrue(store.snapshot.quotas.allSatisfy(\.entirelyUnavailable))
        store.resumeAfterWake(); store.resumeAfterWake()
        XCTAssertEqual(store.sensorStarts, 2); XCTAssertEqual(store.devStarts, 2)
        XCTAssertEqual(store.networkStarts, 2); XCTAssertEqual(store.quotaStarts, 2)
        XCTAssertEqual(store.snapshot.cleaner.state, .notRun)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
        store.suspendForSleep(); store.resumeAfterWake()
        XCTAssertEqual(store.sensorStarts, 2); XCTAssertEqual(store.quotaStarts, 2)
    }
    func testNetworkPathEventDoesNotRestartOtherModulesOrScan() async {
        let path = FakeNetworkPath(), scanner = CleanerScanner(), store = store(path: path, scanner: scanner)
        store.setSystemMode(.live)
        path.send(NetworkPathReading(state: .unsatisfied))
        XCTAssertEqual(store.snapshot.network.path.state, .unsatisfied)
        XCTAssertEqual(store.sensorStarts, 1); XCTAssertEqual(store.devStarts, 1)
        XCTAssertEqual(store.quotaStarts, 1); XCTAssertEqual(store.networkStarts, 1)
        XCTAssertFalse(store.cleanerRunning)
        let scans = await scanner.starts; XCTAssertEqual(scans, 0)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
    }
    func testRetiredQuotaAndPathCallbacksCannotLeakAfterSleepOrPreview() async {
        let path = FakeNetworkPath(), codex = FixtureQuotaProvider(.codex), store = store(path: path, codex: codex)
        store.setSystemMode(.live)
        let oldPath = path.receive, oldQuota = codex.onUpdate
        store.suspendForSleep(); await store.waitForCollectorsToStop(); store.resumeAfterWake()
        let before = store.snapshot
        oldPath?(NetworkPathReading(state: .satisfied))
        oldQuota?(MockProvider(fixture: .quota95).snapshot(now: Date()).quotas[0], codex.detail)
        XCTAssertEqual(store.snapshot.network, before.network)
        XCTAssertEqual(store.snapshot.quotas, before.quotas)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
    }
    func testTerminationCancelsAllCollectorsAndPreventsResurrection() async {
        let store = store(); store.setSystemMode(.live)
        await store.stopQuotaForTermination(); await store.stopQuotaForTermination()
        XCTAssertFalse(store.collectorsRunning.system); XCTAssertFalse(store.collectorsRunning.dev)
        XCTAssertFalse(store.collectorsRunning.network); XCTAssertFalse(store.collectorsRunning.quota)
        store.setSystemMode(.preview); store.setSystemMode(.live); store.resumeAfterWake()
        XCTAssertEqual(store.sensorStarts, 1); XCTAssertEqual(store.devStarts, 1)
        XCTAssertEqual(store.quotaStarts, 1); XCTAssertEqual(store.networkStarts, 1)
        XCTAssertFalse(store.cleanerRunning); XCTAssertNil(store.cleanerPreviewDestination)
    }
    func testDisplayClockDoesNotChangeSnapshotOrRestartProviders() async {
        let store = store(); store.setSystemMode(.live)
        let quota = store.snapshot.quotas, starts = store.quotaStarts
        for i in 1...5 { store.advanceDisplayClock(now: Date(timeIntervalSince1970: Double(i * 60))) }
        XCTAssertEqual(store.snapshot.quotas, quota); XCTAssertEqual(store.quotaStarts, starts)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
    }
    func testFailureStatesRemainDistinctInSharedSnapshot() async {
        let path = FakeNetworkPath(), runner = HardeningDevRunner()
        await runner.fail()
        let store = store(path: path, runner: runner)
        store.setSystemMode(.live); path.send(NetworkPathReading(state: .unsatisfied))
        await wait { store.snapshot.batteryReading != .unknown && store.snapshot.diskReading != .unknown && store.snapshot.portReading?.state == .timeout }
        XCTAssertNil(store.snapshot.cpu.usedPercent); XCTAssertNil(store.snapshot.memoryUsed.usedPercent)
        XCTAssertEqual(store.snapshot.memoryPressure, MemoryPressureLevel.unknown.liveLabel)
        XCTAssertEqual(store.snapshot.diskEmptyState, "Unavailable")
        XCTAssertEqual(store.snapshot.batterySummaryOverride, "No battery")
        XCTAssertEqual(store.snapshot.network.connectivityDisplay(.english), "Offline")
        XCTAssertTrue(store.snapshot.quotas.allSatisfy(\.entirelyUnavailable))
        XCTAssertEqual(store.snapshot.cleaner.state, .notRun)
        store.setSystemMode(.preview); await store.waitForCollectorsToStop()
    }
    func testMenuProcessCadenceAndDiskRemainIndependent() {
        var cadence = DetailCadence()
        XCTAssertTrue(cadence.due(at: 0, systemVisible: false, mainVisible: false).processes)
        XCTAssertFalse(cadence.due(at: 15, systemVisible: false, mainVisible: false).processes)
        XCTAssertTrue(cadence.due(at: 30, systemVisible: false, mainVisible: false).processes)
        XCTAssertFalse(cadence.due(at: 59, systemVisible: false, mainVisible: false).disk)
        XCTAssertTrue(cadence.due(at: 60, systemVisible: false, mainVisible: false).disk)
        XCTAssertTrue(cadence.due(at: 63, systemVisible: true, mainVisible: true).processes)
    }
    func testDevSleepsToDeadlineWithoutFiveSecondPolling() {
        var cadence = DevCadence(); cadence.markPortsSampled(at: 0)
        XCTAssertEqual(cadence.nextDelay(at: 0, visible: false, lastRuntimeSample: 0), 60)
        XCTAssertEqual(cadence.nextDelay(at: 0, visible: true, lastRuntimeSample: 0), 10)
        cadence.markPortsSampled(at: 290)
        XCTAssertEqual(cadence.nextDelay(at: 290, visible: false, lastRuntimeSample: 0), 10)
    }
}
