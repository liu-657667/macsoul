import Foundation

@MainActor final class SensorHub {
    private let sampler: any SystemSampling
    private let soul: SoulEngine
    private let onReading: (SystemReading, SoulStatus) -> Void
    private var loop: Task<Void, Never>?
    private var previousLoop: Task<Void, Never>?
    private var delay: Task<Void, Never>?
    private(set) var starts = 0
    private(set) var samples = 0
    var systemPageVisible = false { didSet { delay?.cancel() } }
    var samplingInterval: TimeInterval { systemPageVisible ? 1 : 5 }
    var isRunning: Bool { loop != nil }

    init(sampler: any SystemSampling = NativeSystemSampler(),
         clock: any SoulClock = UptimeSoulClock(),
         onReading: @escaping (SystemReading, SoulStatus) -> Void) {
        self.sampler = sampler
        soul = SoulEngine(clock: clock)
        self.onReading = onReading
    }

    func start() {
        guard loop == nil else { return }
        starts += 1
        let previous = previousLoop
        loop = Task { [weak self] in
            if let previous { await previous.value }
            guard let self, !Task.isCancelled else { return }
            await sampler.start()
            while !Task.isCancelled {
                let reading = await sampler.sample()
                guard !Task.isCancelled else { break }
                samples += 1
                onReading(reading, soul.evaluate(cpu: reading.cpuPercent, pressure: reading.pressure))
                let nanoseconds = UInt64(samplingInterval * 1_000_000_000)
                let sleeper = Task {
                    do { try await Task.sleep(nanoseconds: nanoseconds) }
                    catch { return }
                }
                delay = sleeper
                await sleeper.value
                delay = nil
            }
            await sampler.stop()
        }
    }

    func stop() {
        guard let loop else { return }
        self.loop = nil
        previousLoop = loop
        loop.cancel()
        delay?.cancel()
        soul.suspend()
    }

    func waitForStop() async { await previousLoop?.value }
}
