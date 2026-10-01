import XCTest
import AppKit
@testable import MacSoul

private actor FakeDevRunner: ShellRunning {
    var calls: [String] = []
    var responses: [String: Result<ShellResult, ShellRunnerError>] = [:]
    func set(_ path: String, stdout: String = "", stderr: String = "") {
        responses[path] = .success(ShellResult(stdout: stdout, stderr: stderr, exitCode: 0,
                                               terminationReason: .exit, outputTruncated: false, duration: 0))
    }
    func fail(_ path: String, _ error: ShellRunnerError) { responses[path] = .failure(error) }
    func count() -> Int { calls.count }
    func run(_ command: ShellCommand) async throws -> ShellResult {
        calls.append(command.executableURL.path)
        return try responses[command.executableURL.path]?.get() ?? ShellResult(
            stdout: "", stderr: "", exitCode: 0, terminationReason: .exit,
            outputTruncated: false, duration: 0)
    }
}

private final class MutableDevClock {
    var value: TimeInterval = 0
}

final class DevEnvironmentTests: XCTestCase {
    func testGracefulStopCommandUsesCurrentPID() {
        XCTAssertEqual(PortCommands.gracefulStopCommand(pid: 71217), "kill -TERM 71217")
        XCTAssertEqual(PortCommands.gracefulStopCommand(pid: 1), "kill -TERM 1")
        XCTAssertEqual(PortCommands.gracefulStopCommand(pid: .max), "kill -TERM 2147483647")
    }

    func testGracefulStopCommandRejectsInvalidPIDs() {
        for pid in [Int32(0), -1, .min] {
            XCTAssertNil(PortCommands.gracefulStopCommand(pid: pid))
        }
    }

    func testStopClipboardActionWritesCommandAndRejectsInvalidPID() async {
        await MainActor.run {
            let pasteboard = NSPasteboard.withUniqueName()
            defer { pasteboard.releaseGlobally() }
            XCTAssertTrue(PortCommands.copyGracefulStopCommand(pid: 71217, to: pasteboard))
            XCTAssertEqual(pasteboard.string(forType: .string), "kill -TERM 71217")
            // Invalid identifiers do not erase an existing clipboard value.
            XCTAssertFalse(PortCommands.copyGracefulStopCommand(pid: 0, to: pasteboard))
            XCTAssertFalse(PortCommands.copyGracefulStopCommand(pid: -1, to: pasteboard))
            XCTAssertEqual(pasteboard.string(forType: .string), "kill -TERM 71217")
        }
    }

    func testGracefulStopCommandContainsOnlySIGTERMandDecimalPID() throws {
        // The API accepts an Int32, so process names or shell syntax cannot enter it.
        for pid in [Int32(1), 71217, .max] {
            let command = try XCTUnwrap(PortCommands.gracefulStopCommand(pid: pid))
            XCTAssertNotNil(command.range(of: #"^kill -TERM [1-9][0-9]*$"#, options: .regularExpression))
            XCTAssertFalse(command.contains("sudo"))
            XCTAssertFalse(command.contains("SIGKILL"))
            XCTAssertFalse(command.contains("-9"))
            XCTAssertFalse(command.contains("$"))
            XCTAssertFalse(command.contains("`"))
            XCTAssertFalse(command.contains(";"))
            XCTAssertFalse(command.contains("\n"))
        }
    }

    private func temporaryHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }
    private func fakeExecutable(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: Data("fake".utf8)))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    func testLiteralArgumentsAndOutputStreams() async throws {
        let result = try await ShellRunner().run(ShellCommand(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["$HOME", "$(touch /tmp/should-not-exist)", "; rm -rf *", "`date`"] ))
        XCTAssertEqual(result.stdout, "$HOME $(touch /tmp/should-not-exist) ; rm -rf * `date`\n")
        XCTAssertEqual(result.stderr, "")
        XCTAssertFalse(result.outputTruncated)
    }

    func testMissingAndNonZeroExitRetainDiagnosticCategory() async {
        do {
            _ = try await ShellRunner().run(ShellCommand(executableURL: URL(fileURLWithPath: "/not/a/real/program"), arguments: []))
            XCTFail("missing executable should fail")
        } catch ShellRunnerError.executableNotFound {} catch { XCTFail("\(error)") }
        do {
            _ = try await ShellRunner().run(ShellCommand(executableURL: URL(fileURLWithPath: "/bin/ls"), arguments: ["/not/a/real/path"]))
            XCTFail("non-zero exit should fail")
        } catch ShellRunnerError.nonZeroExit(let code, _, let stderr) {
            XCTAssertNotEqual(code, 0)
            XCTAssertFalse(stderr.isEmpty)
        } catch { XCTFail("\(error)") }
    }

