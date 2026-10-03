import Foundation
import Darwin

protocol CodexQuotaTransport: Sendable {
    func open() async throws -> AsyncThrowingStream<Data, Error>
    func send(_ data: Data) async throws
    func close() async
}
enum CodexTransportError: Error { case closed, oversized, malformed, launchFailed, timeout }

struct CodexLineBuffer {
    static let limit = 64 * 1024
    private var pending = Data()
    mutating func append(_ chunk: Data) throws -> [Data] {
        var lines: [Data] = []
        for byte in chunk {
            if byte == 10 {
                if !pending.isEmpty { lines.append(pending) }
                pending.removeAll(keepingCapacity: true)
            } else {
                guard pending.count < Self.limit else { throw CodexTransportError.oversized }
                pending.append(byte)
            }
        }
        return lines
    }
    var hasPartialLine: Bool { !pending.isEmpty }
}

// Outbound allowlist makes prompt, thread, login/logout and account mutation unreachable.
enum CodexReadOnlyRPC {
    static func message(method: String, id: Int? = nil) throws -> Data {
        var message: [String: Any] = ["method": method]
        switch method {
        case "initialize":
            guard let id else { throw CodexTransportError.malformed }
            message["id"] = id
            message["params"] = ["clientInfo": ["name": "macsoul", "title": "MacSoul", "version": "0.1.0"]]
        case "initialized": message["params"] = [:] as [String: String]
        case "account/rateLimits/read":
            guard let id else { throw CodexTransportError.malformed }
            message["id"] = id
        default: throw CodexTransportError.malformed
        }
        return try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
    }
}

actor NativeCodexQuotaTransport: CodexQuotaTransport {
    private let executable: URL?
    private var session: CodexPipeSession?
    init(executable: URL?) { self.executable = executable }
    func open() async throws -> AsyncThrowingStream<Data, Error> {
        guard session == nil else { throw CodexTransportError.launchFailed }
        guard let executable else { throw CodexTransportError.launchFailed }
        let session = CodexPipeSession(executable: executable)
        self.session = session
        return try await session.open()
    }
    func send(_ data: Data) async throws {
        guard let session else { throw CodexTransportError.closed }
        try await session.send(data)
    }
    func close() async {
        let old = session
        await old?.close()
        if session === old { session = nil }
    }
}

// Serialized Process lifecycle, detached bounded pipe draining; no stdout/stderr logging.
// Termination targets only this session's child, never a discovered user PID.
private final class CodexPipeSession: @unchecked Sendable {
    private let executable: URL
    private let queue = DispatchQueue(label: "macsoul.quota.child", qos: .utility)
    private let process = Process()
    private let input = Pipe(), output = Pipe(), error = Pipe()
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private let readers = DispatchGroup()
    private let terminated = DispatchGroup()
    private var launched = false
    init(executable: URL) { self.executable = executable }
    func open() async throws -> AsyncThrowingStream<Data, Error> {
        try await withCheckedThrowingContinuation { reply in
            queue.async { [self] in
                let stream = AsyncThrowingStream<Data, Error>(bufferingPolicy: .bufferingOldest(32)) { continuation = $0 }
                process.executableURL = executable
                process.arguments = ["app-server", "--listen", "stdio://"]
                process.currentDirectoryURL = FileManager.default.temporaryDirectory
                process.standardInput = input; process.standardOutput = output; process.standardError = error
                // Do not enable logs or copy credentials; app-server uses its existing client context.
                // Use Foundation's exit callback rather than a run-loop-dependent waitUntilExit.
                terminated.enter()
                process.terminationHandler = { [terminated] _ in terminated.leave() }
                do { try process.run(); launched = true }
                catch {
                    process.terminationHandler = nil
                    terminated.leave()
                    continuation?.finish(throwing: CodexTransportError.launchFailed)
                    reply.resume(throwing: CodexTransportError.launchFailed); return
                }
                readers.enter()
                DispatchQueue.global(qos: .utility).async { [self] in
                    defer { readers.leave() }
                    var buffer = CodexLineBuffer()
                    do {
                        while true {
                            let chunk = try Self.readAvailable(output.fileHandleForReading)
                            if chunk.isEmpty { break }
                            for line in try buffer.append(chunk) {
                                if case .dropped = continuation?.yield(line) {
                                    throw CodexTransportError.oversized
                                }
                            }
                        }
                        continuation?.finish(throwing: buffer.hasPartialLine ? CodexTransportError.malformed : CodexTransportError.closed)
                    } catch { continuation?.finish(throwing: CodexTransportError.closed) }
                }
                readers.enter()
                DispatchQueue.global(qos: .utility).async { [self] in
                    defer { readers.leave() }
                    // Drain/discard diagnostics in bounded chunks, never persist raw messages.
                    while let chunk = try? Self.readAvailable(error.fileHandleForReading), !chunk.isEmpty { }
                }
                reply.resume(returning: stream)
            }
        }
    }
    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (reply: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    guard process.isRunning, data.count <= CodexLineBuffer.limit,
                          let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let method = value["method"] as? String,
                          ["initialize", "initialized", "account/rateLimits/read"].contains(method) else {
                        throw CodexTransportError.closed
                    }
                    try input.fileHandleForWriting.write(contentsOf: data + Data([10]))
                    reply.resume()
                } catch { reply.resume(throwing: CodexTransportError.closed) }
            }
        }
    }
    private static func readAvailable(_ handle: FileHandle) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
            if count >= 0 { return Data(bytes.prefix(count)) }
            if errno != EINTR { throw CodexTransportError.closed }
        }
    }
    func close() async {
        await withCheckedContinuation { reply in
            queue.async { [self] in
                try? input.fileHandleForWriting.close()
                if process.isRunning {
                    process.terminate()
                    // Same ownership rule as ShellRunner: bounded cancellation of our own child only.
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { [process] in
                        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    }
                }
                if launched { terminated.wait() }
                process.terminationHandler = nil
                readers.wait()
                try? output.fileHandleForReading.close(); try? error.fileHandleForReading.close()
                continuation?.finish(); continuation = nil
                reply.resume()
            }
        }
    }
}
