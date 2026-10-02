import XCTest
import Darwin
@testable import MacSoul

private struct LocatorFixture {
    let home: URL
    init() throws {
        let candidate = FileManager.default.temporaryDirectory.appendingPathComponent("CleanerLocator-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
        let ptr = candidate.path.withCString { realpath($0, nil) }!
        home = URL(fileURLWithPath: String(cString: ptr)); free(ptr)
    }
    func directory(_ path: String) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func tool(_ name: String) throws -> URL {
        let url = try directory("bin").appendingPathComponent(name)
        try Data("test fixture only".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
    var environment: [String: String] { ["PATH":home.appendingPathComponent("bin").path] }
    func cleanup() { try? FileManager.default.removeItem(at: home) }
}
private actor LocatorRunner: CleanerCommandRunning {
    var commands: [[String]] = []
    var stdout = ""
    var truncated = false
    var failure: ShellRunnerError?
    var context = "desktop-local"
    var endpoint = "unix:///test/docker.sock"
    var dockerOutput = ""
    var holdDocker = false
    var dockerStarted = false
    func output(_ value: String, truncated: Bool = false) { stdout = value; self.truncated = truncated }
    func fail(_ value: ShellRunnerError) { failure = value }
    func configureDocker(context: String = "desktop-local", endpoint: String = "unix:///test/docker.sock", output: String, hold: Bool = false) {
        self.context = context; self.endpoint = endpoint; dockerOutput = output; holdDocker = hold
    }
    func calls() -> [[String]] { commands }
    func started() -> Bool { dockerStarted }
    func run(_ command: ShellCommand) async throws -> ShellResult {
        commands.append(command.arguments)
        let args = command.arguments
        let text: String
        if args == ["context", "show"] { text = context }
        else if args.contains("inspect") { text = String(data: try JSONSerialization.data(withJSONObject: endpoint, options: .fragmentsAllowed), encoding: .utf8)! }
        else if args.contains("df") {
            dockerStarted = true
            if holdDocker {
                // Tests reuse the actual ShellRunner cancellation path on an owned child only.
                return try await ShellRunner().run(ShellCommand(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"], timeout: 2))
            }
            if let failure { throw failure }
            text = dockerOutput
        } else {
            if let failure { throw failure }
            text = stdout
        }
        XCTAssertLessThanOrEqual(command.timeout, 5)
        XCTAssertLessThanOrEqual(command.stdoutLimit, 65536)
        return ShellResult(stdout: text, stderr: "", exitCode: 0, terminationReason: .exit, outputTruncated: truncated, duration: 0)
    }
}
private func dockerFixture(_ sizes: [String] = ["2GB", "100MB", "300MB", "400MB"]) -> String {
    zip(DockerStorageKind.allCases, sizes).map { kind, size in
        "{\"Type\":\"\(kind.rawValue)\",\"Size\":\"\(size)\",\"Reclaimable\":\"0B (0%)\"}"
    }.joined(separator: "\n")
}
private func shellFixture(_ text: String, truncated: Bool = false) -> ShellResult {
    ShellResult(stdout: text, stderr: "", exitCode: 0, terminationReason: .exit, outputTruncated: truncated, duration: 0)
}
private actor LocatedCategoryResult {
    var value: CleanerCategory?
    func set(_ value: CleanerCategory) { self.value = value }
    func get() -> CleanerCategory? { value }
}

final class CleanerDiscoveryTests: XCTestCase {
    func testGradleEnvironmentResolvesCachesChild() throws {
        let f = try LocatorFixture(); defer { f.cleanup() }
        let root = try f.directory("custom-gradle/caches")
        let result = GradleHomeLocator(home: f.home, environment: ["GRADLE_USER_HOME":root.deletingLastPathComponent().path]).resolveCache()
        XCTAssertEqual(result.url?.path, root.path); XCTAssertEqual(result.source, .gradleEnvironment); XCTAssertEqual(result.state, .resolved)
    }
    func testGradleDefaultIsExplicitFallback() throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; let root = try f.directory(".gradle/caches")
        let result = GradleHomeLocator(home: f.home, environment: [:]).resolveCache()
        XCTAssertEqual(result.url?.path, root.path); XCTAssertEqual(result.source, .gradleDefault); XCTAssertTrue(result.source.isFallback)
    }
    func testGradleMissingIsNotFound() throws {
        let f = try LocatorFixture(); defer { f.cleanup() }
        XCTAssertEqual(GradleHomeLocator(home: f.home, environment: [:]).resolveCache().state, .notFound)
    }
    func testGradleRelativeOverrideIsNotGuessed() throws {
        let f = try LocatorFixture(); defer { f.cleanup() }
        let r = GradleHomeLocator(home: f.home, environment: ["GRADLE_USER_HOME":"relative"]).resolveCache()
        XCTAssertNil(r.url); XCTAssertEqual(r.state, .unresolved)
    }
    func testNPMExplicitCacheUsesOnlyDownloadChildWithoutCLI() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; let root = try f.directory("npm-cache/_cacache")
        let runner = LocatorRunner()
        let env = ["NPM_CONFIG_CACHE":root.deletingLastPathComponent().path]
        let r = await NPMCacheLocator(home: f.home, environment: env, executables: .init(environment: [:], includeKnownLocations: false), runner: runner).resolveCache()
        XCTAssertEqual(r.url?.path, root.path); XCTAssertEqual(r.source, .npmEnvironment)
        let calls = await runner.calls(); XCTAssertTrue(calls.isEmpty)
    }
    func testNPMLowercaseEnvironmentPrecedence() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; let root = try f.directory("lower/_cacache")
        let env = ["npm_config_cache":root.deletingLastPathComponent().path,"NPM_CONFIG_CACHE":"/wrong"]
        let r = await NPMCacheLocator(home: f.home, environment: env, executables: .init(environment: [:], includeKnownLocations: false), runner: LocatorRunner()).resolveCache()
        XCTAssertEqual(r.url?.path, root.path)
    }
    func testNPMMockedConfigDiscovery() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("npm"); let root = try f.directory("configured/_cacache")
        let runner = LocatorRunner(); await runner.output(root.deletingLastPathComponent().path + "\n")
        let r = await NPMCacheLocator(home: f.home, environment: f.environment, executables: .init(environment: f.environment, includeKnownLocations: false), runner: runner).resolveCache()
        XCTAssertEqual(r.source, .npmConfig); XCTAssertEqual(r.url?.path, root.path)
        let calls = await runner.calls(); XCTAssertEqual(calls, [["config","get","cache"]])
    }
    func testNPMMissingExecutableUsesLabeledDefault() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; let root = try f.directory(".npm/_cacache")
        let r = await NPMCacheLocator(home: f.home, environment: [:], executables: .init(environment: [:], includeKnownLocations: false), runner: LocatorRunner()).resolveCache()
        XCTAssertEqual(r.url?.path, root.path); XCTAssertEqual(r.source, .npmDefault); XCTAssertTrue(r.source.isFallback)
    }
    func testNPMMalformedAndTruncatedOutputNeverScansFallback() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("npm")
        let runner = LocatorRunner(), locator = NPMCacheLocator(home: f.home, environment: f.environment, executables: .init(environment: f.environment, includeKnownLocations: false), runner: LocatorRunner())
        // A relative/empty mocked response cannot become an arbitrary filesystem root.
        let bad = await locator.resolveCache(); XCTAssertEqual(bad.state, .unresolved); XCTAssertNil(bad.url)
        await runner.output("/valid", truncated: true)
        let truncated = await NPMCacheLocator(home: f.home, environment: f.environment, executables: .init(environment: f.environment, includeKnownLocations: false), runner: runner).resolveCache()
        XCTAssertEqual(truncated.state, .unresolved)
    }
    func testHomebrewMockedCacheQuery() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("brew"); let root = try f.directory("brew-cache")
        let runner = LocatorRunner(); await runner.output(root.path)
        let r = await HomebrewCacheLocator(home: f.home, executables: .init(environment: f.environment, includeKnownLocations: false), runner: runner).resolveCache()
        XCTAssertEqual(r.source, .brewCLI); XCTAssertEqual(r.url?.path, root.path)
        let calls = await runner.calls(); XCTAssertEqual(calls, [["--cache"]])
    }
    func testHomebrewUnavailableExecutableFallsBackHonestly() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }
        let r = await HomebrewCacheLocator(home: f.home, executables: .init(environment: [:], includeKnownLocations: false), runner: LocatorRunner()).resolveCache()
        XCTAssertEqual(r.source, .brewDefault); XCTAssertTrue(r.source.isFallback); XCTAssertEqual(r.state, .notFound)
    }
    func testHomebrewMalformedOutputRemainsUnresolved() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("brew"); let runner = LocatorRunner(); await runner.output("/one\n/two")
        let r = await HomebrewCacheLocator(home: f.home, executables: .init(environment: f.environment, includeKnownLocations: false), runner: runner).resolveCache()
        XCTAssertEqual(r.state, .unresolved); XCTAssertNil(r.url)
    }
    func testEveryCategoryHasSourceAndMavenSharesResolvedRoot() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }
        let r = await CleanerLocator(home: f.home, environment: [:], runner: LocatorRunner(), includeKnownLocations: false).resolve(CleanerCatalog.categories(home: f.home))
        XCTAssertTrue(r.allSatisfy { $0.resolution != nil && $0.resolution!.source.isFallback })
        XCTAssertEqual(r.first { $0.kind == .maven }?.resolution, r.first { $0.kind == .mavenMarkers }?.resolution)
        XCTAssertEqual(r.first { $0.kind == .xcode }?.resolution?.source, .xcodeDefault)
    }
    func testDiscoveryOnlyNeverInvokesTools() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; for name in ["npm","brew","docker"] { _ = try f.tool(name) }
        let runner = LocatorRunner()
        _ = await CleanerLocator(home: f.home, environment: f.environment, runner: runner, includeKnownLocations: false).resolve(CleanerCatalog.categories(home: f.home), allowCLI: false)
        let calls = await runner.calls(); XCTAssertTrue(calls.isEmpty)
    }
    func testWholeHomeRuntimeAndDockerVMPathsAreRejected() throws {
        let f = try LocatorFixture(); defer { f.cleanup() }
        for path in [f.home.path, "/", f.home.appendingPathComponent(".sdkman/candidates").path,
                     f.home.appendingPathComponent("Library/Containers/com.docker.docker/Data").path,
                     f.home.appendingPathComponent("cache/Docker.raw").path] {
            let r = CleanerPathResolution.resolve(path, home: f.home, source: .npmConfig)
            XCTAssertEqual(r.state, .unresolved); XCTAssertNil(r.url)
        }
    }
    func testDockerCLIUnavailableIsNotZeroUsage() async {
        let r = await DockerCleanerAdapter(environment: [:], runner: LocatorRunner(), includeKnownLocations: false).collect()
        XCTAssertEqual(r.state, .cliNotFound); XCTAssertNil(r.totalBytes)
    }
    func testDockerEngineUnavailableIsNotZeroUsage() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.fail(.nonZeroExit(1, stdout: "", stderr: "private diagnostic not retained"))
        let r = await DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false).collect()
        XCTAssertEqual(r.state, .engineUnavailable); XCTAssertNotNil(r.executable); XCTAssertNil(r.totalBytes)
    }
    func testDockerMachineJSONMapsAllFourCategories() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.configureDocker(output: dockerFixture())
        let r = await DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false).collect()
        XCTAssertEqual(r.state, .available); XCTAssertEqual(r.usage.map(\.kind), DockerStorageKind.allCases)
        XCTAssertEqual(r.totalBytes, 2_800_000_000); XCTAssertEqual(r.localTotalBytes, r.totalBytes)
        let calls = await runner.calls()
        XCTAssertEqual(calls.last, ["--context","desktop-local","system","df","--format","{{json .}}"])
        XCTAssertTrue(calls.allSatisfy { !$0.contains("prune") && !$0.contains("rm") && !$0.contains("rmi") && !$0.contains("-c") })
    }
    func testRemoteDockerContextIsExcludedAndNotQueried() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.configureDocker(endpoint: "ssh://dev@example.invalid", output: dockerFixture())
        let r = await DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false).collect()
        XCTAssertEqual(r.state, .remoteContext); XCTAssertFalse(r.isLocal); XCTAssertNil(r.localTotalBytes)
        let calls = await runner.calls(); XCTAssertFalse(calls.contains { $0.contains("df") })
    }
    func testDockerHostOverrideRemoteDoesNotUseDefaultLocalContext() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        var env = f.environment; env["DOCKER_HOST"] = "tcp://127.0.0.1:2375"
        let r = await DockerCleanerAdapter(environment: env, runner: runner, includeKnownLocations: false).collect()
        XCTAssertEqual(r.state, .remoteContext); let calls = await runner.calls(); XCTAssertTrue(calls.isEmpty)
    }
    func testDockerContextOverridesHostEnvironment() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner(); await runner.configureDocker(output: dockerFixture())
        var env = f.environment; env["DOCKER_HOST"] = "tcp://example.invalid:2375"; env["DOCKER_CONTEXT"] = "desktop-local"
        let r = await DockerCleanerAdapter(environment: env, runner: runner, includeKnownLocations: false).collect()
        XCTAssertTrue(r.isLocal); XCTAssertEqual(r.state, .available)
    }
    func testDockerLocalSummaryAddsParentOnlyOnce() {
        var s = CleanerSnapshot(state: .available)
        s.docker = DockerCleanerResult(state: .available, isLocal: true, usage: DockerStorageParser.parse(shellFixture(dockerFixture()))!)
        XCTAssertEqual(s.estimatedBytes, 2_800_000_000); XCTAssertEqual(s.foundCount, 1)
        s.docker?.isLocal = false; XCTAssertNil(s.estimatedBytes); XCTAssertEqual(s.foundCount, 0)
        s.docker?.isLocal = true
        s.docker?.usage = Array(repeating: DockerStorageUsage(kind: .images, bytes: 100, reclaimableBytes: nil), count: 4)
        XCTAssertNil(s.estimatedBytes) // duplicate logical categories cannot be summed
    }
    func testMalformedDuplicateMissingAndTruncatedDockerResponsesFail() {
        for text in ["human table", "{}", dockerFixture(["-1GB","0B","0B","0B"]), dockerFixture() + "\n" + dockerFixture(), dockerFixture().replacingOccurrences(of: "Containers", with: "Images")] {
            XCTAssertNil(DockerStorageParser.parse(shellFixture(text)))
        }
        XCTAssertNil(DockerStorageParser.parse(shellFixture(dockerFixture(), truncated: true)))
    }
    func testDockerSizeUsesDecimalSIAndRejectsOverflow() {
        XCTAssertEqual(DockerStorageParser.bytes("2.8GB"), 2_800_000_000)
        XCTAssertEqual(DockerStorageParser.bytes("0B"), 0); XCTAssertEqual(DockerStorageParser.bytes("126kB"), 126000)
        for v in ["1GiB", "-1B", "NaNGB", "99999999999999999PB", "1GB;anything"] { XCTAssertNil(DockerStorageParser.bytes(v)) }
    }
    func testDockerEmptyReclaimableDoesNotCrash() {
        let input = dockerFixture().replacingOccurrences(of: "0B (0%)", with: "")
        XCTAssertTrue(DockerStorageParser.parse(shellFixture(input))!.allSatisfy { $0.reclaimableBytes == nil })
    }
    func testOnlyUnixEndpointsAreLocal() {
        XCTAssertTrue(DockerStorageParser.isLocalEndpoint("unix:///custom/socket"))
        for endpoint in ["tcp://localhost:2375", "ssh://localhost", "unix://remote/socket", "garbage"] { XCTAssertFalse(DockerStorageParser.isLocalEndpoint(endpoint)) }
    }
    func testDockerCancellationUsesOwnedShellRunnerChild() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.configureDocker(output: dockerFixture(), hold: true)
        let task = Task { await DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false).collect() }
        for _ in 0..<10000 { if await runner.started() { break }; await Task.yield() }
        task.cancel()
        let r = await task.value; XCTAssertEqual(r.state, .cancelled); XCTAssertNil(r.totalBytes)
    }
    func testNewSourcesAndDockerStatesAreLocalized() {
        for source in [CleanerResolutionSource.xcodeDefault,.gradleDefault,.npmEnvironment,.npmConfig,.npmDefault,.brewDefault] {
            XCTAssertNotEqual(MacSoulLanguage.chinese.cleanerText(source.label), source.label)
        }
        XCTAssertEqual(MacSoulLanguage.chinese.cleanerText(DockerCleanerState.cliNotFound.label), "未发现 Docker CLI")
        XCTAssertTrue(MacSoulLanguage.chinese.cleanerText(DockerCleanerState.remoteContext.label).contains("远程"))
    }
    func testScannerUsesResolvedGradleRootInsteadOfDefaultCandidate() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; let root = try f.directory("custom/caches")
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("fixture"))
        let locator = CleanerLocator(home: f.home, environment: ["GRADLE_USER_HOME":root.deletingLastPathComponent().path], runner: LocatorRunner(), includeKnownLocations: false)
        let recorder = LocatedCategoryResult()
        let descriptors = CleanerCatalog.categories(home: f.home).filter { $0.kind == .gradle }
        _ = await CleanerScanner(locator: locator).scan(descriptors) { await recorder.set($0) }
        let result = await recorder.get()
        XCTAssertEqual(result?.state, .available); XCTAssertEqual(result?.rootURL.path, root.path)
        XCTAssertEqual(result?.counters.fileCount, 1); XCTAssertEqual(result?.descriptor.resolution?.source, .gradleEnvironment)
    }
    @MainActor func testDockerPublishesThroughSingleSharedCleanerSession() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.configureDocker(output: dockerFixture())
        var snapshots: [CleanerSnapshot] = []
        let session = CleanerSession(scanner: CleanerScanner(docker: DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false)), descriptors: []) { snapshots.append($0) }
        session.start(); session.start(); await session.waitForStop()
        XCTAssertEqual(snapshots.last?.docker?.state, .available)
        XCTAssertEqual(snapshots.last?.estimatedBytes, 2_800_000_000)
        let calls = await runner.calls(); XCTAssertEqual(calls.filter { $0.contains("df") }.count, 1)
        XCTAssertFalse(session.isRunning)
    }
    func testInvalidDockerEndpointDoesNotClaimRemoteOrQueryUsage() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.configureDocker(endpoint: "invalid", output: dockerFixture())
        let result = await DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false).collect()
        XCTAssertEqual(result.state, .contextUnavailable)
        let calls = await runner.calls(); XCTAssertFalse(calls.contains { $0.contains("df") })
    }
    func testMalformedDockerQueryResultIsFailedNotAvailableZero() async throws {
        let f = try LocatorFixture(); defer { f.cleanup() }; _ = try f.tool("docker"); let runner = LocatorRunner()
        await runner.configureDocker(output: "unsupported")
        let result = await DockerCleanerAdapter(environment: f.environment, runner: runner, includeKnownLocations: false).collect()
        XCTAssertEqual(result.state, .failed); XCTAssertNil(result.totalBytes)
    }
}
