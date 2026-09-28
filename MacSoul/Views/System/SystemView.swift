import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("System · MOCK DATA") {
                LabeledContent("CPU", value: store.snapshot.cpu.label)
                LabeledContent("Memory used", value: store.snapshot.memoryUsed.label)
                LabeledContent("Memory pressure", value: store.snapshot.memoryPressure)
                LabeledContent("Disk", value: store.snapshot.disk.label)
                LabeledContent("Battery", value: store.snapshot.battery.label)
            }
            Text("No system sampler is connected.").foregroundStyle(.secondary)
        }.padding().navigationTitle("System")
    }
}
