import XCTest
import Dispatch
import Combine
@testable import MacSoul

private final class TestSoulClock: SoulClock {
    var uptime: TimeInterval = 0
}

private actor StubSystemSampler: SystemSampling {
    private(set) var startCalls = 0
    private(set) var stopCalls = 0
    func start() { startCalls += 1 }
    func stop() { stopCalls += 1 }
    func sample() -> SystemReading {
        SystemReading(cpuPercent: 25, memory: MemoryUsage(usedBytes: 4, totalBytes: 8), pressure: .normal)
    }
}

final class SystemSoulTests: XCTestCase {
    func testCPUFirstInvalidAndAggregateDeltas() {
        var calculator = CPUUsageCalculator()
        XCTAssertNil(calculator.sample(CPUTicks(user: 10, system: 10, nice: 0, idle: 80)))
        XCTAssertEqual(calculator.sample(CPUTicks(user: 30, system: 20, nice: 0, idle: 150))!, 30, accuracy: 0.001)
        XCTAssertNil(calculator.sample(CPUTicks(user: 30, system: 20, nice: 0, idle: 150)))
        XCTAssertNil(calculator.sample(nil))
        XCTAssertNil(calculator.sample(CPUTicks(user: 1, system: 1, nice: 1, idle: 1)))
        XCTAssertNil(calculator.sample(CPUTicks(user: 0, system: 1, nice: 1, idle: 1)))
    }

    func testMemoryBytesPercentAndInvalidCounts() {
        let memory = MemoryUsage.calculate(totalBytes: 1000, pageSize: 10,
                                           freePages: 5, fileBackedPages: 15)
        XCTAssertEqual(memory?.usedBytes, 800)
        XCTAssertEqual(memory?.totalBytes, 1000)
        XCTAssertEqual(memory?.usedPercent, 80)
        // Inactive anonymous and compressor pages are included by the residual;
        // speculative pages are already included in freePages, not counted twice.
        let fixture = MemoryUsage.calculate(totalBytes: 1_073_741_824, pageSize: 16_384,
                                            freePages: 100, fileBackedPages: 500)
        XCTAssertEqual(fixture?.usedBytes, 1_063_911_424)
        XCTAssertEqual(fixture?.totalGiB, 1)
        XCTAssertEqual(fixture!.usedGiB, Double(fixture!.usedBytes) / 1_073_741_824, accuracy: 0.00001)
        XCTAssertNil(MemoryUsage.calculate(totalBytes: 100, pageSize: 10,
                                           freePages: 8, fileBackedPages: 3))
        XCTAssertNil(MemoryUsage.calculate(totalBytes: 0, pageSize: 10,
                                           freePages: 0, fileBackedPages: 0))
        XCTAssertNil(MemoryUsage.calculate(totalBytes: 100, pageSize: 0,
                                           freePages: 0, fileBackedPages: 0))
        XCTAssertNil(MemoryUsage.calculate(totalBytes: 100, pageSize: 10,
                                           freePages: UInt64.max, fileBackedPages: 1))
    }

    func testPressureEventMappingKeepsUnknownDistinct() {
        XCTAssertEqual(NativeSystemSampler.mapPressureEvent([]), .unknown)
        XCTAssertEqual(NativeSystemSampler.mapPressureEvent(.normal), .normal)
        XCTAssertEqual(NativeSystemSampler.mapPressureEvent(.warning), .warning)
        XCTAssertEqual(NativeSystemSampler.mapPressureEvent([.warning, .critical]), .critical)
    }

