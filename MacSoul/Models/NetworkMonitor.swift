import Foundation

struct NetworkClock: Sendable {
    var now: @Sendable () -> Date = { Date() }
    var uptime: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var sleep: @Sendable (TimeInterval) async throws -> Void = { seconds in
        try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
    }
}

@MainActor final class NetworkMonitor {
    private let pathProvider: any NetworkPathProviding
    private let ipProvider: PublicIPProvider
    private let connectivity: ConnectivityProvider
    private let localProvider: any LocalNetworkProviding
    private let clock: NetworkClock
    private let publish: (NetworkSnapshot) -> Void
    private var schedule = NetworkSchedule()
    private var timer: Task<Void, Never>?
    private var ipTask: Task<Void, Never>?
    private var localTask: Task<Void, Never>?
    private var probeTasks: [ProbeService: Task<Void, Never>] = [:]
    private var cancelledWork: Task<Void, Never>?
    private var generation = 0
    private var lifecycle = 0
    private(set) var isRunning = false
    private(set) var starts = 0
    private(set) var snapshot = NetworkSnapshot()

    init(path: (any NetworkPathProviding)? = nil,
         client: any NetworkHTTPClient = EphemeralNetworkHTTPClient(),
         local: any LocalNetworkProviding = NativeLocalNetworkProvider(),
         clock: NetworkClock = NetworkClock(), onSnapshot: @escaping (NetworkSnapshot) -> Void) {
        pathProvider = path ?? NativeNetworkPathProvider()
        ipProvider = PublicIPProvider(client: client)
        connectivity = ConnectivityProvider(client: client)
        localProvider = local; self.clock = clock; publish = onSnapshot
    }

    deinit {
        timer?.cancel(); ipTask?.cancel(); localTask?.cancel()
        probeTasks.values.forEach { $0.cancel() }
    }

    func start(probesEnabled: Bool) {
        guard !isRunning else { return }
        isRunning = true; starts += 1; generation += 1; lifecycle += 1
        schedule = NetworkSchedule()
        snapshot = NetworkSnapshot(); snapshot.probesEnabled = probesEnabled
        setProbeStates(probesEnabled ? .checking : .disabled)
        publish(snapshot)
        let token = lifecycle
        pathProvider.start { [weak self] reading in
            guard let self, self.isRunning, self.lifecycle == token else { return }
            self.receivePath(reading)
        }
        runDue() // Read local facts immediately; HTTP waits for a satisfied path.
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false; lifecycle += 1; generation += 1
        pathProvider.stop(); cancelWork()
        let enabled = snapshot.probesEnabled
        snapshot = NetworkSnapshot(); snapshot.probesEnabled = enabled
        setProbeStates(enabled ? .unavailable : .disabled)
        publish(snapshot)
    }

    func setProbesEnabled(_ enabled: Bool) {
        guard enabled != snapshot.probesEnabled else { return }
        snapshot.probesEnabled = enabled
        // Only probe work is cancelled. Public IP/path/local monitoring continue.
        for task in probeTasks.values { task.cancel() }
        // Keep cancelled tasks in the dictionary until they finish so toggling ON
        // cannot create a second active request for the same service.
        setProbeStates(baselineProbeState(enabled: enabled))
        schedule.failureCounts = [:]
        schedule.probeDue = Dictionary(uniqueKeysWithValues: ProbeService.allCases.map { ($0, clock.uptime()) })
        publish(snapshot)
        if isRunning { runDue() }
    }

    func refresh() {
        guard isRunning, schedule.manual(at: clock.uptime()) else { return }
        runDue()
    }

    private func receivePath(_ reading: NetworkPathReading) {
        guard reading != snapshot.path else { return }
        generation += 1; cancelWork()
        snapshot.path = reading
        let failure: NetworkFailure? = reading.state == .unsatisfied || reading.state == .requiresConnection
            ? .offline : reading.state == .unavailable ? .unavailable : nil
        snapshot.ipv4.invalidate(failure)
        snapshot.ipv6.invalidate(failure)
        setProbeStates(baselineProbeState(enabled: snapshot.probesEnabled))
        schedule.pathChanged(at: clock.uptime())
        publish(snapshot)
        reschedule()
    }

    private func baselineProbeState(enabled: Bool) -> ProbeState {
        guard enabled else { return .disabled }
        switch snapshot.path.state {
        case .unsatisfied, .requiresConnection: return .offline
        case .unavailable: return .unavailable
        case .sampling, .satisfied: return .checking
        }
    }

    private func setProbeStates(_ state: ProbeState) {
        // Disabling/offline/wake never keeps a previous green reachable result.
        snapshot.probes = ProbeService.allCases.map { ProbeReading(service: $0, state: state) }
    }

