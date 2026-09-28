import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Phase A · MOCK DATA") {
                LabeledContent("Live sampling", value: "Unavailable")
                LabeledContent("Quota providers", value: "Unavailable")
                LabeledContent("Cleaner actions", value: "Disabled")
            }
            Text("This build is a mock preview. Settings are not active.")
                .foregroundStyle(.secondary)
        }.padding().navigationTitle("Settings")
    }
}
