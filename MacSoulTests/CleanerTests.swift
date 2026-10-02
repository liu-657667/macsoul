import XCTest
import SwiftUI
import Darwin
@testable import MacSoul

// Every scanner root in this suite is under this test's private temporary home.
private struct CleanerFixture {
    let home: URL
    init() throws {
        let proposed = FileManager.default.temporaryDirectory.appendingPathComponent("MacSoulCleanerTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: proposed, withIntermediateDirectories: true)
        let resolved = proposed.path.withCString { realpath($0, nil) }!
        home = URL(fileURLWithPath: String(cString: resolved)); free(resolved)
    }
    var descriptors: [CleanerDescriptor] { CleanerCatalog.categories(home: home) }
    var xcode: CleanerDescriptor { descriptors[0] }
    func directory(_ url: URL) throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    func file(_ url: URL, bytes: Int) throws { try Data(repeating: 42, count: bytes).write(to: url) }
    func cleanup() { try? FileManager.default.removeItem(at: home) } // test-owned temp only
}
private actor CleanerResults {
    var latest: [CleanerCategoryKind: CleanerCategory] = [:]
    func record(_ category: CleanerCategory) { latest[category.id] = category }
    func value(_ kind: CleanerCategoryKind = .xcode) -> CleanerCategory? { latest[kind] }
}
private struct FaultingCleanerFiles: CleanerFileReading {
    let native = FoundationCleanerFiles()
    var unreadablePath: String? = nil
    var failedName: String? = nil
    var cancelName: String? = nil
    var logicalOnly = false
    var enumeratorFails = false
    func metadata(_ url: URL) throws -> CleanerFileMetadata {
        if url.lastPathComponent == failedName { throw CocoaError(.fileReadNoPermission) }
        if url.lastPathComponent == cancelName { withUnsafeCurrentTask { $0?.cancel() } }
        var result = try native.metadata(url)
        if logicalOnly { result.allocatedSize = nil; result.totalAllocatedSize = nil }
        return result
    }
    func isReadable(_ url: URL) -> Bool { url.path != unreadablePath && native.isReadable(url) }
    func enumerator(_ root: URL) -> (any CleanerEntryEnumerating)? { enumeratorFails ? nil : native.enumerator(root) }
}
private actor CleanerStubSampler: SystemSampling {
    func start() {}
    func stop() {}
    func sample() -> SystemReading { SystemReading(cpuPercent: nil, memory: nil, pressure: .unknown) }
}
private actor CleanerStubDetails: SystemDetailSampling {
    func start() {}
    func stop() {}
    func sampleDisk(now: Date) -> DiskReading { .unknown }
    func sampleBattery(now: Date) -> BatteryReading { .unknown }
    func sampleProcesses(now: Date, uptime: TimeInterval) -> ProcessReading { .unknown }
}

final class CleanerTests: XCTestCase {
    private func run(_ descriptor: CleanerDescriptor, files: any CleanerFileReading = FoundationCleanerFiles()) async -> CleanerCategory {
        let result = CleanerResults()
        let scanner = CleanerScanner(files: files)
        let task = Task { await scanner.scan([descriptor]) { await result.record($0) } }
        _ = await task.value
        return await result.value(descriptor.id)!
    }
    func testEmptyDirectoryIsAvailableZero() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        try f.directory(f.xcode.rootURL)
        let value = await run(f.xcode)
        XCTAssertEqual(value.state, .available); XCTAssertEqual(value.sizeBytes, 0)
        XCTAssertEqual(value.counters.fileCount, 0); XCTAssertEqual(value.counters.directoryCount, 0)
    }
    func testRegularFilesUseAllocatedSizeAndNestedDirectories() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let sub = f.xcode.rootURL.appendingPathComponent("nested")
        try f.directory(sub)
        let a = sub.appendingPathComponent("a"), b = f.xcode.rootURL.appendingPathComponent("b")
        try f.file(a, bytes: 100); try f.file(b, bytes: 6000)
        let native = FoundationCleanerFiles()
        let expected = try native.metadata(a).estimate!.bytes + native.metadata(b).estimate!.bytes
        let value = await run(f.xcode)
        XCTAssertEqual(value.state, .available); XCTAssertEqual(value.sizeBytes, expected)
        XCTAssertEqual(value.counters.fileCount, 2); XCTAssertEqual(value.counters.directoryCount, 1)
        XCTAssertNotNil(value.sampledAt)
    }
    func testMissingRootIsNotZeroBytes() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let value = await run(f.xcode)
        XCTAssertEqual(value.state, .notFound); XCTAssertNil(value.sizeBytes)
    }
    func testUnreadableRootIsInaccessible() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let value = await run(f.xcode, files: FaultingCleanerFiles(unreadablePath: f.xcode.rootURL.path))
        XCTAssertEqual(value.state, .inaccessible); XCTAssertNil(value.sizeBytes)
    }
    func testRootMetadataPermissionFailureIsInaccessible() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let value = await run(f.xcode, files: FaultingCleanerFiles(failedName: "DerivedData"))
        XCTAssertEqual(value.state, .inaccessible); XCTAssertNil(value.sizeBytes)
    }
    func testEnumeratorOpenFailureIsInaccessible() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let value = await run(f.xcode, files: FaultingCleanerFiles(enumeratorFails: true))
        XCTAssertEqual(value.state, .inaccessible)
    }
    func testFailedChildIsPartialAndOtherFilesCounted() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        try f.file(f.xcode.rootURL.appendingPathComponent("denied"), bytes: 5000)
        try f.file(f.xcode.rootURL.appendingPathComponent("readable"), bytes: 100)
        let value = await run(f.xcode, files: FaultingCleanerFiles(failedName: "denied"))
        XCTAssertEqual(value.state, .partial); XCTAssertEqual(value.counters.fileCount, 1)
        XCTAssertEqual(value.counters.inaccessibleCount, 1)
    }
    func testUnreadableChildDirectoryIsSkippedAndPartial() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let denied = f.xcode.rootURL.appendingPathComponent("denied")
        try f.directory(denied); try f.file(denied.appendingPathComponent("large"), bytes: 8000)
        let value = await run(f.xcode, files: FaultingCleanerFiles(unreadablePath: denied.path))
        XCTAssertEqual(value.state, .partial); XCTAssertEqual(value.sizeBytes, 0)
        XCTAssertEqual(value.counters.inaccessibleCount, 1)
    }
    func testLogicalSizeFallback() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        try f.file(f.xcode.rootURL.appendingPathComponent("a"), bytes: 113)
        let value = await run(f.xcode, files: FaultingCleanerFiles(logicalOnly: true))
        XCTAssertEqual(value.sizeBytes, 113); XCTAssertEqual(value.counters.fallbackFileCount, 1)
    }
    func testSizePreferenceRejectsInvalidValuesAndDoesNotAddSizes() {
        XCTAssertEqual(CleanerFileMetadata(allocatedSize: 2, totalAllocatedSize: 3, logicalSize: 4).estimate?.bytes, 3)
        XCTAssertEqual(CleanerFileMetadata(allocatedSize: 2, totalAllocatedSize: -1, logicalSize: 4).estimate?.bytes, 2)
        XCTAssertEqual(CleanerFileMetadata(allocatedSize: -1, logicalSize: 4).estimate?.bytes, 4)
        XCTAssertNil(CleanerFileMetadata(logicalSize: -1).estimate)
        XCTAssertFalse(CleanerFileMetadata(allocatedSize: 0, logicalSize: 4).estimate!.fallback)
    }
    func testExternalSymlinkTargetIsNeverCounted() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let external = f.home.appendingPathComponent("outside")
        try f.directory(external); try f.file(external.appendingPathComponent("large"), bytes: 9000)
        try FileManager.default.createSymbolicLink(at: f.xcode.rootURL.appendingPathComponent("link"), withDestinationURL: external)
        let value = await run(f.xcode)
        XCTAssertEqual(value.state, .available); XCTAssertEqual(value.sizeBytes, 0)
        XCTAssertEqual(value.counters.skippedSymlinkCount, 1); XCTAssertEqual(value.counters.fileCount, 0)
    }
    func testInternalSymlinkAndLoopAreNotTraversed() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let sub = f.xcode.rootURL.appendingPathComponent("nested")
        try f.directory(sub); try f.file(sub.appendingPathComponent("a"), bytes: 64)
        try FileManager.default.createSymbolicLink(at: f.xcode.rootURL.appendingPathComponent("alias"), withDestinationURL: sub)
        try FileManager.default.createSymbolicLink(at: sub.appendingPathComponent("loop"), withDestinationURL: f.xcode.rootURL)
        let value = await run(f.xcode)
        XCTAssertEqual(value.counters.fileCount, 1); XCTAssertEqual(value.counters.skippedSymlinkCount, 2)
    }
    func testRootSymlinkIsRejected() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        try f.directory(f.xcode.rootURL.deletingLastPathComponent())
        let external = f.home.appendingPathComponent("outside"); try f.directory(external)
        try f.file(external.appendingPathComponent("large"), bytes: 5000)
        try FileManager.default.createSymbolicLink(at: f.xcode.rootURL, withDestinationURL: external)
        let value = await run(f.xcode)
        XCTAssertEqual(value.state, .inaccessible); XCTAssertNil(value.sizeBytes)
        XCTAssertEqual(value.counters.skippedSymlinkCount, 1)
    }
    func testAncestorSymlinkIsRejected() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let external = f.home.appendingPathComponent("outside"); try f.directory(external.appendingPathComponent("caches"))
        try FileManager.default.createSymbolicLink(at: f.home.appendingPathComponent(".gradle"), withDestinationURL: external)
        let value = await run(f.descriptors[1])
        XCTAssertEqual(value.state, .inaccessible); XCTAssertNil(value.sizeBytes)
    }
    func testCancellationStopsTraversalAndIsNotAvailable() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        for i in 0..<200 { try f.file(f.xcode.rootURL.appendingPathComponent("\(i)"), bytes: 1) }
        // Cancellation injected during metadata read, no wall-clock sleep or real caches.
        let first = FileManager.default.enumerator(at: f.xcode.rootURL, includingPropertiesForKeys: nil)!.nextObject() as! URL
        let value = await run(f.xcode, files: FaultingCleanerFiles(cancelName: first.lastPathComponent))
        XCTAssertEqual(value.state, .cancelled); XCTAssertLessThan(value.counters.fileCount, 200)
    }
    func testSequentialCatalogSessionAndSampledSnapshot() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        for d in f.descriptors { try f.directory(d.rootURL) }
        let results = CleanerResults()
        let state = await CleanerScanner().scan(f.descriptors) { await results.record($0) }
        XCTAssertEqual(state, .available)
        for d in f.descriptors { let value = await results.value(d.id); XCTAssertEqual(value?.state, .available) }
    }
    func testCatalogPathsRisksAndNoRuntimeInstallations() throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        XCTAssertEqual(f.descriptors.map(\.relativePath), ["Library/Developer/Xcode/DerivedData", ".gradle/caches", ".m2/repository", "repository", ".npm/_cacache", "Library/Caches/Homebrew"])
        XCTAssertEqual(f.descriptors.map(\.risk), [.low, .caution, .caution, .low, .low, .low])
        for d in f.descriptors {
            if d.kind != .mavenMarkers { XCTAssertEqual(d.rootURL.path, f.home.appendingPathComponent(d.relativePath).path) }
            XCTAssertFalse(d.explanation.isEmpty); XCTAssertFalse(d.impact.isEmpty)
        }
        let paths = f.descriptors.map(\.relativePath).joined(separator: " ")
        for excluded in [".sdkman/candidates", ".pyenv/versions", ".goenv/versions", ".nvm/versions", ".docker", "Docker.raw"] {
            XCTAssertFalse(paths.contains(excluded))
        }
    }
    func testNpmDoesNotFallbackToConfigDirectory() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        try f.directory(f.home.appendingPathComponent(".npm"))
        try f.file(f.home.appendingPathComponent(".npm/config"), bytes: 100)
        let value = await run(f.descriptors.first { $0.kind == .npm }!); XCTAssertEqual(value.state, .notFound)
    }
    @MainActor func testRepeatedScanUsesOneSessionAndCanRescan() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let scanner = CleanerScanner()
        let session = CleanerSession(scanner: scanner, descriptors: [f.xcode], onSnapshot: { _ in })
        session.start(); session.start()
        await session.waitForStop()
        let starts = await scanner.starts; XCTAssertEqual(starts, 1)
        XCTAssertFalse(session.isRunning); XCTAssertEqual(session.snapshot.state, .available)
        session.start(); await session.waitForStop()
        let repeated = await scanner.starts; XCTAssertEqual(repeated, 2)
    }
    @MainActor func testSessionCancelTaskReallyEnds() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let session = CleanerSession(descriptors: [f.xcode], onSnapshot: { _ in })
        session.start(); session.cancel(); await session.waitForStop()
        XCTAssertFalse(session.isRunning); XCTAssertEqual(session.snapshot.state, .cancelled)
    }
    @MainActor func testLiveStoreDoesNotScanOnModePageOrOverviewAppearance() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let scanner = CleanerScanner()
        let store = AppStore(sampler: CleanerStubSampler(), details: CleanerStubDetails(), networkPath: FakeNetworkPath(),
            cleanerScanner: scanner, cleanerCategories: f.descriptors)
        store.setSystemMode(.live)
        let id = UUID(); store.setWindow(id, visible: true, section: .cleaner)
        store.setWindowSection(id, section: .overview)
        _ = CleanerView(); _ = OverviewView() // no provider work in View initialization
        let starts = await scanner.starts; XCTAssertEqual(starts, 0)
        XCTAssertEqual(store.snapshot.cleaner.state, .notRun)
        XCTAssertNil(store.snapshot.cleaner.estimatedBytes); XCTAssertEqual(store.snapshot.cleaner.mode, .live)
        store.setSystemMode(.preview)
    }
    @MainActor func testUserScanPublishesSharedSnapshotAndPreviewRestoresFixture() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        try f.file(f.xcode.rootURL.appendingPathComponent("a"), bytes: 4096)
        let store = AppStore(sampler: CleanerStubSampler(), details: CleanerStubDetails(), networkPath: FakeNetworkPath(), cleanerScanner: CleanerScanner(), cleanerCategories: [f.xcode])
        store.setSystemMode(.live); store.scanCleaner(); await store.waitForCleanerStop()
        XCTAssertEqual(store.snapshot.cleaner.state, .available)
        XCTAssertGreaterThan(store.snapshot.cleaner.estimatedBytes ?? 0, 0)
        XCTAssertFalse(store.cleanerRunning)
        store.setSystemMode(.preview)
        XCTAssertEqual(store.snapshot.cleaner.mode, .mock); XCTAssertNil(store.snapshot.cleaner.estimatedBytes)
        XCTAssertEqual(store.snapshot.cleanerItems, MockProvider(fixture: .healthy).snapshot(now: Date()).cleanerItems)
    }
    @MainActor func testPreviewSwitchCancelsAndRejectsLateScanSnapshot() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let store = AppStore(sampler: CleanerStubSampler(), details: CleanerStubDetails(), networkPath: FakeNetworkPath(), cleanerScanner: CleanerScanner(), cleanerCategories: [f.xcode])
        store.setSystemMode(.live); store.scanCleaner(); store.setSystemMode(.preview)
        await store.waitForCleanerStop()
        XCTAssertEqual(store.snapshot.cleaner.mode, .mock); XCTAssertEqual(store.snapshot.cleaner.state, .notRun)
        XCTAssertFalse(store.cleanerRunning)
    }
    @MainActor func testRapidPreviewLiveDoesNotRestoreOldCancelledCycle() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let store = AppStore(sampler: CleanerStubSampler(), details: CleanerStubDetails(), networkPath: FakeNetworkPath(), cleanerScanner: CleanerScanner(), cleanerCategories: [f.xcode])
        store.setSystemMode(.live); store.scanCleaner()
        store.setSystemMode(.preview); store.setSystemMode(.live)
        await store.waitForCleanerStop()
        XCTAssertEqual(store.snapshot.cleaner.mode, .live)
        XCTAssertEqual(store.snapshot.cleaner.state, .notRun)
        XCTAssertNil(store.snapshot.cleaner.estimatedBytes)
        store.setSystemMode(.preview)
    }
    @MainActor func testSleepCancelsWithoutAutomaticWakeRescan() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let scanner = CleanerScanner()
        let store = AppStore(sampler: CleanerStubSampler(), details: CleanerStubDetails(), networkPath: FakeNetworkPath(),
                             cleanerScanner: scanner, cleanerCategories: [f.xcode])
        store.setSystemMode(.live); store.scanCleaner(); store.suspendForSleep()
        await store.waitForCleanerStop()
        XCTAssertEqual(store.snapshot.cleaner.state, .cancelled); XCTAssertFalse(store.cleanerRunning)
        store.resumeAfterWake()
        let starts = await scanner.starts; XCTAssertEqual(starts, 1)
        store.setSystemMode(.preview)
    }
    func testScannerDoesNotModifyFilesOrTimestamps() async throws {
        let f = try CleanerFixture(); defer { f.cleanup() }; try f.directory(f.xcode.rootURL)
        let file = f.xcode.rootURL.appendingPathComponent("a"); try f.file(file, bytes: 64)
        let before = try FileManager.default.attributesOfItem(atPath: file.path)
        _ = await run(f.xcode)
        XCTAssertEqual(try Data(contentsOf: file), Data(repeating: 42, count: 64))
        let after = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual(before[.modificationDate] as? Date, after[.modificationDate] as? Date)
        XCTAssertEqual(before[.posixPermissions] as? Int, after[.posixPermissions] as? Int)
    }
    func testCleanerPresentationBothLanguagesAndIncompleteSemantics() throws {
        let f = try CleanerFixture(); defer { f.cleanup() }
        let zh = MacSoulLanguage.chinese, en = MacSoulLanguage.english
        for state in [CleanerScanState.notRun, .scanning, .available, .notFound, .cancelled, .inaccessible, .partial, .failed] {
            XCTAssertNotEqual(zh.cleanerText(state.label), state.label)
        }
        for key in ["Scan", "Rescan", "Cancel scan", "Read only", "Low risk", "Caution", "High risk", "Reveal in Finder", "Copy path", "Path copied"] {
            XCTAssertNotEqual(zh.cleanerText(key), key); XCTAssertEqual(en.cleanerText(key), key)
        }
        for d in f.descriptors {
            XCTAssertNotEqual(zh.cleanerText(d.name), d.name)
            XCTAssertNotEqual(zh.cleanerText(d.explanation), d.explanation)
            XCTAssertNotEqual(zh.cleanerText(d.impact), d.impact)
        }
        var snapshot = CleanerSnapshot.live(categories: [f.xcode])
        XCTAssertEqual(zh.cleanerSummary(snapshot), "未扫描")
        snapshot.state = .cancelled; snapshot.categories[0].state = .cancelled
        snapshot.categories[0].counters.sizeBytes = 1_073_741_824
        XCTAssertTrue(zh.cleanerSummary(snapshot).contains("未完成的估算"))
        XCTAssertTrue(en.cleanerSummary(snapshot).contains("Incomplete estimate"))
        snapshot.state = .available
        XCTAssertTrue(zh.cleanerSummary(snapshot).contains("估算占用空间"))
        XCTAssertFalse(zh.cleanerSummary(snapshot).contains("可释放"))
    }
}