    func testSoulThresholdHysteresisRecoveryAndCooldownWithoutSleeping() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        func sample(_ time: TimeInterval, _ cpu: Double, _ pressure: MemoryPressureLevel = .normal) -> SoulStatus {
            clock.uptime = time
            return soul.evaluate(cpu: cpu, pressure: pressure)
        }
        XCTAssertEqual(sample(0, 86).state, .calm)
        XCTAssertEqual(sample(14, 86).state, .calm) // gap discards sustained time
        XCTAssertEqual(sample(15, 86).state, .calm)
        XCTAssertEqual(sample(30, 86).state, .calm) // another gap
        // Feed at intervals below the 10-second interruption guard.
        for second in stride(from: 31, through: 46, by: 5) { _ = sample(Double(second), 86) }
        XCTAssertEqual(soul.state, .stressed)
        XCTAssertEqual(sample(47, 96).state, .stressed)
        for second in stride(from: 52, through: 67, by: 5) { _ = sample(Double(second), 96) }
        XCTAssertEqual(soul.state, .brainOverload)
        for second in stride(from: 68, through: 98, by: 5) { _ = sample(Double(second), 50) }
        XCTAssertEqual(soul.state, .recovering)
        XCTAssertEqual(sample(99, 50).state, .calm)
        for second in stride(from: 100, through: 115, by: 5) { _ = sample(Double(second), 86) }
        XCTAssertEqual(soul.state, .stressed)
        XCTAssertEqual(sample(116, 86).message, "CPU load remains high.")
    }

    func testSoulMemoryPriorityUnknownAndSuspend() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        XCTAssertEqual(soul.evaluate(cpu: nil, pressure: .unknown).state, .observing)
        clock.uptime = 1
        XCTAssertEqual(soul.evaluate(cpu: 10, pressure: .warning).state, .memoryWarning)
        clock.uptime = 2
        XCTAssertEqual(soul.evaluate(cpu: 99, pressure: .critical).state, .memoryCritical)
        soul.suspend()
        clock.uptime = 100
        XCTAssertEqual(soul.evaluate(cpu: 20, pressure: .unknown).state, .memoryCritical)
        for second in stride(from: 101, through: 131, by: 5) {
            clock.uptime = Double(second)
            _ = soul.evaluate(cpu: 20, pressure: .normal)
        }
        XCTAssertEqual(soul.state, .recovering)
    }

    func testSoulCalmCopyDoesNotClaimKnownMemoryPressure() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        let monitoring = soul.evaluate(cpu: 30, pressure: .unknown)
        XCTAssertEqual(monitoring.state, .calm)
        XCTAssertEqual(monitoring.mood, "CPU calm · Live")
        XCTAssertEqual(monitoring.message, "CPU is steady; memory pressure is still being monitored.")
        clock.uptime = 1
        let known = soul.evaluate(cpu: 30, pressure: .normal)
        XCTAssertEqual(known.state, .calm)
        XCTAssertEqual(known.message, "System load is steady.")
        clock.uptime = 2
        XCTAssertEqual(soul.evaluate(cpu: .nan, pressure: .normal).state, .observing)
    }

    @MainActor func testOneHubForRepeatedWindowAndMenuAppearances() async {
        let sampler = StubSystemSampler()
        let store = AppStore(sampler: sampler)
        store.setSystemMode(.live)
        let first = UUID(), second = UUID()
        store.setWindow(first, visible: true, section: .overview)
        store.setWindow(first, visible: true, section: .overview)
        store.setWindow(second, visible: true, section: .system)
        XCTAssertEqual(store.sensorInterval, 1)
        store.setWindow(second, visible: false, section: .system)
        XCTAssertEqual(store.sensorInterval, 5)
        XCTAssertEqual(store.sensorStarts, 1)
        store.setSystemMode(.preview)
    }

    @MainActor func testSharedStorePublishesOnlyCPUAndMemoryAsLive() async {
        let sampler = StubSystemSampler()
        let store = AppStore(sampler: sampler)
        let received = expectation(description: "shared live snapshot")
        var subscription: AnyCancellable? = store.$snapshot.sink { value in
            if value.systemMode == .live && value.cpu.usedPercent == 25 {
                received.fulfill()
            }
        }
        store.setSystemMode(.live)
        await fulfillment(of: [received], timeout: 2)
        XCTAssertEqual(store.snapshot.cpu.usedPercent, 25)
        XCTAssertEqual(store.snapshot.memoryUsed.usedPercent, 50)
        XCTAssertEqual(store.snapshot.memoryPressure, "Normal · Live")
        XCTAssertEqual(store.snapshot.disk.usedPercent, 67)
        XCTAssertEqual(store.snapshot.battery.usedPercent, 78)
        XCTAssertEqual(store.snapshot.quotas.first?.mode, .mock)
        XCTAssertEqual(store.snapshot.mode, .mock)
        let startCalls = await sampler.startCalls
        XCTAssertEqual(startCalls, 1)
        store.setSystemMode(.preview)
        subscription?.cancel()
        subscription = nil
    }

    @MainActor func testHubStartStopAreIdempotentAndReleaseSampler() async {
        let sampler = StubSystemSampler()
        let received = expectation(description: "first sample")
        let hub = SensorHub(sampler: sampler) { reading, _ in
            XCTAssertEqual(reading.cpuPercent, 25)
            received.fulfill()
        }
        hub.start()
        hub.start()
        await fulfillment(of: [received], timeout: 2)
        XCTAssertEqual(hub.starts, 1)
        hub.stop()
        hub.stop()
        await hub.waitForStop()
        let startCalls = await sampler.startCalls
        let stopCalls = await sampler.stopCalls
        XCTAssertEqual(startCalls, 1)
        XCTAssertEqual(stopCalls, 1)
    }
}
