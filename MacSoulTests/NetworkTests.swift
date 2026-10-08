import XCTest
import Network
@testable import MacSoul

@MainActor final class FakeNetworkPath: NetworkPathProviding {
    var receive: (@MainActor (NetworkPathReading) -> Void)?
    var starts = 0
    var stops = 0
    func start(_ receive: @escaping @MainActor (NetworkPathReading) -> Void) {
        guard self.receive == nil else { return }
        starts += 1; self.receive = receive
    }
    func stop() { stops += 1; receive = nil }
    func send(_ reading: NetworkPathReading) { receive?(reading) }
}
struct FakeLocalNetwork: LocalNetworkProviding {
    var reading = LocalNetworkReading(environment: ProxyReading(), system: ProxyReading(), tunnel: TunnelReading())
    func read() async -> LocalNetworkReading { reading }
}
private actor FakeNetworkHTTP: NetworkHTTPClient {
    struct Call { let url: URL; let method: String; let maxBytes: Int }
    private let trace: NetworkTestTrace?
    private let time: ManualNetworkTime?
    init(trace: NetworkTestTrace? = nil, time: ManualNetworkTime? = nil) { self.trace = trace; self.time = time }
    var calls: [Call] = []
    var answers: [String: Result<NetworkHTTPResponse, NetworkFailure>] = [:]
    var held = false
    var waiting: [UUID: CheckedContinuation<NetworkHTTPResponse, Error>] = [:]
    var cancellations = 0
    // Test-only entry gate: IPv4 may publish before IPv6 even enters its request.
    private var delayedHosts: Set<String> = []
    private var entryWaiters: [UUID: (String, CheckedContinuation<Void, Error>)] = [:]
    func delayEntry(_ url: URL) { delayedHosts.insert(url.host!) }
    func pendingEntryCount() -> Int { entryWaiters.count }
    func releaseEntry(_ url: URL) {
        delayedHosts.remove(url.host!)
        for (id, entry) in entryWaiters.filter({ $0.value.0 == url.host! }) {
            entryWaiters.removeValue(forKey: id); entry.1.resume()
        }
    }
    private func cancelEntry(_ id: UUID) {
        entryWaiters.removeValue(forKey: id)?.1.resume(throwing: CancellationError())
    }
    func set(_ url: URL, status: Int = 200, text: String = "") {
        answers[url.host!] = .success(NetworkHTTPResponse(status: status, body: Data(text.utf8)))
    }
    func fail(_ url: URL, error: NetworkFailure) { answers[url.host!] = .failure(error) }
    func hold() { held = true }
    func count() -> Int { calls.count }
    func probeCount() -> Int { calls.filter { $0.method == "HEAD" }.count }
    func ipCount() -> Int { calls.filter { $0.method == "GET" }.count }
    func cancelledCount() -> Int { cancellations }
    func cancel(_ id: UUID) { if let value = waiting.removeValue(forKey: id) { cancellations += 1; value.resume(throwing: CancellationError()) } }
    func request(url: URL, method: String, maxBytes: Int) async throws -> NetworkHTTPResponse {
        try Task.checkCancellation()
        if delayedHosts.contains(url.host!) {
            let id = UUID()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                    else { entryWaiters[id] = (url.host!, continuation) }
                }
            } onCancel: { Task { await self.cancelEntry(id) } }
            try Task.checkCancellation()
        }
        trace?.record("request-enter time=\(time?.uptime() ?? 0) method=\(method) service=\(url.host ?? "fake")")
        defer { trace?.record("request-complete time=\(time?.uptime() ?? 0) method=\(method) service=\(url.host ?? "fake")") }
        calls.append(Call(url: url, method: method, maxBytes: maxBytes))
        if held {
            let id = UUID()
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                    else { waiting[id] = continuation }
                }
            } onCancel: { Task { await self.cancel(id) } }
        }
        if let answer = answers[url.host!] { return try answer.get() }
        return NetworkHTTPResponse(status: 200, body: Data((url.host == "api.ipify.org" ? "192.0.2.1" : "2001:db8::1").utf8))
    }
}
private final class NetworkTestTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    func record(_ event: String) { lock.lock(); events.append(event); lock.unlock() }
    func dump() { lock.lock(); let copy = events; lock.unlock(); print("NETWORK_EVENTS\n" + copy.joined(separator: "\n")) }
}
private final class ManualNetworkTime: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    let trace: NetworkTestTrace
    init(trace: NetworkTestTrace = NetworkTestTrace()) { self.trace = trace }
    func withTime<T>(_ body: (inout TimeInterval) -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body(&value)
    }
    func uptime() -> TimeInterval { withTime { $0 } }
    // Synchronous main-actor stimulus only. Timer advances use the registered ticket.
    func set(_ time: TimeInterval) { withTime { trace.record("time-set \($0) -> \(time)"); $0 = time } }
    func date() -> Date { Date(timeIntervalSince1970: uptime()) }
}
// Test-only gate between the monitor's relative-duration read and sleep registration.
private final class NetworkSleepEntryGate: @unchecked Sendable {
    private let lock = NSLock()
    private let trace: NetworkTestTrace
    init(trace: NetworkTestTrace = NetworkTestTrace()) { self.trace = trace }
    private var heldSeconds: TimeInterval?
    private var entries: [UUID: CheckedContinuation<Void, Error>] = [:]
    func hold(_ seconds: TimeInterval) { lock.lock(); heldSeconds = seconds; lock.unlock(); trace.record("entry-gate-hold seconds=\(seconds)") }
    func count() -> Int { lock.lock(); defer { lock.unlock() }; return entries.count }
    func release() {
        lock.lock(); heldSeconds = nil; let copy = entries; entries = [:]; lock.unlock()
        for (id, entry) in copy { trace.record("entry-gate-release id=\(id)"); entry.resume() }
    }
    private func cancel(_ id: UUID) {
        lock.lock(); let entry = entries.removeValue(forKey: id); lock.unlock()
        trace.record("entry-gate-cancel id=\(id) removed=\(entry != nil)")
        entry?.resume(throwing: CancellationError())
    }
    func enter(_ seconds: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (entry: CheckedContinuation<Void, Error>) in
                lock.lock()
                if Task.isCancelled { lock.unlock(); entry.resume(throwing: CancellationError()) }
                else if heldSeconds == seconds { entries[id] = entry; lock.unlock(); trace.record("entry-gate-wait id=\(id) seconds=\(seconds)") }
                else { lock.unlock(); entry.resume() }
            }
        } onCancel: { self.cancel(id) }
    }
}
private final class ManualNetworkSleeper: @unchecked Sendable {
    struct Ticket: Equatable { let id: Int; let deadline: TimeInterval }
    private struct Entry { let ticket: Ticket; let continuation: CheckedContinuation<Void, Error> }
    private let time: ManualNetworkTime
    // All entries, IDs and clock changes share the same lock. Cancellation removes
    // synchronously; a cancelled entry can never satisfy a readiness handshake.
    private var nextID = 0
    private var pending: [Int: Entry] = [:]
    init(time: ManualNetworkTime) { self.time = time }
    func wait(seconds: TimeInterval) async throws {
        let id = time.withTime { _ in nextID += 1; return nextID }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let immediate: Result<Void, Error>? = time.withTime { now in
                    if Task.isCancelled {
                        time.trace.record("cancel-before-register id=\(id) time=\(now)")
                        return .failure(CancellationError())
                    }
                    let ticket = Ticket(id: id, deadline: now + seconds)
                    time.trace.record("register id=\(id) time=\(now) deadline=\(ticket.deadline)")
                    if ticket.deadline <= now { return .success(()) }
                    pending[id] = Entry(ticket: ticket, continuation: continuation); return nil
                }
                if let immediate { continuation.resume(with: immediate) }
            }
        } onCancel: { self.cancel(id) }
    }
    private func cancel(_ id: Int) {
        let entry = time.withTime { now in
            let entry = pending.removeValue(forKey: id)
            time.trace.record("cancel/remove id=\(id) time=\(now) registered=\(entry != nil)")
            return entry
        }
        entry?.continuation.resume(throwing: CancellationError())
    }
    func ticket(deadline: TimeInterval) -> Ticket? {
        time.withTime { _ in pending.values.first { $0.ticket.deadline == deadline }?.ticket }
    }
    func count() -> Int { time.withTime { _ in pending.count } }
    // False leaves time untouched: registration, identity and deadline are checked
    // atomically with advancing, not by counting arbitrary pending continuations.
    func advance(to value: TimeInterval, requiring ticket: Ticket) -> Bool {
        let due: [Entry]? = time.withTime { now in
            guard pending[ticket.id]?.ticket == ticket, value >= now else { return nil }
            time.trace.record("advance id=\(ticket.id) deadline=\(ticket.deadline) \(now) -> \(value)")
            now = value
            let due = pending.values.filter { $0.ticket.deadline <= value }
            for entry in due { pending.removeValue(forKey: entry.ticket.id) }
            return due
        }
        guard let due else { return false }
        for entry in due {
            time.trace.record("resume id=\(entry.ticket.id) deadline=\(entry.ticket.deadline)")
            entry.continuation.resume()
        }
        return true
    }
}
@MainActor private final class NetworkHarness {
    let path = FakeNetworkPath()
    let time = ManualNetworkTime()
    lazy var entryGate = NetworkSleepEntryGate(trace: time.trace)
    lazy var client = FakeNetworkHTTP(trace: time.trace, time: time)
    lazy var sleeper = ManualNetworkSleeper(time: time)
    lazy var monitor = NetworkMonitor(path: path, client: client, local: FakeLocalNetwork(),
        clock: NetworkClock(now: { [time] in time.date() }, uptime: { [time] in time.uptime() },
                            sleep: { [time, sleeper, entryGate] seconds in
                                time.trace.record("sleep-entry time=\(time.uptime()) seconds=\(seconds)")
                                try await entryGate.enter(seconds)
                                try await sleeper.wait(seconds: seconds)
                            }), onSnapshot: { _ in })
    func online(_ kind: NetworkInterfaceKind = .wifi) {
        time.trace.record("path time=\(time.uptime()) kind=\(kind)")
        path.send(NetworkPathReading(state: .satisfied, interfaces: [kind], interfaceNames: ["en0"],
                                     expensive: false, constrained: false, supportsIPv4: true, supportsIPv6: true))
    }
    func advance(_ to: TimeInterval, registered deadline: TimeInterval,
                 file: StaticString = #filePath, line: UInt = #line) async -> Bool {
        time.trace.record("handshake-wait time=\(time.uptime()) deadline=\(deadline) target=\(to)")
        let limit = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < limit {
            if let ticket = sleeper.ticket(deadline: deadline), sleeper.advance(to: to, requiring: ticket) {
                time.trace.record("handshake-success id=\(ticket.id)"); return true
            }
            await Task.yield()
        }
        time.trace.record("handshake-failure deadline=\(deadline)")
        XCTFail("Expected live timer registration at \(deadline)", file: file, line: line)
        await stop(); return false
    }
    func stop() async {
        monitor.stop(); entryGate.release(); await monitor.waitForStop()
        // Stop does not join timers. Synchronous cancellation already removed
        // their entries; gated entries observe Task.isCancelled before registration.
        XCTAssertEqual(sleeper.count(), 0); XCTAssertEqual(entryGate.count(), 0)
        time.trace.dump()
    }
}

