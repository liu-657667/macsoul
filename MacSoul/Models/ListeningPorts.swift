import Foundation

enum LsofParser {
    static func endpoint(_ name: String) -> (bind: String, port: Int)? {
        guard let colon = name.lastIndex(of: ":"),
              let port = Int(name[name.index(after: colon)...]), (1...65535).contains(port) else { return nil }
        let bind = String(name[..<colon])
        guard !bind.isEmpty else { return nil }
        if bind.first == "[" && bind.last == "]" {
            return (String(bind.dropFirst().dropLast()), port)
        }
        return (bind, port)
    }

    static func parse(_ output: String, sampledAt: Date) -> [ListeningPort]? {
        if output.isEmpty { return [] }
        var pid: Int32?
        var process: String?
        var insideFile = false
        var ports: [ListeningPort] = []
        var sawField = false
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let type = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch type {
            case "p":
                guard let parsed = Int32(value), parsed > 0 else { return nil }
                pid = parsed; process = nil; insideFile = false; sawField = true
            case "c":
                guard pid != nil, !value.isEmpty else { return nil }
                process = value
            case "f":
                guard pid != nil else { return nil }
                insideFile = true
            case "n":
                guard insideFile, let pid, let process, let endpoint = endpoint(value) else { return nil }
                ports.append(ListeningPort(port: endpoint.port, pid: pid, process: process,
                                           bind: endpoint.bind, sampledAt: sampledAt))
            default: break
            }
        }
        guard sawField else { return nil }
        // Multiple descriptors or IPv4/IPv6 wildcard sockets can refer to the same
        // visible endpoint. Distinct addresses are retained.
        var seen = Set<String>()
        return ports.filter { seen.insert($0.id).inserted }
            .sorted { $0.port == $1.port ? $0.pid < $1.pid : $0.port < $1.port }
    }
}

actor PortDetector {
    static let executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    static let arguments = ["-n", "-P", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
    private let runner: any ShellRunning
    init(runner: any ShellRunning = ShellRunner()) { self.runner = runner }

    func detect() async -> PortReading {
        let now = Date()
        do {
            let result = try await runner.run(ShellCommand(executableURL: Self.executableURL,
                                                           arguments: Self.arguments, timeout: 5,
                                                           stdoutLimit: 512 * 1024, stderrLimit: 64 * 1024))
            guard !result.outputTruncated, let ports = LsofParser.parse(result.stdout, sampledAt: now) else {
                return PortReading(state: .parseFailed, items: [], sampledAt: now)
            }
            return PortReading(state: ports.isEmpty ? .empty : .available, items: ports, sampledAt: now)
        } catch ShellRunnerError.nonZeroExit(let code, let stdout, let stderr) {
            // lsof returns 1 when no sockets match. Only a completely quiet 1 is empty.
            if code == 1 && stdout.isEmpty && stderr.isEmpty {
                return PortReading(state: .empty, items: [], sampledAt: now)
            }
            return PortReading(state: .failed, items: [], sampledAt: now)
        } catch ShellRunnerError.executableNotFound {
            return PortReading(state: .notFound, items: [], sampledAt: now)
        } catch ShellRunnerError.timeout {
            return PortReading(state: .timeout, items: [], sampledAt: now)
        } catch {
            return PortReading(state: .failed, items: [], sampledAt: now)
        }
    }
}
