import SwiftUI
import AppKit

struct CleanerPreviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    let destination: CleanerPreviewDestination
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.cleanerText("Content preview")).font(.title2.bold())
                Text(language.cleanerText("Read only")).font(.caption.weight(.semibold))
                Spacer()
                Button(language.cleanerText("Close")) { store.closeCleanerPreview() }
                    .keyboardShortcut(.cancelAction)
            }
            switch destination {
            case .directory(let category): directoryContents(category)
            case .docker(let value):
                DockerCleanerCard(value: value, offersPreview: false)
                Text(language.cleanerText("This preview reuses the last Docker statistics. Scan is required for new data; no VM filesystem is browsed."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                Spacer()
            }
            Divider()
            Text(language.cleanerText("Read-only preview. MacSoul does not modify or delete these files."))
                .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
        }
        .padding(MacSoulTheme.Spacing.section)
        .frame(minWidth: 760, idealWidth: 900, minHeight: 520, idealHeight: 640)
    }
    @ViewBuilder private func directoryContents(_ category: CleanerCategory) -> some View {
        Text(language.cleanerText(category.descriptor.name)).font(.headline)
        Text(category.rootURL.path).font(.caption.monospaced()).textSelection(.enabled)
            .lineLimit(2).truncationMode(.middle)
        if let resolution = category.descriptor.resolution {
            Text(language.text("Source") + ": " + language.cleanerText(resolution.source.label)
                 + (resolution.source.isFallback ? " · " + language.cleanerText("Default / fallback") : ""))
                .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
        } else if let location = category.descriptor.mavenLocation {
            Text(language.text("Source") + ": " + language.cleanerText(location.source.label)).font(.caption)
        }
        HStack {
            Text(language.cleanerText(category.descriptor.risk.label))
            if let bytes = category.sizeBytes { Text(language.cleanerText("Estimated disk usage") + ": " + language.cleanerMarkerBytes(bytes)).monospacedDigit() }
            Spacer()
            Button(language.cleanerText("Reveal in Finder")) { reveal(category.rootURL) }
            CleanerPathCopyMenu(url: category.rootURL)
        }.controlSize(.small).font(.caption)
        Text(language.cleanerText(category.descriptor.explanation)).font(.callout)
        Text(language.cleanerText(category.descriptor.impact)).font(.caption).foregroundStyle(MacSoulTheme.supportingText)
        if let snapshot = store.cleanerPreview, snapshot.category.id == category.id {
            let components = pathComponents(snapshot)
            HStack {
                Button { store.backCleanerPreview() } label: { Label(language.cleanerText("Back"), systemImage: "chevron.left") }
                    .disabled(components.isEmpty)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button(category.rootURL.lastPathComponent) { store.backCleanerPreview(to: 0) }.buttonStyle(.borderless)
                        ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                            Button(component) { store.backCleanerPreview(to: index + 1) }.buttonStyle(.borderless)
                        }
                    }
                }
                Picker(language.cleanerText("Sort"), selection: Binding(get: { snapshot.sort }, set: store.sortCleanerPreview)) {
                    Text(language.cleanerText("Size descending")).tag(CleanerPreviewSort.sizeDescending)
                    Text(language.cleanerText("Name ascending")).tag(CleanerPreviewSort.nameAscending)
                }.frame(width: 180)
            }.controlSize(.small)
            HStack {
                if snapshot.state == .scanning { ProgressView().controlSize(.small).accessibilityLabel(language.cleanerText("Calculating…")) }
                Text(language.cleanerText(snapshot.state == .scanning ? "Calculating…" : snapshot.state.label))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                Spacer()
                if store.cleanerPreviewRunning { Button(language.cleanerText("Cancel preview")) { store.cancelCleanerPreview() }.controlSize(.small) }
            }
            if snapshot.isTruncated {
                Text(language.cleanerText("Preview limited to 2,000 direct children. Other entries are omitted; size order applies only to the displayed entries."))
                    .font(.caption).foregroundStyle(.orange)
            }
            if snapshot.items.isEmpty, snapshot.state != .scanning {
                Text(language.cleanerText(snapshot.state == .available ? "This directory is empty." : "No preview entries available."))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                CleanerPreviewTable(snapshot: snapshot)
            }
            Text(language.cleanerText("Sizes use the existing allocation estimate. Directory counts include descendants; links are not followed. Changing files and shared blocks can affect estimates."))
                .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
            if category.descriptor.target != .directory {
                Text(language.cleanerText("This category estimates matching marker files only; other entries have no category size."))
                    .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
            }
        } else { ProgressView().accessibilityLabel(language.cleanerText("Calculating…")); Spacer() }
    }
    private func pathComponents(_ snapshot: CleanerPreviewSnapshot) -> [String] {
        let root = snapshot.category.rootURL.path
        guard snapshot.directoryURL.path.hasPrefix(root + "/") else { return [] }
        return snapshot.directoryURL.path.dropFirst(root.count + 1).split(separator: "/").map(String.init)
    }
    private func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}

private struct CleanerPreviewTable: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    let snapshot: CleanerPreviewSnapshot
    @State private var selection: CleanerPreviewItem.ID?
    var body: some View {
        Table(snapshot.sortedItems, selection: $selection) {
            TableColumn(language.cleanerText("Name")) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.kind == .directory ? "folder" : item.isSymlink ? "link" : "doc")
                        .foregroundStyle(.secondary).accessibilityHidden(true)
                    Text(item.name).lineLimit(1).truncationMode(.middle).help(item.name)
                    Spacer(minLength: 0)
                    if item.kind == .directory {
                        Button { store.enterCleanerPreview(item) } label: { Image(systemName: "chevron.right").frame(width: 24, height: 24) }
                            .buttonStyle(.borderless)
                            .help(language.cleanerText("Open directory"))
                            .accessibilityLabel(language.cleanerText("Open directory") + ": " + item.name)
                            .disabled(![.available, .partial, .scanning].contains(item.state))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { store.enterCleanerPreview(item) }
                .contextMenu {
                    Button(language.cleanerText("Reveal in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                    Button(language.cleanerText("Copy path")) { copy(item.url.path) }
                }
            }.width(min: 200, ideal: 300, max: .infinity)
            TableColumn(language.cleanerText("Type")) { item in
                Text(language.cleanerKind(item.kind)).font(.caption).lineLimit(1)
            }.width(min: 110, ideal: 140, max: 160)
            TableColumn(language.cleanerText("Estimated Usage")) { item in
                VStack(alignment: .trailing, spacing: 1) {
                    if let bytes = item.estimatedAllocatedBytes { Text(language.cleanerMarkerBytes(bytes)).monospacedDigit() }
                    else { Text(language.cleanerText(item.state == .scanning ? "Calculating…" : item.isSymlink ? "Not followed" : "Not estimated")) }
                    if item.state != .available && item.state != .scanning {
                        Text(language.cleanerText(item.state.label)).font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                    }
                }.frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 110, ideal: 135, max: 160)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .controlSize(.small)
        .frame(minHeight: 180, maxHeight: .infinity)
    }
    private func copy(_ value: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(value, forType: .string) }
}

struct CleanerPathCopyMenu: View {
    @Environment(\.macSoulLanguage) private var language
    let url: URL
    @State private var copied = false
    var body: some View {
        HStack {
            Menu {
                Button(language.cleanerText("Copy path")) {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.setString(url.path, forType: .string)
                }
            } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help(language.cleanerText("Copy path")).accessibilityLabel(language.cleanerText("Copy path"))
            if copied { Text(language.cleanerText("Path copied")).font(.caption) }
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copied = false }
        }
    }
}
