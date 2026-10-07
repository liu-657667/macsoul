import Foundation

struct CleanerFileMetadata: Sendable {
    var isDirectory = false
    var isRegularFile = false
    var isSymlink = false
    var allocatedSize: Int64?
    var totalAllocatedSize: Int64?
    var logicalSize: Int64?
    var estimate: (bytes: Int64, fallback: Bool)? {
        if let value = totalAllocatedSize, value >= 0 { return (value, false) }
        if let value = allocatedSize, value >= 0 { return (value, false) }
        if let value = logicalSize, value >= 0 { return (value, true) }
        return nil
    }
}
// Deliberately read-only surface, also permits deterministic permission-error tests.
protocol CleanerEntryEnumerating: AnyObject {
    func next() -> URL?
    func skipDescendants()
    var inaccessibleCount: Int { get }
}
protocol CleanerFileReading: Sendable {
    func metadata(_ url: URL) throws -> CleanerFileMetadata
    func isReadable(_ url: URL) -> Bool
    func enumerator(_ root: URL) -> (any CleanerEntryEnumerating)?
}
struct FoundationCleanerFiles: CleanerFileReading {
    static let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
        .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]
    func metadata(_ url: URL) throws -> CleanerFileMetadata {
        // No file timestamps or volume-capacity metadata are requested.
        let v = try url.resourceValues(forKeys: Self.keys)
        return CleanerFileMetadata(isDirectory: v.isDirectory == true, isRegularFile: v.isRegularFile == true,
            isSymlink: v.isSymbolicLink == true, allocatedSize: v.fileAllocatedSize.map(Int64.init),
            totalAllocatedSize: v.totalFileAllocatedSize.map(Int64.init), logicalSize: v.fileSize.map(Int64.init))
    }
    func isReadable(_ url: URL) -> Bool { FileManager.default.isReadableFile(atPath: url.path) }
    func enumerator(_ root: URL) -> (any CleanerEntryEnumerating)? { FoundationCleanerEnumerator(root: root) }
}
private final class FoundationCleanerEnumerator: CleanerEntryEnumerating {
    private var value: FileManager.DirectoryEnumerator?
    private(set) var inaccessibleCount = 0
    init?(root: URL) {
        value = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(FoundationCleanerFiles.keys),
            options: [], errorHandler: { [weak self] _, _ in
                self?.inaccessibleCount += 1
                return true // a descendant error must not discard other readable results
            })
        if value == nil { return nil }
    }
    func next() -> URL? { value?.nextObject() as? URL }
    func skipDescendants() { value?.skipDescendants() }
}

