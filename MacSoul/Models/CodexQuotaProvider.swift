import Foundation

@MainActor protocol LiveQuotaProviding: AnyObject {
    var provider: QuotaProvider { get }
    var item: QuotaItem { get }
    var detail: QuotaProviderDetail { get }
    var onUpdate: ((QuotaItem, QuotaProviderDetail) -> Void)? { get set }
    func start()
    func stop()
    func waitForStop() async
}

@MainActor final class CodexQuotaProvider: LiveQuotaProviding {
    let provider = QuotaProvider.codex
    private(set) var item = QuotaItem.unavailable(.codex)
    private(set) var detail = QuotaProviderDetail(provider: .codex, connection: .stopped)
    var onUpdate: ((QuotaItem, QuotaProviderDetail) -> Void)?
    static let verificationInterval: TimeInterval = 240
    private let makeTransport: () -> any CodexQuotaTransport
    private let clock: any QuotaClock
    private let approved: Bool
    private let versionLookup: (() async -> String?)?
    private var task: Task<Void, Never>?
    private var retired: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var verification: Task<Void, Never>?
    private var lastNumericSample: QuotaItem?
    private var generation = 0
    private var connectionID: UUID?
    private(set) var starts = 0

    private final class Connection {
        let id = UUID()
        var initialized = false
        var pendingRead: Int?
        var nextRead = 2
        var hasBaseline = false
    }

    // Unapproved by default for injected/test AppStores. App entry explicitly selects nativeLive.
    init(approved: Bool = false, version: String? = nil, clock: any QuotaClock = SystemQuotaClock(),
         versionLookup: (() async -> String?)? = nil,
         makeTransport: @escaping () -> any CodexQuotaTransport = {
             NativeCodexQuotaTransport(executable: QuotaExecutableDiscovery.codex())
         }) {
        self.approved = approved; self.clock = clock; self.makeTransport = makeTransport
        self.versionLookup = versionLookup
        detail.version = version
    }

    static func nativeLive() -> CodexQuotaProvider {
        // Unit-test host must never observe the owner's account, even if UI preferences change.
        guard NSClassFromString("XCTestCase") == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return CodexQuotaProvider()
        }
        let executable = ExecutableResolver.explicit(
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex")
        return CodexQuotaProvider(approved: true, versionLookup: {
            guard let executable else { return nil }
            var command = ShellCommand(executableURL: executable, arguments: ["--version"])
            command.timeout = 3; command.stdoutLimit = 1024; command.stderrLimit = 1024
            guard let result = try? await ShellRunner().run(command), !result.outputTruncated else { return nil }
            return QuotaExecutableDiscovery.version(result.stdout)
        }, makeTransport: { NativeCodexQuotaTransport(executable: executable) })
    }

    func start() {
        guard task == nil else { return }
        guard approved else {
            detail.authorizationRequired = true
            publish(.unavailable, failed: false)
            return
        }
        starts += 1; generation += 1
        let cycle = generation
        let previous = retired
        task = Task { [weak self] in
            if let previous { await previous.value }
            guard let self, !Task.isCancelled, cycle == generation else { return }
            if let versionLookup {
                let version = await versionLookup()
                guard !Task.isCancelled, cycle == generation else { return }
                detail.version = version
                // Installed capability was verified for this exact version. Others fail closed.
                guard version == "0.160.0" else { publish(.unavailable, failed: false); return }
            }
            await run(cycle: cycle)
        }
    }
    func stop() {
        generation += 1; connectionID = nil
        cancelTimers()
        if let task { retired = task; task.cancel(); self.task = nil }
        lastNumericSample = nil // Explicit stop/sleep/Preview is a fresh lifecycle baseline.
        publish(.stopped, failed: false)
    }
    func waitForStop() async { await retired?.value }

