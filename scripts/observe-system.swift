import Foundation

@main struct ObserveSystem {
    static func main() async {
        let sampler = NativeSystemSampler()
        await sampler.start()
        let first = await sampler.sample()
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        let second = await sampler.sample()
        await sampler.stop()
        print("first_cpu=\(first.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "unknown")")
        print("next_cpu=\(second.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "unknown")")
        if let memory = second.memory {
            print("memory_used_bytes=\(memory.usedBytes) total_bytes=\(memory.totalBytes) used_percent=\(String(format: "%.1f", memory.usedPercent))%")
        } else {
            print("memory=unknown")
        }
        print("memory_pressure=\(second.pressure.liveLabel)")
    }
}
