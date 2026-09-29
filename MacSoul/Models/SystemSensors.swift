import Foundation
import Dispatch
import Darwin

// Aggregate host CPU busy ticks / all host ticks over the previous sampling interval.
// This is 0–100% across the whole machine, unlike Activity Monitor's per-process
// percentages, which can exceed 100% on a multicore Mac.
struct CPUTicks: Equatable {
    let user: UInt64
    let system: UInt64
    let nice: UInt64
    let idle: UInt64
}

struct CPUUsageCalculator {
    private(set) var previous: CPUTicks?

    mutating func sample(_ current: CPUTicks?) -> Double? {
        defer { previous = current }
        guard let current, let previous,
              current.user >= previous.user, current.system >= previous.system,
              current.nice >= previous.nice, current.idle >= previous.idle else { return nil }
        let busy = (current.user - previous.user) + (current.system - previous.system)
            + (current.nice - previous.nice)
        let total = busy + current.idle - previous.idle
        guard total > 0 else { return nil }
        return Double(busy) * 100 / Double(total)
    }
}

struct MemoryUsage: Equatable {
    let usedBytes: UInt64
    let totalBytes: UInt64
    var usedPercent: Double { Double(usedBytes) * 100 / Double(totalBytes) }
    var usedGiB: Double { Double(usedBytes) / 1_073_741_824 }
    var totalGiB: Double { Double(totalBytes) / 1_073_741_824 }

    // Approximation of Activity Monitor's Memory Used: installed physical RAM
    // minus free and file-backed pages. Inactive anonymous pages remain used;
    // speculative pages are already part of free_count and are not subtracted
    // again. external_page_count is file-backed, not a claim that every such
    // page is instantly reclaimable or identical to Activity Monitor's cache.
    static func calculate(totalBytes: UInt64, pageSize: UInt64, freePages: UInt64,
                          fileBackedPages: UInt64) -> MemoryUsage? {
        guard totalBytes > 0, pageSize > 0,
              freePages <= UInt64.max - fileBackedPages else { return nil }
        let excludedPages = freePages + fileBackedPages
        guard excludedPages <= totalBytes / pageSize else { return nil }
        return MemoryUsage(usedBytes: totalBytes - excludedPages * pageSize,
                           totalBytes: totalBytes)
    }
}

struct SystemReading: Equatable {
    let cpuPercent: Double?
    let memory: MemoryUsage?
    let pressure: MemoryPressureLevel
}

protocol SystemSampling: AnyObject {
    func start() async
    func stop() async
    func sample() async -> SystemReading
}

actor NativeSystemSampler: SystemSampling {
    private var cpu = CPUUsageCalculator()
    private var pressure: MemoryPressureLevel = .unknown
    private var pressureSource: (any DispatchSourceMemoryPressure)?
    private var pressureGeneration = 0

    func start() {
        guard pressureSource == nil else { return }
        cpu = CPUUsageCalculator()
        pressure = .unknown
        pressureGeneration += 1
        let generation = pressureGeneration
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self, weak source] in
            guard let source else { return }
            let level = Self.mapPressureEvent(source.data)
            Task { await self?.setPressure(level, generation: generation) }
        }
        source.resume()
        pressureSource = source
    }

    func stop() {
        pressureSource?.cancel()
        pressureSource = nil
        pressureGeneration += 1
        cpu = CPUUsageCalculator()
        pressure = .unknown
    }

    func sample() -> SystemReading {
        SystemReading(cpuPercent: cpu.sample(readCPUTicks()),
                      memory: readMemory(), pressure: pressure)
    }

    private func setPressure(_ level: MemoryPressureLevel, generation: Int) {
        guard generation == pressureGeneration else { return }
        pressure = level
    }

    static func mapPressureEvent(_ flags: DispatchSource.MemoryPressureEvent) -> MemoryPressureLevel {
        if flags.contains(.critical) { return .critical }
        if flags.contains(.warning) { return .warning }
        if flags.contains(.normal) { return .normal }
        return .unknown
    }

    private func readCPUTicks() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = info.cpu_ticks
        return CPUTicks(user: UInt64(ticks.0), system: UInt64(ticks.1),
                        nice: UInt64(ticks.3), idle: UInt64(ticks.2))
    }

    private func readMemory() -> MemoryUsage? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryUsage.calculate(totalBytes: ProcessInfo.processInfo.physicalMemory,
                                     pageSize: UInt64(vm_kernel_page_size),
                                     freePages: UInt64(info.free_count),
                                     fileBackedPages: UInt64(info.external_page_count))
    }
}
