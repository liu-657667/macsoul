import Foundation
import Dispatch
import Darwin
import IOKit.ps
import CoreFoundation

struct DiskUsage: Equatable {
    let totalBytes: UInt64
    let availableBytes: UInt64
    var usedBytes: UInt64 { totalBytes - availableBytes }
    var usedPercent: Double { Double(usedBytes) * 100 / Double(totalBytes) }
    var usedGiB: Double { Double(usedBytes) / 1_073_741_824 }
    var totalGiB: Double { Double(totalBytes) / 1_073_741_824 }

    static func calculate(totalBytes: Int64?, availableBytes: Int64?) -> DiskUsage? {
        guard let totalBytes, let availableBytes, totalBytes > 0,
              availableBytes >= 0, availableBytes <= totalBytes else { return nil }
        return DiskUsage(totalBytes: UInt64(totalBytes), availableBytes: UInt64(availableBytes))
    }
}

enum DiskReading: Equatable {
    case unknown
    case available(DiskUsage, sampledAt: Date)
    case unavailable(sampledAt: Date)
}

enum BatteryChargeState: String, Equatable {
    case charging, discharging, full, unknown
}

struct BatteryStatus: Equatable {
    let chargePercent: Int
    let chargeState: BatteryChargeState
    let externalPower: Bool?

    static func parse(_ description: [String: Any]) -> BatteryStatus? {
        guard let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int,
              maximum > 0, current >= 0, current <= maximum else { return nil }
        let percentage = Int((Double(current) * 100 / Double(maximum)).rounded())
        guard (0...100).contains(percentage) else { return nil }
        let source = description[kIOPSPowerSourceStateKey] as? String
        let external: Bool? = switch source {
        case kIOPSACPowerValue: true
        case kIOPSBatteryPowerValue: false
        default: nil
        }
        let charging = description[kIOPSIsChargingKey] as? Bool
        let full = description[kIOPSIsChargedKey] as? Bool
        let state: BatteryChargeState = if full == true || (percentage == 100 && external == true && charging == false) {
            .full
        } else if charging == true {
            .charging
        } else if external == false {
            .discharging
        } else {
            .unknown
        }
        return BatteryStatus(chargePercent: percentage, chargeState: state, externalPower: external)
    }
}

enum BatteryReading: Equatable {
    case unknown
    case present(BatteryStatus, sampledAt: Date)
    case notPresent(sampledAt: Date)
    case unavailable(sampledAt: Date)

    static func interpret(_ descriptions: [[String: Any]]?, at now: Date) -> BatteryReading {
        guard let descriptions else { return .unavailable(sampledAt: now) }
        for description in descriptions where description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
            guard let present = description[kIOPSIsPresentKey] as? Bool else {
                return .unavailable(sampledAt: now)
            }
            guard present else { return .notPresent(sampledAt: now) }
            guard let status = BatteryStatus.parse(description) else { return .unavailable(sampledAt: now) }
            return .present(status, sampledAt: now)
        }
        return .notPresent(sampledAt: now)
    }
}

struct ProcessObservation: Equatable {
    let pid: Int32
    let name: String
    let cpuTimeNanoseconds: UInt64
    let residentBytes: UInt64
}

struct DeveloperProcess: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let cpuPercent: Double?
    let residentBytes: UInt64
    var id: Int32 { pid }
    var residentMiB: Double { Double(residentBytes) / 1_048_576 }
}

enum ProcessReading: Equatable {
    case unknown
    case available([DeveloperProcess], sampledAt: Date)
    case unavailable(sampledAt: Date)
}

enum SystemDetailUpdate {
    case disk(DiskReading)
    case battery(BatteryReading)
    case processes(ProcessReading)
}

enum DeveloperProcessClassifier {
    private static let exactNames: Set<String> = [
        "xcode", "xcodebuild", "swift", "swiftc", "clang", "clang++",
        "gradle", "mvn", "java", "node", "python", "python3", "go",
        "rustc", "cargo", "bun", "deno", "npm", "pnpm", "yarn", "git",
        "docker", "docker desktop", "postgres", "mysql", "mysqld", "redis-server", "nginx",
        "idea", "idea64", "intellij idea", "com.jetbrains.intellij", "apifox",
        "apifoxappagent", "lingma"
    ]

