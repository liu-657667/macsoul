import XCTest
import Combine
import IOKit.ps
@testable import MacSoul

actor StubDetailSampler: SystemDetailSampling {
    private(set) var starts = 0
    private(set) var stops = 0
    private(set) var diskReads = 0
    private(set) var batteryReads = 0
    private(set) var processReads = 0
    var disk: DiskReading = .available(DiskUsage(totalBytes: 100, availableBytes: 40), sampledAt: Date())
    var battery: BatteryReading = .notPresent(sampledAt: Date())
    var processes: ProcessReading = .available([], sampledAt: Date())

    func start() { starts += 1 }
    func stop() { stops += 1 }
    func sampleDisk(now: Date) -> DiskReading { diskReads += 1; return disk }
    func sampleBattery(now: Date) -> BatteryReading { batteryReads += 1; return battery }
    func sampleProcesses(now: Date, uptime: TimeInterval) -> ProcessReading {
        processReads += 1; return processes
    }
    func setDisk(_ value: DiskReading) { disk = value }
    func setBattery(_ value: BatteryReading) { battery = value }
}

private struct FailedProcessScanner: ProcessScanning {
    func scan() -> [ProcessObservation]? { nil }
}

final class SystemDetailsTests: XCTestCase {
    func testDiskRawBytesAndInvalidCapacity() {
        let disk = DiskUsage.calculate(totalBytes: 1_000, availableBytes: 255)
        XCTAssertEqual(disk?.totalBytes, 1_000)
        XCTAssertEqual(disk?.availableBytes, 255)
        XCTAssertEqual(disk?.usedBytes, 745)
        XCTAssertEqual(disk?.usedPercent, 74.5)
        XCTAssertEqual(disk!.usedGiB, 745.0 / 1_073_741_824, accuracy: 0.00001)
        XCTAssertNil(DiskUsage.calculate(totalBytes: nil, availableBytes: 50))
        XCTAssertNil(DiskUsage.calculate(totalBytes: 0, availableBytes: 0))
        XCTAssertNil(DiskUsage.calculate(totalBytes: 100, availableBytes: -1))
        XCTAssertNil(DiskUsage.calculate(totalBytes: 100, availableBytes: 101))
    }

