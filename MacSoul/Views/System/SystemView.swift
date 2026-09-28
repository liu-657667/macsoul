import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        Form {
            Section(language.text("System · MOCK DATA")) {
                LabeledContent(language.text("CPU"), value: store.snapshot.cpu.label)
                LabeledContent(language.text("Memory used"), value: store.snapshot.memoryUsed.label)
                LabeledContent(language.text("Memory pressure"), value: language.text(store.snapshot.memoryPressure))
                LabeledContent(language.text("Disk"), value: store.snapshot.disk.label)
                LabeledContent(language.text("Battery"), value: store.snapshot.battery.label)
            }
            Text(language.text("No system sampler is connected.")).foregroundStyle(.secondary)
        }.padding().navigationTitle(language.text("System"))
    }
}
