import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        Form {
            Section(language.text(store.systemMode == .live ? "System · LIVE" : "System · MOCK DATA")) {
                LabeledContent(language.text("CPU"), value: store.snapshot.cpu.label)
                LabeledContent(language.text("Memory used"), value: store.snapshot.memoryUsed.label)
                if let memory = store.snapshot.memoryBytes {
                    LabeledContent(language.text("Memory used / total"), value:
                        String(format: "%.2f / %.2f GiB", memory.usedGiB, memory.totalGiB))
                }
                LabeledContent(language.text("Memory pressure"), value: language.text(store.snapshot.memoryPressure))
                diskRows
                batteryRows
            }
            if store.systemMode == .live {
                Section(language.text("Top Developer Processes")) { processRows }
                Text(language.text("Process CPU is per logical CPU over two samples; a multicore process can exceed 100%. First CPU sample is unknown."))
                    .foregroundStyle(.secondary)
            }
            Text(language.text(store.systemMode == .live
                ? "CPU is host-wide busy time between samples; first sample is unknown. Memory pressure stays unknown until macOS reports an event."
                : "No system sampler is connected."))
                .foregroundStyle(.secondary)
            if store.systemMode == .live {
                Text(language.text("Memory used estimate: physical RAM minus free and file-backed pages; pressure is independent."))
                    .foregroundStyle(.secondary)
                Text(language.text("Disk uses root volume total minus available bytes; APFS and purgeable space may differ from Storage Settings."))
                    .foregroundStyle(.secondary)
            }
        }.padding().navigationTitle(language.text("System"))
    }

    @ViewBuilder private var diskRows: some View {
        if store.systemMode == .preview {
            LabeledContent(language.text("Disk · Mock"), value: store.snapshot.disk.label)
        } else {
            LabeledContent(language.text("Disk"), value: store.snapshot.disk.label)
            switch store.snapshot.diskReading {
            case .available(let usage, _):
                LabeledContent(language.text("Disk used / total"), value:
                    String(format: "%.1f / %.1f GiB", usage.usedGiB, usage.totalGiB))
            case .unknown:
                Text(language.text("Disk sampling…")).foregroundStyle(.secondary)
            case .unavailable:
                Text(language.text("Disk unavailable")).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var batteryRows: some View {
        if store.systemMode == .preview {
            LabeledContent(language.text("Battery · Mock"), value: store.snapshot.battery.label)
        } else {
            switch store.snapshot.batteryReading {
            case .unknown:
                LabeledContent(language.text("Battery"), value: language.text("Sampling…"))
            case .notPresent:
                LabeledContent(language.text("Battery"), value: language.text("No battery"))
            case .unavailable:
                LabeledContent(language.text("Battery"), value: language.text("Unavailable"))
            case .present(let status, _):
                LabeledContent(language.text("Battery"), value: "\(status.chargePercent)%")
                LabeledContent(language.text("Charge state"), value: language.text(status.chargeState.rawValue.capitalized))
                if let external = status.externalPower {
                    LabeledContent(language.text("External power"), value: language.text(external ? "Connected" : "Disconnected"))
                }
            }
        }
    }

    @ViewBuilder private var processRows: some View {
        switch store.snapshot.processReading {
        case .unknown:
            Text(language.text("Process sampling…")).foregroundStyle(.secondary)
        case .unavailable:
            Text(language.text("Process collection unavailable")).foregroundStyle(.secondary)
        case .available(let processes, _):
            if processes.isEmpty {
                Text(language.text("No developer processes found")).foregroundStyle(.secondary)
            } else {
                HStack {
                    Text(language.text("Process")).frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU").frame(width: 78, alignment: .trailing)
                    Text(language.text("Memory")).frame(width: 90, alignment: .trailing)
                    Text("PID").frame(width: 64, alignment: .trailing)
                }.font(.caption).foregroundStyle(.secondary)
                ForEach(processes) { process in
                    HStack {
                        Text(process.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(process.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—")
                            .frame(width: 78, alignment: .trailing)
                        Text(process.residentMiB >= 1024
                             ? String(format: "%.1f GiB", process.residentMiB / 1024)
                             : String(format: "%.0f MiB", process.residentMiB))
                            .frame(width: 90, alignment: .trailing)
                        Text(String(process.pid)).frame(width: 64, alignment: .trailing)
                    }
                }
            }
        }
    }
}