actor CleanerScanner {
    private let files: any CleanerFileReading
    private let mavenLocator: (any MavenRepositoryLocating)?
    private let locator: (any CleanerLocating)?
    private let docker: DockerCleanerAdapter?
    private var busy = false
    private(set) var starts = 0
    init(files: any CleanerFileReading = FoundationCleanerFiles(), mavenLocator: (any MavenRepositoryLocating)? = nil,
         locator: (any CleanerLocating)? = nil, docker: DockerCleanerAdapter? = nil) {
        self.files = files; self.mavenLocator = mavenLocator; self.locator = locator; self.docker = docker
    }

    // One explicit sequential session: bounded tool discovery, metadata traversal, then Docker.
    // No timer, shell interpreter, stored URL lists or UI work.
    func scan(_ descriptors: [CleanerDescriptor],
              updateDocker: @Sendable (DockerCleanerResult) async -> Void = { _ in },
              update: @Sendable (CleanerCategory) async -> Void) async -> CleanerScanState {
        guard !busy else { return .failed }
        busy = true; starts += 1
        defer { busy = false }
        if Task.isCancelled { return .cancelled }
        let catalog: [CleanerDescriptor]
        if let locator { catalog = await locator.resolve(descriptors) }
        else { catalog = mavenLocator.map { CleanerCatalog.resolvingMaven(descriptors, location: $0.discover().location) } ?? descriptors }
        var partial = false
        for descriptor in catalog {
            if Task.isCancelled { return .cancelled }
            var result = await scanCategory(descriptor, update: update)
            result.sampledAt = Date()
            await update(result)
            if result.state == .cancelled { return .cancelled }
            if [.partial, .inaccessible, .failed].contains(result.state) { partial = true }
        }
        if Task.isCancelled { return .cancelled }
        if let docker {
            await updateDocker(DockerCleanerResult(state: .checking))
            let reading = await docker.collect()
            await updateDocker(reading)
            if reading.state == .cancelled || Task.isCancelled { return .cancelled }
            if [.engineUnavailable, .contextUnavailable, .failed].contains(reading.state) { partial = true }
        }
        return partial ? .partial : .available
    }

    private func scanCategory(_ descriptor: CleanerDescriptor,
                              update: @Sendable (CleanerCategory) async -> Void) async -> CleanerCategory {
        var result = CleanerCategory(descriptor: descriptor, state: .scanning)
        await update(result)
        let root = result.rootURL
        if let resolution = descriptor.resolution, resolution.state != .resolved {
            result.state = resolution.state == .notFound ? .notFound : .inaccessible
            return result
        }
        if let location = descriptor.mavenLocation, location.state != .resolved {
            result.state = location.state == .notFound ? .notFound : .inaccessible
            return result
        }
        do {
            guard root.isFileURL, root.path.hasPrefix("/"), root == root.standardized else {
                result.state = .inaccessible; return result
            }
            // A link in a root ancestor is also rejected; never enter its target.
            var ancestor = root
            while ancestor.path != "/" {
                if try files.metadata(ancestor).isSymlink {
                    result.counters.skippedSymlinkCount += 1
                    result.state = .inaccessible; return result
                }
                ancestor.deleteLastPathComponent()
            }
            guard try files.metadata(root).isDirectory, files.isReadable(root) else {
                result.state = .inaccessible; return result
            }
        } catch {
            let error = error as NSError
            result.state = error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code)
                ? .notFound : .inaccessible
            return result
        }
        guard let entries = files.enumerator(root) else { result.state = .inaccessible; return result }
        let resolvedRootPath = root.resolvingSymlinksInPath().path
        var visited = 0
        let clock = ContinuousClock()
        var lastUpdate = clock.now
        while true {
            if Task.isCancelled { result.state = .cancelled; break }
            // Reject a root replaced by a symlink during traversal as well.
            guard (try? files.metadata(root).isSymlink) == false,
                  root.resolvingSymlinksInPath().path == resolvedRootPath else {
                result.counters.inaccessibleCount += 1; result.state = .partial; break
            }
            guard let url = entries.next() else { result.state = .available; break }
            visited += 1
            do {
                let entry = try files.metadata(url)
                if entry.isSymlink {
                    // DirectoryEnumerator never descends into symbolic links. Calling
                    // skipDescendants on a link can skip unrelated siblings instead.
                    result.counters.skippedSymlinkCount += 1
                } else if !url.standardized.path.hasPrefix(root.path + "/")
                            || !url.resolvingSymlinksInPath().path.hasPrefix(resolvedRootPath + "/") {
                    entries.skipDescendants(); result.counters.inaccessibleCount += 1
                } else if entry.isDirectory {
                    result.counters.directoryCount += 1
                    if !files.isReadable(url) { entries.skipDescendants(); result.counters.inaccessibleCount += 1 }
                } else if entry.isRegularFile && descriptor.target.includes(url.lastPathComponent) {
                    if let estimate = entry.estimate {
                        let sum = result.counters.sizeBytes.addingReportingOverflow(estimate.bytes)
                        if sum.overflow { result.counters.inaccessibleCount += 1 }
                        else {
                            result.counters.sizeBytes = sum.partialValue; result.counters.fileCount += 1
                            if estimate.fallback { result.counters.fallbackFileCount += 1 }
                        }
                    } else { result.counters.inaccessibleCount += 1 }
                }
            } catch { entries.skipDescendants(); result.counters.inaccessibleCount += 1 }
            if visited % 64 == 0 {
                await Task.yield()
                if clock.now - lastUpdate >= .milliseconds(200) {
                    await update(result); lastUpdate = clock.now
                }
            }
        }
        result.counters.inaccessibleCount += entries.inaccessibleCount
        if result.state == .available && result.counters.inaccessibleCount > 0 { result.state = .partial }
        result.sampledAt = Date()
        return result
    }
}

// Owned by AppStore, independent of whether the Cleaner page is visible.
@MainActor final class CleanerSession {
    private let scanner: CleanerScanner
    private let descriptors: [CleanerDescriptor]
    private let onSnapshot: (CleanerSnapshot) -> Void
    private var task: Task<Void, Never>?
    private(set) var snapshot: CleanerSnapshot
    private var generation = 0
    var isRunning: Bool { task != nil }
    init(scanner: CleanerScanner = CleanerScanner(), descriptors: [CleanerDescriptor] = CleanerCatalog.categories(),
         onSnapshot: @escaping (CleanerSnapshot) -> Void) {
        self.scanner = scanner; self.descriptors = descriptors; self.onSnapshot = onSnapshot
        snapshot = .live(categories: descriptors)
    }
    deinit { task?.cancel() }
    func start() {
        guard task == nil else { return }
        generation += 1
        let cycle = generation
        snapshot = .live(categories: descriptors); snapshot.state = .scanning
        onSnapshot(snapshot)
        let scanner = scanner, descriptors = descriptors
        task = Task { [weak self] in
            let state = await scanner.scan(descriptors, updateDocker: { [weak self] docker in
                await self?.receiveDocker(docker, cycle: cycle)
            }, update: { [weak self] category in
                await self?.receive(category, cycle: cycle)
            })
            guard let self else { return }
            if self.generation == cycle {
                self.snapshot.state = state; self.snapshot.sampledAt = Date()
                for i in self.snapshot.categories.indices where self.snapshot.categories[i].state == .scanning {
                    self.snapshot.categories[i].state = state == .cancelled ? .cancelled : .partial
                }
                self.onSnapshot(self.snapshot)
            }
            self.task = nil
        }
    }
    private func receive(_ category: CleanerCategory, cycle: Int) {
        guard generation == cycle else { return }
        if let index = snapshot.categories.firstIndex(where: { $0.id == category.id }) {
            snapshot.categories[index] = category; onSnapshot(snapshot)
        }
    }
    private func receiveDocker(_ value: DockerCleanerResult, cycle: Int) {
        guard generation == cycle else { return }
        snapshot.docker = value; onSnapshot(snapshot)
    }
    func cancel() { task?.cancel() }
    func suspend() {
        task?.cancel(); generation += 1
        if task != nil {
            snapshot.state = .cancelled
            onSnapshot(snapshot)
        }
    }
    func resetForPreview() {
        task?.cancel(); generation += 1
        snapshot = .live(categories: descriptors)
    }
    func waitForStop() async { await task?.value }
}