    func testBatteryChargingDischargingAndNoBattery() {
        let date = Date(timeIntervalSince1970: 123)
        var description: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSIsPresentKey: true,
            kIOPSCurrentCapacityKey: 40,
            kIOPSMaxCapacityKey: 80,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSIsChargingKey: true
        ]
        XCTAssertEqual(BatteryReading.interpret([description], at: date),
                       .present(BatteryStatus(chargePercent: 50, chargeState: .charging,
                                              externalPower: true), sampledAt: date))
        description[kIOPSPowerSourceStateKey] = kIOPSBatteryPowerValue
        description[kIOPSIsChargingKey] = false
        XCTAssertEqual(BatteryReading.interpret([description], at: date),
                       .present(BatteryStatus(chargePercent: 50, chargeState: .discharging,
                                              externalPower: false), sampledAt: date))
        description[kIOPSIsPresentKey] = false
        XCTAssertEqual(BatteryReading.interpret([description], at: date), .notPresent(sampledAt: date))
        XCTAssertEqual(BatteryReading.interpret([], at: date), .notPresent(sampledAt: date))
    }

    func testBatteryMalformedAndFailedReadAreUnavailableNotZero() {
        let date = Date(timeIntervalSince1970: 123)
        let type: [String: Any] = [kIOPSTypeKey: kIOPSInternalBatteryType]
        XCTAssertEqual(BatteryReading.interpret(nil, at: date), .unavailable(sampledAt: date))
        XCTAssertEqual(BatteryReading.interpret([type], at: date), .unavailable(sampledAt: date))
        var invalid = type
        invalid[kIOPSIsPresentKey] = true
        invalid[kIOPSCurrentCapacityKey] = 101
        invalid[kIOPSMaxCapacityKey] = 100
        XCTAssertEqual(BatteryReading.interpret([invalid], at: date), .unavailable(sampledAt: date))
        XCTAssertNil(BatteryStatus.parse(invalid))
    }

    func testConservativeDeveloperClassifier() {
        for name in ["Xcode", "xcodebuild", "swift", "clang", "gradle", "java", "node",
                     "python3", "cargo", "bun", "npm", "git", "com.docker.backend", "postgres", "redis-server"] {
            XCTAssertTrue(DeveloperProcessClassifier.isDeveloperProcess(name), name)
        }
        for name in ["Safari", "Finder", "java-helper-random", "node-web-browser", "unknown"] {
            XCTAssertFalse(DeveloperProcessClassifier.isDeveloperProcess(name), name)
        }
    }

    func testProcessFirstDeltaMulticoreDisappearanceResetAndOrdering() {
        var calculator = ProcessCPUCalculator()
        func item(_ pid: Int32, _ name: String, _ time: UInt64, _ rss: UInt64) -> ProcessObservation {
            ProcessObservation(pid: pid, name: name, cpuTimeNanoseconds: time, residentBytes: rss)
        }
        let first = calculator.sample([item(1, "node", 1_000_000_000, 200),
                                       item(2, "java", 1_000_000_000, 100)], at: 10)
        XCTAssertNil(first[0].cpuPercent)
        XCTAssertEqual(first.map(\.pid), [1, 2]) // RSS fallback before CPU baseline.
        let second = calculator.sample([item(1, "node", 7_000_000_000, 200),
                                        item(2, "java", 4_000_000_000, 100)], at: 13)
        XCTAssertEqual(second.map(\.pid), [1, 2])
        XCTAssertEqual(second[0].cpuPercent!, 200, accuracy: 0.001) // >100% is valid.
        XCTAssertEqual(second[1].cpuPercent!, 100, accuracy: 0.001)
        _ = calculator.sample([item(2, "java", 5_000_000_000, 100)], at: 16)
        XCTAssertNil(calculator.sample([item(1, "node", 8_000_000_000, 200)], at: 19)[0].cpuPercent)
        XCTAssertNil(calculator.sample([item(1, "node", 1, 200)], at: 22)[0].cpuPercent)
        XCTAssertNil(calculator.sample([item(1, "node", 2, 200)], at: 22)[0].cpuPercent)
    }

    func testInaccessiblePIDIsSkippedAndEnumerationFailureIsUnavailable() async {
        let observation = ProcessObservation(pid: 2, name: "node", cpuTimeNanoseconds: 1,
                                             residentBytes: 1)
        let collected = NativeProcessScanner.collect([1, 2, 3]) { $0 == 2 ? observation : nil }
        XCTAssertEqual(collected, [observation])
        let sampler = NativeSystemDetailSampler(processScanner: FailedProcessScanner())
        let date = Date(timeIntervalSince1970: 123)
        let reading = await sampler.sampleProcesses(now: date, uptime: 10)
        XCTAssertEqual(reading, .unavailable(sampledAt: date))
    }

    func testTopNAndEqualCPUSortsByResidentMemory() {
        var calculator = ProcessCPUCalculator()
        let initial = (1...6).map { ProcessObservation(pid: Int32($0), name: "node",
                                                      cpuTimeNanoseconds: 0, residentBytes: UInt64($0)) }
        XCTAssertEqual(calculator.sample(initial, at: 0, limit: 5).map(\.pid), [6, 5, 4, 3, 2])
        let next = initial.map { ProcessObservation(pid: $0.pid, name: $0.name,
            cpuTimeNanoseconds: 1_000_000_000, residentBytes: $0.residentBytes) }
        XCTAssertEqual(calculator.sample(next, at: 1, limit: 5).map(\.pid), [6, 5, 4, 3, 2])
    }

    func testIndependentCadenceKeepsCPUFastAndDetailsSlow() {
        var cadence = DetailCadence()
        XCTAssertEqual(cadence.due(at: 0, systemVisible: true).disk, true)
        XCTAssertEqual(cadence.due(at: 1, systemVisible: true).processes, false)
        XCTAssertEqual(cadence.due(at: 3, systemVisible: true).processes, true)
        XCTAssertEqual(cadence.due(at: 5, systemVisible: false).processes, false)
        XCTAssertEqual(cadence.due(at: 18, systemVisible: false).processes, true)
        XCTAssertEqual(cadence.due(at: 59, systemVisible: true).disk, false)
        XCTAssertEqual(cadence.due(at: 60, systemVisible: true).disk, true)
    }
}
