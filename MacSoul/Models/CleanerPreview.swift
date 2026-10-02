import Foundation

enum CleanerPreviewKind: String, Sendable { case directory, file, symlink, other }
enum CleanerPreviewSort: String, CaseIterable, Sendable { case sizeDescending, nameAscending }
struct CleanerPreviewItem: Identifiable, Equatable, Sendable {
    let name: String
    let relativePath: String
    let url: URL
    let kind: CleanerPreviewKind
    var estimatedAllocatedBytes: Int64?
    var childCount: Int?
    var state: CleanerScanState
    var isSymlink: Bool { kind == .symlink }
    var id: String { relativePath }
}
struct CleanerPreviewSnapshot: Equatable, Sendable {
    let category: CleanerCategory
    let directoryURL: URL
    var state: CleanerScanState = .scanning
    var items: [CleanerPreviewItem] = []
    var isTruncated = false
    var sort: CleanerPreviewSort = .sizeDescending
    var sortedItems: [CleanerPreviewItem] {
        items.sorted {
            if sort == .sizeDescending, $0.estimatedAllocatedBytes != $1.estimatedAllocatedBytes {
                return ($0.estimatedAllocatedBytes ?? -1) > ($1.estimatedAllocatedBytes ?? -1)
            }
            return $0.relativePath < $1.relativePath
        }
    }
}
enum CleanerPreviewDestination: Identifiable, Equatable {
    case directory(CleanerCategory), docker(DockerCleanerResult)
    var id: String { switch self { case .directory(let category): category.id.rawValue; case .docker: "docker" } }
    var dockerRows: [DockerStorageUsage] { if case .docker(let value) = self { return value.usage }; return [] }
}

protocol CleanerPreviewFileReading: CleanerFileReading {
    func directChildren(_ root: URL) -> (any CleanerEntryEnumerating)?
}
extension FoundationCleanerFiles: CleanerPreviewFileReading {
    func directChildren(_ root: URL) -> (any CleanerEntryEnumerating)? { CleanerDirectChildren(root: root) }
}
private final class CleanerDirectChildren: CleanerEntryEnumerating {
    private var enumerator: FileManager.DirectoryEnumerator?
    private(set) var inaccessibleCount = 0
    init?(root: URL) {
        enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(FoundationCleanerFiles.keys),
            options: [.skipsSubdirectoryDescendants], errorHandler: { [weak self] _, _ in
                self?.inaccessibleCount += 1; return true
            })
        if enumerator == nil { return nil }
    }
    func next() -> URL? { enumerator?.nextObject() as? URL }
    func skipDescendants() { enumerator?.skipDescendants() }
}

// No arbitrary-path browser: only the already resolved category root can establish a boundary.
struct CleanerPreviewBoundary: Sendable {
    let root: URL
    let resolvedRootPath: String
    static func resolvedRoot(for category: CleanerCategory) -> URL? {
        let root: URL
        if let resolution = category.descriptor.resolution {
            guard resolution.state == .resolved, let url = resolution.url else { return nil }
            root = url
        } else if let location = category.descriptor.mavenLocation {
            guard location.state == .resolved, let url = location.url else { return nil }
            root = url
        } else { return nil }
        guard root.isFileURL, root.path.hasPrefix("/"), root.path == root.standardized.path else { return nil }
        return root
    }
    init?(category: CleanerCategory) {
        guard let root = Self.resolvedRoot(for: category) else { return nil }
        self.root = root
        resolvedRootPath = root.resolvingSymlinksInPath().path // scanner actor only; UI uses the pure helper
    }
    func contains(_ url: URL) -> Bool {
        url.isFileURL && url.path == url.standardized.path &&
            (url.path == root.path || url.path.hasPrefix(root.path + "/"))
    }
    func validateDirectory(_ url: URL, files: any CleanerFileReading) throws -> Bool {
        guard contains(url), root.resolvingSymlinksInPath().path == resolvedRootPath else { return false }
        var ancestor = url
        var ancestors: [URL] = []
        while ancestor.path != "/" { ancestors.append(ancestor); ancestor.deleteLastPathComponent() }
        // Check outer ancestors before a missing leaf, so an ancestor link is always rejected.
        for ancestor in ancestors.reversed() {
            if try files.metadata(ancestor).isSymlink { return false }
        }
        let path = url.resolvingSymlinksInPath().path
        guard path == resolvedRootPath || path.hasPrefix(resolvedRootPath + "/") else { return false }
        return try files.metadata(url).isDirectory && files.isReadable(url)
    }
}

