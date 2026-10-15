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
    // Metadata only. Both version lookup and transport capture this same trusted source.
    nonisolated static let bundledExecutablePath = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
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
        var timedOut = false
    }

    // Unapproved by default for injected/test AppStores. App entry explicitly selects nativeLive.
    init(approved: Bool = false, version: String? = nil, clock: any QuotaClock = SystemQuotaClock(),
         versionLookup: (() async -> String?)? = nil,
         makeTransport: @escaping () -> any CodexQuotaTransport = {
             NativeCodexQuotaTransport(executable: ExecutableResolver.explicit(CodexQuotaProvider.bundledExecutablePath))
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
        let executable = ExecutableResolver.explicit(bundledExecutablePath)
        return CodexQuotaProvider(approved: true, versionLookup: {
            guard let executable else { return nil }
            var command = ShellCommand(executableURL: executable, arguments: ["--version"])
            command.timeout = 3; command.stdoutLimit = 1024; command.stderrLimit = 1024
            guard let result = try? await ShellRunner().run(command), !result.outputTruncated, result.exitCode == 0 else { return nil }
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
            defer { if cycle == generation { task = nil } }
            detail.codexSession = .checking
            publish(.connecting, failed: false)
            guard !Task.isCancelled, cycle == generation else { return }
            if let versionLookup {
                let version = await versionLookup()
                guard !Task.isCancelled, cycle == generation else { return }
                detail.version = version
                // Version metadata does not attest protocol compatibility. A missing/unreadable
                // version still requires the exact same handshake and validated first read.
            }
            await run(cycle: cycle)
        }
    }
    func stop() {
        generation += 1; connectionID = nil
        cancelTimers()
        if let task { retired = task; task.cancel(); self.task = nil }
        lastNumericSample = nil // Explicit stop/sleep/Preview is a fresh lifecycle baseline.
        detail.codexSession = .stopped
        publish(.stopped, failed: false)
    }
    func waitForStop() async { await retired?.value }

    private func publish(_ state: QuotaConnectionState, failed: Bool) {
        detail.connection = state
        if let sample = lastNumericSample {
            item = QuotaItem(provider: sample.provider, fiveHour: sample.fiveHour, weekly: sample.weekly,
                             sampledAt: sample.sampledAt, source: sample.source, freshness: .stale, mode: .live)
        } else { item = .unavailable(.codex, failed: failed) }
        onUpdate?(item, detail)
    }
    private func cancelTimers() {
        watchdog?.cancel(); watchdog = nil
        verification?.cancel(); verification = nil
    }
    private func isCurrent(_ connection: Connection, cycle: Int) -> Bool {
        !Task.isCancelled && cycle == generation && connection.id == connectionID && !connection.timedOut
    }
    private func deadline(_ transport: any CodexQuotaTransport, connection: Connection, cycle: Int) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            guard let self else { return }
            do { try await clock.sleep(seconds: 10) } catch { return }
            guard isCurrent(connection, cycle: cycle) else { return }
            connection.timedOut = true
            detail.codexSession = connection.initialized ? .requestTimeout : .handshakeTimeout
            publish(.unavailable, failed: connection.initialized)
            // Publication can synchronously stop/restart the provider. This old transport
            // still must close, even though timedOut/cancellation now invalidate admission.
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
            detail.codexSession = .handshaking
            publish(starts > 1 || backoff.failures > 0 ? .reconnecting : .connecting, failed: false)
            guard !Task.isCancelled, cycle == generation else { break }
            let transport = makeTransport()
            let connection = Connection()
            connectionID = connection.id
            var terminal = false
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
                                try checkResponse(json, initializing: true)
                                guard let result = json["result"] as? [String: Any],
                                      let agent = result["userAgent"] as? String, !agent.isEmpty else {
                                    throw QuotaParseError.malformed
                                }
                                connection.initialized = true
                                detail.codexSession = .reading
                                publish(.connecting, failed: false)
                                guard isCurrent(connection, cycle: cycle) else { break }
                                try await transport.send(CodexReadOnlyRPC.message(method: "initialized"))
                                try await read(transport, connection: connection, cycle: cycle)
                            } else if let pending = connection.pendingRead, numericID == Double(pending) {
                                try checkResponse(json, initializing: false)
                                guard let payload = json["result"] as? [String: Any] else { throw QuotaParseError.malformed }
                                try accept(payload, cycle: cycle)
                                guard isCurrent(connection, cycle: cycle) else { break }
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
                    let reason: CodexSessionStatus
                    if error is QuotaParseError {
                        reason = .invalidResponse; terminal = true
                    } else if let rejection = error as? SessionRejection {
                        reason = rejection.reason; terminal = rejection.terminal
                    } else if let transportError = error as? CodexTransportError,
                              transportError == .malformed || transportError == .oversized {
                        reason = .invalidResponse; terminal = true
                    } else if connection.timedOut {
                        reason = connection.initialized ? .requestTimeout : .handshakeTimeout
                    } else if let transportError = error as? CodexTransportError,
                              transportError == .launchFailed {
                        reason = .cliUnavailable
                    } else { reason = connection.initialized ? .communicationFailure : .handshakeFailed }
                    detail.codexSession = reason
                    publish(terminal ? .malformed : .unavailable, failed: connection.initialized)
                }
            }
            cancelTimers()
            await transport.close() // Reap this child/pipe before another connection/generation.
            guard !Task.isCancelled, cycle == generation else { break }
            connectionID = nil
            if terminal { break } // Explicit stop/start may retry; no incompatible-process loop.
            detail.connection = .reconnecting
            onUpdate?(item, detail)
            do { try await clock.sleep(seconds: backoff.next()) } catch { break }
        }
    }
    private struct SessionRejection: Error {
        let reason: CodexSessionStatus
        let terminal: Bool
    }
    private func checkResponse(_ json: [String: Any], initializing: Bool) throws {
        if let raw = json["error"] {
            guard json["result"] == nil, let error = raw as? [String: Any],
                  error["message"] is String else { throw QuotaParseError.malformed }
            let code = try QuotaWireValue.number(error["code"])
            guard code.rounded() == code else { throw QuotaParseError.malformed }
            // Never retain/display server message, data or stderr.
            if code == -32601 { throw SessionRejection(reason: .methodUnsupported, terminal: true) }
            if code == -32600 || code == -32602 { throw QuotaParseError.malformed }
            throw SessionRejection(reason: initializing ? .handshakeFailed : .quotaRequestFailed, terminal: false)
        }
        guard json["result"] is [String: Any] else { throw QuotaParseError.malformed }
    }
    private func accept(_ payload: [String: Any], cycle: Int) throws {
        let parsed = try CodexQuotaParser.parse(payload, now: clock.now())
        guard cycle == generation, !Task.isCancelled else { return }
        guard parsed.fiveHour != .requestFailed, parsed.weekly != .requestFailed else {
            throw QuotaParseError.malformed
        }
        item = parsed
        lastNumericSample = nil
        if case .available = parsed.fiveHour { lastNumericSample = parsed }
        else if case .available = parsed.weekly { lastNumericSample = parsed }
        detail.codexSession = lastNumericSample == nil ? .quotaUnavailable : .available
        detail.connection = lastNumericSample == nil ? .unavailable : .available
        onUpdate?(item, detail)
    }
}