final class NetworkTests: XCTestCase {
    @discardableResult @MainActor private func eventually(_ condition: () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async -> Bool {
        let limit = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < limit {
            if await condition() { return true }
            await Task.yield()
        }
        XCTFail("Deterministic fake work did not complete", file: file, line: line)
        return false
    }
    @MainActor private func completed(_ h: NetworkHarness, file: StaticString = #filePath, line: UInt = #line) async -> Bool {
        h.time.trace.record("batch-wait time=\(h.time.uptime())")
        guard await eventually({ !h.monitor.snapshot.ipv4.checking && !h.monitor.snapshot.ipv6.checking
            && h.monitor.snapshot.probes.allSatisfy { $0.state != .checking }
            && h.monitor.snapshot.localSampledAt != nil }, file: file, line: line) else { h.time.trace.record("batch-condition-failure"); await h.stop(); return false }
        // Join is bounded as well: published family results need not mean that the
        // containing batch has finished scheduling its next timer.
        var done = false
        let join = Task { await h.monitor.waitForCurrentWork(); done = true }
        guard await eventually({ done }, file: file, line: line) else { h.time.trace.record("batch-join-failure"); await h.stop(); join.cancel(); return false }
        await join.value; h.time.trace.record("batch-join-success time=\(h.time.uptime())"); return true
    }
    @MainActor private func connected(_ h: NetworkHarness, probes: Bool = true) async -> Bool {
        h.monitor.start(probesEnabled: probes); h.online()
        guard await h.advance(0.75, registered: 0.75), await completed(h) else { return false }
        XCTAssertEqual(h.monitor.snapshot.ipv4.freshness, .fresh)
        if probes { XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .reachable }) }
        return true
    }

    @MainActor func testDelayedTimerEntryCannotShiftPathDebounceDeadline() async {
        let h = NetworkHarness(); guard await connected(h) else { return }
        guard await eventually({ h.sleeper.ticket(deadline: 60.75) != nil }),
              let old = h.sleeper.ticket(deadline: 60.75) else { await h.stop(); return }
        h.entryGate.hold(0.75)
        h.time.set(62); h.online(.ethernet)
        guard await eventually({ h.entryGate.count() == 1 }) else { await h.stop(); return }
        XCTAssertEqual(h.sleeper.count(), 0) // Cancellation does not await another actor task.
        XCTAssertFalse(h.sleeper.advance(to: 62.75, requiring: old))
        XCTAssertEqual(h.time.uptime(), 62)
        var started = false, finished = false
        let advance = Task { @MainActor in
            started = true
            let result = await h.advance(62.75, registered: 62.75)
            finished = true; return result
        }
        guard await eventually({ started }) else { await h.stop(); advance.cancel(); return }
        XCTAssertFalse(finished); XCTAssertEqual(h.time.uptime(), 62)
        XCTAssertNil(h.sleeper.ticket(deadline: 63.5))
        h.entryGate.release()
        guard await eventually({ finished }), await advance.value, await completed(h) else { await h.stop(); advance.cancel(); return }
        let count = await h.client.probeCount(); XCTAssertEqual(count, 6)
        XCTAssertEqual(h.time.uptime(), 62.75)
        XCTAssertNil(h.sleeper.ticket(deadline: 63.5))
        await h.stop()
    }
    @MainActor func testSleeperCancellationBeforeRegistrationDoesNotLeaveEntry() async {
        let time = ManualNetworkTime()
        let gate = NetworkSleepEntryGate(trace: time.trace)
        let sleeper = ManualNetworkSleeper(time: time)
        var finished = false, cancelled = false
        gate.hold(10)
        let task = Task { @MainActor in
            do { try await gate.enter(10); try await sleeper.wait(seconds: 10) }
            catch { cancelled = error is CancellationError }
            finished = true
        }
        guard await eventually({ gate.count() == 1 }) else { task.cancel(); gate.release(); return }
        task.cancel()
        guard await eventually({ finished }) else { gate.release(); return }
        await task.value; gate.release()
        XCTAssertTrue(cancelled); XCTAssertEqual(gate.count(), 0); XCTAssertEqual(sleeper.count(), 0)
        // Cancellation before the operation body also cannot register or resume twice.
        finished = false; cancelled = false
        let early = Task { @MainActor in
            do { try await sleeper.wait(seconds: 10) }
            catch { cancelled = error is CancellationError }
            finished = true
        }
        early.cancel(); early.cancel()
        guard await eventually({ finished }) else { early.cancel(); return }
        await early.value
        XCTAssertTrue(cancelled); XCTAssertEqual(sleeper.count(), 0); time.trace.dump()
    }
    @MainActor func testCancelledTicketCannotAuthorizeNewWaitOrAdvanceTime() async {
        let time = ManualNetworkTime()
        let sleeper = ManualNetworkSleeper(time: time)
        var oldCompleted = 0, newCompleted = 0, cancelled = false
        let oldTask = Task { @MainActor in
            do { try await sleeper.wait(seconds: 10) }
            catch { cancelled = error is CancellationError }
            oldCompleted += 1
        }
        guard await eventually({ sleeper.ticket(deadline: 10) != nil }),
              let old = sleeper.ticket(deadline: 10) else { oldTask.cancel(); return }
        oldTask.cancel(); oldTask.cancel()
        XCTAssertEqual(sleeper.count(), 0)
        XCTAssertFalse(sleeper.advance(to: 10, requiring: old)); XCTAssertEqual(time.uptime(), 0)
        guard await eventually({ oldCompleted == 1 }) else { return }
        await oldTask.value; XCTAssertTrue(cancelled)
        let newTask = Task { @MainActor in
            do { try await sleeper.wait(seconds: 5) } catch { XCTFail("New timer unexpectedly cancelled") }
            newCompleted += 1
        }
        guard await eventually({ sleeper.ticket(deadline: 5) != nil }),
              let current = sleeper.ticket(deadline: 5) else { newTask.cancel(); return }
        XCTAssertNotEqual(old.id, current.id)
        XCTAssertFalse(sleeper.advance(to: 5, requiring: old)); XCTAssertEqual(time.uptime(), 0)
        XCTAssertTrue(sleeper.advance(to: 4.999, requiring: current)); XCTAssertEqual(newCompleted, 0)
        XCTAssertTrue(sleeper.advance(to: 5, requiring: current))
        XCTAssertFalse(sleeper.advance(to: 5, requiring: current))
        guard await eventually({ newCompleted == 1 }) else { newTask.cancel(); return }
        await newTask.value; newTask.cancel()
        XCTAssertEqual(oldCompleted, 1); XCTAssertEqual(newCompleted, 1); XCTAssertEqual(sleeper.count(), 0)
        time.trace.dump()
    }

    func testPublicIPv4Parser() throws {
        XCTAssertEqual(try PublicIPProvider.parse(Data(" 192.0.2.8\n".utf8), family: .ipv4), "192.0.2.8")
        for value in ["256.0.0.1", "1.2.3", "192.0.2.8 extra", "<html>", "2001:db8::1", "01.2.3.4"] {
            XCTAssertThrowsError(try PublicIPProvider.parse(Data(value.utf8), family: .ipv4))
        }
    }
    func testPublicIPv6Parser() throws {
        XCTAssertEqual(try PublicIPProvider.parse(Data("2001:db8::1".utf8), family: .ipv6), "2001:db8::1")
        for value in ["gggg::1", "2001::db8::1", "192.0.2.1", "fe80::1%en0", "", "2001:db8::1\nextra"] {
            XCTAssertThrowsError(try PublicIPProvider.parse(Data(value.utf8), family: .ipv6))
        }
    }
    func testIPResponseSizeBound() {
        XCTAssertThrowsError(try PublicIPProvider.parse(Data(repeating: 65, count: 1025), family: .ipv4)) { XCTAssertEqual($0 as? NetworkFailure, .tooLarge) }
    }
    func testHTTPFailuresDistinctFromTimeout() async {
        let client = FakeNetworkHTTP(), url = PublicIPProvider.endpoint(.ipv4)
        await client.set(url, status: 503)
        do { _ = try await PublicIPProvider(client: client).fetch(.ipv4); XCTFail() }
        catch { XCTAssertEqual(error as? NetworkFailure, .http) }
        await client.fail(url, error: .timeout)
        do { _ = try await PublicIPProvider(client: client).fetch(.ipv4); XCTFail() }
        catch { XCTAssertEqual(networkFailure(error), .timeout) }
        XCTAssertEqual(networkFailure(URLError(.timedOut)), .timeout)
        XCTAssertEqual(networkFailure(URLError(.cannotFindHost)), .transport)
    }
    func testEphemeralSessionHasNoPersistentCredentialsCookiesOrCache() {
        let config = EphemeralNetworkHTTPClient.configuration()
        XCTAssertNil(config.urlCredentialStorage); XCTAssertNil(config.httpCookieStorage); XCTAssertNil(config.urlCache)
        XCTAssertFalse(config.httpShouldSetCookies)
        XCTAssertEqual(config.timeoutIntervalForRequest, 4); XCTAssertEqual(config.timeoutIntervalForResource, 5)
    }
    func testFreshStaleAndNeverSuccessfulIP() {
        var value = PublicIPReading(source: "fake")
        value.apply(.failure(.timeout), at: Date(timeIntervalSince1970: 0))
        XCTAssertNil(value.address); XCTAssertEqual(value.freshness, .unavailable)
        value.apply(.success("192.0.2.1"), at: Date(timeIntervalSince1970: 1))
        XCTAssertFalse(value.label(now: Date(timeIntervalSince1970: 300)).contains("Stale"))
        XCTAssertTrue(value.label(now: Date(timeIntervalSince1970: 301)).contains("Stale"))
        value.apply(.failure(.http), at: Date(timeIntervalSince1970: 302))
        XCTAssertEqual(value.address, "192.0.2.1"); XCTAssertEqual(value.sampledAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(value.freshness, .stale); XCTAssertEqual(value.failure, .http)
    }
    func testUpperAndLowerProxyKeysAndBypassCount() {
        for key in ["HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"] {
            let result = ProxyParser.environment([key: "http://127.0.0.1:7890", "no_proxy": "localhost,example.test"])
            XCTAssertEqual(result.endpoints.count, 1); XCTAssertEqual(result.bypassCount, 2)
            XCTAssertEqual(result.endpoints.first?.host, "127.0.0.1")
        }
    }
    func testProxyCaseMismatchExplicitAndUpperWins() {
        let result = ProxyParser.environment(["HTTP_PROXY": "http://127.0.0.1:7890", "http_proxy": "http://127.0.0.1:8888"])
        XCTAssertEqual(result.mismatchedKeys, ["HTTP_PROXY"]); XCTAssertEqual(result.endpoints.first?.port, 7890)
    }
    func testProxyCredentialsDoNotEnterSnapshot() throws {
        let endpoint = try XCTUnwrap(ProxyParser.endpoint("http://test-user:test-secret@127.0.0.1:7890/path?credential=private", kind: "HTTP"))
        XCTAssertEqual(endpoint.summary, "http://127.0.0.1:7890")
        // Only the sanitized endpoint is asserted/logged; no raw value is retained.
        XCTAssertEqual(endpoint.host, "127.0.0.1")
    }
    func testMalformedProxyIsNotNoProxy() {
        for value in ["not a url", "file:///private/file", "http://", "http://host:99999"] {
            let result = ProxyParser.environment(["HTTP_PROXY": value])
            XCTAssertEqual(result.invalidKeys, ["HTTP_PROXY"]); XCTAssertEqual(result.summary, "Invalid proxy setting")
        }
    }
    func testSystemHTTPHTTPSandSOCKS() {
        let result = ProxyParser.system(["HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": 7890,
            "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 7890,
            "SOCKSEnable": 1, "SOCKSProxy": "::1", "SOCKSPort": 1080, "ExceptionsList": ["localhost"]])
        XCTAssertEqual(result.endpoints.map(\.kind), ["HTTP", "HTTPS", "SOCKS"])
        XCTAssertEqual(result.endpoints.last?.summary, "socks5://[::1]:1080"); XCTAssertEqual(result.bypassCount, 1)
    }
    func testPACSanitizationAndAutoDiscovery() {
        let result = ProxyParser.system(["ProxyAutoConfigEnable": 1, "ProxyAutoConfigURLString": "https://u:p@proxy.test/pac?secret=x", "ProxyAutoDiscoveryEnable": 1])
        XCTAssertEqual(result.pacURL, "https://proxy.test"); XCTAssertTrue(result.autoDiscovery)
    }
    func testNoProxyAndUnavailableAreDifferent() {
        XCTAssertEqual(ProxyParser.system([:]).summary, "No proxy")
        XCTAssertEqual(ProxyParser.system(nil).summary, "Unavailable")
        XCTAssertEqual(ProxyParser.environment([:]).summary, "No proxy")
    }
    func testProxyContextsSameDifferentAndUnavailable() {
        var value = NetworkSnapshot()
        value.environmentProxy = ProxyParser.environment(["HTTP_PROXY": "http://localhost:7890"])
        value.systemProxy = ProxyParser.system(["HTTPEnable": 1, "HTTPProxy": "localhost", "HTTPPort": 7890])
        XCTAssertEqual(value.proxyContext, "Same proxy contexts")
        value.systemProxy = ProxyReading(); XCTAssertEqual(value.proxyContext, "Different proxy contexts")
        value.systemProxy = ProxyReading(state: .unavailable); XCTAssertEqual(value.proxyContext, "Unavailable")
    }
    func testTunnelHintsDeduplicateWithoutVPNClaim() {
        XCTAssertEqual(NativeLocalNetworkProvider.tunnelHints(["utun0", "utun1", "utun0", "tun0", "tap1", "ppp0", "ipsec0", "en0", "lo0"]), ["ipsec0", "ppp0", "tap1", "tun0", "utun0", "utun1"])
        XCTAssertTrue(NativeLocalNetworkProvider.tunnelHints(["en0"]).isEmpty)
        XCTAssertEqual(TunnelReading().summary, "None observed")
    }
    func testProbeAnyHTTPResponseIsReachableIncluding401403() async throws {
        let client = FakeNetworkHTTP()
        for code in [200, 401, 403, 500] {
            await client.set(ProbeService.openai.url, status: code)
            let result = try await ConnectivityProvider(client: client).probe(.openai)
            XCTAssertEqual(result.state, .reachable); XCTAssertEqual(result.httpStatus, code)
        }
        let calls = await client.calls
        XCTAssertTrue(calls.allSatisfy { $0.method == "HEAD" && $0.maxBytes == 0 })
    }
    func testProbeFailureMapping() {
        XCTAssertEqual(networkFailure(URLError(.notConnectedToInternet)), .offline)
        XCTAssertEqual(networkFailure(URLError(.secureConnectionFailed)), .transport)
        XCTAssertEqual(networkFailure(NetworkFailure.tooLarge), .tooLarge)
    }
    func testSuccessCadenceAndBackoffMaximum() {
        var schedule = NetworkSchedule()
        schedule.completedProbe(.github, success: true, at: 0)
        XCTAssertEqual(schedule.probeDue[.github], 60)
        for interval in [60.0, 120, 300, 600, 900, 900, 900] {
            schedule.completedProbe(.github, success: false, at: 10)
            XCTAssertEqual(schedule.probeDue[.github], 10 + interval)
        }
        schedule.completedProbe(.github, success: true, at: 20)
        XCTAssertEqual(schedule.failureCounts[.github], 0); XCTAssertEqual(schedule.probeDue[.github], 80)
    }
    func testPathChangeResetsBackoffAndDebounces() {
        var schedule = NetworkSchedule()
        schedule.completedProbe(.github, success: false, at: 0)
        schedule.pathChanged(at: 100)
        XCTAssertTrue(schedule.failureCounts.isEmpty)
        XCTAssertEqual(schedule.ipDue, 100.75); XCTAssertEqual(schedule.probeDue[.github], 100.75)
    }
    func testIPCacheTTLAndManualCooldownSchedule() {
        var schedule = NetworkSchedule()
        schedule.completedIP(at: 10); XCTAssertEqual(schedule.ipDue, 310)
        XCTAssertTrue(schedule.manual(at: 20)); XCTAssertFalse(schedule.manual(at: 23.99)); XCTAssertTrue(schedule.manual(at: 24))
    }

    @MainActor func testPathStatesAndInterfaceFactsAreNotVPNConclusions() async {
        let h = NetworkHarness(); h.monitor.start(probesEnabled: false)
        for state in [NetworkPathState.satisfied, .unsatisfied, .requiresConnection, .unavailable] {
            for kind in [NetworkInterfaceKind.wifi, .ethernet, .other] {
                let value = NetworkPathReading(state: state, interfaces: [kind], expensive: true, constrained: true)
                h.path.send(value)
                XCTAssertEqual(h.monitor.snapshot.path, value)
            }
        }
        await h.stop()
    }
    @MainActor func testRepeatedStartAndStopWakeResetBaseline() async {
        let h = NetworkHarness()
        h.monitor.start(probesEnabled: false); h.monitor.start(probesEnabled: false)
        XCTAssertEqual(h.path.starts, 1); XCTAssertEqual(h.monitor.starts, 1)
        h.online(); await h.stop()
        XCTAssertEqual(h.monitor.snapshot.path.state, .sampling); XCTAssertNil(h.monitor.snapshot.ipv4.address)
        h.monitor.start(probesEnabled: false)
        XCTAssertEqual(h.path.starts, 2); XCTAssertEqual(h.monitor.snapshot.path.state, .sampling)
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .disabled })
        await h.stop()
    }
    @MainActor func testOfflineMakesNoHTTPRequestsAndClearsReachability() async {
        let h = NetworkHarness(); h.monitor.start(probesEnabled: true)
        h.path.send(NetworkPathReading(state: .unsatisfied))
        guard await h.advance(100, registered: 0.75) else { return }
        await eventually { h.monitor.snapshot.localSampledAt != nil }
        let calls = await h.client.count(); XCTAssertEqual(calls, 0)
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .offline })
        await h.stop()
    }
    @MainActor func testIPv4SuccessDoesNotDependOnIPv6() async {
        let h = NetworkHarness(); await h.client.fail(PublicIPProvider.endpoint(.ipv6), error: .timeout)
        guard await connected(h, probes: false) else { return }
        await eventually { !h.monitor.snapshot.ipv6.checking }
        XCTAssertEqual(h.monitor.snapshot.ipv4.address, "192.0.2.1")
        XCTAssertEqual(h.monitor.snapshot.ipv6.failure, .timeout)
        await h.stop()
    }
    @MainActor func testIPv6SuccessDoesNotDependOnIPv4() async {
        let h = NetworkHarness(); await h.client.fail(PublicIPProvider.endpoint(.ipv4), error: .transport)
        h.monitor.start(probesEnabled: false); h.online()
        guard await h.advance(0.75, registered: 0.75) else { return }
        await eventually { h.monitor.snapshot.ipv6.freshness == .fresh && !h.monitor.snapshot.ipv4.checking }
        XCTAssertEqual(h.monitor.snapshot.ipv6.address, "2001:db8::1"); XCTAssertEqual(h.monitor.snapshot.ipv4.failure, .transport)
        await h.stop()
    }
    @MainActor func testCacheBeforeExpiryThenTTLRefresh() async {
        let h = NetworkHarness(); guard await connected(h, probes: false) else { return }
        guard await h.advance(299, registered: 60.75),
              await eventually({ h.monitor.snapshot.localSampledAt == h.time.date() }), await completed(h) else { await h.stop(); return }
        let before = await h.client.ipCount(); XCTAssertEqual(before, 2)
        guard await h.advance(301, registered: 300.75),
              await eventually({ await h.client.ipCount() == 4 }), await completed(h) else { await h.stop(); return }
        await eventually { await h.client.ipCount() == 4 }
        await h.stop()
    }
    @MainActor func testPathChangeRefreshAndDuplicateEventsCoalesce() async {
        let h = NetworkHarness(); guard await connected(h, probes: false) else { return }
        h.time.set(1); h.online(.ethernet); h.online(.ethernet); h.online(.ethernet)
        XCTAssertEqual(h.monitor.snapshot.ipv4.freshness, .stale)
        guard await h.advance(1.75, registered: 1.75) else { return }
        await eventually { await h.client.ipCount() == 4 }
        XCTAssertEqual(h.path.starts, 1)
        await h.stop()
    }
    @MainActor func testRefreshStaleFailureAndManualCooldown() async {
        let h = NetworkHarness(); guard await connected(h, probes: false) else { return }
        await h.client.fail(PublicIPProvider.endpoint(.ipv4), error: .http)
        h.time.set(4); h.monitor.refresh(); h.monitor.refresh(); h.monitor.refresh()
        await eventually { h.monitor.snapshot.ipv4.failure == .http }
        // One family result is not batch completion. Bound the fake work wait,
        // then join the existing batch before asserting its dual-stack total.
        guard await completed(h) else { return }
        let calls = await h.client.ipCount(); XCTAssertEqual(calls, 4)
        XCTAssertEqual(h.monitor.snapshot.ipv4.freshness, .stale); XCTAssertEqual(h.monitor.snapshot.ipv4.address, "192.0.2.1")
        XCTAssertEqual(h.path.starts, 1)
        await h.stop()
    }
    @MainActor func testRefreshWaitsForDelayedIPv6BatchCompletion() async {
        let h = NetworkHarness(); guard await connected(h, probes: false) else { return }
        let ipv6 = PublicIPProvider.endpoint(.ipv6)
        await h.client.fail(PublicIPProvider.endpoint(.ipv4), error: .http)
        await h.client.delayEntry(ipv6)
        h.time.set(4); h.monitor.refresh(); h.monitor.refresh(); h.monitor.refresh()
        await eventually { h.monitor.snapshot.ipv4.failure == .http }
        await eventually { await h.client.pendingEntryCount() == 1 }
        // The old completion predicate is now true, but its count assertion is not.
        let partialCalls = await h.client.ipCount(); XCTAssertEqual(partialCalls, 3)
        XCTAssertTrue(h.monitor.snapshot.ipv6.checking)
        var waiterStarted = false, batchCompleted = false
        let currentBatch = Task { @MainActor in
            waiterStarted = true
            await h.monitor.waitForCurrentWork()
            batchCompleted = true
        }
        await eventually { waiterStarted }
        XCTAssertFalse(batchCompleted)
        await h.client.releaseEntry(ipv6)
        guard await eventually({ batchCompleted && !h.monitor.snapshot.ipv4.checking && !h.monitor.snapshot.ipv6.checking }) else { await h.stop(); currentBatch.cancel(); return }
        await currentBatch.value
        let calls = await h.client.ipCount(); XCTAssertEqual(calls, 4)
        XCTAssertEqual(h.monitor.snapshot.ipv4.freshness, .stale)
        XCTAssertEqual(h.monitor.snapshot.ipv4.address, "192.0.2.1")
        XCTAssertEqual(h.monitor.snapshot.ipv4.failure, .http)
        XCTAssertEqual(h.path.starts, 1)
        let waiting = await h.client.pendingEntryCount(); XCTAssertEqual(waiting, 0)
        await h.stop()
    }
    @MainActor func testDisableProbesCancelsPendingButNotPublicIP() async {
        let h = NetworkHarness(); await h.client.hold()
        h.monitor.start(probesEnabled: true); h.online()
        guard await h.advance(0.75, registered: 0.75) else { return }
        await eventually { await h.client.count() == 5 }
        h.monitor.setProbesEnabled(false)
        await eventually { await h.client.cancelledCount() == 3 }
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .disabled })
        let ip = await h.client.ipCount(); XCTAssertEqual(ip, 2)
        await h.stop()
        let total = await h.client.cancelledCount(); XCTAssertEqual(total, 5)
    }
    @MainActor func testToggleOnRefreshesAndSuccessCadenceIs60Seconds() async {
        let h = NetworkHarness(); guard await connected(h, probes: false) else { return }
        h.monitor.setProbesEnabled(true)
        await eventually { h.monitor.snapshot.probes.allSatisfy { $0.state == .reachable } }
        let initial = await h.client.probeCount(); XCTAssertEqual(initial, 3)
        guard await completed(h), await h.advance(59, registered: 60.75) else { return }
        let before = await h.client.probeCount(); XCTAssertEqual(before, 3)
        guard await h.advance(61, registered: 60.75),
              await eventually({ await h.client.probeCount() == 6 }), await completed(h) else { await h.stop(); return }
        await eventually { await h.client.probeCount() == 6 }
        await h.stop()
    }
    @MainActor func testStopRejectsOldPathCallbackAndResults() async {
        let h = NetworkHarness(); await h.client.hold()
        h.monitor.start(probesEnabled: true); let oldCallback = h.path.receive
        h.online(); guard await h.advance(0.75, registered: 0.75) else { return }
        await eventually { await h.client.count() == 5 }; await h.stop()
        oldCallback?(NetworkPathReading(state: .satisfied))
        XCTAssertEqual(h.monitor.snapshot.path.state, .sampling)
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .unavailable })
        XCTAssertNil(h.monitor.snapshot.ipv4.address)
    }
    @MainActor func testAppStoreLiveBoundaryAndRepeatedPagesShareNetwork() {
        let path = FakeNetworkPath()
        let store = AppStore(networkPath: path, networkHTTP: FakeNetworkHTTP(), networkLocal: FakeLocalNetwork())
        store.setSystemMode(.live)
        XCTAssertEqual(store.snapshot.systemMode, .live); XCTAssertEqual(store.snapshot.devMode, .live); XCTAssertEqual(store.snapshot.networkMode, .live)
        XCTAssertNil(store.snapshot.publicIP); XCTAssertNil(store.snapshot.region)
        XCTAssertEqual(store.snapshot.network.region, "Not collected")
        XCTAssertEqual(store.snapshot.quotas.first?.mode, .live)
        XCTAssertTrue(store.snapshot.quotas.allSatisfy(\.entirelyUnavailable)) // AI Live never reuses Mock quotas.
        for _ in 0..<5 {
            let id = UUID(); store.setWindow(id, visible: true, section: .network)
            store.setWindowSection(id, section: .overview); store.setWindow(id, visible: false, section: .network)
            store.refreshNetwork()
        }
        XCTAssertEqual(store.networkStarts, 1); XCTAssertEqual(path.starts, 1)
        store.setSystemMode(.preview)
        XCTAssertEqual(store.snapshot.networkMode, .mock); XCTAssertEqual(store.snapshot.publicIP, "203.0.113.42")
    }
    func testDifferentBypassListsWithSameCountAreDifferentContexts() {
        var value = NetworkSnapshot()
        value.environmentProxy = ProxyParser.environment(["NO_PROXY": "example.test"])
        value.systemProxy = ProxyParser.system(["ExceptionsList": ["other.test"]])
        XCTAssertEqual(value.proxyContext, "Different proxy contexts")
    }
    @MainActor func testProbeTimeoutAndTransportFailureStates() async {
        let h = NetworkHarness()
        await h.client.fail(ProbeService.openai.url, error: .timeout)
        await h.client.fail(ProbeService.anthropic.url, error: .transport)
        h.monitor.start(probesEnabled: true); h.online()
        guard await h.advance(0.75, registered: 0.75) else { return }
        await eventually { h.monitor.snapshot.probes.allSatisfy { $0.state != .checking } }
        XCTAssertEqual(h.monitor.snapshot.probes.first { $0.service == .openai }?.state, .timeout)
        XCTAssertEqual(h.monitor.snapshot.probes.first { $0.service == .anthropic }?.state, .transportFailed)
        await h.stop()
    }
    @MainActor func testInFlightRefreshTriggersCoalesceWithoutSecondBatch() async {
        let h = NetworkHarness(); await h.client.hold()
        h.monitor.start(probesEnabled: true); h.online()
        guard await h.advance(0.75, registered: 0.75) else { return }
        await eventually { await h.client.count() == 5 }
        for time in [4.0, 8, 12] { h.time.set(time); h.monitor.refresh() }
        let count = await h.client.count(); XCTAssertEqual(count, 5)
        await h.stop()
    }
    @MainActor func testOfflineToOnlineResumesAfterDebounce() async {
        let h = NetworkHarness(); h.monitor.start(probesEnabled: false)
        h.path.send(NetworkPathReading(state: .unsatisfied))
        h.online()
        let before = await h.client.count(); XCTAssertEqual(before, 0)
        guard await h.advance(0.75, registered: 0.75) else { return }
        await eventually { h.monitor.snapshot.ipv4.freshness == .fresh }
        await h.stop()
    }
    @MainActor func testFailedProbeRetriesFollowBackoffAndPathChangeResets() async {
        let h = NetworkHarness()
        await h.client.fail(ProbeService.github.url, error: .timeout)
        h.monitor.start(probesEnabled: true); h.online()
        guard await h.advance(0.75, registered: 0.75), await completed(h) else { return }
        var count = await h.client.probeCount(); XCTAssertEqual(count, 3)
        XCTAssertEqual(h.monitor.snapshot.probes.first { $0.service == .github }?.state, .timeout)
        XCTAssertTrue(h.monitor.snapshot.probes.filter { $0.service != .github }.allSatisfy { $0.state == .reachable })
        guard await h.advance(61, registered: 60.75),
              await eventually({ await h.client.probeCount() == 6 }), await completed(h) else { await h.stop(); return }
        count = await h.client.probeCount(); XCTAssertEqual(count, 6)
        // Failed GitHub backs off for120s; successful probes/local work wait60s.
        // Hold successes so their completion cannot cancel the remaining GitHub timer.
        await h.client.delayEntry(ProbeService.openai.url); await h.client.delayEntry(ProbeService.anthropic.url)
        guard await h.advance(121, registered: 121),
              await eventually({ await h.client.pendingEntryCount() == 2 }) else { await h.stop(); return }
        count = await h.client.probeCount(); XCTAssertEqual(count, 6)
        guard await h.advance(180.999, registered: 181) else { return }
        count = await h.client.probeCount(); XCTAssertEqual(count, 6)
        // Path change resets backoff and cancels those held requests/timer.
        h.online(.ethernet)
        guard await h.advance(181.748, registered: 181.749) else { return }
        count = await h.client.probeCount(); XCTAssertEqual(count, 6)
        await h.client.releaseEntry(ProbeService.openai.url); await h.client.releaseEntry(ProbeService.anthropic.url)
        guard await h.advance(181.749, registered: 181.749),
              await eventually({ await h.client.probeCount() == 9 }), await completed(h) else { await h.stop(); return }
        count = await h.client.probeCount(); XCTAssertEqual(count, 9)
        XCTAssertEqual(h.monitor.snapshot.probes.first { $0.service == .github }?.state, .timeout)
        XCTAssertEqual(h.path.starts, 1)
        await h.stop()
    }

}

