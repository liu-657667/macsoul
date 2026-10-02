import Foundation

enum DockerCleanerState: String, Sendable {
    case notRun, checking, available, cliNotFound, contextUnavailable, engineUnavailable, remoteContext, failed, cancelled
    var label: String {
        switch self {
        case .notRun: "Docker not queried"
        case .checking: "Querying Docker…"
        case .available: "Complete"
        case .cliNotFound: "Docker CLI not found"
        case .contextUnavailable: "Docker context unavailable"
        case .engineUnavailable: "CLI detected · Docker Engine unavailable or query failed"
        case .remoteContext: "Remote Docker Context · excluded from local total"
        case .failed: "Docker response unsupported or invalid"
        case .cancelled: "Cancelled"
        }
    }
}
enum DockerStorageKind: String, CaseIterable, Sendable {
    case images = "Images", containers = "Containers", volumes = "Local Volumes", buildCache = "Build Cache"
}
struct DockerStorageUsage: Equatable, Sendable {
    let kind: DockerStorageKind
    let bytes: Int64
    let reclaimableBytes: Int64?
}
struct DockerCleanerResult: Equatable, Sendable {
    var state: DockerCleanerState = .notRun
    var executable: URL?
    var context: String?
    var isLocal = false
    var usage: [DockerStorageUsage] = []
    var sampledAt: Date?
    var totalBytes: Int64? {
        guard state == .available, usage.count == DockerStorageKind.allCases.count,
              Set(usage.map(\.kind)) == Set(DockerStorageKind.allCases) else { return nil }
        var total: Int64 = 0
        for row in usage { let next = total.addingReportingOverflow(row.bytes); guard !next.overflow else { return nil }; total = next.partialValue }
        return total
    }
    var localTotalBytes: Int64? { isLocal ? totalBytes : nil }
}
enum DockerStorageParser {
    // Docker's Go-template JSON contains formatted decimal SI sizes, not raw allocated bytes.
    static func bytes(_ value: String) -> Int64? {
        let pattern = #"^([0-9]+(?:\.[0-9]+)?)\s*(B|kB|KB|MB|GB|TB|PB)$"#
        guard let match = value.range(of: pattern, options: .regularExpression), match == value.startIndex..<value.endIndex else { return nil }
        let trimmed = value.replacingOccurrences(of: " ", with: "")
        let unit = String(trimmed.suffix(2))
        let exponent = ["kB":1, "KB":1, "MB":2, "GB":3, "TB":4, "PB":5][unit] ?? 0
        let number = String(trimmed.dropLast(exponent == 0 ? 1 : 2))
        guard let size = Double(number), size.isFinite else { return nil }
        let bytes = size * pow(1000, Double(exponent))
        guard bytes >= 0, bytes < Double(Int64.max) else { return nil }
        return Int64(bytes.rounded(.down))
    }
    static func parse(_ result: ShellResult) -> [DockerStorageUsage]? {
        guard !result.outputTruncated, result.exitCode == 0, result.stdout.utf8.count <= 65536 else { return nil }
        let lines = result.stdout.split(whereSeparator: \.isNewline)
        guard lines.count == DockerStorageKind.allCases.count else { return nil }
        var rows: [DockerStorageKind: DockerStorageUsage] = [:]
        for line in lines {
            guard let data = String(line).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["Type"] as? String, let kind = DockerStorageKind(rawValue: type), rows[kind] == nil,
                  let size = json["Size"] as? String, let count = bytes(size) else { return nil }
            let reclaimable = (json["Reclaimable"] as? String).flatMap {  $0.split(separator: "(", maxSplits: 1).first.flatMap { bytes(String($0).trimmingCharacters(in: .whitespaces)) } }
            rows[kind] = .init(kind: kind, bytes: count, reclaimableBytes: reclaimable)
        }
        return DockerStorageKind.allCases.compactMap { rows[$0] }
    }
    static func isLocalEndpoint(_ value: String) -> Bool {
        // TCP/SSH, including loopback tunnels, cannot prove that storage belongs to this Mac.
        guard let url = URL(string: value), url.scheme == "unix", (url.host ?? "").isEmpty,
              url.path.hasPrefix("/"), !url.path.isEmpty, url.user == nil, url.password == nil else { return false }
        return true
    }
}
struct DockerCleanerAdapter: Sendable {
    let executables: CleanerExecutables
    let runner: any CleanerCommandRunning
    let environment: [String: String]
    init(environment: [String: String] = ProcessInfo.processInfo.environment, runner: any CleanerCommandRunning = CleanerShellRunner(), includeKnownLocations: Bool = true) {
        self.environment = environment; self.runner = runner
        executables = CleanerExecutables(environment: environment, includeKnownLocations: includeKnownLocations)
    }
    // CLI calls occur only inside the explicit Cleaner scan session.
    func collect() async -> DockerCleanerResult {
        var value = DockerCleanerResult(state: .checking, executable: executables.find("docker"))
        guard let executable = value.executable else { value.state = .cliNotFound; return value }
        func query(_ args: [String], limit: Int = 4096) async throws -> ShellResult {
            try Task.checkCancellation()
            return try await runner.run(ShellCommand(executableURL: executable, arguments: args, timeout: 5, stdoutLimit: limit, stderrLimit: 4096))
        }
        let selector: [String]
        let endpoint: String
        do {
            if let host = environment["DOCKER_HOST"], !host.isEmpty,
               (environment["DOCKER_CONTEXT"] ?? "").isEmpty {
                endpoint = host; value.context = "DOCKER_HOST"; selector = ["--host", host]
            } else {
                let shown = try await query(["context", "show"])
                let context = shown.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                guard shown.exitCode == 0, !shown.outputTruncated, context.utf8.count <= 128,
                      context.range(of: #"^[A-Za-z0-9][A-Za-z0-9_.-]*$"#, options: .regularExpression) != nil else {
                    value.state = .contextUnavailable; return value
                }
                value.context = context
                let inspected = try await query(["context", "inspect", context, "--format", "{{json .Endpoints.docker.Host}}"])
                guard inspected.exitCode == 0, !inspected.outputTruncated, let data = inspected.stdout.data(using: .utf8),
                      let host = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? String else {
                    value.state = .contextUnavailable; return value
                }
                endpoint = host; selector = ["--context", context] // freeze the observed context for this query
            }
        } catch {
            value.state = Task.isCancelled || (error as? ShellRunnerError) == .cancelled ? .cancelled : .contextUnavailable
            return value
        }
        value.isLocal = DockerStorageParser.isLocalEndpoint(endpoint)
        guard value.isLocal else {
            let remote = URL(string: endpoint).map { ["tcp", "ssh", "http", "https"].contains($0.scheme ?? "") && !($0.host ?? "").isEmpty } ?? false
            value.state = remote ? .remoteContext : .contextUnavailable
            return value // never query remote storage automatically
        }
        do {
            let result = try await query(selector + ["system", "df", "--format", "{{json .}}"], limit: 65536)
            guard let rows = DockerStorageParser.parse(result) else { value.state = .failed; return value }
            value.usage = rows; value.state = .available
            guard value.totalBytes != nil else { value.state = .failed; value.usage = []; return value }
        } catch {
            value.state = Task.isCancelled || (error as? ShellRunnerError) == .cancelled ? .cancelled : .engineUnavailable
        }
        value.sampledAt = Date()
        return value
    }
}
