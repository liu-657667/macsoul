import SwiftUI
import AppKit

struct CleanerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    // Pure display inputs for synthetic captures; production defaults read the store
    // and the existing path check. These never start collection or perform actions.
    var scanRunning: Bool? = nil
    var previewRunning: Bool? = nil
    var pathExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    private var isScanRunning: Bool { scanRunning ?? store.cleanerRunning }
    private var isPreviewRunning: Bool { previewRunning ?? store.cleanerPreviewRunning }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                TypographySection(language.cleanerText("Read only")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        HStack {
                            Spacer()
                            if store.snapshot.cleaner.mode == .live {
                                if store.snapshot.cleaner.state == .scanning {
                                    ProgressView().controlSize(.small).accessibilityLabel(language.cleanerText("Scanning…"))
                                    Button(language.cleanerText("Cancel scan")) { store.cancelCleaner() }
                                } else {
                                    Button(language.cleanerText(store.snapshot.cleaner.state == .notRun ? "Scan" : "Rescan")) { store.scanCleaner() }
                                        .disabled(isScanRunning || isPreviewRunning)
                                }
                            } else { Text(language.text("MOCK")).font(MacSoulTheme.Typography.status) }
                        }
                        Text(language.cleanerText("Read-only developer cache scan. MacSoul never deletes files."))
                            .font(MacSoulTheme.Typography.body)
                        Text(language.cleanerText("Only an explicit Scan starts traversal. Leaving this page does not cancel it. Preview, sleep or app exit cancels the scan."))
                            .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                    }
                }
                if store.snapshot.cleaner.mode == .live {
                    Text(language.cleanerSummary(store.snapshot.cleaner))
                        .font(MacSoulTheme.Typography.sectionTitle).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(store.snapshot.cleaner.categories) { category in
                        CleanerCategoryCard(category: category, scanRunning: isScanRunning, pathExists: pathExists)
                    }
                    if let docker = store.snapshot.cleaner.docker { DockerCleanerCard(value: docker, scanRunning: isScanRunning) }
                } else {
                    Text(language.cleanerText("Preview uses Mock fixtures; no filesystem scan runs.")).font(MacSoulTheme.Typography.body)
                    if store.snapshot.cleanerItems.isEmpty {
                        Text(language.cleanerText("No Mock scan results in this fixture.")).font(MacSoulTheme.Typography.status)
                    }
                    ForEach(store.snapshot.cleanerItems) { item in
                        HStack {
                            Text(item.name).font(MacSoulTheme.Typography.itemTitle)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Text(language.cleanerText(item.risk == .safe ? "Low risk" : item.risk == .caution ? "Caution" : "High risk"))
                                .font(MacSoulTheme.Typography.status)
                            Text(item.size).font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                        }
                    }
                }
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.cleanerText("Allocated file bytes where available, otherwise logical size; directories are not added. APFS clones, sparse files, hard links and shared data mean this estimate is not reclaimable space."))
                    Text(language.cleanerText("Summary combines file allocation estimates and local Docker logical usage; remote Docker is excluded."))
                    Text(language.cleanerText("Risk describes usual recovery cost if you remove the directory yourself; it is not a safety guarantee."))
                    Text(language.cleanerText("Symlink roots (including linked ancestors) are not scanned. Internal links are skipped."))
                }
                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
            }
            .frame(maxWidth: 820, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
    let scanRunning: Bool
    let pathExists: (String) -> Bool
    private var descriptor: CleanerDescriptor { category.descriptor }
    private var hasResolvedPath: Bool {
        if let resolution = descriptor.resolution { return resolution.url != nil }
        return descriptor.mavenLocation == nil || descriptor.mavenLocation?.url != nil
    }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                HStack(alignment: .top, spacing: MacSoulTheme.Spacing.card) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                        Text(language.cleanerText(descriptor.name)).font(MacSoulTheme.Typography.itemTitle)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(language.cleanerText(descriptor.risk.label)).font(MacSoulTheme.Typography.status)
                            .foregroundStyle(descriptor.risk == .low ? Color.primary : Color.orange)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: MacSoulTheme.Spacing.compact) {
                        Text(language.cleanerText(category.state.label)).font(MacSoulTheme.Typography.status)
                        if let bytes = category.sizeBytes {
                            Text(descriptor.kind == .mavenMarkers ? language.cleanerMarkerBytes(bytes) : language.cleanerBytes(bytes))
                                .font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                        }
                    }.fixedSize(horizontal: true, vertical: false)
                }
                if hasResolvedPath {
                    Text(category.rootURL.path).font(MacSoulTheme.Typography.technical).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        .help(category.rootURL.path)
                } else { Text(language.cleanerText("Repository path unresolved")).font(MacSoulTheme.Typography.supporting) }
                if let resolution = descriptor.resolution {
                    Text(language.cleanerResolutionDescription(resolution))
                        .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                } else if let location = descriptor.mavenLocation {
                    Text(language.cleanerMavenLocationDescription(location))
                        .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                } else {
                    Text(language.text("Source") + ": " + language.cleanerText("Default candidate · discovery not run"))
                        .font(MacSoulTheme.Typography.supporting)
                }
                if !descriptor.contributesToTotalEstimate {
                    Text(language.cleanerText("Included in repository usage; not added to total again."))
                        .font(MacSoulTheme.Typography.supporting)
                }
                Text(language.cleanerText(descriptor.explanation)).font(MacSoulTheme.Typography.body)
                Text(language.cleanerText(descriptor.impact)).font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                if category.state != .notRun {
                    Text(language.cleanerCounts(category.counters)).font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                    if let date = category.sampledAt {
                        Text(language.cleanerText("Updated") + ": " + language.dateTime(date)).font(MacSoulTheme.Typography.supporting)
                    }
                }
                HStack(spacing: 12) {
                    Button(language.cleanerText("View contents")) { store.openCleanerPreview(category) }
                        .buttonStyle(.borderedProminent)
                        .disabled(scanRunning || CleanerPreviewBoundary.resolvedRoot(for: category) == nil || [.notFound, .inaccessible].contains(category.state))
                    Button(language.cleanerText("Reveal in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([category.rootURL])
                    }
                    .disabled(!hasResolvedPath || !pathExists(category.rootURL.path))
                    if hasResolvedPath { CleanerPathCopyMenu(url: category.rootURL) }
                }.controlSize(.small)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(MacSoulTheme.Spacing.regular)
        }

    }
}

