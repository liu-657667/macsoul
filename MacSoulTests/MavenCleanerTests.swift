import XCTest
import Darwin
@testable import MacSoul

private struct MavenFixture {
    let home: URL
    init() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MacSoulMavenTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let ptr = url.path.withCString { realpath($0, nil) }!
        home = URL(fileURLWithPath: String(cString: ptr)); free(ptr)
    }
    func mkdir(_ url: URL) throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    func write(_ text: String, to url: URL) throws {
        try mkdir(url.deletingLastPathComponent()); try Data(text.utf8).write(to: url)
    }
    var settings: URL { home.appendingPathComponent(".m2/settings.xml") }
    var repo: URL { home.appendingPathComponent(".m2/repository") }
    func locate(_ env: [String: String] = [:]) -> MavenDiscovery { MavenRepositoryLocator(home: home, environment: env).discover() }
    func cleanup() { try? FileManager.default.removeItem(at: home) }
}
private actor MavenResults {
    var values: [CleanerCategoryKind: CleanerCategory] = [:]
    func record(_ value: CleanerCategory) { values[value.id] = value }
    func all() -> [CleanerCategory] { Array(values.values) }
}
final class MavenCleanerTests: XCTestCase {
    func testUserSettingsCustomRootWithoutMvn() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let custom = f.home.appendingPathComponent("custom-repo"); try f.mkdir(custom)
        try f.write("<settings><localRepository>\(custom.path)</localRepository></settings>", to: f.settings)
        let d = f.locate()
        XCTAssertEqual(d.location.url?.path, custom.path); XCTAssertEqual(d.location.source, .userSettings)
        XCTAssertEqual(d.location.state, .resolved); XCTAssertNil(d.executable)
    }
    func testUserHomeExpansionAndWhitespace() throws {
        let f = try MavenFixture(); defer { f.cleanup() }; try f.mkdir(f.home.appendingPathComponent("custom"))
        try f.write("<settings><localRepository> ${user.home}/custom </localRepository></settings>", to: f.settings)
        XCTAssertEqual(f.locate().location.url?.path, f.home.appendingPathComponent("custom").path)
    }
    func testGlobalSettingsAfterUserWithoutRepository() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let install = f.home.appendingPathComponent("maven-install"), custom = f.home.appendingPathComponent("custom")
        try f.mkdir(custom); try f.write("<settings/>", to: f.settings)
        try f.write("<settings><localRepository>\(custom.path)</localRepository></settings>", to: install.appendingPathComponent("conf/settings.xml"))
        let d = f.locate(["M2_HOME": install.path])
        XCTAssertEqual(d.location.source, .globalSettings); XCTAssertEqual(d.location.url?.path, custom.path)
        XCTAssertEqual(d.mavenHome?.path, install.path); XCTAssertNotEqual(d.location.url, install)
    }
    func testUserSettingsWinsOverGlobal() throws {
        let f = try MavenFixture(); defer { f.cleanup() }; try f.mkdir(f.repo)
        let install = f.home.appendingPathComponent("maven")
        try f.write("<settings><localRepository>\(f.repo.path)</localRepository></settings>", to: f.settings)
        try f.write("<settings><localRepository>/other</localRepository></settings>", to: install.appendingPathComponent("conf/settings.xml"))
        XCTAssertEqual(f.locate(["MAVEN_HOME": install.path]).location.source, .userSettings)
    }
    func testMalformedSettingsIsExplicitUnresolvedNoGuessedFallback() throws {
        let f = try MavenFixture(); defer { f.cleanup() }; try f.mkdir(f.repo)
        try f.write("<settings><localRepository>", to: f.settings)
        let value = f.locate().location
        XCTAssertEqual(value.state, .unresolved); XCTAssertEqual(value.source, .userSettings); XCTAssertNil(value.url)
    }
    func testUnknownPropertyAndRelativePathAreUnresolved() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        for value in ["${unknown}/repo", "relative/repo"] {
            try f.write("<settings><localRepository>\(value)</localRepository></settings>", to: f.settings)
            XCTAssertEqual(f.locate().location.state, .unresolved)
        }
    }
    func testDefaultExistingAndMissingWithoutExecutable() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        XCTAssertEqual(f.locate().location.state, .notFound)
        try f.mkdir(f.repo)
        let d = f.locate(); XCTAssertEqual(d.location.state, .resolved)
        XCTAssertEqual(d.location.source, .defaultLocation); XCTAssertEqual(d.location.url, f.repo)
        XCTAssertNil(d.executable)
    }
    func testSettingsIsBoundedAndRejectsEntities() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        for xml in [String(repeating: " ", count: 65537), "<!DOCTYPE settings [<!ENTITY repo SYSTEM 'file:///private'>]><settings><localRepository>&repo;</localRepository></settings>"] {
            try f.write(xml, to: f.settings); XCTAssertEqual(f.locate().location.state, .unresolved)
        }
    }
    func testCredentialsAndProfileRepositoryNeverEnterDiscoveryResult() throws {
        let f = try MavenFixture(); defer { f.cleanup() }; try f.mkdir(f.repo)
        try f.write("<settings><servers><server><password>SENSITIVE</password></server></servers><profiles><profile><localRepository>/wrong</localRepository></profile></profiles></settings>", to: f.settings)
        let d = f.locate()
        XCTAssertEqual(d.location.source, .defaultLocation)
        XCTAssertFalse(String(describing: d).contains("SENSITIVE"))
    }
    func testUnsafeWholeHomeRuntimeRootsAndRootSymlinkRejected() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        for path in ["/", f.home.path, f.home.appendingPathComponent(".nvm/versions").path] {
            try f.write("<settings><localRepository>\(path)</localRepository></settings>", to: f.settings)
            XCTAssertEqual(f.locate().location.state, .unresolved)
        }
        try f.mkdir(f.home.appendingPathComponent("other"))
        try FileManager.default.createSymbolicLink(at: f.repo, withDestinationURL: f.home.appendingPathComponent("other"))
        try f.write("<settings/>", to: f.settings)
        XCTAssertEqual(f.locate().location.state, .unavailable)
    }
    func testSettingsSymlinkIsNotRead() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let other = f.home.appendingPathComponent("private-configuration")
        try f.write("<settings/>", to: other); try f.mkdir(f.settings.deletingLastPathComponent())
        try FileManager.default.createSymbolicLink(at: f.settings, withDestinationURL: other)
        XCTAssertEqual(f.locate().location.state, .unavailable)
    }
    private func scan(_ f: MavenFixture) async -> [CleanerCategory] {
        let result = MavenResults()
        let scanner = CleanerScanner(mavenLocator: MavenRepositoryLocator(home: f.home, environment: [:]))
        let descriptors = CleanerCatalog.categories(home: f.home).filter { $0.kind == .maven || $0.kind == .mavenMarkers }
        _ = await scanner.scan(descriptors) { await result.record($0) }
        return await result.all()
    }
    func testNestedMarkersOnlyAndParentChildNoDoubleCount() async throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let dir = f.repo.appendingPathComponent("nested/artifact")
        for name in ["x.lastUpdated", "y.lastUpdated", "x.jar", "x.pom", "_remote.repositories", "maven-metadata.xml"] {
            try f.write("fixture", to: dir.appendingPathComponent(name))
        }
        let results = await scan(f), repository = results.first { $0.id == .maven }!, marker = results.first { $0.id == .mavenMarkers }!
        XCTAssertEqual(repository.counters.fileCount, 6); XCTAssertEqual(marker.counters.fileCount, 2)
        XCTAssertEqual(repository.rootURL, marker.rootURL); XCTAssertEqual(marker.rootURL, f.repo)
        XCTAssertEqual(repository.descriptor.risk, .caution); XCTAssertEqual(marker.descriptor.risk, .low)
        XCTAssertFalse(marker.descriptor.contributesToTotalEstimate)
        let summary = CleanerSnapshot(mode: .live, state: .available, categories: results)
        XCTAssertEqual(summary.estimatedBytes, repository.sizeBytes)
        XCTAssertNotNil(marker.sampledAt)
    }
    func testNoMarkersIsAvailableZeroNotMissing() async throws {
        let f = try MavenFixture(); defer { f.cleanup() }; try f.write("jar", to: f.repo.appendingPathComponent("x.jar"))
        let marker = await scan(f).first { $0.id == .mavenMarkers }!
        XCTAssertEqual(marker.state, .available); XCTAssertEqual(marker.sizeBytes, 0); XCTAssertEqual(marker.counters.fileCount, 0)
    }
    func testMissingRepositoryMarksBothNotFound() async throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let results = await scan(f)
        XCTAssertEqual(results.count, 2); XCTAssertTrue(results.allSatisfy { $0.state == .notFound && $0.sizeBytes == nil })
    }
    func testMarkerDirectoryAndFileSymlinksOutsideRootAreSkipped() async throws {
        let f = try MavenFixture(); defer { f.cleanup() }; try f.mkdir(f.repo)
        let other = f.home.appendingPathComponent("outside")
        try f.write("private", to: other.appendingPathComponent("external.lastUpdated"))
        try FileManager.default.createSymbolicLink(at: f.repo.appendingPathComponent("link"), withDestinationURL: other)
        try FileManager.default.createSymbolicLink(at: f.repo.appendingPathComponent("alias.lastUpdated"), withDestinationURL: other.appendingPathComponent("external.lastUpdated"))
        let marker = await scan(f).first { $0.id == .mavenMarkers }!
        XCTAssertEqual(marker.counters.fileCount, 0); XCTAssertEqual(marker.sizeBytes, 0)
        XCTAssertEqual(marker.counters.skippedSymlinkCount, 2)
    }
    func testRepositoryLinkedAncestorIsUnavailable() throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let target = f.home.appendingPathComponent("outside")
        try f.mkdir(target.appendingPathComponent("repo"))
        let link = f.home.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try f.write("<settings><localRepository>\(link.path)/repo</localRepository></settings>", to: f.settings)
        XCTAssertEqual(f.locate().location.state, .unavailable)
    }
    func testMarkerSizeShowsSmallBytesWithoutGiBRounding() {
        XCTAssertEqual(MacSoulLanguage.english.cleanerMarkerBytes(128), "128 bytes")
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerMarkerBytes(0), "0 字节")
        XCTAssertTrue(MacSoulLanguage.english.cleanerMarkerBytes(126 * 1024).contains("126.00 KiB"))
    }
    func testUnresolvedRepositoryCopyIsLocalized() {
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerText("Repository path unresolved"), "仓库路径未解析")
        XCTAssertEqual(MacSoulLanguage.english.cleanerText("Repository path unresolved"), "Repository path unresolved")
    }
    func testConfiguredMavenRootFlowsToBothDescriptors() async throws {
        let f = try MavenFixture(); defer { f.cleanup() }
        let custom = f.home.appendingPathComponent("custom"); try f.mkdir(custom)
        try f.write("<settings><localRepository>${user.home}/custom</localRepository></settings>", to: f.settings)
        let results = await scan(f)
        XCTAssertTrue(results.allSatisfy { $0.rootURL.path == custom.path && $0.descriptor.mavenLocation?.source == .userSettings })
    }
}