    func testExecutableLaunchFailureIsSeparateFromMissing() async throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let invalid = home.appendingPathComponent("not-a-binary")
        try fakeExecutable(invalid)
        do {
            _ = try await ShellRunner().run(ShellCommand(executableURL: invalid, arguments: []))
            XCTFail("invalid executable should not launch")
        } catch ShellRunnerError.launchFailure {} catch { XCTFail("\(error)") }
    }

    func testBoundedStdoutAndStderr() async throws {
        let stdout = try await ShellRunner().run(ShellCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/seq"), arguments: ["1", "10000"], stdoutLimit: 32))
        XCTAssertTrue(stdout.outputTruncated)
        XCTAssertLessThanOrEqual(stdout.stdout.utf8.count, 32)
        let stderr = try await ShellRunner().run(ShellCommand(
            executableURL: URL(fileURLWithPath: "/bin/dd"),
            arguments: ["if=/dev/zero", "of=/dev/stderr", "bs=1024", "count=16"], stderrLimit: 32))
        XCTAssertTrue(stderr.outputTruncated)
        XCTAssertLessThanOrEqual(stderr.stderr.utf8.count, 32)
    }

    func testTimeoutAndCancellationReturnPromptly() async {
        let command = ShellCommand(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.1)
        let start = ProcessInfo.processInfo.systemUptime
        do { _ = try await ShellRunner().run(command); XCTFail() }
        catch ShellRunnerError.timeout {} catch { XCTFail("\(error)") }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 2)
        let task = Task {
            try await ShellRunner().run(ShellCommand(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"]))
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()
        do { _ = try await task.value; XCTFail() }
        catch ShellRunnerError.cancelled {} catch { XCTFail("\(error)") }
    }

    func testTimeoutCancellationRaceCompletesEachTaskOnce() async {
        let tasks = (0..<5).map { _ in
            Task {
                try await ShellRunner().run(ShellCommand(executableURL: URL(fileURLWithPath: "/bin/sleep"),
                                                       arguments: ["5"], timeout: 0.05))
            }
        }
        try? await Task.sleep(nanoseconds: 40_000_000)
        for task in tasks { task.cancel() }
        for task in tasks {
            do { _ = try await task.value; XCTFail() }
            catch ShellRunnerError.cancelled {} catch ShellRunnerError.timeout {}
            catch { XCTFail("\(error)") }
        }
    }

    func testExecutableResolverSkipsEmptyRelativeDuplicateAndNonExecutable() throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let first = home.appendingPathComponent("first/tool")
        let second = home.appendingPathComponent("second/tool")
        try fakeExecutable(first); try fakeExecutable(second)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: first.path)
        let path = ":relative:\(home.appendingPathComponent("first").path):\(home.appendingPathComponent("second").path):\(home.appendingPathComponent("second").path)"
        XCTAssertEqual(ExecutableResolver.resolve("tool", path: path)?.path, second.path)
        XCTAssertNil(ExecutableResolver.resolve("../tool", path: path))
        XCTAssertNil(ExecutableResolver.explicit(home.appendingPathComponent("second").path))
    }

    func testVersionParsers() {
        XCTAssertEqual(RuntimeVersionParser.parse("Java", stdout: "", stderr: "java version \"1.8.0_472\""), "1.8.0_472")
        XCTAssertEqual(RuntimeVersionParser.parse("Java", stdout: "openjdk version \"21.0.2\"", stderr: ""), "21.0.2")
        XCTAssertEqual(RuntimeVersionParser.parse("Node", stdout: "v18.20.8", stderr: ""), "18.20.8")
        XCTAssertEqual(RuntimeVersionParser.parse("Node", stdout: "v20.1.0", stderr: ""), "20.1.0")
        XCTAssertEqual(RuntimeVersionParser.parse("Python", stdout: "Python 3.12.0", stderr: ""), "3.12.0")
        XCTAssertEqual(RuntimeVersionParser.parse("Go", stdout: "go version go1.23.2 darwin/arm64", stderr: ""), "1.23.2")
        XCTAssertNil(RuntimeVersionParser.parse("Java", stdout: "garbage", stderr: ""))
    }

    func testRuntimeSourcesConflictCacheExpiryAndRefresh() async throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let javaPATH = home.appendingPathComponent("gui/java")
        let sdkJava = home.appendingPathComponent(".sdkman/candidates/java/current/bin/java")
        let pyenv = home.appendingPathComponent(".pyenv/versions/3.12.0/bin/python3")
        let nvm = home.appendingPathComponent(".nvm/versions/node/v18.20.8/bin/node")
        let goenv = home.appendingPathComponent(".goenv/versions/1.23.2/bin/go")
        for url in [javaPATH, sdkJava, pyenv, nvm, goenv] { try fakeExecutable(url) }
        for (relative, content) in [(".pyenv/version", "3.12.0"), (".nvm/alias/default", "v18.20.8"), (".goenv/version", "1.23.2")] {
            let url = home.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        let runner = FakeDevRunner()
        await runner.set(javaPATH.path, stderr: "openjdk version \"17.0.1\"")
        await runner.set(sdkJava.path, stderr: "java version \"1.8.0_472\"")
        await runner.set(pyenv.path, stdout: "Python 3.12.0")
        await runner.set(nvm.path, stdout: "v18.20.8")
        await runner.set(goenv.path, stdout: "go version go1.23.2 darwin/arm64")
        let clock = MutableDevClock()
        let detector = RuntimeDetector(runner: runner, environment: ["PATH": home.appendingPathComponent("gui").path],
                                       home: home, uptime: { clock.value })
        let first = await detector.detect()
        XCTAssertEqual(first.records.count, 4)
        XCTAssertTrue(first.records[0].hasMismatch)
        XCTAssertEqual(first.records[0].contexts.map(\.source), ["Process PATH", "SDKMAN current"])
        XCTAssertEqual(first.records[1].primary?.source, "NVM default")
        XCTAssertEqual(first.records[2].primary?.source, "pyenv global")
        XCTAssertEqual(first.records[3].primary?.source, "goenv global")
        let calls = await runner.count()
        _ = await detector.detect()
        let cachedCalls = await runner.count()
        XCTAssertEqual(cachedCalls, calls)
        _ = await detector.detect(refresh: true)
        let refreshedCalls = await runner.count()
        XCTAssertGreaterThan(refreshedCalls, calls)
        let refreshed = await runner.count()
        clock.value = 301
        _ = await detector.detect()
        let expiredCalls = await runner.count()
        XCTAssertGreaterThan(expiredCalls, refreshed)
    }

    func testUnresolvedNvmAliasAndRuntimeTimeoutRemainDistinct() async throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let alias = home.appendingPathComponent(".nvm/alias/default")
        try FileManager.default.createDirectory(at: alias.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "lts/*".write(to: alias, atomically: true, encoding: .utf8)
        let java = home.appendingPathComponent("gui/java"); try fakeExecutable(java)
        let runner = FakeDevRunner(); await runner.fail(java.path, .timeout)
        let reading = await RuntimeDetector(runner: runner, environment: ["PATH": home.appendingPathComponent("gui").path], home: home).detect()
        XCTAssertEqual(reading.records[0].status, .timeout)
        XCTAssertEqual(reading.records[1].status, .unresolved)
        XCTAssertEqual(reading.records[1].contexts[0].source, "NVM default alias")
    }

    func testMacOSJavaHomeFallbackUsesSafeRunner() async throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let java = home.appendingPathComponent("jdk/bin/java"); try fakeExecutable(java)
        let runner = FakeDevRunner()
        await runner.set("/usr/libexec/java_home", stdout: home.appendingPathComponent("jdk").path + "\n")
        await runner.set(java.path, stderr: "openjdk version \"21.0.1\"")
        let records = await RuntimeDetector(runner: runner, environment: ["PATH": ""], home: home).detect().records
        XCTAssertEqual(records[0].primary?.source, "macOS java_home")
        XCTAssertEqual(records[0].primary?.version, "21.0.1")
    }

    func testEnvironmentOverridesAreSeparateDetectionContexts() async throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let java = home.appendingPathComponent("jdk/bin/java")
        let node = home.appendingPathComponent("nvm-bin/node")
        let python = home.appendingPathComponent(".pyenv/versions/3.11.9/bin/python3")
        let go = home.appendingPathComponent(".goenv/versions/1.22.0/bin/go")
        let goroot = home.appendingPathComponent("goroot/bin/go")
        for url in [java, node, python, go, goroot] { try fakeExecutable(url) }
        let runner = FakeDevRunner()
        await runner.set(java.path, stderr: "openjdk version \"21.0.1\"")
        await runner.set(node.path, stdout: "v20.0.0")
        await runner.set(python.path, stdout: "Python 3.11.9")
        await runner.set(go.path, stdout: "go version go1.22.0 darwin/arm64")
        await runner.set(goroot.path, stdout: "go version go1.23.0 darwin/arm64")
        let env = ["PATH": "", "JAVA_HOME": home.appendingPathComponent("jdk").path,
                   "NVM_BIN": home.appendingPathComponent("nvm-bin").path,
                   "PYENV_VERSION": "3.11.9", "GOENV_VERSION": "1.22.0",
                   "GOROOT": home.appendingPathComponent("goroot").path]
        let records = await RuntimeDetector(runner: runner, environment: env, home: home).detect().records
        XCTAssertEqual(records[0].primary?.source, "JAVA_HOME")
        XCTAssertEqual(records[1].primary?.source, "NVM_BIN")
        XCTAssertEqual(records[2].primary?.source, "PYENV_VERSION")
        XCTAssertEqual(records[3].primary?.source, "GOENV_VERSION")
        XCTAssertEqual(records[3].contexts.map(\.source), ["GOENV_VERSION", "GOROOT"])
        XCTAssertTrue(records[3].hasMismatch)
    }

    func testMissingRuntimeAndMalformedVersionAreNotAvailable() async throws {
        let home = try temporaryHome(); defer { try? FileManager.default.removeItem(at: home) }
        let node = home.appendingPathComponent("bin/node"); try fakeExecutable(node)
        let runner = FakeDevRunner(); await runner.set(node.path, stdout: "not a version")
        let records = await RuntimeDetector(runner: runner, environment: ["PATH": home.appendingPathComponent("bin").path], home: home).detect().records
        XCTAssertEqual(records[1].status, .failed)
        XCTAssertEqual(records[1].contexts.first?.state, .parseFailed)
        XCTAssertEqual(records[2].status, .notFound)
    }

    func testLsofIPv4IPv6WildcardDedupeAndMalformed() {
        XCTAssertEqual(LsofParser.endpoint("127.0.0.1:8080")?.port, 8080)
        XCTAssertEqual(LsofParser.endpoint("*:3000")?.bind, "*")
        XCTAssertEqual(LsofParser.endpoint("[::1]:8080")?.bind, "::1")
        XCTAssertEqual(LsofParser.endpoint("[::]:8080")?.bind, "::")
        XCTAssertNil(LsofParser.endpoint("[::1]:service"))
        let output = "p123\ncnode\nf4\nn127.0.0.1:8080\nf5\nn127.0.0.1:8080\nf6\nn[::1]:8080\n"
        let ports = LsofParser.parse(output, sampledAt: Date())
        XCTAssertEqual(ports?.count, 2)
        XCTAssertEqual(ports?.first?.pid, 123)
        XCTAssertEqual(ports?.first?.process, "node")
        XCTAssertNil(LsofParser.parse("pnot-a-pid\n", sampledAt: Date()))
        XCTAssertNil(LsofParser.parse("p123\ncnode\nf4\nnbad\n", sampledAt: Date()))
    }

    func testListeningPortSummaryKeepsIdentifiersUngrouped() {
        let item = LogicalListener(id: .init(pid: 8299, process: "Apifox", port: 4523),
                                   bindAddresses: ["127.0.0.1"])
        XCTAssertEqual(item.overviewSummary, "4523 · Apifox · PID 8299")
        let upper = LogicalListener(id: .init(pid: 58727, process: "node", port: 65535),
                                    bindAddresses: ["*"])
        XCTAssertEqual(upper.overviewSummary, "65535 · node · PID 58727")
    }

    func testDeveloperListenerClassificationIsConservativeAndSharedWithProcesses() {
        for name in ["java", "node", "python3", "go", "swiftc", "xcodebuild", "gradle", "mvn",
                     "idea", "Xcode", "Apifox", "ApifoxAppAgent", "Lingma", "com.docker.backend",
                     "mysql", "mysqld", "postgres", "redis-server", "nginx"] {
            XCTAssertTrue(DeveloperProcessClassifier.isDeveloperProcess(name), name)
        }
        for name in ["WeChat", "DingTalk", "wpscloudsvr", "ControlCenter", "ASM"] {
            XCTAssertFalse(DeveloperProcessClassifier.isDeveloperProcess(name), name)
        }
    }

    func testFilteredAndAllListenersShareOneRawSnapshotAndFoldOnlyMatchingKeys() async {
        let runner = FakeDevRunner()
        await runner.set(PortDetector.executableURL.path, stdout:
            "p100\ncjava\nf4\nn127.0.0.1:8080\nf5\nn[::1]:8080\nf6\nn127.0.0.1:8081\n" +
            "p101\ncWeChat\nf4\nn127.0.0.1:8080\n" +
            "p102\ncnode\nf4\nn*:8080\n")
        let reading = await PortDetector(runner: runner).detect()
        XCTAssertEqual(reading.items.count, 5) // Raw IPv4/IPv6 socket records remain intact.
        XCTAssertEqual(reading.allListeners.count, 4)
        XCTAssertEqual(reading.developerListeners.count, 3)
        XCTAssertTrue(reading.allListeners.contains { $0.process == "WeChat" })
        XCTAssertFalse(reading.developerListeners.contains { $0.process == "WeChat" })
        let java = reading.developerListeners.first { $0.pid == 100 && $0.port == 8080 }
        XCTAssertEqual(java?.bindAddresses, ["127.0.0.1", "::1"])
        XCTAssertTrue(reading.developerListeners.contains { $0.pid == 100 && $0.port == 8081 })
        XCTAssertTrue(reading.developerListeners.contains { $0.pid == 102 && $0.port == 8080 })
        let callCount = await runner.count()
        XCTAssertEqual(callCount, 1) // Presentation never starts a second lsof.
    }

    func testOverviewShowsAtMostThreeDeveloperListeners() {
        let names = ["java", "node", "python3", "go", "WeChat"]
        let items = names.enumerated().map { index, name in
            ListeningPort(port: 8000 + index, pid: Int32(100 + index), process: name,
                          bind: "127.0.0.1", sampledAt: Date())
        }
        let reading = PortReading(state: .available, items: items, sampledAt: Date())
        XCTAssertEqual(reading.developerListeners.count, 4)
        XCTAssertEqual(reading.overviewListeners.count, 3)
        XCTAssertFalse(reading.overviewListeners.contains { $0.process == "WeChat" })
        XCTAssertEqual(reading.developerListeners.count - reading.overviewListeners.count, 1)
    }

    func testLsofEmptyFailureAndTimeout() async {
        let runner = FakeDevRunner()
        await runner.fail(PortDetector.executableURL.path, .nonZeroExit(1, stdout: "", stderr: ""))
        let empty = await PortDetector(runner: runner).detect()
        XCTAssertEqual(empty.state, .empty)
        await runner.fail(PortDetector.executableURL.path, .nonZeroExit(1, stdout: "", stderr: "denied"))
        let failed = await PortDetector(runner: runner).detect()
        XCTAssertEqual(failed.state, .failed)
        await runner.fail(PortDetector.executableURL.path, .timeout)
        let timeout = await PortDetector(runner: runner).detect()
        XCTAssertEqual(timeout.state, .timeout)
        await runner.set(PortDetector.executableURL.path, stdout: "p123\ncnode\nf4\nn*:3000\n")
        let success = await PortDetector(runner: runner).detect()
        XCTAssertEqual(success.state, .available)
        XCTAssertEqual(success.items.first?.port, 3000)
        await runner.set(PortDetector.executableURL.path, stdout: "p123\ncnode\nf4\nnbad\n")
        let malformed = await PortDetector(runner: runner).detect()
        XCTAssertEqual(malformed.state, .parseFailed)
    }

    func testCadenceAndPreviewLiveBoundary() async {
        var cadence = DevCadence()
        XCTAssertTrue(cadence.portsDue(at: 0, visible: false))
        XCTAssertFalse(cadence.portsDue(at: 10, visible: false))
        XCTAssertTrue(cadence.portsDue(at: 60, visible: false))
        XCTAssertFalse(cadence.portsDue(at: 65, visible: true))
        XCTAssertTrue(cadence.portsDue(at: 70, visible: true))
        cadence.markPortsSampled(at: 75)
        XCTAssertFalse(cadence.portsDue(at: 80, visible: true))
        await MainActor.run {
            let store = AppStore()
            XCTAssertEqual(store.snapshot.devMode, .mock)
            XCTAssertFalse(store.snapshot.runtimes.isEmpty)
            store.setSystemMode(.live)
            XCTAssertEqual(store.snapshot.devMode, .live)
            XCTAssertTrue(store.snapshot.runtimes.isEmpty)
            XCTAssertTrue(store.snapshot.ports.isEmpty)
            XCTAssertEqual(store.snapshot.runtimeReading?.state, .sampling)
            XCTAssertEqual(store.snapshot.portReading?.state, .sampling)
            XCTAssertEqual(store.devStarts, 1)
            let id = UUID()
            for _ in 0..<5 {
                store.setWindow(id, visible: true, section: .dev)
                XCTAssertEqual(store.devPortInterval, 10)
                store.setWindow(id, visible: false, section: .dev)
            }
            XCTAssertEqual(store.devStarts, 1)
            XCTAssertEqual(store.devPortInterval, 60)
            store.setSystemMode(.preview)
            XCTAssertEqual(store.snapshot.devMode, .mock)
            XCTAssertFalse(store.snapshot.runtimes.isEmpty)
        }
    }
}
