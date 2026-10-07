import Foundation

protocol ShellRunning {
    func run(_ command: ShellCommand) async throws -> ShellResult
}
extension ShellRunner: ShellRunning {}

enum DevCollectionState: Equatable {
    case sampling, available, empty, notFound, unresolved, timeout, failed, parseFailed
}

struct RuntimeContext: Equatable, Identifiable {
    let source: String
    let path: String?
    let version: String?
    let state: DevCollectionState
    let sampledAt: Date
    var id: String { source + (path ?? "") }
}

struct RuntimeRecord: Equatable, Identifiable {
    let name: String
    let contexts: [RuntimeContext]
    var id: String { name }
    var primary: RuntimeContext? { contexts.first { $0.state == .available } }
    var status: DevCollectionState {
        if primary != nil { return .available }
        if contexts.contains(where: { $0.state == .timeout }) { return .timeout }
        if contexts.contains(where: { $0.state == .failed || $0.state == .parseFailed }) { return .failed }
        if contexts.contains(where: { $0.state == .unresolved }) { return .unresolved }
        return .notFound
    }
    var hasMismatch: Bool { Set(contexts.compactMap { $0.version }).count > 1 }
}

struct RuntimeReading: Equatable {
    let state: DevCollectionState
    let records: [RuntimeRecord]
    let sampledAt: Date?
    let freshness: Freshness
    static let sampling = RuntimeReading(state: .sampling, records: [], sampledAt: nil, freshness: .unavailable)
}

struct ListeningPort: Hashable, Identifiable {
    let port: Int
    let pid: Int32
    let process: String
    let bind: String
    let sampledAt: Date
    var id: String { "\(pid):\(port):\(bind)" }
}

struct LogicalListener: Hashable, Identifiable {
    struct Key: Hashable {
        let pid: Int32
        let process: String
        let port: Int
    }
    let id: Key
    let bindAddresses: [String]
    var port: Int { id.port }
    var pid: Int32 { id.pid }
    var process: String { id.process }
    // Port numbers and PIDs are identifiers; SwiftUI must receive a String rather than format an Int.
    var overviewSummary: String { "\(port) · \(process) · PID \(pid)" }
}

struct PortReading: Equatable {
    let state: DevCollectionState
    let items: [ListeningPort]
    let sampledAt: Date?
    static let sampling = PortReading(state: .sampling, items: [], sampledAt: nil)

    var allListeners: [LogicalListener] {
        var binds: [LogicalListener.Key: [String]] = [:]
        for item in items {
            let key = LogicalListener.Key(pid: item.pid, process: item.process, port: item.port)
            if binds[key]?.contains(item.bind) != true { binds[key, default: []].append(item.bind) }
        }
        return binds.map { LogicalListener(id: $0.key, bindAddresses: $0.value) }
            .sorted { lhs, rhs in
                if lhs.port != rhs.port { return lhs.port < rhs.port }
                if lhs.pid != rhs.pid { return lhs.pid < rhs.pid }
                return lhs.process < rhs.process
            }
    }

    var developerListeners: [LogicalListener] {
        allListeners.filter { DeveloperProcessClassifier.isDeveloperProcess($0.process) }
    }

    var overviewListeners: [LogicalListener] { Array(developerListeners.prefix(3)) }
}

struct DevCadence {
    static let visible: TimeInterval = 10
    static let background: TimeInterval = 60
    static let runtimeTTL: TimeInterval = 300
    private(set) var lastPortSample: TimeInterval?
    mutating func reset() { lastPortSample = nil }
    mutating func portsDue(at now: TimeInterval, visible: Bool) -> Bool {
        let interval = visible ? Self.visible : Self.background
        guard lastPortSample.map({ now - $0 < interval }) != true else { return false }
        lastPortSample = now
        return true
    }
    mutating func markPortsSampled(at now: TimeInterval) { lastPortSample = now }
    func nextDelay(at now: TimeInterval, visible: Bool, lastRuntimeSample: TimeInterval?) -> TimeInterval {
        let portDue = (lastPortSample ?? now) + (visible ? Self.visible : Self.background)
        let runtimeDue = (lastRuntimeSample ?? now) + Self.runtimeTTL
        return max(0.01, min(portDue, runtimeDue) - now)
    }
}

