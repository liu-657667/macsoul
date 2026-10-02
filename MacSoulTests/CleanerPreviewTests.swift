import XCTest
import Darwin
@testable import MacSoul

private struct PreviewFixture {
    let home: URL
    init() throws {
        let raw = FileManager.default.temporaryDirectory.appendingPathComponent("MacSoulPreviewTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        let path = raw.path.withCString { realpath($0, nil) }!
        home = URL(fileURLWithPath: String(cString: path)); free(path)
    }
    var category: CleanerCategory {
        var descriptor = CleanerCatalog.categories(home: home)[0]
        descriptor.resolution = .init(url: descriptor.rootURL, source: .xcodeDefault, state: .resolved)
        return CleanerCategory(descriptor: descriptor, state: .available)
    }
    func category(at root: URL, source: CleanerResolutionSource = .xcodeDefault) -> CleanerCategory {
        var descriptor = category.descriptor
        descriptor.resolution = .init(url: root, source: source, state: .resolved)
        return CleanerCategory(descriptor: descriptor, state: .available)
    }
    var root: URL { category.rootURL }
    func directory(_ url: URL) throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    func file(_ url: URL, bytes: Int) throws { try Data(repeating: 42, count: bytes).write(to: url) }
    func cleanup() { try? FileManager.default.removeItem(at: home) } // private test fixture only
}
private struct PreviewFiles: CleanerPreviewFileReading {
    let native = FoundationCleanerFiles()
    var missingName: String? = nil
    var inaccessibleName: String? = nil
    var cancelName: String? = nil
    var logicalOnly = true
    func metadata(_ url: URL) throws -> CleanerFileMetadata {
        if url.lastPathComponent == missingName { throw CocoaError(.fileReadNoSuchFile) }
        if url.lastPathComponent == inaccessibleName { throw CocoaError(.fileReadNoPermission) }
        if url.lastPathComponent == cancelName { withUnsafeCurrentTask { $0?.cancel() } }
        var value = try native.metadata(url)
        if logicalOnly { value.allocatedSize = nil; value.totalAllocatedSize = nil }
        return value
    }
    func isReadable(_ url: URL) -> Bool { native.isReadable(url) }
    func enumerator(_ root: URL) -> (any CleanerEntryEnumerating)? { native.enumerator(root) }
    func directChildren(_ root: URL) -> (any CleanerEntryEnumerating)? { native.directChildren(root) }
}
private actor PreviewSystem: SystemSampling {
    func start() {}
    func stop() {}
    func sample() -> SystemReading { SystemReading(cpuPercent: nil, memory: nil, pressure: .unknown) }
}
private actor PreviewDetails: SystemDetailSampling {
    func start() {}
    func stop() {}
    func sampleDisk(now: Date) -> DiskReading { .unknown }
    func sampleBattery(now: Date) -> BatteryReading { .unknown }
    func sampleProcesses(now: Date, uptime: TimeInterval) -> ProcessReading { .unknown }
}

final class CleanerPreviewTests: XCTestCase {
    private func scan(_ category: CleanerCategory, directory: URL? = nil, files: PreviewFiles = PreviewFiles()) async -> CleanerPreviewSnapshot {
        await CleanerPreviewScanner(files: files).scan(category: category, directory: directory ?? category.rootURL) { _ in }
    }
    func testPreviewEnumeratesDirectChildrenNotWholeTree() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }
        let nested = f.root.appendingPathComponent("child/deep")
        try f.directory(nested); try f.file(nested.appendingPathComponent("leaf"), bytes: 123)
        try f.file(f.root.appendingPathComponent("file"), bytes: 10)
        let result = await scan(f.category)
        XCTAssertEqual(result.state, .available)
        XCTAssertEqual(Set(result.items.map(\.name)), ["child", "file"])
        XCTAssertEqual(result.items.count, 2)
    }
    func testRegularFileAllocatedSizeAndStableRelativeID() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let file = f.root.appendingPathComponent("one"); try f.file(file, bytes: 113)
        let value = await scan(f.category, files: PreviewFiles(logicalOnly: false))
        let item = try XCTUnwrap(value.items.first)
        XCTAssertEqual(item.kind, .file); XCTAssertFalse(item.isSymlink)
        XCTAssertEqual(item.estimatedAllocatedBytes, try FoundationCleanerFiles().metadata(file).estimate?.bytes)
        XCTAssertEqual(item.id, "one"); XCTAssertEqual(item.relativePath, "one"); XCTAssertEqual(item.url.path, file.path)
    }
    func testDirectoryUsesExistingAggregateNotDirectoryMetadataSize() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let child = f.root.appendingPathComponent("child")
        try f.directory(child.appendingPathComponent("deep")); try f.file(child.appendingPathComponent("a"), bytes: 10)
        try f.file(child.appendingPathComponent("deep/b"), bytes: 120)
        let result = await scan(f.category); let item = try XCTUnwrap(result.items.first)
        XCTAssertEqual(item.kind, .directory); XCTAssertEqual(item.state, .available)
        XCTAssertEqual(item.estimatedAllocatedBytes, 130); XCTAssertEqual(item.childCount, 3)
    }
    func testLargestFirstAndNameSortingDoNotScanAgain() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        try f.file(f.root.appendingPathComponent("a"), bytes: 2); try f.file(f.root.appendingPathComponent("z"), bytes: 50)
        var value = await scan(f.category)
        XCTAssertEqual(value.sortedItems.map(\.name), ["z", "a"])
        value.sort = .nameAscending; XCTAssertEqual(value.sortedItems.map(\.name), ["a", "z"])
    }
    func testValidZeroFileIsNotUnknownSize() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root); try f.file(f.root.appendingPathComponent("empty"), bytes: 0)
        let value = await scan(f.category); XCTAssertEqual(value.items.first?.estimatedAllocatedBytes, 0)
        XCTAssertEqual(value.items.first?.state, .available)
    }
    func testEmptyDirectoryRemainsAvailable() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let result = await scan(f.category); XCTAssertEqual(result.state, .available); XCTAssertTrue(result.items.isEmpty)
    }
    func testDrillDownAndBackNavigationStayWithinRoot() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let child = f.root.appendingPathComponent("child")
        try f.directory(child); try f.file(child.appendingPathComponent("file"), bytes: 3)
        let root = await scan(f.category); let item = try XCTUnwrap(root.items.first)
        var navigation = CleanerPreviewNavigation(category: f.category)
        XCTAssertTrue(navigation.enter(item)); XCTAssertEqual(navigation.components, ["child"])
        let detail = await scan(f.category, directory: navigation.directory)
        XCTAssertEqual(detail.items.map(\.relativePath), ["child/file"])
        navigation.back(); XCTAssertEqual(navigation.directory.path, f.root.path); XCTAssertTrue(navigation.components.isEmpty)
    }
    func testBreadcrumbBackToKnownAncestor() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root.appendingPathComponent("a/b"))
        var nav = CleanerPreviewNavigation(category: f.category)
        let a = await scan(f.category); XCTAssertTrue(nav.enter(try XCTUnwrap(a.items.first)))
        let b = await scan(f.category, directory: nav.directory); XCTAssertTrue(nav.enter(try XCTUnwrap(b.items.first)))
        XCTAssertEqual(nav.components, ["a", "b"]); nav.back(to: 1); XCTAssertEqual(nav.components, ["a"])
        nav.back(to: 0); XCTAssertTrue(nav.components.isEmpty)
    }
    func testMissingDirectoryDoesNotBecomeEmptyAvailable() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let result = await scan(f.category, directory: f.root.appendingPathComponent("missing"))
        XCTAssertEqual(result.state, .notFound); XCTAssertTrue(result.items.isEmpty)
    }
    func testDisappearedChildStaysNotFoundNotZero() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root); try f.file(f.root.appendingPathComponent("gone"), bytes: 3)
        let result = await scan(f.category, files: PreviewFiles(missingName: "gone"))
        XCTAssertEqual(result.state, .partial); XCTAssertEqual(result.items.first?.state, .notFound)
        XCTAssertNil(result.items.first?.estimatedAllocatedBytes)
    }
    func testInaccessibleChildRetainsErrorAndOtherResults() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        try f.file(f.root.appendingPathComponent("denied"), bytes: 3); try f.file(f.root.appendingPathComponent("ok"), bytes: 4)
        let result = await scan(f.category, files: PreviewFiles(inaccessibleName: "denied"))
        XCTAssertEqual(result.state, .partial); XCTAssertEqual(result.items.first { $0.name == "denied" }?.state, .inaccessible)
        XCTAssertNil(result.items.first { $0.name == "denied" }?.estimatedAllocatedBytes)
        XCTAssertEqual(result.items.first { $0.name == "ok" }?.estimatedAllocatedBytes, 4)
    }
    func testInaccessibleRootIsExplicit() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let result = await scan(f.category, files: PreviewFiles(inaccessibleName: f.root.lastPathComponent))
        XCTAssertEqual(result.state, .inaccessible); XCTAssertTrue(result.items.isEmpty)
    }
    func testSymlinkVisibleButNeverFollowedOrCounted() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let outside = f.home.appendingPathComponent("outside"); try f.directory(outside); try f.file(outside.appendingPathComponent("large"), bytes: 9000)
        try FileManager.default.createSymbolicLink(at: f.root.appendingPathComponent("link"), withDestinationURL: outside)
        let result = await scan(f.category); let item = try XCTUnwrap(result.items.first)
        XCTAssertEqual(item.kind, .symlink); XCTAssertTrue(item.isSymlink); XCTAssertNil(item.estimatedAllocatedBytes)
        var navigation = CleanerPreviewNavigation(category: f.category); XCTAssertFalse(navigation.enter(item))
        let forbidden = await scan(f.category, directory: item.url); XCTAssertEqual(forbidden.state, .inaccessible)
    }
    func testNestedExternalSymlinkDoesNotAffectDirectoryEstimate() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let child = f.root.appendingPathComponent("child")
        let outside = f.home.appendingPathComponent("outside"); try f.directory(child); try f.directory(outside)
        try f.file(child.appendingPathComponent("ok"), bytes: 9); try f.file(outside.appendingPathComponent("large"), bytes: 9000)
        try FileManager.default.createSymbolicLink(at: child.appendingPathComponent("link"), withDestinationURL: outside)
        let result = await scan(f.category); XCTAssertEqual(result.items.first?.estimatedAllocatedBytes, 9)
    }
    func testRootAndAncestorSymlinksAreRejected() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }
        let outside = f.home.appendingPathComponent("outside"); try f.directory(outside)
        try f.directory(f.root.deletingLastPathComponent())
        try FileManager.default.createSymbolicLink(at: f.root, withDestinationURL: outside)
        let result = await scan(f.category); XCTAssertEqual(result.state, .inaccessible)
        let category = f.category(at: f.root.appendingPathComponent("nested"))
        let ancestor = await scan(category); XCTAssertEqual(ancestor.state, .inaccessible)
    }
    func testArbitraryOutsideSiblingAndDotDotPathsRejected() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let outside = f.home.appendingPathComponent("outside"); try f.directory(outside)
        for url in [outside, f.root.deletingLastPathComponent(), URL(fileURLWithPath: f.root.path + "/../outside")] {
            let result = await scan(f.category, directory: url); XCTAssertEqual(result.state, .inaccessible)
        }
    }
    func testUnresolvedDefaultCandidateCannotEstablishPreviewBoundary() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let category = CleanerCategory(descriptor: CleanerCatalog.categories(home: f.home)[0])
        XCTAssertNil(CleanerPreviewBoundary(category: category)); let result = await scan(category)
        XCTAssertEqual(result.state, .inaccessible)
    }
    func testResolvedCustomRootAndSourceSurvivePreview() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let custom = f.home.appendingPathComponent("custom-cache")
        try f.directory(custom); try f.file(custom.appendingPathComponent("one"), bytes: 2)
        let category = f.category(at: custom, source: .brewCLI)
        let result = await scan(category); XCTAssertEqual(result.category.rootURL.path, custom.path)
        XCTAssertEqual(result.category.descriptor.resolution?.source, .brewCLI)
        XCTAssertTrue(result.items.allSatisfy { $0.url.path.hasPrefix(custom.path + "/") })
    }
    func testCancellationDuringPreviewStopsBeforeCompletion() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        for i in 0..<10 { try f.file(f.root.appendingPathComponent(String(i)), bytes: 1) }
        let first = try XCTUnwrap(FoundationCleanerFiles().directChildren(f.root)?.next()?.lastPathComponent)
        let category = f.category
        let task = Task { await self.scan(category, files: PreviewFiles(cancelName: first)) }
        let result = await task.value; XCTAssertEqual(result.state, .cancelled); XCTAssertLessThan(result.items.count, 10)
    }
    @MainActor func testRepeatedOpenUsesOnePreviewScanner() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let scanner = CleanerPreviewScanner(files: PreviewFiles())
        let session = CleanerPreviewSession(scanner: scanner) { _ in }
        session.open(f.category); session.open(f.category); await session.waitForStop()
        let starts = await scanner.starts; XCTAssertEqual(starts, 1); XCTAssertFalse(session.isRunning)
    }
    @MainActor func testClosingPreviewCancelsAndDropsLateUpdates() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        var updates = 0
        let session = CleanerPreviewSession(scanner: CleanerPreviewScanner(files: PreviewFiles())) { _ in updates += 1 }
        session.open(f.category); let before = updates; session.close(); await session.waitForStop()
        XCTAssertEqual(updates, before); XCTAssertNil(session.snapshot); XCTAssertNil(session.navigation); XCTAssertFalse(session.isRunning)
    }
    @MainActor func testRapidCategorySwitchIsSerializedAndFinalSourceWins() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let custom = f.home.appendingPathComponent("custom")
        try f.directory(f.root); try f.directory(custom)
        let second = f.category(at: custom, source: .brewCLI)
        let scanner = CleanerPreviewScanner(files: PreviewFiles()); let session = CleanerPreviewSession(scanner: scanner) { _ in }
        session.open(f.category); session.open(second); await session.waitForStop()
        XCTAssertEqual(session.snapshot?.directoryURL.path, custom.path); XCTAssertEqual(session.snapshot?.state, .available)
        let starts = await scanner.starts; XCTAssertEqual(starts, 1)
    }
    @MainActor func testSessionEnterAndBackLoadLazily() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root.appendingPathComponent("child"))
        let session = CleanerPreviewSession(scanner: CleanerPreviewScanner(files: PreviewFiles())) { _ in }
        session.open(f.category); await session.waitForStop()
        session.enter(try XCTUnwrap(session.snapshot?.items.first)); await session.waitForStop()
        XCTAssertEqual(session.navigation?.components, ["child"])
        session.back(); await session.waitForStop(); XCTAssertEqual(session.navigation?.components, [])
    }
    @MainActor func testSessionRejectsForgedItemNotInCurrentSnapshot() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let scanner = CleanerPreviewScanner(files: PreviewFiles()); let session = CleanerPreviewSession(scanner: scanner) { _ in }
        session.open(f.category); await session.waitForStop()
        let forged = CleanerPreviewItem(name: "..", relativePath: "..", url: f.home, kind: .directory, state: .available)
        session.enter(forged); XCTAssertTrue(session.navigation?.components.isEmpty == true)
        let starts = await scanner.starts; XCTAssertEqual(starts, 1)
    }
    func testPreviewDoesNotMutateFilesOrFollowLinks() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let nested = f.root.appendingPathComponent("nested")
        try f.directory(nested); let file = nested.appendingPathComponent("one"); try f.file(file, bytes: 9)
        let before = try Data(contentsOf: file); let paths = try FileManager.default.subpathsOfDirectory(atPath: f.root.path)
        _ = await scan(f.category)
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(try FileManager.default.subpathsOfDirectory(atPath: f.root.path), paths)
    }
    func testDockerPreviewReusesExistingLogicalRows() {
        let rows = DockerStorageKind.allCases.map { DockerStorageUsage(kind: $0, bytes: 2, reclaimableBytes: 1) }
        let value = DockerCleanerResult(state: .available, isLocal: true, usage: rows)
        let preview = CleanerPreviewDestination.docker(value)
        XCTAssertEqual(preview.dockerRows, rows); XCTAssertEqual(value.localTotalBytes, 8)
    }
    func testPreviewStringsRespectAppLanguage() {
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerText("Estimated Usage"), "估算占用")
        XCTAssertEqual(MacSoulLanguage.english.cleanerText("Estimated Usage"), "Estimated Usage")
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerText("View contents"), "查看内容")
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerKind(.symlink), "符号链接 · 未跟随")
        XCTAssertEqual(MacSoulLanguage.english.cleanerKind(.directory), "Directory")
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerText("Calculating…"), "正在计算…")
    }
    @MainActor func testPreviewModeCancelsContentPreview() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let store = makeStore(f); store.setSystemMode(.live); store.scanCleaner(); await store.waitForCleanerStop()
        store.openCleanerPreview(try XCTUnwrap(store.snapshot.cleaner.categories.first))
        store.setSystemMode(.preview); await store.waitForCleanerPreviewStop()
        XCTAssertNil(store.cleanerPreview); XCTAssertNil(store.cleanerPreviewDestination); XCTAssertFalse(store.cleanerPreviewRunning)
    }
    @MainActor func testSleepCancelsContentPreviewAndWakeDoesNotRescan() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let scanner = CleanerPreviewScanner(files: PreviewFiles()); let store = makeStore(f, preview: scanner)
        store.setSystemMode(.live); store.scanCleaner(); await store.waitForCleanerStop()
        store.openCleanerPreview(try XCTUnwrap(store.snapshot.cleaner.categories.first)); store.suspendForSleep()
        await store.waitForCleanerPreviewStop(); store.resumeAfterWake()
        XCTAssertNil(store.cleanerPreviewDestination); let starts = await scanner.starts; XCTAssertEqual(starts, 0)
        store.setSystemMode(.preview)
    }
    @MainActor func testSummaryAndPreviewAreMutuallyExclusive() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let summary = CleanerScanner(locator: CleanerLocator(home: f.home, environment: [:], includeKnownLocations: false))
        let store = makeStore(f, summary: summary)
        store.setSystemMode(.live); store.scanCleaner(); await store.waitForCleanerStop()
        store.openCleanerPreview(try XCTUnwrap(store.snapshot.cleaner.categories.first)); store.scanCleaner()
        await store.waitForCleanerPreviewStop(); await store.waitForCleanerStop()
        let starts = await summary.starts; XCTAssertEqual(starts, 1)
        store.closeCleanerPreview(); store.setSystemMode(.preview)
    }
    func testDirectChildLimitIsExplicitAndPartial() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        for i in 0...CleanerPreviewScanner.maximumItems { try f.file(f.root.appendingPathComponent(String(i)), bytes: 0) }
        let value = await scan(f.category)
        XCTAssertEqual(value.items.count, CleanerPreviewScanner.maximumItems)
        XCTAssertTrue(value.isTruncated); XCTAssertEqual(value.state, .partial)
    }
    func testBoundaryRejectsRootReplacedBySymlink() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let category = f.category; let boundary = try XCTUnwrap(CleanerPreviewBoundary(category: category))
        let outside = f.home.appendingPathComponent("outside"); try f.directory(outside)
        // Mutation is exclusively test setup under the private fixture.
        try FileManager.default.moveItem(at: f.root, to: f.root.appendingPathExtension("old"))
        try FileManager.default.createSymbolicLink(at: f.root, withDestinationURL: outside)
        XCTAssertFalse(try boundary.validateDirectory(f.root, files: PreviewFiles()))
        let result = await scan(category); XCTAssertEqual(result.state, .inaccessible)
    }
    @MainActor func testSummaryCannotOpenPreviewWhileItIsScanning() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        let scanner = CleanerPreviewScanner(files: PreviewFiles()); let store = makeStore(f, preview: scanner)
        store.setSystemMode(.live); store.scanCleaner()
        store.openCleanerPreview(f.category) // scanning snapshot is not a completed, trusted category
        XCTAssertNil(store.cleanerPreviewDestination)
        await store.waitForCleanerStop(); let starts = await scanner.starts; XCTAssertEqual(starts, 0)
        store.setSystemMode(.preview)
    }
    @MainActor func testClosingDuringActiveListingCancelsBeforeDirectoryAggregation() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; let child = f.root.appendingPathComponent("child")
        try f.directory(child); try f.file(child.appendingPathComponent("one"), bytes: 30)
        let scanner = CleanerPreviewScanner(files: PreviewFiles())
        var session: CleanerPreviewSession?
        session = CleanerPreviewSession(scanner: scanner) { value in
            if !value.items.isEmpty { session?.close() }
        }
        session?.open(f.category); await session?.waitForStop()
        let starts = await scanner.starts; XCTAssertEqual(starts, 1)
        XCTAssertNil(session?.snapshot); XCTAssertFalse(session?.isRunning ?? true)
        session = nil
    }
    @MainActor func testCategorySwitchDuringActiveListingWaitsForCancelledTraversal() async throws {
        let f = try PreviewFixture(); defer { f.cleanup() }; try f.directory(f.root)
        try f.file(f.root.appendingPathComponent("first"), bytes: 20)
        let custom = f.home.appendingPathComponent("custom"); try f.directory(custom)
        try f.file(custom.appendingPathComponent("second"), bytes: 30)
        let second = f.category(at: custom, source: .brewCLI)
        let scanner = CleanerPreviewScanner(files: PreviewFiles()); var switched = false
        var session: CleanerPreviewSession?
        session = CleanerPreviewSession(scanner: scanner) { value in
            if !switched && !value.items.isEmpty {
                switched = true; session?.open(second)
            }
        }
        session?.open(f.category); await session?.waitForStop(); await session?.waitForStop()
        XCTAssertTrue(switched); XCTAssertEqual(session?.snapshot?.items.map(\.name), ["second"])
        XCTAssertEqual(session?.snapshot?.state, .available)
        let starts = await scanner.starts; XCTAssertEqual(starts, 2)
        session?.close(); session = nil
    }
    @MainActor private func makeStore(_ f: PreviewFixture, preview: CleanerPreviewScanner = CleanerPreviewScanner(files: PreviewFiles()), summary: CleanerScanner? = nil) -> AppStore {
        AppStore(sampler: PreviewSystem(), details: PreviewDetails(), networkPath: FakeNetworkPath(),
                 cleanerScanner: summary ?? CleanerScanner(locator: CleanerLocator(home: f.home, environment: [:], includeKnownLocations: false)),
                 cleanerCategories: [f.category.descriptor], cleanerPreviewScanner: preview)
    }
}
