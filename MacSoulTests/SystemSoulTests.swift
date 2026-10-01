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

    func testCPUSeverityUpgradeSharesAnnouncementCooldown() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        func sample(_ time: TimeInterval, _ cpu: Double) -> SoulStatus {
            clock.uptime = time
            return soul.evaluate(cpu: cpu, pressure: .normal)
        }
        for second in stride(from: 0, through: 10, by: 5) { _ = sample(Double(second), 86) }
        let stressed = sample(15, 86)
        XCTAssertEqual(stressed.state, .stressed)
        XCTAssertEqual(stressed.message, "我开始认真工作了。")

        for second in stride(from: 20, through: 35, by: 5) { _ = sample(Double(second), 96) }
        let overload = sample(40, 96)
        XCTAssertEqual(overload.state, .brainOverload)
        XCTAssertEqual(overload.visual, .overload)
        XCTAssertEqual(overload.mood, "Overload · Live")
        XCTAssertEqual(overload.message, "CPU load remains critical.")

        soul.suspend()
        for second in stride(from: 1800, through: 1810, by: 5) { _ = sample(Double(second), 86) }
        XCTAssertEqual(sample(1815, 86).message, "我开始认真工作了。")
    }

    func testMemorySeverityUpgradeSharesAnnouncementCooldownAcrossSuspend() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        let warning = soul.evaluate(cpu: 20, pressure: .warning)
        XCTAssertEqual(warning.state, .memoryWarning)
        XCTAssertEqual(warning.message, "我的胃快撑爆了。")

        clock.uptime = 1
        let critical = soul.evaluate(cpu: 20, pressure: .critical)
        XCTAssertEqual(critical.state, .memoryCritical)
        XCTAssertEqual(critical.visual, .bloated)
        XCTAssertEqual(critical.mood, "Memory critical · Live")
        XCTAssertEqual(critical.message, "Memory pressure remains critical.")

        soul.suspend()
        clock.uptime = 100
        XCTAssertEqual(soul.evaluate(cpu: 20, pressure: .warning).message,
                       "Memory pressure remains elevated.")
        soul.suspend()
        clock.uptime = 1800
        XCTAssertEqual(soul.evaluate(cpu: 20, pressure: .critical).message, "我的胃快撑爆了。")
    }

    func testRecoveryAnnouncesOncePerCooldown() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        func sample(_ time: TimeInterval, _ pressure: MemoryPressureLevel) -> SoulStatus {
            clock.uptime = time
            return soul.evaluate(cpu: 20, pressure: pressure)
        }
        _ = sample(0, .critical)
        for second in stride(from: 1, through: 26, by: 5) { _ = sample(Double(second), .normal) }
        let firstRecovery = sample(31, .normal)
        XCTAssertEqual(firstRecovery.state, .recovering)
        XCTAssertEqual(firstRecovery.message, "呼……终于安静了。")
        XCTAssertEqual(sample(32, .normal).state, .calm)

        _ = sample(33, .critical)
        for second in stride(from: 34, through: 59, by: 5) { _ = sample(Double(second), .normal) }
        let secondRecovery = sample(64, .normal)
        XCTAssertEqual(secondRecovery.state, .recovering)
        XCTAssertEqual(secondRecovery.message, "System load is recovering.")
    }

    func testSoulMemoryPriorityAndRecovery() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        XCTAssertEqual(soul.evaluate(cpu: nil, pressure: .unknown).state, .observing)
        clock.uptime = 1
        XCTAssertEqual(soul.evaluate(cpu: 10, pressure: .warning).state, .memoryWarning)
        clock.uptime = 2
        XCTAssertEqual(soul.evaluate(cpu: 99, pressure: .critical).state, .memoryCritical)
        for second in stride(from: 3, through: 33, by: 5) {
            clock.uptime = Double(second)
            _ = soul.evaluate(cpu: 20, pressure: .normal)
        }
        XCTAssertEqual(soul.state, .recovering)
    }

    func testSuspendDiscardsOldMemoryCriticalWhenPressureIsUnknown() {
        let clock = TestSoulClock()
        let soul = SoulEngine(clock: clock)
        XCTAssertEqual(soul.evaluate(cpu: 20, pressure: .critical).state, .memoryCritical)

        soul.suspend()
        XCTAssertEqual(soul.state, .observing)
        clock.uptime = 100
        let first = soul.evaluate(cpu: nil, pressure: .unknown)
        XCTAssertEqual(first.state, .observing)
        clock.uptime = 101
        let next = soul.evaluate(cpu: 20, pressure: .unknown)
        XCTAssertEqual(next.state, .calm)
        XCTAssertEqual(next.mood, "CPU calm · Live")
        for second in stride(from: 106, through: 136, by: 5) {
            clock.uptime = Double(second)
            XCTAssertNotEqual(soul.evaluate(cpu: 20, pressure: .unknown).state, .memoryCritical)
        }
    }

    func testSuspendDiscardsOldStressedAndBrainOverloadStates() {
        for oldState in [SoulState.stressed, .brainOverload] {
            let clock = TestSoulClock()
            let soul = SoulEngine(clock: clock)
            let highCPU = oldState == .stressed ? 86.0 : 96.0
            let duration = oldState == .stressed ? 15 : 20
            for second in stride(from: 0, through: duration, by: 5) {
                clock.uptime = Double(second)
                _ = soul.evaluate(cpu: highCPU, pressure: .normal)
            }
            XCTAssertEqual(soul.state, oldState)

            soul.suspend()
            XCTAssertEqual(soul.state, .observing)
            clock.uptime = 100
            XCTAssertEqual(soul.evaluate(cpu: nil, pressure: .unknown).state, .observing)
            clock.uptime = 101
            XCTAssertEqual(soul.evaluate(cpu: 20, pressure: .unknown).state, .calm)
        }
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
        let details = StubDetailSampler()
        let store = AppStore(sampler: sampler, details: details)
        let received = expectation(description: "first live disk and CPU sample")
        var didFulfill = false
        let subscription = store.$snapshot.sink { value in
            if !didFulfill && value.cpu.usedPercent == 25 && value.disk.usedPercent == 60 {
                didFulfill = true
                received.fulfill()
            }
        }
        store.setSystemMode(.live)
        await fulfillment(of: [received], timeout: 2)
        let first = UUID(), second = UUID()
        store.setWindow(first, visible: true, section: .overview)
        store.setWindow(first, visible: true, section: .overview)
        store.setWindow(second, visible: true, section: .system)
        XCTAssertEqual(store.sensorInterval, 1)
        store.setWindow(second, visible: false, section: .system)
        XCTAssertEqual(store.sensorInterval, 5)
        XCTAssertEqual(store.sensorStarts, 1)
        let detailStarts = await details.starts
        let diskReads = await details.diskReads
        let processReads = await details.processReads
        XCTAssertEqual(detailStarts, 1)
        XCTAssertEqual(diskReads, 1)
        XCTAssertLessThanOrEqual(processReads, 1)
        store.setSystemMode(.preview)
        subscription.cancel()
    }

    @MainActor func testSharedStorePublishesLiveSystemDetailsWithoutReplacingMockModules() async {
        let sampler = StubSystemSampler()
        let details = StubDetailSampler()
        let store = AppStore(sampler: sampler, details: details)
        let received = expectation(description: "shared live snapshot")
        var didFulfill = false
        var subscription: AnyCancellable? = store.$snapshot.sink { value in
            if !didFulfill && value.systemMode == .live && value.cpu.usedPercent == 25 &&
                value.disk.usedPercent == 60 && value.batterySummaryOverride == "No battery" {
                didFulfill = true
                received.fulfill()
            }
        }
        store.setSystemMode(.live)
        await fulfillment(of: [received], timeout: 2)
        XCTAssertEqual(store.snapshot.cpu.usedPercent, 25)
        XCTAssertEqual(store.snapshot.memoryUsed.usedPercent, 50)
        XCTAssertEqual(store.snapshot.memoryPressure, "Normal · Live")
        XCTAssertEqual(store.snapshot.disk.usedPercent, 60)
        XCTAssertNil(store.snapshot.battery.usedPercent)
        XCTAssertEqual(store.snapshot.batterySummaryOverride, "No battery")
        XCTAssertEqual(store.snapshot.quotas.first?.mode, .mock)
        XCTAssertEqual(store.snapshot.publicIP, "203.0.113.42")
        XCTAssertEqual(store.snapshot.devMode, .live)
        XCTAssertTrue(store.snapshot.runtimes.isEmpty) // No old Mock runtime in Live mode.
        XCTAssertEqual(store.snapshot.mode, .mock)
        let startCalls = await sampler.startCalls
        XCTAssertEqual(startCalls, 1)
        store.setSystemMode(.preview)
        XCTAssertEqual(store.snapshot.disk.usedPercent, 67)
        XCTAssertEqual(store.snapshot.battery.usedPercent, 78)
        subscription?.cancel()
        subscription = nil
    }

    @MainActor func testLiveDetailFailuresNeverReuseMockDiskOrBattery() async {
        let details = StubDetailSampler()
        let sampleTime = Date(timeIntervalSince1970: 123)
        await details.setDisk(.unavailable(sampledAt: sampleTime))
        await details.setBattery(.unavailable(sampledAt: sampleTime))
        let store = AppStore(sampler: StubSystemSampler(), details: details)
        let received = expectation(description: "detail failures in shared snapshot")
        var didFulfill = false
        let subscription = store.$snapshot.sink { value in
            if !didFulfill, case .unavailable = value.diskReading,
               case .unavailable = value.batteryReading {
                didFulfill = true
                received.fulfill()
            }
        }
        store.setSystemMode(.live)
        await fulfillment(of: [received], timeout: 2)
        XCTAssertNil(store.snapshot.disk.usedPercent)
        XCTAssertNil(store.snapshot.battery.usedPercent)
        XCTAssertEqual(store.snapshot.diskEmptyState, "Unavailable")
        XCTAssertEqual(store.snapshot.batteryEmptyState, "Unavailable")
        XCTAssertEqual(store.snapshot.quotas.first?.mode, .mock)
        store.setSystemMode(.preview)
        subscription.cancel()
    }

    @MainActor func testHubStartStopAreIdempotentAndReleaseSampler() async {
        let sampler = StubSystemSampler()
        let received = expectation(description: "first sample")
        let details = StubDetailSampler()
        let hub = SensorHub(sampler: sampler, details: details, onReading: { reading, _ in
            XCTAssertEqual(reading.cpuPercent, 25)
            received.fulfill()
        })
        hub.start()
        hub.start()
        await fulfillment(of: [received], timeout: 2)
        XCTAssertEqual(hub.starts, 1)
        hub.stop()
        hub.stop()
        await hub.waitForStop()
        let startCalls = await sampler.startCalls
        let stopCalls = await sampler.stopCalls
        let detailStarts = await details.starts
        let detailStops = await details.stops
        XCTAssertEqual(startCalls, 1)
        XCTAssertEqual(stopCalls, 1)
        XCTAssertEqual(detailStarts, 1)
        XCTAssertEqual(detailStops, 1)
    }
}