enum ExecutableResolver {
    static func resolve(_ name: String, path: String, fileManager: FileManager = .default) -> URL? {
        guard !name.isEmpty, !name.contains("/") else { return nil }
        var seen = Set<String>()
        for entry in path.split(separator: ":", omittingEmptySubsequences: false) {
            // Empty and relative PATH entries would search the current working directory.
            guard entry.first == "/" else { continue }
            let directory = URL(fileURLWithPath: String(entry)).standardizedFileURL
            let url = directory.appendingPathComponent(name).resolvingSymlinksInPath()
            guard seen.insert(url.path).inserted else { continue }
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
               fileManager.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }

    static func explicit(_ path: String, fileManager: FileManager = .default) -> URL? {
        guard path.first == "/" else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true &&
            fileManager.isExecutableFile(atPath: url.path) ? url : nil
    }
}

enum RuntimeVersionParser {
    static func parse(_ name: String, stdout: String, stderr: String) -> String? {
        let text = stdout + "\n" + stderr
        let pattern: String
        switch name {
        case "Java": pattern = #"(?:openjdk|java) version\s+"([0-9][^"\s]*)""#
        case "Node": pattern = #"\bv([0-9]+(?:\.[0-9]+){1,2})\b"#
        case "Python": pattern = #"\bPython\s+([0-9]+(?:\.[0-9]+){1,2})\b"#
        case "Go": pattern = #"\bgo version go([0-9]+(?:\.[0-9]+){1,2})\b"#
        default: return nil
        }
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}

actor RuntimeDetector {
    private let runner: any ShellRunning
    private let environment: [String: String]
    private let home: URL
    private let uptime: () -> TimeInterval
    private var cached: RuntimeReading?
    private var cacheUptime: TimeInterval?

    init(runner: any ShellRunning = ShellRunner(),
         environment: [String: String] = ProcessInfo.processInfo.environment,
         home: URL = FileManager.default.homeDirectoryForCurrentUser,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.runner = runner; self.environment = environment; self.home = home; self.uptime = uptime
    }

    func detect(refresh: Bool = false) async -> RuntimeReading {
        let now = uptime()
        if !refresh, let cached, let cacheUptime, now - cacheUptime < DevCadence.runtimeTTL { return cached }
        let sampledAt = Date()
        var records: [RuntimeRecord] = []
        for name in ["Java", "Node", "Python", "Go"] {
            if Task.isCancelled { return .sampling }
            var contexts: [RuntimeContext] = []
            var candidates = candidates(for: name)
            if name == "Java", candidates.allSatisfy({ $0.url == nil }) {
                candidates.append(await javaHomeCandidate())
            }
            var resolved: [String: (DevCollectionState, String?)] = [:]
            for candidate in candidates {
                if Task.isCancelled { return .sampling }
                guard let url = candidate.url else {
                    contexts.append(RuntimeContext(source: candidate.source, path: nil, version: nil,
                                                   state: candidate.state, sampledAt: sampledAt))
                    continue
                }
                let state: DevCollectionState
                let version: String?
                if let prior = resolved[url.path] {
                    (state, version) = prior
                } else {
                    do {
                        let result = try await runner.run(ShellCommand(executableURL: url, arguments: candidate.arguments,
                                                                       timeout: 4, stdoutLimit: 64 * 1024, stderrLimit: 64 * 1024))
                        if result.outputTruncated { state = .parseFailed; version = nil }
                        else if let parsed = RuntimeVersionParser.parse(name, stdout: result.stdout, stderr: result.stderr) {
                            version = parsed; state = .available
                        } else { state = .parseFailed; version = nil }
                    } catch ShellRunnerError.timeout { state = .timeout; version = nil }
                    catch ShellRunnerError.cancelled { return .sampling }
                    catch { state = .failed; version = nil }
                    resolved[url.path] = (state, version)
                }
                contexts.append(RuntimeContext(source: candidate.source, path: url.path, version: version,
                                               state: state, sampledAt: sampledAt))
            }
            if contexts.isEmpty {
                contexts = [RuntimeContext(source: "Current detection context", path: nil,
                                           version: nil, state: .notFound, sampledAt: sampledAt)]
            }
            records.append(RuntimeRecord(name: name, contexts: contexts))
        }
        let reading = RuntimeReading(state: .available, records: records, sampledAt: sampledAt, freshness: .fresh)
        cached = reading; cacheUptime = uptime()
        return reading
    }

    private struct Candidate {
        let source: String
        let url: URL?
        let state: DevCollectionState
        let arguments: [String]
    }

    private func candidates(for name: String) -> [Candidate] {
        let executable = name == "Java" ? "java" : name == "Node" ? "node" : name == "Python" ? "python3" : "go"
        let arguments = name == "Java" ? ["-version"] : name == "Go" ? ["version"] : ["--version"]
        var result: [Candidate] = []
        func add(_ source: String, _ path: String?) {
            guard let path else { return }
            let url = ExecutableResolver.explicit(path)
            result.append(Candidate(source: source, url: url, state: url == nil ? .notFound : .available, arguments: arguments))
        }
        let pathURL = ExecutableResolver.resolve(executable, path: environment["PATH"] ?? "")
        // For Python/Go a shim is a pointer to a version manager, not the final runtime.
        let isShim = (name == "Python" && pathURL?.path.contains("/.pyenv/shims/") == true)
            || (name == "Go" && pathURL?.path.contains("/.goenv/shims/") == true)
        if isShim { result.append(Candidate(source: "Process PATH shim", url: nil, state: .unresolved, arguments: arguments)) }
        else if let pathURL { add("Process PATH", pathURL.path) }

        switch name {
        case "Java":
            add("SDKMAN current", home.appendingPathComponent(".sdkman/candidates/java/current/bin/java").path)
            if let javaHome = environment["JAVA_HOME"], javaHome.first == "/" {
                add("JAVA_HOME", URL(fileURLWithPath: javaHome).appendingPathComponent("bin/java").path)
            }
        case "Node":
            if let bin = environment["NVM_BIN"], bin.first == "/" {
                add("NVM_BIN", URL(fileURLWithPath: bin).appendingPathComponent("node").path)
            }
            let alias = readSelection(home.appendingPathComponent(".nvm/alias/default"))
            if let alias {
                let version = alias.hasPrefix("v") ? String(alias.dropFirst()) : alias
                if version.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil {
                    add("NVM default", home.appendingPathComponent(".nvm/versions/node/v\(version)/bin/node").path)
                } else { result.append(Candidate(source: "NVM default alias", url: nil, state: .unresolved, arguments: arguments)) }
            }
        case "Python":
            let root = environment["PYENV_ROOT"].flatMap { $0.first == "/" ? URL(fileURLWithPath: $0) : nil } ?? home.appendingPathComponent(".pyenv")
            let selection = environment["PYENV_VERSION"] ?? readSelection(root.appendingPathComponent("version"))
            if let selection, selection.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil, selection != "system" {
                add(environment["PYENV_VERSION"] == nil ? "pyenv global" : "PYENV_VERSION", root.appendingPathComponent("versions/\(selection)/bin/python3").path)
            }
        case "Go":
            let root = environment["GOENV_ROOT"].flatMap { $0.first == "/" ? URL(fileURLWithPath: $0) : nil } ?? home.appendingPathComponent(".goenv")
            let selection = environment["GOENV_VERSION"] ?? readSelection(root.appendingPathComponent("version"))
            if let selection, selection.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil, selection != "system" {
                add(environment["GOENV_VERSION"] == nil ? "goenv global" : "GOENV_VERSION", root.appendingPathComponent("versions/\(selection)/bin/go").path)
            }
            if let goroot = environment["GOROOT"], goroot.first == "/" {
                add("GOROOT", URL(fileURLWithPath: goroot).appendingPathComponent("bin/go").path)
            }
        default: break
        }
        return result
    }

    private func javaHomeCandidate() async -> Candidate {
        let arguments: [String] = ["-version"]
        do {
            let result = try await runner.run(ShellCommand(executableURL: URL(fileURLWithPath: "/usr/libexec/java_home"),
                                                           arguments: [], timeout: 4, stdoutLimit: 4096, stderrLimit: 4096))
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, !result.outputTruncated else {
                return Candidate(source: "macOS java_home", url: nil, state: .notFound, arguments: arguments)
            }
            let url = ExecutableResolver.explicit(URL(fileURLWithPath: path).appendingPathComponent("bin/java").path)
            return Candidate(source: "macOS java_home", url: url,
                             state: url == nil ? .notFound : .available, arguments: arguments)
        } catch ShellRunnerError.timeout {
            return Candidate(source: "macOS java_home", url: nil, state: .timeout, arguments: arguments)
        } catch {
            return Candidate(source: "macOS java_home", url: nil, state: .notFound, arguments: arguments)
        }
    }

    private func readSelection(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 257), data.count <= 256,
              let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