    static func isDeveloperProcess(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return exactNames.contains(normalized) || normalized.hasPrefix("com.docker.")
    }
}

struct ProcessCPUCalculator {
    private var previous: [Int32: (name: String, time: UInt64)] = [:]
    private var previousUptime: TimeInterval?

    // proc_taskinfo cumulative user + system time is in nanoseconds. Divide its
    // delta by elapsed wall time; 100% is one fully busy logical CPU, so a
    // multithreaded process may legitimately exceed 100%.
    mutating func sample(_ observations: [ProcessObservation], at uptime: TimeInterval,
                         limit: Int = 5) -> [DeveloperProcess] {
        let elapsed = previousUptime.map { uptime - $0 }
        var next: [Int32: (name: String, time: UInt64)] = [:]
        let result = observations.map { item -> DeveloperProcess in
            next[item.pid] = (item.name, item.cpuTimeNanoseconds)
            var percent: Double?
            if let old = previous[item.pid], old.name == item.name,
               let elapsed, elapsed > 0, elapsed.isFinite,
               item.cpuTimeNanoseconds >= old.time {
                percent = Double(item.cpuTimeNanoseconds - old.time) / (elapsed * 1_000_000_000) * 100
                if percent?.isFinite != true { percent = nil }
            }
            return DeveloperProcess(pid: item.pid, name: item.name,
                                    cpuPercent: percent, residentBytes: item.residentBytes)
        }
        previous = next // Missing PIDs lose their baseline; PID reuse never inherits it.
        previousUptime = uptime
        return Array(result.sorted {
            if let lhs = $0.cpuPercent, let rhs = $1.cpuPercent, lhs != rhs { return lhs > rhs }
            if $0.cpuPercent != nil && $1.cpuPercent == nil { return true }
            if $0.cpuPercent == nil && $1.cpuPercent != nil { return false }
            if $0.residentBytes != $1.residentBytes { return $0.residentBytes > $1.residentBytes }
            return $0.pid < $1.pid
        }.prefix(max(limit, 0)))
    }

    mutating func reset() {
        previous = [:]
        previousUptime = nil
    }
}

enum SamplingTier: Equatable {
    case foregroundRelevant, foregroundBackground, menuBarOnly

    static func resolve(mainVisible: Bool, relevantVisible: Bool) -> Self {
        mainVisible ? (relevantVisible ? .foregroundRelevant : .foregroundBackground) : .menuBarOnly
    }
    var systemInterval: TimeInterval {
        switch self {
        case .foregroundRelevant: return 1
        case .foregroundBackground: return 5
        case .menuBarOnly: return 10
        }
    }
}

struct DetailCadence {
    var lastDisk: TimeInterval?
    var lastProcesses: TimeInterval?
    var diskInterval: TimeInterval = 60
    var visibleProcessInterval: TimeInterval = 3
    var backgroundProcessInterval: TimeInterval = 15
    var menuBarProcessInterval: TimeInterval = 30

    mutating func due(at uptime: TimeInterval, systemVisible: Bool, mainVisible: Bool = true) -> (disk: Bool, processes: Bool) {
        let disk = lastDisk.map { uptime - $0 >= diskInterval || uptime < $0 } ?? true
        let processInterval = mainVisible ? (systemVisible ? visibleProcessInterval : backgroundProcessInterval) : menuBarProcessInterval
        let processes = lastProcesses.map { uptime - $0 >= processInterval || uptime < $0 } ?? true
        if disk { lastDisk = uptime }
        if processes { lastProcesses = uptime }
        return (disk, processes)
    }

    mutating func reset() { lastDisk = nil; lastProcesses = nil }
}

protocol SystemDetailSampling: AnyObject {
    func start() async
    func stop() async
    func sampleDisk(now: Date) async -> DiskReading
    func sampleBattery(now: Date) async -> BatteryReading
    func sampleProcesses(now: Date, uptime: TimeInterval) async -> ProcessReading
}