struct DockerCleanerCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    let value: DockerCleanerResult
    var offersPreview = true
    var scanRunning: Bool? = nil
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                HStack {
                    Text("Docker").font(MacSoulTheme.Typography.itemTitle)
                    Text(language.cleanerText("Read only")).font(MacSoulTheme.Typography.status)
                    Spacer()
                    Text(language.cleanerText(value.state.label)).font(MacSoulTheme.Typography.status)
                }
                Text(language.text("Source") + ": " + language.cleanerText(value.state == .available ? "Docker Engine" : "Docker CLI"))
                    .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                if let context = value.context { Text(language.cleanerText("Context") + ": " + context).font(MacSoulTheme.Typography.supporting) }
                if let executable = value.executable { Text(executable.path).font(MacSoulTheme.Typography.technical).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
                ForEach(value.usage, id: \.kind) { row in
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                        HStack {
                            Text(language.cleanerText(row.kind.rawValue)).font(MacSoulTheme.Typography.fieldLabel)
                            Spacer()
                            Text(language.cleanerMarkerBytes(row.bytes)).font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                        }
                        if let reclaimable = row.reclaimableBytes {
                            Text(language.cleanerText("Docker-reported reclaimable estimate") + ": " + language.cleanerMarkerBytes(reclaimable))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        }
                    }
                }
                if let total = value.totalBytes {
                    HStack {
                        Text(language.cleanerText("Total logical usage")).font(MacSoulTheme.Typography.fieldLabel); Spacer()
                        Text(language.cleanerBytes(total)).font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                    }
                }
                Text(language.cleanerText("Docker logical usage is not VM-file allocated space or a promise of safe deletion. No VM files are scanned."))
                    .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                if value.state == .remoteContext {
                    Text(language.cleanerText("Remote storage was not queried and is excluded from this Mac’s total."))
                        .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                }
                if offersPreview {
                    Button(language.cleanerText("View contents")) { store.openDockerPreview() }
                        .buttonStyle(.borderedProminent).controlSize(.small).disabled(scanRunning ?? store.cleanerRunning)
                }
                if let date = value.sampledAt { Text(language.cleanerText("Updated") + ": " + language.dateTime(date)).font(MacSoulTheme.Typography.supporting) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(MacSoulTheme.Spacing.regular)
        }
    }
}
