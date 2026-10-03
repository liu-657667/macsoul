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
    var calls: [Call] = []
    var answers: [String: Result<NetworkHTTPResponse, NetworkFailure>] = [:]
    var held = false
    var waiting: [UUID: CheckedContinuation<NetworkHTTPResponse, Error>] = [:]
    var cancellations = 0
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
private final class ManualNetworkTime: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    func uptime() -> TimeInterval { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ time: TimeInterval) { lock.lock(); value = time; lock.unlock() }
    func date() -> Date { Date(timeIntervalSince1970: uptime()) }
}
private actor ManualNetworkSleeper {
    private var time: TimeInterval = 0
    private var pending: [UUID: (TimeInterval, CheckedContinuation<Void, Error>)] = [:]
    func wait(until deadline: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()) }
                else if deadline <= time { continuation.resume() }
                else { pending[id] = (deadline, continuation) }
            }
        } onCancel: { Task { await self.cancel(id) } }
    }
    func cancel(_ id: UUID) { pending.removeValue(forKey: id)?.1.resume(throwing: CancellationError()) }
    func advance(to value: TimeInterval) {
        time = value
        let due = pending.filter { $0.value.0 <= value }
        for (id, entry) in due { pending.removeValue(forKey: id); entry.1.resume() }
    }
    func count() -> Int { pending.count }
}
@MainActor private final class NetworkHarness {
    let path = FakeNetworkPath()
    let client = FakeNetworkHTTP()
    let time = ManualNetworkTime()
    let sleeper = ManualNetworkSleeper()
    lazy var monitor = NetworkMonitor(path: path, client: client, local: FakeLocalNetwork(),
        clock: NetworkClock(now: { [time] in time.date() }, uptime: { [time] in time.uptime() },
                            sleep: { [time, sleeper] seconds in try await sleeper.wait(until: time.uptime() + seconds) }),
        onSnapshot: { _ in })
    func online(_ kind: NetworkInterfaceKind = .wifi) {
        path.send(NetworkPathReading(state: .satisfied, interfaces: [kind], interfaceNames: ["en0"],
                                     expensive: false, constrained: false, supportsIPv4: true, supportsIPv6: true))
    }
    func advance(_ to: TimeInterval) async { time.set(to); await sleeper.advance(to: to) }
    func stop() async { monitor.stop(); await monitor.waitForStop() }
}