protocol ProcessScanning {
    // nil means enumeration failed; [] means no accessible developer processes.
    func scan() -> [ProcessObservation]?
}

struct NativeProcessScanner: ProcessScanning {
    static func collect(_ pids: [Int32], read: (Int32) -> ProcessObservation?) -> [ProcessObservation] {
        pids.compactMap(read) // An inaccessible or exited PID does not fail the scan.
    }

    func scan() -> [ProcessObservation]? {
        let bytesNeeded = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytesNeeded > 0 else { return nil }
        var pids = [Int32](repeating: 0, count: Int(bytesNeeded) / MemoryLayout<Int32>.size + 64)
        let bytesRead = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard bytesRead > 0 else { return nil }
        return Self.collect(Array(pids.prefix(Int(bytesRead) / MemoryLayout<Int32>.size))) { pid in
            guard !Task<Never, Never>.isCancelled, pid > 0 else { return nil }
            var name = [CChar](repeating: 0, count: 256)
            guard proc_name(pid, &name, UInt32(name.count)) > 0 else { return nil }
            let processName = String(cString: name)
            guard DeveloperProcessClassifier.isDeveloperProcess(processName) else { return nil }
            var info = proc_taskinfo()
            let size = Int32(MemoryLayout<proc_taskinfo>.size)
            let read = withUnsafeMutablePointer(to: &info) {
                proc_pidinfo(pid, Int32(PROC_PIDTASKINFO), 0, $0, size)
            }
            guard read == size, info.pti_total_user <= UInt64.max - info.pti_total_system else { return nil }
            return ProcessObservation(pid: pid, name: processName,
                cpuTimeNanoseconds: info.pti_total_user + info.pti_total_system,
                residentBytes: info.pti_resident_size)
        }
    }
}

actor NativeSystemDetailSampler: SystemDetailSampling {
    private let processScanner: any ProcessScanning
    private var processCPU = ProcessCPUCalculator()

    init(processScanner: any ProcessScanning = NativeProcessScanner()) {
        self.processScanner = processScanner
    }

    func start() { processCPU.reset() }
    func stop() { processCPU.reset() }

    func sampleDisk(now: Date) -> DiskReading {
        do {
            let values = try URL(fileURLWithPath: "/", isDirectory: true)
                .resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            guard let usage = DiskUsage.calculate(totalBytes: values.volumeTotalCapacity.map(Int64.init),
                                                 availableBytes: values.volumeAvailableCapacity.map(Int64.init)) else {
                return .unavailable(sampledAt: now)
            }
            return .available(usage, sampledAt: now)
        } catch {
            return .unavailable(sampledAt: now)
        }
    }

    func sampleBattery(now: Date) -> BatteryReading {
        guard let information = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(information)?.takeRetainedValue() as? [Any] else {
            return .unavailable(sampledAt: now)
        }
        var descriptions: [[String: Any]] = []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(information, source as CFTypeRef)?
                .takeUnretainedValue() as? [String: Any] else { return .unavailable(sampledAt: now) }
            descriptions.append(description)
        }
        return .interpret(descriptions, at: now)
    }

    func sampleProcesses(now: Date, uptime: TimeInterval) -> ProcessReading {
        guard let observations = processScanner.scan() else { return .unavailable(sampledAt: now) }
        return .available(processCPU.sample(observations, at: uptime), sampledAt: now)
    }
}

// IOKit power-source change notifications are registered once per live hub
// lifecycle on the main run loop, then removed when sampling stops.
@MainActor final class PowerSourceNotifications {
    private var source: CFRunLoopSource?
    private let onChange: () -> Void
    init(onChange: @escaping () -> Void) { self.onChange = onChange }

    @discardableResult func start() -> Bool {
        if source != nil { return true }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let observer = Unmanaged<PowerSourceNotifications>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in observer.onChange() }
        }, context)?.takeRetainedValue() else { return false }
        source = created
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
        return true
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            CFRunLoopSourceInvalidate(source)
        }
        source = nil
    }
}
