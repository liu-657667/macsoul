import SwiftUI
import AppKit

struct CleanerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.card) {
                HStack {
                    Text(language.text("Cleaner")).font(.title2.bold())
                    Text(language.cleanerText("Read only")).font(.caption.weight(.semibold))
                    Spacer()
                    if store.snapshot.cleaner.mode == .live {
                        if store.snapshot.cleaner.state == .scanning {
                            ProgressView().controlSize(.small).accessibilityLabel(language.cleanerText("Scanning…"))
                            Button(language.cleanerText("Cancel scan")) { store.cancelCleaner() }
                        } else {
                            Button(language.cleanerText(store.snapshot.cleaner.state == .notRun ? "Scan" : "Rescan")) { store.scanCleaner() }
                                .disabled(store.cleanerRunning || store.cleanerPreviewRunning)
                        }
                    } else { Text(language.text("MOCK")).font(.caption) }
                }
                Text(language.cleanerText("Read-only developer cache scan. MacSoul never deletes files."))
                Text(language.cleanerText("Only an explicit Scan starts traversal. Leaving this page does not cancel it. Preview, sleep or app exit cancels the scan."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                Divider()
                if store.snapshot.cleaner.mode == .live {
                    Text(language.cleanerSummary(store.snapshot.cleaner)).font(.headline)
                    ForEach(store.snapshot.cleaner.categories) { category in
                        CleanerCategoryCard(category: category)
                    }
                    if let docker = store.snapshot.cleaner.docker { DockerCleanerCard(value: docker) }
                } else {
                    Text(language.cleanerText("Preview uses Mock fixtures; no filesystem scan runs."))
                    if store.snapshot.cleanerItems.isEmpty {
                        Text(language.cleanerText("No Mock scan results in this fixture.")).foregroundStyle(.secondary)
                    }
                    ForEach(store.snapshot.cleanerItems) { item in
                        HStack {
                            Text(item.name); Spacer()
                            Text(language.cleanerText(item.risk == .safe ? "Low risk" : item.risk == .caution ? "Caution" : "High risk"))
                            Text(item.size)
                        }
                    }
                }
                Text(language.cleanerText("Allocated file bytes where available, otherwise logical size; directories are not added. APFS clones, sparse files, hard links and shared data mean this estimate is not reclaimable space."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                Text(language.cleanerText("Summary combines file allocation estimates and local Docker logical usage; remote Docker is excluded."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                Text(language.cleanerText("Risk describes usual recovery cost if you remove the directory yourself; it is not a safety guarantee."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                Text(language.cleanerText("Symlink roots (including linked ancestors) are not scanned. Internal links are skipped."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
            }
            .padding(MacSoulTheme.Spacing.section)
        }
        .navigationTitle(language.text("Cleaner"))
        .sheet(item: Binding(get: { store.cleanerPreviewDestination }, set: { if $0 == nil { store.closeCleanerPreview() } })) { destination in
            CleanerPreviewView(destination: destination).environmentObject(store)
        }
        .onDisappear { store.closeCleanerPreview() }
    }
}
private struct CleanerCategoryCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    let category: CleanerCategory
    private var descriptor: CleanerDescriptor { category.descriptor }
    private var hasResolvedPath: Bool {
        if let resolution = descriptor.resolution { return resolution.url != nil }
        return descriptor.mavenLocation == nil || descriptor.mavenLocation?.url != nil
    }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(language.cleanerText(descriptor.name)).font(.headline)
                    Text(language.cleanerText(descriptor.risk.label)).font(.caption.weight(.semibold))
                        .foregroundStyle(descriptor.risk == .low ? Color.secondary : Color.orange)
                    Spacer()
                    Text(language.cleanerText(category.state.label)).font(.caption)
                    if let bytes = category.sizeBytes {
                        Text(descriptor.kind == .mavenMarkers ? language.cleanerMarkerBytes(bytes) : language.cleanerBytes(bytes)).monospacedDigit().fontWeight(.semibold)
                    }
                }
                if hasResolvedPath {
                    Text(category.rootURL.path).font(.caption.monospaced()).textSelection(.enabled)
                        .help(category.rootURL.path)
                } else { Text(language.cleanerText("Repository path unresolved")).font(.caption) }
                if let resolution = descriptor.resolution {
                    Text(language.cleanerResolutionDescription(resolution))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                } else if let location = descriptor.mavenLocation {
                    Text(language.cleanerMavenLocationDescription(location))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                } else {
                    Text(language.text("Source") + ": " + language.cleanerText("Default candidate · discovery not run"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !descriptor.contributesToTotalEstimate {
                    Text(language.cleanerText("Included in repository usage; not added to total again."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(language.cleanerText(descriptor.explanation))
                Text(language.cleanerText(descriptor.impact)).font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                if category.state != .notRun {
                    Text(language.cleanerCounts(category.counters)).font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                    if let date = category.sampledAt {
                        Text(language.cleanerText("Updated") + ": " + language.dateTime(date)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 12) {
                    Button(language.cleanerText("View contents")) { store.openCleanerPreview(category) }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.cleanerRunning || CleanerPreviewBoundary.resolvedRoot(for: category) == nil || [.notFound, .inaccessible].contains(category.state))
                    Button(language.cleanerText("Reveal in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([category.rootURL])
                    }
                    .disabled(!hasResolvedPath || !FileManager.default.fileExists(atPath: category.rootURL.path))
                    if hasResolvedPath { CleanerPathCopyMenu(url: category.rootURL) }
                }.controlSize(.small)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }

    }
}

struct DockerCleanerCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    let value: DockerCleanerResult
    var offersPreview = true
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Docker").font(.headline)
                    Text(language.cleanerText("Read only")).font(.caption)
                    Spacer()
                    Text(language.cleanerText(value.state.label)).font(.caption)
                }
                Text(language.text("Source") + ": " + language.cleanerText(value.state == .available ? "Docker Engine" : "Docker CLI"))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                if let context = value.context { Text(language.cleanerText("Context") + ": " + context).font(.caption) }
                if let executable = value.executable { Text(executable.path).font(.caption.monospaced()).textSelection(.enabled) }
                ForEach(value.usage, id: \.kind) { row in
                    HStack {
                        Text(language.cleanerText(row.kind.rawValue)); Spacer()
                        Text(language.cleanerMarkerBytes(row.bytes)).monospacedDigit()
                        if let reclaimable = row.reclaimableBytes {
                            Text(language.cleanerText("Docker-reported reclaimable estimate") + ": " + language.cleanerMarkerBytes(reclaimable))
                                .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                        }
                    }
                }
                if let total = value.totalBytes {
                    HStack {
                        Text(language.cleanerText("Total logical usage")); Spacer()
                        Text(language.cleanerBytes(total)).fontWeight(.semibold).monospacedDigit()
                    }
                }
                Text(language.cleanerText("Docker logical usage is not VM-file allocated space or a promise of safe deletion. No VM files are scanned."))
                    .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                if value.state == .remoteContext {
                    Text(language.cleanerText("Remote storage was not queried and is excluded from this Mac’s total."))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                }
                if offersPreview {
                    Button(language.cleanerText("View contents")) { store.openDockerPreview() }
                        .buttonStyle(.borderedProminent).controlSize(.small).disabled(store.cleanerRunning)
                }
                if let date = value.sampledAt { Text(language.cleanerText("Updated") + ": " + language.dateTime(date)).font(.caption2) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }
    }
}