    private func publish(_ state: QuotaConnectionState, failed: Bool) {
        detail.connection = state
        item = lastNumericSample ?? .unavailable(.codex, failed: failed)
        onUpdate?(item, detail)
    }
    private func cancelTimers() {
        watchdog?.cancel(); watchdog = nil
        verification?.cancel(); verification = nil
    }
    private func isCurrent(_ connection: Connection, cycle: Int) -> Bool {
        !Task.isCancelled && cycle == generation && connection.id == connectionID
    }
    private func deadline(_ transport: any CodexQuotaTransport, connection: Connection, cycle: Int) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            guard let self else { return }
            do { try await clock.sleep(seconds: 10) } catch { return }
            guard isCurrent(connection, cycle: cycle) else { return }
            await transport.close()
        }
    }
    private func read(_ transport: any CodexQuotaTransport, connection: Connection, cycle: Int) async throws {
        guard isCurrent(connection, cycle: cycle), connection.pendingRead == nil else { return }
        let id = connection.nextRead
        connection.nextRead += 1; connection.pendingRead = id
        deadline(transport, connection: connection, cycle: cycle)
        try await transport.send(CodexReadOnlyRPC.message(method: "account/rateLimits/read", id: id))
    }
    private func scheduleVerification(_ transport: any CodexQuotaTransport, connection: Connection, cycle: Int) {
        verification?.cancel()
        verification = Task { [weak self] in
            guard let self else { return }
            do {
                try await clock.sleep(seconds: Self.verificationInterval)
                guard isCurrent(connection, cycle: cycle) else { return }
                try await read(transport, connection: connection, cycle: cycle)
            } catch {
                guard isCurrent(connection, cycle: cycle) else { return }
                await transport.close() // Stream ends; the sole run loop handles reconnect/backoff.
            }
        }
    }
    private func run(cycle: Int) async {
        var backoff = QuotaBackoff()
        while !Task.isCancelled && cycle == generation {
            publish(starts > 1 || backoff.failures > 0 ? .reconnecting : .connecting, failed: false)
            let transport = makeTransport()
            let connection = Connection()
            connectionID = connection.id
            do {
                let stream = try await transport.open()
                try Task.checkCancellation()
                try await transport.send(CodexReadOnlyRPC.message(method: "initialize", id: 1))
                deadline(transport, connection: connection, cycle: cycle)
                try await withTaskCancellationHandler {
                    for try await data in stream {
                        try Task.checkCancellation()
                        guard isCurrent(connection, cycle: cycle) else { break }
                        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                            throw QuotaParseError.malformed
                        }
                        if let id = json["id"] {
                            guard json["method"] == nil else { throw CodexTransportError.malformed }
                            let numericID = try QuotaWireValue.number(id)
                            if numericID == 1 && !connection.initialized {
                                guard json["error"] == nil, json["result"] is [String: Any] else {
                                    throw CodexTransportError.closed
                                }
                                connection.initialized = true
                                try await transport.send(CodexReadOnlyRPC.message(method: "initialized"))
                                try await read(transport, connection: connection, cycle: cycle)
                            } else if let pending = connection.pendingRead, numericID == Double(pending) {
                                guard json["error"] == nil else { throw CodexTransportError.closed }
                                guard let payload = json["result"] as? [String: Any] else { throw QuotaParseError.malformed }
                                try accept(payload, cycle: cycle)
                                connection.pendingRead = nil; connection.hasBaseline = true
                                backoff.reset(); watchdog?.cancel(); watchdog = nil
                                scheduleVerification(transport, connection: connection, cycle: cycle)
                            }
                            // Late/duplicate/unrelated IDs never complete the current read.
                        } else if json["method"] as? String == "account/rateLimits/updated",
                                  connection.initialized, connection.hasBaseline {
                            guard let payload = json["params"] as? [String: Any] else { throw QuotaParseError.malformed }
                            try accept(payload, cycle: cycle)
                        }
                        // Other notifications are discarded without logging or retained payloads.
                    }
                    if !Task.isCancelled { throw CodexTransportError.closed }
                } onCancel: { Task { await transport.close() } }
            } catch {
                if !Task.isCancelled && cycle == generation {
                    publish(error is QuotaParseError ? .malformed : .unavailable, failed: connection.initialized)
                }
            }
            cancelTimers()
            await transport.close() // Reap this child/pipe before another connection/generation.
            guard !Task.isCancelled, cycle == generation else { break }
            connectionID = nil
            detail.connection = .reconnecting
            onUpdate?(item, detail)
            do { try await clock.sleep(seconds: backoff.next()) } catch { break }
        }
    }
    private func accept(_ payload: [String: Any], cycle: Int) throws {
        let parsed = try CodexQuotaParser.parse(payload, now: clock.now())
        guard cycle == generation, !Task.isCancelled else { return }
        item = parsed
        lastNumericSample = nil
        if case .available = parsed.fiveHour { lastNumericSample = parsed }
        else if case .available = parsed.weekly { lastNumericSample = parsed }
        detail.connection = parsed.fiveHour == .requestFailed || parsed.weekly == .requestFailed ? .malformed : .available
        onUpdate?(item, detail)
    }
}