final class NetworkPresentationTests: XCTestCase {
    private let chinese = MacSoulLanguage.chinese
    private let english = MacSoulLanguage.english
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let date = Date(timeIntervalSince1970: 1790904600) // 2026-10-02 01:30 UTC

    func testNetworkLabelsChinese() {
        XCTAssertEqual(chinese.text("Status"), "状态")
        XCTAssertEqual(chinese.text("Context"), "上下文")
        XCTAssertEqual(chinese.text("IPv4 updated"), "IPv4 更新时间")
        XCTAssertEqual(chinese.text("IPv6 updated"), "IPv6 更新时间")
        XCTAssertEqual(chinese.text("Not collected"), "未采集")
        XCTAssertEqual(chinese.sampledTime(nil), "未采样")
    }
    func testPathAndInterfacePresentationChinese() {
        XCTAssertEqual(chinese.networkText(NetworkPathState.sampling), "监测中…")
        XCTAssertEqual(chinese.networkText(NetworkPathState.satisfied), "已连接")
        XCTAssertEqual(chinese.networkText(NetworkPathState.requiresConnection), "需要建立连接")
        XCTAssertEqual(chinese.networkText(NetworkPathState.unsatisfied), "离线")
        XCTAssertEqual(chinese.networkText(NetworkPathState.unavailable), "不可用")
        XCTAssertEqual(NetworkInterfaceKind.allCases.map { chinese.networkText($0) },
                       ["Wi-Fi", "有线以太网", "蜂窝网络", "回环", "其他"])
    }
    func testAllNetworkFailuresChinese() {
        let values: [NetworkFailure] = [.timeout, .transport, .http, .malformed, .tooLarge, .unavailable, .offline]
        XCTAssertEqual(values.map { chinese.networkText($0) },
                       ["探测超时", "传输失败", "HTTP 请求失败", "响应格式无效", "响应超出限制", "不可用", "离线"])
    }
    func testAllProbeStatesChinese() {
        let values: [ProbeState] = [.disabled, .checking, .reachable, .timeout, .offline, .transportFailed, .unavailable]
        XCTAssertEqual(values.map { chinese.networkText($0) },
                       ["探测已关闭", "正在探测…", "网络可达", "探测超时", "离线", "传输失败", "不可用"])
    }
    func testChineseSampledTimeUsesAppLocale() {
        XCTAssertEqual(chinese.sampledTime(date, timeZone: utc), "2026年10月2日 01:30:00")
    }
    func testEnglishSampledTimeUsesAppLocale() {
        let value = english.sampledTime(date, timeZone: utc)
        XCTAssertTrue(value.hasPrefix("Oct 2, 2026 at 1:30:00"), value)
        XCTAssertTrue(value.hasSuffix("AM"), value)
        XCTAssertFalse(value.contains("年"))
    }
    func testLanguageSwitchRendersSameSnapshotWithoutMutation() {
        let reading = PublicIPReading(sampledAt: date, failure: .transport, source: "api.ipify.org")
        XCTAssertEqual(reading.display(english, now: date), "Transport failed")
        XCTAssertEqual(reading.display(chinese, now: date), "传输失败")
        XCTAssertEqual(reading.display(english, now: date), "Transport failed")
        XCTAssertEqual(reading.sampledAt, date)
        XCTAssertNotEqual(chinese.dateTime(date, timeZone: utc), english.dateTime(date, timeZone: utc))
    }
    func testProxyContextsChinese() {
        var snapshot = NetworkSnapshot()
        XCTAssertEqual(chinese.text(snapshot.proxyContext), "不可用")
        snapshot.environmentProxy = ProxyReading()
        snapshot.systemProxy = ProxyReading(autoDiscovery: true)
        XCTAssertEqual(chinese.text(snapshot.proxyContext), "代理上下文不同")
        snapshot.environmentProxy = snapshot.systemProxy
        XCTAssertEqual(chinese.text(snapshot.proxyContext), "代理上下文一致")
    }
    func testCompositeProxySummaryAndTechnicalValues() {
        let proxy = ProxyReading(endpoints: [ProxyEndpoint(kind: "HTTP", scheme: "http", host: "127.0.0.1", port: 7890)], autoDiscovery: true)
        XCTAssertEqual(proxy.display(chinese), "HTTP / 自动发现")
        XCTAssertEqual(proxy.display(english), "HTTP / Auto discovery")
        XCTAssertEqual(proxy.endpoints[0].summary, "http://127.0.0.1:7890")
        XCTAssertEqual(ProbeService.allCases.map(\.displayName), ["GitHub", "OpenAI", "Anthropic"])
        XCTAssertEqual(ProxyReading().display(chinese), "无代理")
        XCTAssertEqual(ProxyReading(state: .unavailable).display(chinese), "不可用")
        XCTAssertEqual(ProxyReading(invalidKeys: ["HTTP_PROXY"]).display(chinese), "代理配置无效")
    }
    func testPublicIPPresentationPreservesTTLAndErrorSemantics() {
        var reading = PublicIPReading(address: "192.0.2.1", sampledAt: date, freshness: .fresh, source: "api.ipify.org")
        XCTAssertEqual(reading.display(chinese, now: date.addingTimeInterval(299)), "192.0.2.1")
        XCTAssertEqual(reading.display(chinese, now: date.addingTimeInterval(300)), "192.0.2.1 · 已过期")
        reading.failure = .transport
        XCTAssertEqual(reading.display(chinese, now: date.addingTimeInterval(300)), "192.0.2.1 · 已过期 · 传输失败")
        XCTAssertEqual(reading.display(english, now: date.addingTimeInterval(300)), reading.label(now: date.addingTimeInterval(300)))
        reading.address = nil; reading.checking = true
        XCTAssertEqual(reading.display(chinese, now: date), "正在探测…")
    }
    func testConnectivitySummaryUnknownPathAlsoLocalized() {
        var snapshot = NetworkSnapshot()
        XCTAssertEqual(snapshot.connectivityDisplay(chinese), "正在探测…")
        XCTAssertEqual(snapshot.connectivityDisplay(english), "Checking…")
        XCTAssertEqual(snapshot.connectivitySummary, "Checking…")
        snapshot.probes[0].state = .reachable
        XCTAssertEqual(snapshot.connectivityDisplay(chinese), "1/3 可达 · 正在探测")
        XCTAssertEqual(snapshot.connectivityDisplay(english), "1/3 reachable · Checking…")
        XCTAssertEqual(snapshot.connectivitySummary, "1/3 reachable · Checking…")
        snapshot.probesEnabled = false
        XCTAssertEqual(snapshot.connectivityDisplay(chinese), "探测已关闭")
        XCTAssertEqual(snapshot.connectivityDisplay(english), "Probes disabled")
        XCTAssertEqual(snapshot.connectivitySummary, "Probes disabled")
        snapshot.probesEnabled = true
        for state in [NetworkPathState.unsatisfied, .requiresConnection] {
            snapshot.path.state = state
            XCTAssertEqual(snapshot.connectivityDisplay(chinese), "离线")
            XCTAssertEqual(snapshot.connectivityDisplay(english), "Offline")
            XCTAssertEqual(snapshot.connectivitySummary, "Offline")
        }
    }
    func testConnectivityFinalReachableCountsBothLanguages() {
        for count in [3, 2, 0] {
            var snapshot = NetworkSnapshot()
            snapshot.path.state = .satisfied
            snapshot.probes = ProbeService.allCases.enumerated().map { index, service in
                ProbeReading(service: service, state: index < count ? .reachable : .timeout)
            }
            XCTAssertEqual(snapshot.connectivityDisplay(chinese), "\(count)/3 可达")
            XCTAssertEqual(snapshot.connectivityDisplay(english), "\(count)/3 reachable")
            XCTAssertEqual(snapshot.connectivitySummary, "\(count)/3 reachable")
        }
    }
    func testConnectivityPartialFailureStillCheckingBothLanguages() {
        var snapshot = NetworkSnapshot()
        snapshot.probes[0].state = .timeout
        XCTAssertEqual(snapshot.connectivityDisplay(chinese), "0/3 可达 · 正在探测")
        XCTAssertEqual(snapshot.connectivityDisplay(english), "0/3 reachable · Checking…")
        XCTAssertEqual(snapshot.connectivitySummary, "0/3 reachable · Checking…")
    }
    func testTunnelPresentationKeepsInterfaceNames() {
        let reading = TunnelReading(names: ["utun0", "utun1"])
        XCTAssertEqual(reading.display(chinese), "2 个类隧道接口")
        XCTAssertEqual(reading.display(english), reading.summary)
        XCTAssertEqual(reading.names, ["utun0", "utun1"])
        XCTAssertEqual(TunnelReading().display(chinese), "未发现类隧道接口")
        XCTAssertEqual(TunnelReading(available: false).display(chinese), "不可用")
    }
}