final class NetworkTests: XCTestCase {
    @MainActor private func eventually(_ condition: () async -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10000 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Deterministic fake work did not complete", file: file, line: line)
    }
    @MainActor private func connected(_ h: NetworkHarness, probes: Bool = true) async {
        h.monitor.start(probesEnabled: probes); h.online()
        await eventually { await h.sleeper.count() > 0 }
        await h.advance(0.75)
        await eventually { h.monitor.snapshot.ipv4.freshness == .fresh && (!probes || h.monitor.snapshot.probes.allSatisfy { $0.state == .reachable }) }
        await h.monitor.waitForCurrentWork()
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
        await eventually { await h.sleeper.count() > 0 }
        await h.advance(100)
        await eventually { h.monitor.snapshot.localSampledAt != nil }
        let calls = await h.client.count(); XCTAssertEqual(calls, 0)
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .offline })
        await h.stop()
    }
    @MainActor func testIPv4SuccessDoesNotDependOnIPv6() async {
        let h = NetworkHarness(); await h.client.fail(PublicIPProvider.endpoint(.ipv6), error: .timeout)
        await connected(h, probes: false)
        await eventually { !h.monitor.snapshot.ipv6.checking }
        XCTAssertEqual(h.monitor.snapshot.ipv4.address, "192.0.2.1")
        XCTAssertEqual(h.monitor.snapshot.ipv6.failure, .timeout)
        await h.stop()
    }
    @MainActor func testIPv6SuccessDoesNotDependOnIPv4() async {
        let h = NetworkHarness(); await h.client.fail(PublicIPProvider.endpoint(.ipv4), error: .transport)
        h.monitor.start(probesEnabled: false); h.online()
        await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
        await eventually { h.monitor.snapshot.ipv6.freshness == .fresh && !h.monitor.snapshot.ipv4.checking }
        XCTAssertEqual(h.monitor.snapshot.ipv6.address, "2001:db8::1"); XCTAssertEqual(h.monitor.snapshot.ipv4.failure, .transport)
        await h.stop()
    }
    @MainActor func testCacheBeforeExpiryThenTTLRefresh() async {
        let h = NetworkHarness(); await connected(h, probes: false)
        await eventually { await h.sleeper.count() > 0 }
        await h.advance(299)
        for _ in 0..<30 { await Task.yield() }
        let before = await h.client.ipCount(); XCTAssertEqual(before, 2)
        await eventually { await h.sleeper.count() > 0 }; await h.advance(301)
        await eventually { await h.client.ipCount() == 4 }
        await h.stop()
    }
    @MainActor func testPathChangeRefreshAndDuplicateEventsCoalesce() async {
        let h = NetworkHarness(); await connected(h, probes: false)
        h.time.set(1); h.online(.ethernet); h.online(.ethernet); h.online(.ethernet)
        XCTAssertEqual(h.monitor.snapshot.ipv4.freshness, .stale)
        await eventually { await h.sleeper.count() > 0 }; await h.advance(1.75)
        await eventually { await h.client.ipCount() == 4 }
        XCTAssertEqual(h.path.starts, 1)
        await h.stop()
    }
    @MainActor func testRefreshStaleFailureAndManualCooldown() async {
        let h = NetworkHarness(); await connected(h, probes: false)
        await h.client.fail(PublicIPProvider.endpoint(.ipv4), error: .http)
        h.time.set(4); h.monitor.refresh(); h.monitor.refresh(); h.monitor.refresh()
        await eventually { h.monitor.snapshot.ipv4.failure == .http }
        let calls = await h.client.ipCount(); XCTAssertEqual(calls, 4)
        XCTAssertEqual(h.monitor.snapshot.ipv4.freshness, .stale); XCTAssertEqual(h.monitor.snapshot.ipv4.address, "192.0.2.1")
        XCTAssertEqual(h.path.starts, 1)
        await h.stop()
    }
    @MainActor func testDisableProbesCancelsPendingButNotPublicIP() async {
        let h = NetworkHarness(); await h.client.hold()
        h.monitor.start(probesEnabled: true); h.online()
        await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
        await eventually { await h.client.count() == 5 }
        h.monitor.setProbesEnabled(false)
        await eventually { await h.client.cancelledCount() == 3 }
        XCTAssertTrue(h.monitor.snapshot.probes.allSatisfy { $0.state == .disabled })
        let ip = await h.client.ipCount(); XCTAssertEqual(ip, 2)
        await h.stop()
        let total = await h.client.cancelledCount(); XCTAssertEqual(total, 5)
    }
    @MainActor func testToggleOnRefreshesAndSuccessCadenceIs60Seconds() async {
        let h = NetworkHarness(); await connected(h, probes: false)
        h.monitor.setProbesEnabled(true)
        await eventually { h.monitor.snapshot.probes.allSatisfy { $0.state == .reachable } }
        let initial = await h.client.probeCount(); XCTAssertEqual(initial, 3)
        await eventually { await h.sleeper.count() > 0 }; await h.advance(59)
        for _ in 0..<30 { await Task.yield() }
        let before = await h.client.probeCount(); XCTAssertEqual(before, 3)
        await eventually { await h.sleeper.count() > 0 }; await h.advance(61)
        await eventually { await h.client.probeCount() == 6 }
        await h.stop()
    }
    @MainActor func testStopRejectsOldPathCallbackAndResults() async {
        let h = NetworkHarness(); await h.client.hold()
        h.monitor.start(probesEnabled: true); let oldCallback = h.path.receive
        h.online(); await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
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
        await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
        await eventually { h.monitor.snapshot.probes.allSatisfy { $0.state != .checking } }
        XCTAssertEqual(h.monitor.snapshot.probes.first { $0.service == .openai }?.state, .timeout)
        XCTAssertEqual(h.monitor.snapshot.probes.first { $0.service == .anthropic }?.state, .transportFailed)
        await h.stop()
    }
    @MainActor func testInFlightRefreshTriggersCoalesceWithoutSecondBatch() async {
        let h = NetworkHarness(); await h.client.hold()
        h.monitor.start(probesEnabled: true); h.online()
        await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
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
        await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
        await eventually { h.monitor.snapshot.ipv4.freshness == .fresh }
        await h.stop()
    }
    @MainActor func testFailedProbeRetriesFollowBackoffAndPathChangeResets() async {
        let h = NetworkHarness()
        await h.client.fail(ProbeService.github.url, error: .timeout)
        h.monitor.start(probesEnabled: true); h.online()
        await eventually { await h.sleeper.count() > 0 }; await h.advance(0.75)
        await eventually { h.monitor.snapshot.probes.allSatisfy { $0.state != .checking } }
        await h.monitor.waitForCurrentWork()
        await eventually { await h.sleeper.count() > 0 }; await h.advance(61)
        await eventually { await h.client.probeCount() == 6 }
        await h.monitor.waitForCurrentWork()
        h.time.set(62); h.online(.ethernet)
        await eventually { await h.sleeper.count() > 0 }; await h.advance(62.75)
        await eventually { await h.client.probeCount() == 9 }
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
        let h = NetworkHarness(); await connected(h)
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
        await eventually { await h.sleeper.count() > 0 }
        await h.advance(90)
        h.monitor.refresh()
        await eventually { h.monitor.snapshot.ipv4.attemptedAt == h.time.date() }
        checkDisabled()
        let finalCalls = await h.client.probeCount()
        XCTAssertEqual(finalCalls, calls)
        XCTAssertTrue(h.monitor.snapshot.path.online)
        await h.stop()
    }
    @MainActor func testOnPresentationEntersCheckingWithoutRetainingDisabled() async {
        let h = NetworkHarness(); await connected(h, probes: false)
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