actor CleanerPreviewScanner {
    static let maximumItems = 2000
    private let files: any CleanerPreviewFileReading
    private let aggregate: CleanerScanner
    private var busy = false
    private(set) var starts = 0
    init(files: any CleanerPreviewFileReading = FoundationCleanerFiles()) {
        self.files = files; aggregate = CleanerScanner(files: files) // no discovery or Docker calls here
    }
    func scan(category: CleanerCategory, directory: URL,
              update: @Sendable (CleanerPreviewSnapshot) async -> Void) async -> CleanerPreviewSnapshot {
        var snapshot = CleanerPreviewSnapshot(category: category, directoryURL: directory)
        guard !busy else { snapshot.state = .failed; return snapshot }
        busy = true; starts += 1
        defer { busy = false }
        if Task.isCancelled { snapshot.state = .cancelled; return snapshot }
        guard let boundary = CleanerPreviewBoundary(category: category) else { snapshot.state = .inaccessible; return snapshot }
        do {
            guard try boundary.validateDirectory(directory, files: files) else { snapshot.state = .inaccessible; return snapshot }
        } catch {
            snapshot.state = missing(error) ? .notFound : .inaccessible; return snapshot
        }
        guard let entries = files.directChildren(directory) else { snapshot.state = .inaccessible; return snapshot }
        let clock = ContinuousClock()
        var lastUpdate = clock.now
        var partial = false
        await update(snapshot)
        while let url = entries.next() {
            if Task.isCancelled { snapshot.state = .cancelled; return snapshot }
            guard snapshot.items.count < Self.maximumItems else { snapshot.isTruncated = true; partial = true; break }
            guard boundary.contains(url), url.deletingLastPathComponent().path == directory.path else { partial = true; continue }
            let relative = String(url.path.dropFirst(boundary.root.path.count + 1))
            var item = CleanerPreviewItem(name: url.lastPathComponent, relativePath: relative, url: url,
                                          kind: .other, state: .inaccessible)
            do {
                guard try boundary.validateDirectory(directory, files: files) else {
                    snapshot.state = .inaccessible; return snapshot
                }
                let metadata = try files.metadata(url)
                let kind: CleanerPreviewKind = metadata.isSymlink ? .symlink : metadata.isDirectory ? .directory : metadata.isRegularFile ? .file : .other
                item = .init(name: url.lastPathComponent, relativePath: relative, url: url, kind: kind,
                             state: kind == .directory ? .scanning : .available)
                if kind == .file {
                    if !files.isReadable(url) { item.state = .inaccessible }
                    else if category.descriptor.target.includes(item.name), let estimate = metadata.estimate {
                        item.estimatedAllocatedBytes = estimate.bytes
                    } else if category.descriptor.target.includes(item.name) { item.state = .partial }
                }
                // Links are visible records with unknown target size; they never enter aggregate traversal.
            } catch { item.state = missing(error) ? .notFound : .inaccessible }
            if [.inaccessible, .partial, .notFound].contains(item.state) { partial = true }
            snapshot.items.append(item)
            if snapshot.items.count % 64 == 0 {
                await Task.yield()
                if clock.now - lastUpdate >= .milliseconds(200) { await update(snapshot); lastUpdate = clock.now }
            }
        }
        partial = partial || entries.inaccessibleCount > 0
        await update(snapshot) // complete direct-child listing before sequential child estimates
        for index in snapshot.items.indices where snapshot.items[index].kind == .directory {
            if Task.isCancelled { snapshot.state = .cancelled; return snapshot }
            let url = snapshot.items[index].url
            do {
                guard try boundary.validateDirectory(url, files: files) else {
                    snapshot.items[index].state = .inaccessible; partial = true; continue
                }
            } catch {
                snapshot.items[index].state = missing(error) ? .notFound : .inaccessible; partial = true; continue
            }
            var descriptor = category.descriptor
            descriptor.resolution = ResolvedCleanerTarget(url: url, source: descriptor.resolution?.source ?? .mavenDefault, state: .resolved)
            descriptor.mavenLocation = nil
            let result = PreviewAggregateResult()
            _ = await aggregate.scan([descriptor]) { await result.receive($0) }
            if let reading = await result.category {
                snapshot.items[index].state = reading.state
                snapshot.items[index].estimatedAllocatedBytes = reading.sizeBytes
                snapshot.items[index].childCount = reading.counters.fileCount + reading.counters.directoryCount
                if reading.state != .available { partial = true }
            }
            if Task.isCancelled { snapshot.state = .cancelled; return snapshot }
            if clock.now - lastUpdate >= .milliseconds(200) { await update(snapshot); lastUpdate = clock.now }
        }
        if Task.isCancelled { snapshot.state = .cancelled }
        else { snapshot.state = partial ? .partial : .available }
        return snapshot
    }
    private func missing(_ error: Error) -> Bool {
        let value = error as NSError
        return value.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(value.code)
    }
}
private actor PreviewAggregateResult {
    var category: CleanerCategory?
    func receive(_ value: CleanerCategory) { category = value }
}

