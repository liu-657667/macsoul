import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        Form {
            Section(language.text(store.systemMode == .live ? "System · CPU / MEMORY LIVE" : "System · MOCK DATA")) {
                LabeledContent(language.text("CPU"), value: store.snapshot.cpu.label)
                LabeledContent(language.text("Memory used"), value: store.snapshot.memoryUsed.label)
                if let memory = store.snapshot.memoryBytes {
                    LabeledContent(language.text("Memory used / total"), value:
                        String(format: "%.2f / %.2f GiB", memory.usedGiB, memory.totalGiB))
                }
                LabeledContent(language.text("Memory pressure"), value: language.text(store.snapshot.memoryPressure))
                LabeledContent(language.text("Disk · Mock"), value: store.snapshot.disk.label)
                LabeledContent(language.text("Battery · Mock"), value: store.snapshot.battery.label)
            }
            Text(language.text(store.systemMode == .live
                ? "CPU is host-wide busy time between samples; first sample is unknown. Memory pressure stays unknown until macOS reports an event."
                : "No system sampler is connected."))
                .foregroundStyle(.secondary)
            if store.systemMode == .live {
                Text(language.text("Memory used estimate: physical RAM minus free and file-backed pages; pressure is independent."))
                    .foregroundStyle(.secondary)
            }
        }.padding().navigationTitle(language.text("System"))
    }
}
