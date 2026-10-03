import Foundation

@MainActor final class AIQuotaMonitor {
    private let codex: any LiveQuotaProviding
    private let claude: any LiveQuotaProviding
    private let clock: any QuotaClock
    private let alerts = QuotaAlertEngine()
    private let onSnapshot: (AIQuotaSnapshot, [QuotaAlertEvent]) -> Void
    private(set) var snapshot = AIQuotaSnapshot.stopped
    private(set) var starts = 0
    private var active = false
    private var generation = 0
    init(codex: any LiveQuotaProviding, claude: any LiveQuotaProviding,
         clock: any QuotaClock = SystemQuotaClock(),
         onSnapshot: @escaping (AIQuotaSnapshot, [QuotaAlertEvent]) -> Void) {
        self.codex = codex; self.claude = claude; self.clock = clock; self.onSnapshot = onSnapshot
    }
    func start() {
        guard !active else { return }
        active = true; starts += 1; generation += 1
        let cycle = generation
        codex.onUpdate = { [weak self] item, detail in self?.receive(item, detail: detail, cycle: cycle) }
        claude.onUpdate = { [weak self] item, detail in self?.receive(item, detail: detail, cycle: cycle) }
        snapshot = .stopped
        onSnapshot(snapshot, [])
        codex.start(); claude.start()
    }
    func stop() {
        active = false; generation += 1
        codex.onUpdate = nil; claude.onUpdate = nil
        codex.stop(); claude.stop()
        snapshot = .stopped
    }
    func waitForStop() async { await codex.waitForStop(); await claude.waitForStop() }
    private func receive(_ item: QuotaItem, detail: QuotaProviderDetail, cycle: Int) {
        guard active, generation == cycle, item.mode == .live, item.provider == detail.provider else { return }
        snapshot.items = QuotaProvider.allCases.map { provider in
            provider == item.provider ? item : snapshot.items.first { $0.provider == provider } ?? .unavailable(provider)
        }
        if let index = snapshot.details.firstIndex(where: { $0.provider == detail.provider }) { snapshot.details[index] = detail }
        onSnapshot(snapshot, alerts.evaluate(snapshot.items, now: clock.now()))
    }
}
