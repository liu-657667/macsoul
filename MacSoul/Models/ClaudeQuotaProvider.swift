import Foundation

enum QuotaExecutableDiscovery {
    static func codex(path: String = ProcessInfo.processInfo.environment["PATH"] ?? "") -> URL? {
        ExecutableResolver.resolve("codex", path: path) ?? ExecutableResolver.explicit(
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex")
    }
    static func claude(path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
                       home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        ExecutableResolver.resolve("claude", path: path) ?? ExecutableResolver.resolve("claude",
            path: home.appendingPathComponent(".local/bin").path + ":/opt/homebrew/bin:/usr/local/bin")
    }
    static func version(_ text: String) -> String? {
        // Retain a version only, never arbitrary CLI diagnostics.
        guard let regex = try? NSRegularExpression(pattern: #"\b[0-9]+\.[0-9]+\.[0-9]+(?:[-+][a-zA-Z0-9.-]+)?\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }
}

@MainActor final class ClaudeQuotaProvider: LiveQuotaProviding {
    let provider = QuotaProvider.claude
    private(set) var item = QuotaItem.unavailable(.claude)
    private(set) var detail = QuotaProviderDetail(provider: .claude, connection: .stopped)
    var onUpdate: ((QuotaItem, QuotaProviderDetail) -> Void)?
    private let executable: () -> URL?
    private let runner: any ShellRunning
    private var task: Task<Void, Never>?
    private var retired: Task<Void, Never>?
    private var generation = 0
    private var active = false
    init(executable: @escaping () -> URL? = { QuotaExecutableDiscovery.claude() },
         runner: any ShellRunning = ShellRunner()) {
        self.executable = executable; self.runner = runner
    }
    func start() {
        guard !active else { return }
        active = true; generation += 1
        let cycle = generation
        let previous = retired
        task = Task { [weak self] in
            if let previous { await previous.value }
            guard let self, !Task.isCancelled, cycle == generation else { return }
            guard let executable = executable() else {
                applyCapability(.notInstalled); return
            }
            // Version only: no authentication check, /status, subscription or network request.
            do {
                var command = ShellCommand(executableURL: executable, arguments: ["--version"])
                command.timeout = 3; command.stdoutLimit = 1024; command.stderrLimit = 1024
                let result = try await runner.run(command)
                guard !Task.isCancelled, cycle == generation else { return }
                detail.version = result.outputTruncated ? nil : QuotaExecutableDiscovery.version(result.stdout)
                applyCapability(detail.version == nil ? .unsupportedVersion : .noVerifiedSource)
            } catch {
                guard !Task.isCancelled, cycle == generation else { return }
                applyCapability(.unsupportedVersion)
            }
        }
    }
    func stop() {
        active = false; generation += 1
        if let task { retired = task; task.cancel(); self.task = nil }
        item = .unavailable(.claude); detail.connection = .stopped
        onUpdate?(item, detail)
    }
    func waitForStop() async { await retired?.value }
    private func applyCapability(_ capability: ClaudeQuotaCapability) {
        detail.claudeCapability = capability; detail.connection = .unavailable
        item = .unavailable(.claude)
        onUpdate?(item, detail)
    }

    // An isolated, explicitly verified future bridge supplies only the two quota fields.
    // Detection alone never enables this source or infers auth/subscription state.
    static func map(capability: ClaudeQuotaCapability, sanitizedLimits: [String: Any]? = nil,
                    sampledAt: Date = Date()) -> QuotaItem {
        guard capability == .available else {
            return .unavailable(.claude, failed: capability == .requestFailed)
        }
        guard let sanitizedLimits else {
            return QuotaItem(provider: .claude, fiveHour: .unreported, weekly: .unreported,
                sampledAt: sampledAt, source: "Claude Code status line", freshness: .fresh, mode: .live)
        }
        return (try? ClaudeQuotaParser.parse(sanitizedLimits, sampledAt: sampledAt)) ?? .unavailable(.claude, failed: true)
    }
}