struct CleanerPreviewNavigation: Equatable {
    let category: CleanerCategory
    private(set) var components: [String] = []
    var directory: URL { components.reduce(category.rootURL) { $0.appendingPathComponent($1, isDirectory: true) } }
    mutating func enter(_ item: CleanerPreviewItem) -> Bool {
        guard item.kind == .directory, item.state == .available || item.state == .partial || item.state == .scanning,
              item.url.deletingLastPathComponent().path == directory.path,
              !item.name.isEmpty, item.name != ".", item.name != "..", !item.name.contains("/"),
              item.url.path == directory.appendingPathComponent(item.name).path,
              (item.url.path == category.rootURL.path || item.url.path.hasPrefix(category.rootURL.path + "/")) else { return false }
        components.append(item.name); return true
    }
    mutating func back(to depth: Int? = nil) {
        let target = depth ?? components.count - 1
        guard target >= 0, target < components.count else { return }
        components = Array(components.prefix(target))
    }
}

// One AppStore-owned preview session, serialized across navigation/category changes.
@MainActor final class CleanerPreviewSession {
    private let scanner: CleanerPreviewScanner
    private let onSnapshot: (CleanerPreviewSnapshot) -> Void
    private var task: Task<Void, Never>?
    private var generation = 0
    private var activeTaskCycle = 0
    private(set) var snapshot: CleanerPreviewSnapshot?
    private(set) var navigation: CleanerPreviewNavigation?
    var isRunning: Bool { task != nil }
    init(scanner: CleanerPreviewScanner = CleanerPreviewScanner(), onSnapshot: @escaping (CleanerPreviewSnapshot) -> Void) {
        self.scanner = scanner; self.onSnapshot = onSnapshot
    }
    deinit { task?.cancel() }
    func open(_ category: CleanerCategory) {
        if navigation?.category == category, isRunning { return }
        navigation = CleanerPreviewNavigation(category: category); load()
    }
    func enter(_ item: CleanerPreviewItem) {
        guard snapshot?.items.contains(where: { $0.id == item.id && $0 == item }) == true,
              navigation?.enter(item) == true else { return }
        load()
    }
    func back(to depth: Int? = nil) {
        guard let before = navigation else { return }
        navigation?.back(to: depth)
        if navigation != before { load() }
    }
    func sort(_ order: CleanerPreviewSort) {
        guard var value = snapshot else { return }; value.sort = order; snapshot = value; onSnapshot(value)
    }
    func cancel() { task?.cancel() }
    func close() { task?.cancel(); generation += 1; navigation = nil; snapshot = nil }
    func waitForStop() async { await task?.value }
    private func load() {
        guard let navigation else { return }
        let previous = task
        previous?.cancel(); generation += 1
        let cycle = generation, scanner = scanner
        let initial = CleanerPreviewSnapshot(category: navigation.category, directoryURL: navigation.directory)
        snapshot = initial; onSnapshot(initial)
        activeTaskCycle = cycle
        task = Task { [weak self] in
            await previous?.value // cancelled work must finish before the next traversal starts
            if !Task.isCancelled {
                let result = await scanner.scan(category: navigation.category, directory: navigation.directory) { [weak self] value in
                    await self?.receive(value, cycle: cycle)
                }
                self?.receive(result, cycle: cycle)
            } else {
                var cancelled = initial; cancelled.state = .cancelled
                self?.receive(cancelled, cycle: cycle)
            }
            if self?.activeTaskCycle == cycle { self?.task = nil }
        }
    }
    private func receive(_ value: CleanerPreviewSnapshot, cycle: Int) {
        guard generation == cycle else { return }
        var result = value; result.sort = snapshot?.sort ?? .sizeDescending
        if result.state == .cancelled {
            for index in result.items.indices where result.items[index].state == .scanning { result.items[index].state = .cancelled }
        }
        snapshot = result; onSnapshot(result)
    }
}
