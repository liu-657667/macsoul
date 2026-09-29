import Foundation

protocol SoulClock { var uptime: TimeInterval { get } }
struct UptimeSoulClock: SoulClock { var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime } }

enum SoulState: Equatable {
    case observing, calm, stressed, brainOverload, memoryWarning, memoryCritical, recovering
}

struct SoulStatus: Equatable {
    let state: SoulState
    let visual: SoulVisual?
    let mood: String
    let message: String
}

// A single engine belongs to the shared hub. All durations use monotonic uptime;
// suspend/resume and unexpected sampling gaps discard pending threshold time.
final class SoulEngine {
    private let clock: any SoulClock
    private(set) var state: SoulState = .observing
    private var current = SoulStatus(state: .observing, visual: .normal,
                                     mood: "Observing · Live", message: "Waiting for a valid system sample.")
    private var highSince: TimeInterval?
    private var criticalSince: TimeInterval?
    private var safeSince: TimeInterval?
    private var lastSample: TimeInterval?
    private var lastAnnouncement: [SoulState: TimeInterval] = [:]
    private let cooldown: TimeInterval = 1800

    init(clock: any SoulClock = UptimeSoulClock()) { self.clock = clock }

    func suspend() {
        highSince = nil
        criticalSince = nil
        safeSince = nil
        lastSample = nil
    }

    func evaluate(cpu: Double?, pressure: MemoryPressureLevel) -> SoulStatus {
        let now = clock.uptime
        if let lastSample, now < lastSample || now - lastSample > 10 { suspend() }
        lastSample = now

        if let cpu, cpu.isFinite, (0...100).contains(cpu) {
            highSince = cpu > 85 ? highSince ?? now : nil
            criticalSince = cpu > 95 ? criticalSince ?? now : nil
        } else {
            highSince = nil
            criticalSince = nil
        }

        let cpuSafe = cpu.map { $0.isFinite && $0 < 60 } ?? false
        let recoveringFromMemory = state == .memoryWarning || state == .memoryCritical
        let pressureAllowsRecovery = recoveringFromMemory ? pressure == .normal
            : pressure != .warning && pressure != .critical
        safeSince = cpuSafe && pressureAllowsRecovery ? safeSince ?? now : nil

        let next: SoulState
        if pressure == .critical {
            next = .memoryCritical
        } else if let criticalSince, now - criticalSince >= 20 {
            next = .brainOverload
        } else if pressure == .warning {
            next = .memoryWarning
        } else if let highSince, now - highSince >= 15 {
            next = .stressed
        } else if [.stressed, .brainOverload, .memoryWarning, .memoryCritical].contains(state) {
            next = safeSince.map { now - $0 >= 30 } == true ? .recovering : state
        } else if state == .recovering {
            next = .calm
        } else {
            next = cpu.map { $0.isFinite && (0...100).contains($0) } == true ? .calm : .observing
        }

        let changed = next != state
        if !changed {
            if next == .calm || next == .recovering {
                current = presentation(for: next, announce: false, pressure: pressure)
            }
            return current
        }
        state = next
        let canAnnounce = changed && (lastAnnouncement[next].map { now - $0 >= cooldown } ?? true)
        if canAnnounce { lastAnnouncement[next] = now }
        current = presentation(for: next, announce: canAnnounce, pressure: pressure)
        return current
    }

    private func presentation(for state: SoulState, announce: Bool,
                              pressure: MemoryPressureLevel) -> SoulStatus {
        switch state {
        case .observing:
            SoulStatus(state: state, visual: .normal, mood: "Observing · Live", message: "Waiting for a valid system sample.")
        case .calm:
            pressure == .unknown
                ? SoulStatus(state: state, visual: .normal, mood: "CPU calm · Live",
                             message: "CPU is steady; memory pressure is still being monitored.")
                : SoulStatus(state: state, visual: .normal, mood: "Calm · Live", message: "System load is steady.")
        case .stressed:
            SoulStatus(state: state, visual: .busy, mood: "Stressed · Live",
                       message: announce ? "我开始认真工作了。" : "CPU load remains high.")
        case .brainOverload:
            SoulStatus(state: state, visual: .overload, mood: "Overload · Live",
                       message: announce ? "我的脑子要爆炸了。" : "CPU load remains critical.")
        case .memoryWarning:
            SoulStatus(state: state, visual: .bloated, mood: "Memory warning · Live",
                       message: announce ? "我的胃快撑爆了。" : "Memory pressure remains elevated.")
        case .memoryCritical:
            SoulStatus(state: state, visual: .bloated, mood: "Memory critical · Live",
                       message: announce ? "我的胃快撑爆了。" : "Memory pressure remains critical.")
        case .recovering:
            SoulStatus(state: state, visual: .normal,
                       mood: pressure == .unknown ? "CPU recovering · Live" : "Recovering · Live",
                       message: pressure == .unknown ? "CPU is recovering; memory pressure is still being monitored."
                           : announce ? "呼……终于安静了。" : "System load is recovering.")
        }
    }
}
