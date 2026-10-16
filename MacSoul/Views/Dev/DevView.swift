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
                        .font(MacSoulTheme.Typography.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if store.snapshot.devMode == .live {
                        Button(language.text("Refresh")) { store.refreshDev() }
                    }
                }
                TypographySection(language.text("Runtimes")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                        if store.snapshot.devMode == .live, let reading = store.snapshot.runtimeReading {
                            if reading.state == .sampling {
                                Text(language.text("Sampling…"))
                                    .font(MacSoulTheme.Typography.status)
                            } else {
                                ForEach(reading.records) { record in
                                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                                        Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card) {
                                            GridRow(alignment: .firstTextBaseline) {
                                                Text(record.name).font(MacSoulTheme.Typography.itemTitle)
                                                    .frame(width: 100, alignment: .leading)
                                                Text(language.text(record.primary?.version ?? record.status.label))
                                                    .font(MacSoulTheme.Typography.fieldValue)
                                                    .monospacedDigit()
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        ForEach(record.contexts) { context in
                                            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                                                HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.card) {
                                                    Text(context.source).font(MacSoulTheme.Typography.fieldLabel)
                                                    Text(language.text(context.version ?? context.state.label))
                                                        .font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                                                }
                                                if let path = context.path {
                                                    Text(path).font(MacSoulTheme.Typography.technical)
                                                        .textSelection(.enabled)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                            }
                                        }
                                        if record.hasMismatch {
                                            Text(language.text("Different detection contexts resolve different versions."))
                                                .font(MacSoulTheme.Typography.supporting).foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(.vertical, MacSoulTheme.Spacing.compact)
                                    if record.id != reading.records.last?.id { Divider() }
                                }
                            }
                        } else {
                            Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card,
                                 verticalSpacing: MacSoulTheme.Spacing.regular) {
                                ForEach(store.snapshot.runtimes) { runtime in
                                    TypographyField(runtime.name, value: language.text(runtime.version))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(store.snapshot.devMode == .live
                        ? "Developer TCP Listeners" : "Listening Ports — Mock"))
                        .font(MacSoulTheme.Typography.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    if store.snapshot.devMode == .live, let reading = store.snapshot.portReading {
                        if reading.state == .available || reading.state == .empty {
                            let developer = reading.developerListeners
                            let all = reading.allListeners
                            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                                if developer.isEmpty {
                                    Text(language.text("No developer TCP listeners found"))
                                        .font(MacSoulTheme.Typography.supporting)
                                } else {
                                    PortTable(items: developer)
                                }
                                DisclosureGroup(isExpanded: $showAllListeners) {
                                    if all.isEmpty {
                                        Text(language.text("No visible TCP listeners"))
                                            .font(MacSoulTheme.Typography.supporting)
                                    } else {
                                        PortTable(items: all)
                                    }
                                } label: {
                                    Text(language.text("Show all user-visible listeners") + " (\(all.count))")
                                        .font(MacSoulTheme.Typography.fieldLabel)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(language.text(reading.state.label))
                                .font(MacSoulTheme.Typography.status)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading) {
                            ForEach(store.snapshot.ports) { item in
                                LabeledContent(item.displayPort, value: language.text(item.process))
                                    .font(MacSoulTheme.Typography.body)
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
    @State private var selection: LogicalListener.ID?

    private var copyHelp: String {
        language == .english ? "Copy port or PID" : "复制端口或 PID"
    }

    var body: some View {
        Table(items, selection: $selection) {
            column(language.text("Port")) {
                Text(String($0.port)).font(MacSoulTheme.Typography.body).monospacedDigit().lineLimit(1)
            }
            .width(65)
            column(language.text("Process")) { item in
                Text(item.process).font(MacSoulTheme.Typography.body).lineLimit(1).truncationMode(.tail)
                    .help(item.process)
            }
            .width(min: 140, ideal: 140, max: 360)
            column("PID") { item in
                Text(String(item.pid)).font(MacSoulTheme.Typography.body).monospacedDigit().lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .help(String(item.pid))
            }
            .width(100)
            column(language.text("Bind")) { item in
                ListenerBindCell(item: item).font(MacSoulTheme.Typography.body)
            }
            .width(min: 120, ideal: 120, max: 300)
            column(language.text("Actions")) { item in
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
            .width(100)
        }
        .font(MacSoulTheme.Typography.tableHeader)
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .controlSize(.small)
        // Include the 26pt action target and native row insets, not text height
        // alone, so the final row is fully visible before Table starts scrolling.
        .frame(height: min(max(CGFloat(items.count) * 42 + 28, 80), 320))
        .border(Color(nsColor: .separatorColor), width: 0.5)
    }

    // Text column headers are available from macOS 13.5; keep the original
    // String initializer on 13.0–13.4 and the same native Table on both paths.
    private func column<Cell: View>(_ title: String, @ViewBuilder content: @escaping (LogicalListener) -> Cell)
        -> TableColumn<LogicalListener, Never, Cell, Text> {
        if #available(macOS 13.5, *) {
            return TableColumn(Text(title).font(MacSoulTheme.Typography.tableHeader), content: content)
        } else {
            return TableColumn(title, content: content)
        }
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
                .font(MacSoulTheme.Typography.supporting)
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
                    Text(language.text("Bind")).font(MacSoulTheme.Typography.itemTitle)
                    ForEach(item.bindAddresses, id: \.self) { address in
                        Text(address).font(MacSoulTheme.Typography.technical)
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