extension NetworkPresentationTests {
    func testNetworkPathTerminologyBothLanguages() {
        XCTAssertEqual(chinese.text("Expensive network"), "高流量成本网络")
        XCTAssertEqual(chinese.text("Low Data Mode"), "低数据模式")
        XCTAssertEqual(english.text("Expensive network"), "Expensive network")
        XCTAssertEqual(english.text("Low Data Mode"), "Low Data Mode")
    }
    func testNetworkAdditionalLabelsAndContextTerminology() {
        XCTAssertEqual(chinese.networkLabel("Status"), "状态")
        XCTAssertEqual(chinese.networkLabel("Context"), "上下文")
        XCTAssertEqual(chinese.networkLabel("Source"), "来源")
        XCTAssertEqual(chinese.networkLabel("Updated"), "更新时间")
        XCTAssertEqual(chinese.networkLabel("Last updated"), "上次更新时间")
        XCTAssertEqual(chinese.text("Same proxy contexts"), "代理上下文一致")
        XCTAssertEqual(english.networkLabel("Updated"), "Updated")
        // Quota/System timestamps keep their existing shared dictionary copy.
        XCTAssertEqual(chinese.text("Updated"), "更新于")
    }
    func testEmptyProxyAndTunnelPresentationNoWrongClaims() {
        XCTAssertEqual(ProxyReading().display(chinese, system: true), "无系统代理")
        XCTAssertEqual(ProxyReading().display(english, system: true), "No system proxy")
        XCTAssertEqual(ProxyReading().display(chinese), "无代理")
        XCTAssertEqual(ProxyReading(state: .unavailable).display(chinese, system: true), "不可用")
        XCTAssertEqual(TunnelReading().display(chinese), "未发现类隧道接口")
        XCTAssertEqual(TunnelReading().display(english), "No tunnel hints")
        XCTAssertEqual(chinese.networkText(ProbeState.checking), "正在探测…")
        XCTAssertEqual(chinese.networkText(ProbeState.timeout), "探测超时")
    }
}

