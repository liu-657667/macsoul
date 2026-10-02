import Foundation

enum CleanerRisk: String, Sendable { case low, caution, high
    var label: String { switch self { case .low: "Low risk"; case .caution: "Caution"; case .high: "High risk" } }
}
enum CleanerScanState: String, Sendable {
    case notRun, scanning, available, notFound, cancelled, inaccessible, partial, failed
    var label: String {
        switch self {
        case .notRun: "Not scanned"
        case .scanning: "Scanning…"
        case .available: "Complete"
        case .notFound: "Not found"
        case .cancelled: "Cancelled"
        case .inaccessible: "Inaccessible"
        case .partial: "Partial"
        case .failed: "Scan failed"
        }
    }
}
enum CleanerCategoryKind: String, CaseIterable, Sendable { case xcode, gradle, maven, mavenMarkers, npm, homebrew }

// Descriptors can only be produced by the fixed catalog. There is no free-path scan API.
struct CleanerDescriptor: Identifiable, Equatable, Sendable {
    let kind: CleanerCategoryKind
    let name: String
    let rootURL: URL
    let relativePath: String
    let risk: CleanerRisk
    let explanation: String
    let impact: String
    // rootURL is a documented fallback candidate; production scans resolve it first.
    var resolution: ResolvedCleanerTarget?
    var mavenLocation: MavenRepositoryLocation?
    var contributesToTotalEstimate = true
    var target: CleanerScanTarget = .directory
    var id: CleanerCategoryKind { kind }
    fileprivate init(kind: CleanerCategoryKind, name: String, home: URL, relativePath: String,
                     risk: CleanerRisk, explanation: String, impact: String) {
        self.kind = kind; self.name = name; self.relativePath = relativePath
        rootURL = home.appendingPathComponent(relativePath, isDirectory: true).standardized
        self.risk = risk; self.explanation = explanation; self.impact = impact
    }
}
enum CleanerScanTarget: Equatable, Sendable {
    case directory
    case matchingFiles(suffix: String)
    func includes(_ name: String) -> Bool {
        switch self { case .directory: true; case .matchingFiles(let suffix): name.hasSuffix(suffix) }
    }
}
enum CleanerCatalog {
    // A different home is dependency injection for isolated temporary-directory tests.
    static func categories(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [CleanerDescriptor] {
        let primary: [CleanerDescriptor] = [
            .init(kind: .xcode, name: "Xcode DerivedData", home: home, relativePath: "Library/Developer/Xcode/DerivedData", risk: .low,
                  explanation: "Derived build data produced by Xcode.", impact: "Removing it yourself causes reindexing and rebuilding; the first build may be slower."),
            .init(kind: .gradle, name: "Gradle Cache", home: home, relativePath: ".gradle/caches", risk: .caution,
                  explanation: "Gradle dependencies, build caches and transform results.", impact: "Removing it yourself may require downloads and regeneration; offline builds may be affected."),
            .init(kind: .maven, name: "Maven Local Repository", home: home, relativePath: ".m2/repository", risk: .caution,
                  explanation: "Maven local dependency repository, including manually installed artifacts.", impact: "Removing it yourself may lose local artifacts and break offline builds; remote dependencies need downloading again."),
            .init(kind: .npm, name: "npm Cache", home: home, relativePath: ".npm/_cacache", risk: .low,
                  explanation: "npm download cache only; user configuration is excluded.", impact: "Removing it yourself usually requires downloads on the next install. No fallback to the whole .npm directory."),
            .init(kind: .homebrew, name: "Homebrew Download Cache", home: home, relativePath: "Library/Caches/Homebrew", risk: .low,
                  explanation: "Homebrew download cache.", impact: "Removing it yourself may require downloads for future installs or upgrades.")
        ]
        return primary.flatMap { $0.kind == .maven ? [$0, markers(for: $0)] : [$0] }
    }
    static func resolvingMaven(_ categories: [CleanerDescriptor], location: MavenRepositoryLocation) -> [CleanerDescriptor] {
        categories.map { original in
            guard original.kind == .maven || original.kind == .mavenMarkers else { return original }
            var updated = original
            // Unresolved location never scans the candidate path: state checked by Scanner.
            updated.mavenLocation = location
            return updated
        }
    }
    private static func markers(for repository: CleanerDescriptor) -> CleanerDescriptor {
        var value = CleanerDescriptor(kind: .mavenMarkers, name: "Maven Failed Download Markers",
            home: repository.rootURL.deletingLastPathComponent(), relativePath: repository.rootURL.lastPathComponent,
            risk: .low, explanation: "Maven Resolver markers for unsuccessful dependency or plugin resolution/downloads.",
            impact: "Removing markers yourself may prompt another remote attempt; it does not guarantee a fix. This is negative-cache diagnostics, not a large-file cleanup.")
        value.target = .matchingFiles(suffix: ".lastUpdated")
        value.contributesToTotalEstimate = false
        return value
    }
}
struct CleanerCounters: Equatable, Sendable {
    var sizeBytes: Int64 = 0
    var fileCount = 0
    var directoryCount = 0 // descendants only; directory metadata contributes no bytes
    var skippedSymlinkCount = 0
    var inaccessibleCount = 0
    var fallbackFileCount = 0
}
struct CleanerCategory: Identifiable, Equatable, Sendable {
    let descriptor: CleanerDescriptor
    var state: CleanerScanState = .notRun
    var counters = CleanerCounters()
    var sampledAt: Date?
    var id: CleanerCategoryKind { descriptor.id }
    var rootURL: URL { descriptor.resolution?.url ?? descriptor.mavenLocation?.url ?? descriptor.rootURL }
    var sizeBytes: Int64? {
        switch state {
        case .available, .partial, .cancelled, .scanning: counters.sizeBytes
        default: nil
        }
    }
}
struct CleanerSnapshot: Equatable, Sendable {
    var mode: DataMode = .mock
    var state: CleanerScanState = .notRun
    var categories: [CleanerCategory] = []
    var sampledAt: Date?
    var docker: DockerCleanerResult?
    static func live(categories: [CleanerDescriptor]) -> Self {
        Self(mode: .live, categories: categories.map { CleanerCategory(descriptor: $0) }, docker: DockerCleanerResult())
    }
    var estimatedBytes: Int64? {
        guard state != .notRun else { return nil }
        var values = categories.filter { $0.descriptor.contributesToTotalEstimate }.compactMap(\.sizeBytes)
        if let bytes = docker?.localTotalBytes { values.append(bytes) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0) { value, next in
            let sum = value.addingReportingOverflow(next)
            return sum.overflow ? Int64.max : sum.partialValue
        }
    }
    var foundCount: Int { categories.filter { $0.sizeBytes != nil }.count + (docker?.localTotalBytes == nil ? 0 : 1) }
}
