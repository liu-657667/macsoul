import SwiftUI
import AppKit

enum PortCommands {
    // Typed positive PIDs produce clipboard text only; never execute this command.
    static func gracefulStopCommand(pid: Int32) -> String? {
        guard pid > 0 else { return nil }
        return "kill -TERM " + String(pid)
    }

    @MainActor
    static func copyGracefulStopCommand(pid: Int32, to pasteboard: NSPasteboard = .general) -> Bool {
        guard let command = gracefulStopCommand(pid: pid) else { return false }
        pasteboard.clearContents()
        return pasteboard.setString(command, forType: .string)
    }
}

struct DevView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    @State private var showAllListeners = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                HStack {
                    Text(language.text(store.snapshot.devMode == .live ? "Dev Environment · LIVE" : "Dev Environment · MOCK"))
                        .font(.headline)
                    Spacer()
                    if store.snapshot.devMode == .live {
                        Button(language.text("Refresh")) { store.refreshDev() }
                    }
                }
                GroupBox(language.text("Runtimes")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        if store.snapshot.devMode == .live, let reading = store.snapshot.runtimeReading {
                            if reading.state == .sampling {
                                Text(language.text("Sampling…"))
                            } else {
                                ForEach(reading.records) { record in
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(record.name).fontWeight(.semibold)
                                            Spacer()
                                            Text(language.text(record.primary?.version ?? record.status.label))
                                        }
                                        ForEach(record.contexts) { context in
                                            HStack(alignment: .firstTextBaseline) {
                                                Text(context.source).foregroundStyle(.secondary)
                                                Spacer()
                                                Text(language.text(context.version ?? context.state.label))
                                                if let path = context.path {
                                                    Text(path).font(.caption.monospaced())
                                                        .foregroundStyle(.secondary)
                                                        .textSelection(.enabled)
                                                        .lineLimit(1).truncationMode(.middle)
                                                }
                                            }
                                        }
                                        if record.hasMismatch {
                                            Text(language.text("Different detection contexts resolve different versions."))
                                                .font(.caption).foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    if record.id != reading.records.last?.id { Divider() }
                                }
                            }
                        } else {
                            ForEach(store.snapshot.runtimes) { runtime in
                                LabeledContent(runtime.name, value: language.text(runtime.version))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(store.snapshot.devMode == .live
                        ? "Developer TCP Listeners" : "Listening Ports — Mock"))
                        .font(.headline)
                    if store.snapshot.devMode == .live, let reading = store.snapshot.portReading {
                        if reading.state == .available || reading.state == .empty {
                            let developer = reading.developerListeners
                            let all = reading.allListeners
                            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                                if developer.isEmpty {
                                    Text(language.text("No developer TCP listeners found"))
                                        .foregroundStyle(.secondary)
                                } else {
                                    PortTable(items: developer)
                                }
                                DisclosureGroup(isExpanded: $showAllListeners) {
                                    if all.isEmpty {
                                        Text(language.text("No visible TCP listeners"))
                                            .foregroundStyle(.secondary)
                                    } else {
                                        PortTable(items: all)
                                    }
                                } label: {
                                    Text(language.text("Show all user-visible listeners") + " (\(all.count))")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(language.text(reading.state.label))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            ForEach(store.snapshot.ports) { item in
                                LabeledContent(item.displayPort, value: language.text(item.process))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: 1040, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(MacSoulTheme.Spacing.section)
        }
        .navigationTitle(language.text("Dev"))
    }

}

private struct PortTable: View {
    @Environment(\.macSoulLanguage) private var language
    let items: [LogicalListener]

    private var copyHelp: String {
        language == .english ? "Copy port or PID" : "复制端口或 PID"
    }

    var body: some View {
        Table(items) {
            TableColumn(language.text("Port")) { item in
                Text(String(item.port)).monospacedDigit().lineLimit(1)
            }
            .width(85)
            TableColumn(language.text("Process")) { item in
                Text(item.process).lineLimit(1).truncationMode(.tail)
                    .help(item.process)
            }
            .width(min: 160, ideal: 190, max: 240)
            TableColumn("PID") { item in
                Text(String(item.pid)).monospacedDigit().lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(85)
            TableColumn(language.text("Bind")) { item in
                ListenerBindCell(item: item)
            }
            .width(min: 120, ideal: 150, max: 180)
            TableColumn(language.text("Actions")) { item in
                HStack(spacing: 12) {
                    Menu {
                        Button(language.text("Copy Port")) { copy(String(item.port)) }
                        Button(language.text("Copy PID")) { copy(String(item.pid)) }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .padding(4)
                            .contentShape(Rectangle())
                            .help(copyHelp)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(copyHelp)
                    .accessibilityLabel(copyHelp)

                    StopCommandButton(pid: item.pid)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 110, ideal: 120, max: .infinity)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .controlSize(.small)
        .frame(height: min(max(CGFloat(items.count) * 26 + 28, 80), 320))
        .border(Color(nsColor: .separatorColor), width: 0.5)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct StopCommandButton: View {
    @Environment(\.macSoulLanguage) private var language
    @State private var showingCopied = false
    @State private var feedbackID = UUID()
    let pid: Int32

    private var help: String {
        language == .english ? "Copy graceful stop command" : "复制停止命令"
    }

    var body: some View {
        Button {
            guard PortCommands.copyGracefulStopCommand(pid: pid) else { return }
            feedbackID = UUID()
            showingCopied = true
        } label: {
            Image(systemName: "terminal")
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(PortCommands.gracefulStopCommand(pid: pid) == nil)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityHint(language == .english
            ? "Copy a SIGTERM command for the current PID. Verify the PID still belongs to this process before running it."
            : "复制当前 PID 的 SIGTERM 命令。执行前请确认 PID 仍属于该进程。")
        .popover(isPresented: $showingCopied, arrowEdge: .bottom) {
            Text(language == .english ? "Stop command copied" : "已复制停止命令")
                .font(.callout)
                .padding(10)
                .task(id: feedbackID) {
                    do { try await Task.sleep(nanoseconds: 1_500_000_000) }
                    catch { return }
                    showingCopied = false
                }
        }
    }
}

private struct ListenerBindCell: View {
    @Environment(\.macSoulLanguage) private var language
    @State private var showingAddresses = false
    let item: LogicalListener

    var body: some View {
        if item.bindAddresses.count == 1 {
            Text(item.bindAddresses[0]).lineLimit(1).truncationMode(.middle)
                .help(item.bindAddresses[0])
        } else {
            Button {
                showingAddresses.toggle()
            } label: {
                Text(language == .english
                     ? "\(item.bindAddresses.count) bind addresses"
                     : "\(item.bindAddresses.count) 个绑定地址")
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help(item.bindAddresses.joined(separator: "\n"))
            .popover(isPresented: $showingAddresses) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text("Bind")).font(.headline)
                    ForEach(item.bindAddresses, id: \.self) { address in
                        Text(address).font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
            }
        }
    }
}

extension DevCollectionState {
    var label: String {
        switch self {
        case .sampling: "Sampling…"
        case .available: "Available"
        case .empty: "No visible TCP listeners"
        case .notFound: "Not found"
        case .unresolved: "Unresolved default"
        case .timeout: "Detection timed out"
        case .failed: "Collection failed"
        case .parseFailed: "Unrecognized output"
        }
    }
}
