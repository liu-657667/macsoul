import Foundation

@MainActor final class SensorHub {
    private let sampler: any SystemSampling
    private let details: any SystemDetailSampling
    private let soul: SoulEngine
    private let onReading: (SystemReading, SoulStatus) -> Void
    private let onDetails: (SystemDetailUpdate) -> Void
    private var loop: Task<Void, Never>?
    private var previousLoop: Task<Void, Never>?
    private var delay: Task<Void, Never>?
    private var diskTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var cadence = DetailCadence()
    private var generation = 0
    private var batteryRefreshPending = false
    private var batteryNotificationsActive = false
    private var lastBatteryFallback: TimeInterval?
    private lazy var powerNotifications = PowerSourceNotifications { [weak self] in self?.refreshBattery() }
    private(set) var starts = 0
    private(set) var samples = 0
    var samplingTier: SamplingTier = .foregroundBackground { didSet { if oldValue != samplingTier { delay?.cancel() } } }
    var samplingInterval: TimeInterval { samplingTier.systemInterval }
    var isRunning: Bool { loop != nil }

    init(sampler: any SystemSampling = NativeSystemSampler(),
         details: any SystemDetailSampling = NativeSystemDetailSampler(),
         clock: any SoulClock = UptimeSoulClock(),
         onReading: @escaping (SystemReading, SoulStatus) -> Void,
         onDetails: @escaping (SystemDetailUpdate) -> Void = { _ in }) {
        self.sampler = sampler
        self.details = details
        soul = SoulEngine(clock: clock)
        self.onReading = onReading
        self.onDetails = onDetails
    }

    func start() {
        guard loop == nil else { return }
        starts += 1
        generation += 1
        cadence.reset()
        batteryNotificationsActive = powerNotifications.start()
        lastBatteryFallback = nil
        let previous = previousLoop
        loop = Task { [weak self] in
            if let previous { await previous.value }
            guard let self, !Task.isCancelled else { return }
            await sampler.start()
            await details.start()
            refreshBattery()
            lastBatteryFallback = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                let reading = await sampler.sample()
                guard !Task.isCancelled else { break }
                samples += 1
                onReading(reading, soul.evaluate(cpu: reading.cpuPercent, pressure: reading.pressure))
                let due = cadence.due(at: ProcessInfo.processInfo.systemUptime,
                                      systemVisible: samplingTier == .foregroundRelevant,
                                      mainVisible: samplingTier != .menuBarOnly)
                if due.disk { refreshDisk() }
                if due.processes { refreshProcesses() }
                if !batteryNotificationsActive,
                   let lastBatteryFallback,
                   ProcessInfo.processInfo.systemUptime - lastBatteryFallback >= 60 {
                    refreshBattery() // Rare fallback when IOKit notification registration fails.
                    self.lastBatteryFallback = ProcessInfo.processInfo.systemUptime
                }
                let nanoseconds = UInt64(samplingInterval * 1_000_000_000)
                let sleeper = Task {
                    do { try await Task.sleep(nanoseconds: nanoseconds) }
                    catch { return }
                }
                delay = sleeper
                await sleeper.value
                delay = nil
            }
            diskTask?.cancel(); batteryTask?.cancel(); processTask?.cancel()
            await diskTask?.value; await batteryTask?.value; await processTask?.value
            diskTask = nil; batteryTask = nil; processTask = nil
            await sampler.stop()
            await details.stop()
        }
    }

    func stop() {
        guard let loop else { return }
        self.loop = nil
        previousLoop = loop
        generation += 1
        loop.cancel()
        delay?.cancel()
        diskTask?.cancel(); batteryTask?.cancel(); processTask?.cancel()
        powerNotifications.stop()
        batteryNotificationsActive = false
        lastBatteryFallback = nil
        batteryRefreshPending = false
        soul.suspend()
    }

    func waitForStop() async { await previousLoop?.value }

    private func refreshDisk() {
        guard diskTask == nil else { return }
        let activeGeneration = generation
        diskTask = Task { [weak self] in
            guard let self else { return }
            let reading = await details.sampleDisk(now: Date())
            if !Task.isCancelled && activeGeneration == generation && loop != nil {
                onDetails(.disk(reading))
            }
            diskTask = nil
        }
    }

    private func refreshProcesses() {
        guard processTask == nil else { return }
        let activeGeneration = generation
        processTask = Task { [weak self] in
            guard let self else { return }
            let reading = await details.sampleProcesses(now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            if !Task.isCancelled && activeGeneration == generation && loop != nil {
                onDetails(.processes(reading))
            }
            processTask = nil
        }
    }

    private func refreshBattery() {
        guard loop != nil else { return }
        guard batteryTask == nil else { batteryRefreshPending = true; return }
        let activeGeneration = generation
        batteryTask = Task { [weak self] in
            guard let self else { return }
            let reading = await details.sampleBattery(now: Date())
            if !Task.isCancelled && activeGeneration == generation && loop != nil {
                onDetails(.battery(reading))
            }
            batteryTask = nil
            if batteryRefreshPending && activeGeneration == generation {
                batteryRefreshPending = false
                refreshBattery()
            }
        }
    }
}
