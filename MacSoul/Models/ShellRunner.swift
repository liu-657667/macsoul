import Foundation
import Darwin

struct ShellCommand {
    let executableURL: URL
    let arguments: [String]
    var environmentOverrides: [String: String] = [:]
    var timeout: TimeInterval = 5
    var stdoutLimit = 512 * 1024
    var stderrLimit = 512 * 1024
}

struct ShellResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let terminationReason: Process.TerminationReason
    let outputTruncated: Bool
    let duration: TimeInterval
}

enum ShellRunnerError: Error, Equatable {
    case executableNotFound
    case launchFailure
    case nonZeroExit(Int32, stdout: String, stderr: String)
    case timeout
    case cancelled
}

/// A command always names an executable and literal arguments. No shell is involved.
struct ShellRunner {
    func run(_ command: ShellCommand) async throws -> ShellResult {
        guard command.timeout > 0, command.stdoutLimit > 0, command.stderrLimit > 0 else {
            throw ShellRunnerError.launchFailure
        }
        guard FileManager.default.isExecutableFile(atPath: command.executableURL.path) else {
            throw ShellRunnerError.executableNotFound
        }
        let execution = ShellExecution(command: command)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                execution.run(continuation: continuation)
            }
        } onCancel: {
            execution.stop(.cancelled)
        }
    }
}

private final class ShellExecution: @unchecked Sendable {
    enum StopReason { case timeout, cancelled }
    private let command: ShellCommand
    private let lock = NSLock()
    private let pipeCancellation = PipeReadCancellation()
    private var process: Process?
    private var stopReason: StopReason?
    private var timeoutWork: DispatchWorkItem?

    init(command: ShellCommand) { self.command = command }

    func run(continuation: CheckedContinuation<ShellResult, Error>) {
        DispatchQueue.global(qos: .utility).async { [self] in
            let started = ProcessInfo.processInfo.systemUptime
            let process = Process()
            process.executableURL = self.command.executableURL
            process.arguments = self.command.arguments
            if !self.command.environmentOverrides.isEmpty {
                process.environment = ProcessInfo.processInfo.environment.merging(self.command.environmentOverrides) { _, new in new }
            }
            let stdout = Pipe(), stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            self.lock.lock()
            if let reason = self.stopReason {
                self.lock.unlock()
                continuation.resume(throwing: reason == .timeout ? ShellRunnerError.timeout : ShellRunnerError.cancelled)
                return
            }
            self.process = process
            do {
                try process.run()
            } catch {
                self.process = nil
                self.lock.unlock()
                continuation.resume(throwing: ShellRunnerError.launchFailure)
                return
            }
            self.lock.unlock()

            let timeoutWork = DispatchWorkItem { [weak self] in self?.stop(.timeout) }
            self.lock.lock()
            self.timeoutWork = timeoutWork
            let alreadyStopped = self.stopReason != nil
            self.lock.unlock()
            if alreadyStopped { self.requestTermination(process) }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + self.command.timeout, execute: timeoutWork)

            let readers = DispatchGroup()
            let output = BoundedStream(limit: self.command.stdoutLimit)
            let errors = BoundedStream(limit: self.command.stderrLimit)
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                output.drain(stdout.fileHandleForReading, cancellation: self.pipeCancellation)
                readers.leave()
            }
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                errors.drain(stderr.fileHandleForReading, cancellation: self.pipeCancellation)
                readers.leave()
            }
            process.waitUntilExit() // Utility queue only; both pipes drain concurrently.
            readers.wait()
            timeoutWork.cancel()
            self.lock.lock()
            let reason = self.stopReason
            self.process = nil
            self.timeoutWork = nil
            self.lock.unlock()
            if reason == .cancelled { continuation.resume(throwing: ShellRunnerError.cancelled); return }
            if reason == .timeout { continuation.resume(throwing: ShellRunnerError.timeout); return }
            if process.terminationStatus != 0 {
                continuation.resume(throwing: ShellRunnerError.nonZeroExit(process.terminationStatus,
                                                                           stdout: output.text, stderr: errors.text)); return
            }
            continuation.resume(returning: ShellResult(
                stdout: output.text, stderr: errors.text,
                exitCode: process.terminationStatus,
                terminationReason: process.terminationReason,
                outputTruncated: output.truncated || errors.truncated,
                duration: ProcessInfo.processInfo.systemUptime - started))
        }
    }

    func stop(_ reason: StopReason) {
        lock.lock()
        if stopReason == nil { stopReason = reason }
        let child = process
        lock.unlock()
        pipeCancellation.cancel()
        if let child { requestTermination(child) }
    }

    private func requestTermination(_ child: Process) {
        guard child.isRunning else { return }
        child.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
            // This PID belongs to this runner's child, never to a scanned user process.
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
        }
    }
}

private final class BoundedStream: @unchecked Sendable {
    let limit: Int
    private var bytes = Data()
    private(set) var truncated = false
    var text: String { String(decoding: bytes, as: UTF8.self) }
    init(limit: Int) { self.limit = limit }
    func drain(_ handle: FileHandle, cancellation: PipeReadCancellation) {
        while let chunk = try? CancellablePipeReader.read(handle, cancellation: cancellation), !chunk.isEmpty {
            let remaining = max(0, limit - bytes.count)
            if remaining < chunk.count { truncated = true }
            if remaining > 0 { bytes.append(chunk.prefix(remaining)) }
        }
    }
}

// Waking poll with a dedicated cancellation pipe avoids EOF-dependent teardown
// and avoids periodic background polling. Both readers share the wake descriptor;
// neither consumes its byte, so both see cancellation. Close only after joining.
final class PipeReadCancellation: @unchecked Sendable {
    private let pipe = Pipe()
    private let lock = NSLock()
    private var cancelled = false
    var descriptor: Int32 { pipe.fileHandleForReading.fileDescriptor }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return }
        cancelled = true
        try? pipe.fileHandleForWriting.write(contentsOf: Data([1]))
    }
}
enum CancellablePipeReader {
    static func read(_ handle: FileHandle, cancellation: PipeReadCancellation) throws -> Data {
        var descriptors = [pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0),
                           pollfd(fd: cancellation.descriptor, events: Int16(POLLIN), revents: 0)]
        var bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let ready = Darwin.poll(&descriptors, 2, -1)
            if ready < 0 {
                if errno == EINTR { continue }
                throw CocoaError(.fileReadUnknown)
            }
            if descriptors[1].revents != 0 { return Data() }
            if descriptors[0].revents & Int16(POLLNVAL) != 0 { throw CocoaError(.fileReadUnknown) }
            let count = Darwin.read(handle.fileDescriptor, &bytes, bytes.count)
            if count >= 0 { return Data(bytes.prefix(count)) }
            if errno != EINTR { throw CocoaError(.fileReadUnknown) }
        }
    }
}