    private func cancelWork() {
        timer?.cancel(); timer = nil
        let ip = ipTask, local = localTask, probes = Array(probeTasks.values), prior = cancelledWork
        ip?.cancel(); local?.cancel(); probes.forEach { $0.cancel() }
        ipTask = nil; localTask = nil; probeTasks = [:]
        cancelledWork = Task {
            await prior?.value; await ip?.value; await local?.value
            for probe in probes { await probe.value }
        }
    }

    // Timer sleeps to the nearest deadline; there is no per-second polling loop.
    private func reschedule() {
        timer?.cancel(); timer = nil
        guard isRunning else { return }
        var due: [TimeInterval] = []
        if localTask == nil { due.append(schedule.localDue) }
        if snapshot.path.online {
            if ipTask == nil { due.append(schedule.ipDue) }
            if snapshot.probesEnabled {
                due += ProbeService.allCases.filter { probeTasks[$0] == nil }.map { schedule.probeDue[$0] ?? 0 }
            }
        }
        guard let next = due.min() else { return }
        let token = generation, clock = clock
        timer = Task { [weak self] in
            do { try await clock.sleep(max(0, next - clock.uptime())) } catch { return }
            guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { return }
            self.timer = nil
            self.runDue()
        }
    }

    private func runDue() {
        guard isRunning else { return }
        let now = clock.uptime()
        if localTask == nil && now >= schedule.localDue { readLocal() }
        if snapshot.path.online {
            if ipTask == nil && now >= schedule.ipDue { readPublicIP() }
            if snapshot.probesEnabled {
                for service in ProbeService.allCases where probeTasks[service] == nil && now >= (schedule.probeDue[service] ?? 0) {
                    probe(service)
                }
            }
        }
        reschedule()
    }

    private func readLocal() {
        let token = generation, prior = cancelledWork, provider = localProvider
        localTask = Task { [weak self] in
            await prior?.value
            guard !Task.isCancelled else { return }
            let reading = await provider.read()
            guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { return }
            self.snapshot.environmentProxy = reading.environment
            self.snapshot.systemProxy = reading.system
            self.snapshot.tunnel = reading.tunnel
            self.snapshot.localSampledAt = self.clock.now()
            self.schedule.localDue = self.clock.uptime() + 60
            self.localTask = nil
            self.publish(self.snapshot); self.reschedule()
        }
    }

    private func readPublicIP() {
        let token = generation, prior = cancelledWork, provider = ipProvider
        snapshot.ipv4.checking = true; snapshot.ipv6.checking = true; publish(snapshot)
        ipTask = Task { [weak self] in
            await prior?.value
            guard !Task.isCancelled else { return }
            // A single batch task permits one request per family, independently.
            await withTaskGroup(of: (IPFamily, Result<String, NetworkFailure>).self) { group in
                for family in IPFamily.allCases {
                    group.addTask {
                        do { return (family, .success(try await provider.fetch(family))) }
                        catch { return (family, .failure(networkFailure(error))) }
                    }
                }
                for await (family, result) in group {
                    guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { continue }
                    if family == .ipv4 { self.snapshot.ipv4.apply(result, at: self.clock.now()) }
                    else { self.snapshot.ipv6.apply(result, at: self.clock.now()) }
                    self.publish(self.snapshot)
                }
            }
            guard !Task.isCancelled, let self, self.isRunning, self.generation == token else { return }
            self.ipTask = nil; self.schedule.completedIP(at: self.clock.uptime()); self.reschedule()
        }
    }

    private func probe(_ service: ProbeService) {
        let token = generation, prior = cancelledWork, provider = connectivity, clock = clock
        if let index = snapshot.probes.firstIndex(where: { $0.service == service }) {
            snapshot.probes[index] = ProbeReading(service: service, state: .checking)
        }
        publish(snapshot)
        probeTasks[service] = Task { [weak self] in
            await prior?.value
            var reading: ProbeReading
            do {
                try Task.checkCancellation()
                reading = try await provider.probe(service, now: clock.now, uptime: clock.uptime)
            } catch {
                let failure = networkFailure(error)
                reading = ProbeReading(service: service, state: failure == .timeout ? .timeout : failure == .offline ? .offline : .transportFailed,
                                       sampledAt: clock.now(), failure: failure)
            }
            guard let self, self.isRunning, self.generation == token else { return }
            self.probeTasks[service] = nil
            if !Task.isCancelled && self.snapshot.probesEnabled {
                if let index = self.snapshot.probes.firstIndex(where: { $0.service == service }) { self.snapshot.probes[index] = reading }
                self.schedule.completedProbe(service, success: reading.state == .reachable, at: clock.uptime())
                self.publish(self.snapshot)
            }
            self.reschedule()
        }
    }

    // Enables deterministic observers/tests to await the current batch without
    // creating another request or changing scheduling policy.
    func waitForCurrentWork() async {
        let ip = ipTask, local = localTask, probes = Array(probeTasks.values)
        await ip?.value; await local?.value
        for probe in probes { await probe.value }
    }
    func waitForStop() async { await cancelledWork?.value }
}