extension NetworkTests {
    @MainActor func testOffPresentationStaysDisabledAfter90SecondsAndManualRefresh() async {
        let h = NetworkHarness(); guard await connected(h) else { return }
        let calls = await h.client.probeCount()
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.httpStatus != nil })
        h.monitor.setProbesEnabled(false)
        func checkDisabled() {
            XCTAssertFalse(h.monitor.snapshot.probesEnabled)
            XCTAssertEqual(h.monitor.snapshot.connectivityDisplay(.chinese), "探测已关闭")
            for probe in h.monitor.snapshot.probes {
                XCTAssertEqual(probe.state, .disabled)
                XCTAssertEqual(MacSoulLanguage.chinese.networkText(probe.state), "探测已关闭")
                XCTAssertNil(probe.latencyMilliseconds)
                XCTAssertNil(probe.httpStatus)
                XCTAssertNil(probe.sampledAt)
            }
        }
        checkDisabled()
        guard await h.advance(90, registered: 60.75),
              await eventually({ h.monitor.snapshot.localSampledAt == h.time.date() }), await completed(h) else { await h.stop(); return }
        h.monitor.refresh()
        await eventually { h.monitor.snapshot.ipv4.attemptedAt == h.time.date() }
        checkDisabled()
        let finalCalls = await h.client.probeCount()
        XCTAssertEqual(finalCalls, calls)
        XCTAssertTrue(h.monitor.snapshot.path.online)
        await h.stop()
    }
    @MainActor func testOnPresentationEntersCheckingWithoutRetainingDisabled() async {
        let h = NetworkHarness(); guard await connected(h, probes: false) else { return }
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .disabled })
        await h.client.hold()
        h.monitor.setProbesEnabled(true)
        XCTAssertTrue(h.monitor.snapshot.probesEnabled)
        for probe in h.monitor.snapshot.probes {
            XCTAssertEqual(probe.state, .checking)
            XCTAssertEqual(MacSoulLanguage.chinese.networkText(probe.state), "正在探测…")
            XCTAssertNil(probe.latencyMilliseconds)
            XCTAssertNil(probe.httpStatus)
        }
        await eventually { await h.client.probeCount() == 3 }
        await h.stop()
    }
}
