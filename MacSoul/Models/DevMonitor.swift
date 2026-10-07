import Foundation

@MainActor final class DevMonitor {
    private let runtimes: RuntimeDetector
    private let ports: PortDetector
    private let onRuntimes: (RuntimeReading) -> Void
    private let onPorts: (PortReading) -> Void
    private var loop: Task<Void, Never>?
    private var previousLoop: Task<Void, Never>?
    private var delay: Task<Void, Never>?
    private var runtimeTask: Task<Void, Never>?
    private var portTask: Task<Void, Never>?
    private var cadence = DevCadence()
    private var lastRuntimeSample: TimeInterval?
    private var generation = 0
    private var refreshPending = false
    private var portRefreshPending = false
    private(set) var starts = 0
    var samplingTier: SamplingTier = .foregroundBackground { didSet { if oldValue != samplingTier { delay?.cancel() } } }
    var portInterval: TimeInterval { samplingTier == .foregroundRelevant ? DevCadence.visible : DevCadence.background }
    var isRunning: Bool { loop != nil }

    init(runtimes: RuntimeDetector = RuntimeDetector(), ports: PortDetector = PortDetector(),
         onRuntimes: @escaping (RuntimeReading) -> Void,
         onPorts: @escaping (PortReading) -> Void) {
        self.runtimes = runtimes; self.ports = ports
        self.onRuntimes = onRuntimes; self.onPorts = onPorts
    }

    func start() {
        guard loop == nil else { return }
        starts += 1
        generation += 1
        cadence.reset()
        lastRuntimeSample = nil
        let prior = previousLoop
        loop = Task { [weak self] in
            if let prior { await prior.value }
            guard let self, !Task.isCancelled else { return }
            sampleRuntimes(refresh: false)
            while !Task.isCancelled {
                let now = ProcessInfo.processInfo.systemUptime
                if let lastRuntimeSample, now - lastRuntimeSample >= DevCadence.runtimeTTL {
                    sampleRuntimes(refresh: false)
                }
                if cadence.portsDue(at: now, visible: samplingTier == .foregroundRelevant) {
                    samplePorts()
                }
                let seconds = cadence.nextDelay(at: now, visible: samplingTier == .foregroundRelevant,
                                                lastRuntimeSample: lastRuntimeSample)
                let sleeper = Task {
                    do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
                    catch { return }
                }
                delay = sleeper
                await sleeper.value
                delay = nil
            }
            runtimeTask?.cancel(); portTask?.cancel()
            await runtimeTask?.value; await portTask?.value
            runtimeTask = nil; portTask = nil
        }
    }

    func waitForStop() async { await previousLoop?.value }

    func stop() {
        guard let active = loop else { return }
        loop = nil; previousLoop = active; generation += 1
        active.cancel(); delay?.cancel()
        runtimeTask?.cancel(); portTask?.cancel()
        refreshPending = false
        portRefreshPending = false
    }

    func refresh() {
        guard loop != nil else { return }
        if runtimeTask != nil { refreshPending = true }
        else { sampleRuntimes(refresh: true) }
        cadence.markPortsSampled(at: ProcessInfo.processInfo.systemUptime)
        if portTask == nil { samplePorts() }
        else { portRefreshPending = true }
    }

    private func sampleRuntimes(refresh: Bool) {
        guard runtimeTask == nil else { return }
        lastRuntimeSample = ProcessInfo.processInfo.systemUptime
        let activeGeneration = generation
        runtimeTask = Task { [weak self] in
            guard let self else { return }
            let reading = await runtimes.detect(refresh: refresh)
            if !Task.isCancelled && activeGeneration == generation && loop != nil { onRuntimes(reading) }
            runtimeTask = nil
            if refreshPending && activeGeneration == generation {
                refreshPending = false
                sampleRuntimes(refresh: true)
            }
        }
    }

    private func samplePorts() {
        guard portTask == nil else { return }
        let activeGeneration = generation
        portTask = Task { [weak self] in
            guard let self else { return }
            let reading = await ports.detect()
            if !Task.isCancelled && activeGeneration == generation && loop != nil { onPorts(reading) }
            portTask = nil
            if portRefreshPending && activeGeneration == generation {
                portRefreshPending = false
                samplePorts()
            }
        }
    }
}
