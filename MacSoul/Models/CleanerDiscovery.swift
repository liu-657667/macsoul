import Foundation

enum CleanerResolutionSource: String, Sendable {
    case xcodeDefault, gradleEnvironment, gradleDefault, mavenUser, mavenGlobal, mavenDefault, mavenOverride
    case npmEnvironment, npmConfig, npmDefault, brewCLI, brewDefault
    var label: String {
        switch self {
        case .xcodeDefault: "Xcode default location"
        case .gradleEnvironment: "GRADLE_USER_HOME"
        case .gradleDefault: "Gradle default location"
        case .mavenUser: "User Maven settings"
        case .mavenGlobal: "Global Maven settings"
        case .mavenDefault: "Default Maven location"
        case .mavenOverride: "Explicit override"
        case .npmEnvironment: "npm cache environment"
        case .npmConfig: "npm config"
        case .npmDefault: "npm default location"
        case .brewCLI: "brew --cache"
        case .brewDefault: "Homebrew default location"
        }
    }
    var isFallback: Bool { [.xcodeDefault, .gradleDefault, .mavenDefault, .npmDefault, .brewDefault].contains(self) }
}
enum CleanerLocationState: String, Sendable { case resolved, notFound, unresolved, unavailable }
struct ResolvedCleanerTarget: Equatable, Sendable {
    let url: URL?
    let source: CleanerResolutionSource
    let state: CleanerLocationState
    var context: String? = nil
}
protocol CleanerCommandRunning: ShellRunning, Sendable {}
struct CleanerShellRunner: CleanerCommandRunning {
    func run(_ command: ShellCommand) async throws -> ShellResult { try await ShellRunner().run(command) }
}
protocol CleanerLocating: Sendable {
    func resolve(_ catalog: [CleanerDescriptor]) async -> [CleanerDescriptor]
}

// Bounded executable metadata lookup, shared with Dev; no shell initialization or disk search.
struct CleanerExecutables: Sendable {
    let environment: [String: String]
    var includeKnownLocations = true
    func find(_ tool: String) -> URL? {
        if let url = ExecutableResolver.resolve(tool, path: String((environment["PATH"] ?? "").prefix(32768))) { return url }
        guard includeKnownLocations else { return nil }
        return ["/opt/homebrew/bin/", "/usr/local/bin/"].compactMap { ExecutableResolver.explicit($0 + tool) }.first
    }
}
enum CleanerPathResolution {
    static func resolve(_ path: String, home: URL, source: CleanerResolutionSource) -> ResolvedCleanerTarget {
        let value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("/"), value.utf8.count <= 4096, !value.contains("\n"), !value.contains("\0"), !value.contains("${") else {
            return .init(url: nil, source: source, state: .unresolved)
        }
        let root = URL(fileURLWithPath: value).standardized
        let forbidden = ["/", "/Applications", "/Library", "/System", "/Users", "/Volumes", home.path, home.appendingPathComponent("Library").path]
        let exclusions = [".sdkman/candidates", ".pyenv/versions", ".goenv/versions", ".nvm/versions", ".docker", "Library/Containers/com.docker.docker"]
        let containers = home.appendingPathComponent("Library/Containers").path + "/com.docker."
        guard !forbidden.contains(root.path), !root.path.hasPrefix(containers),
              !root.path.hasPrefix("/System/"), !root.path.hasPrefix("/Applications/"),
              !["Docker.raw", "Docker.qcow2"].contains(root.lastPathComponent),
              !exclusions.contains(where: { let p = home.appendingPathComponent($0).path; return root.path == p || root.path.hasPrefix(p + "/") }) else {
            return .init(url: nil, source: source, state: .unresolved)
        }
        do {
            var ancestor = root
            while ancestor.path != "/" {
                if try ancestor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                    return .init(url: root, source: source, state: .unavailable)
                }
                ancestor.deleteLastPathComponent()
            }
            let values = try root.resourceValues(forKeys: [.isDirectoryKey])
            return .init(url: root, source: source, state: values.isDirectory == true ? .resolved : .unavailable)
        } catch {
            let e = error as NSError
            let missing = e.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(e.code)
            return .init(url: root, source: source, state: missing ? .notFound : .unavailable)
        }
    }
    static func commandPath(_ output: ShellResult) -> String? {
        guard !output.outputTruncated, output.exitCode == 0 else { return nil }
        let path = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.hasPrefix("/"), path.utf8.count <= 4096, !path.contains("\n"), !path.contains("\r") else { return nil }
        return path
    }
}
struct GradleHomeLocator: Sendable {
    let home: URL
    let environment: [String: String]
    func resolveCache() -> ResolvedCleanerTarget {
        let override = environment["GRADLE_USER_HOME"]
        let source: CleanerResolutionSource = override == nil ? .gradleDefault : .gradleEnvironment
        let base = override ?? home.appendingPathComponent(".gradle").path
        guard base.hasPrefix("/"), !base.contains("\n"), !base.contains("\0"), !base.contains("${") else {
            return .init(url: nil, source: source, state: .unresolved)
        }
        return CleanerPathResolution.resolve(URL(fileURLWithPath: base).appendingPathComponent("caches").path, home: home, source: source)
    }
}
struct NPMCacheLocator: Sendable {
    let home: URL
    let environment: [String: String]
    let executables: CleanerExecutables
    let runner: any CleanerCommandRunning
    func resolveCache(allowCLI: Bool = true) async -> ResolvedCleanerTarget {
        let override = environment["npm_config_cache"] ?? environment["NPM_CONFIG_CACHE"]
        var source: CleanerResolutionSource = .npmDefault
        let base: String
        if let override { base = override; source = .npmEnvironment }
        else if allowCLI, let executable = executables.find("npm") {
            source = .npmConfig
            do {
                var command = ShellCommand(executableURL: executable, arguments: ["config", "get", "cache"], timeout: 3, stdoutLimit: 4096, stderrLimit: 4096)
                command.environmentOverrides = ["NPM_CONFIG_UPDATE_NOTIFIER": "false", "NPM_CONFIG_LOGS_MAX": "0"]
                guard let value = CleanerPathResolution.commandPath(try await runner.run(command)) else { return .init(url: nil, source: source, state: .unresolved) }
                base = value
            } catch { return .init(url: nil, source: source, state: .unavailable) }
        } else { base = home.appendingPathComponent(".npm").path }
        // The configuration names npm's cache home; only its download-cache child is traversed.
        guard base.hasPrefix("/"), !base.contains("\n"), !base.contains("\0"), !base.contains("${") else { return .init(url: nil, source: source, state: .unresolved) }
        return CleanerPathResolution.resolve(URL(fileURLWithPath: base).appendingPathComponent("_cacache").path, home: home, source: source)
    }
}
struct HomebrewCacheLocator: Sendable {
    let home: URL
    let executables: CleanerExecutables
    let runner: any CleanerCommandRunning
    func resolveCache(allowCLI: Bool = true) async -> ResolvedCleanerTarget {
        guard allowCLI, let executable = executables.find("brew") else {
            return CleanerPathResolution.resolve(home.appendingPathComponent("Library/Caches/Homebrew").path, home: home, source: .brewDefault)
        }
        do {
            var command = ShellCommand(executableURL: executable, arguments: ["--cache"], timeout: 3, stdoutLimit: 4096, stderrLimit: 4096)
            command.environmentOverrides = ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ANALYTICS": "1"]
            guard let value = CleanerPathResolution.commandPath(try await runner.run(command)) else { return .init(url: nil, source: .brewCLI, state: .unresolved) }
            return CleanerPathResolution.resolve(value, home: home, source: .brewCLI)
        } catch { return .init(url: nil, source: .brewCLI, state: .unavailable) }
    }
}
struct CleanerLocator: CleanerLocating {
    let home: URL
    let environment: [String: String]
    let runner: any CleanerCommandRunning
    let executables: CleanerExecutables
    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, environment: [String: String] = ProcessInfo.processInfo.environment,
         runner: any CleanerCommandRunning = CleanerShellRunner(), includeKnownLocations: Bool = true) {
        self.home = home; self.environment = environment; self.runner = runner
        executables = CleanerExecutables(environment: environment, includeKnownLocations: includeKnownLocations)
    }
    // Passing allowCLI: false limits discovery to configuration and metadata; no tool commands.
    func resolve(_ catalog: [CleanerDescriptor]) async -> [CleanerDescriptor] { await resolve(catalog, allowCLI: true) }
    func resolve(_ catalog: [CleanerDescriptor], allowCLI: Bool) async -> [CleanerDescriptor] {
        let maven = MavenRepositoryLocator(home: home, environment: environment).discover().location
        var result = CleanerCatalog.resolvingMaven(catalog, location: maven)
        for index in result.indices {
            if Task.isCancelled { break }
            let location: ResolvedCleanerTarget
            switch result[index].kind {
            case .xcode: location = CleanerPathResolution.resolve(result[index].rootURL.path, home: home, source: .xcodeDefault)
            case .gradle: location = GradleHomeLocator(home: home, environment: environment).resolveCache()
            case .maven, .mavenMarkers:
                let source: CleanerResolutionSource = switch maven.source { case .userSettings: .mavenUser; case .globalSettings: .mavenGlobal; case .defaultLocation: .mavenDefault; case .environmentOverride: .mavenOverride }
                if maven.state == .resolved, let url = maven.url {
                    location = CleanerPathResolution.resolve(url.path, home: home, source: source)
                } else {
                    let state: CleanerLocationState = switch maven.state { case .resolved: .resolved; case .notFound: .notFound; case .unresolved: .unresolved; case .unavailable: .unavailable }
                    location = .init(url: maven.url, source: source, state: state)
                }
            case .npm: location = await NPMCacheLocator(home: home, environment: environment, executables: executables, runner: runner).resolveCache(allowCLI: allowCLI)
            case .homebrew: location = await HomebrewCacheLocator(home: home, executables: executables, runner: runner).resolveCache(allowCLI: allowCLI)
            }
            result[index].resolution = location
        }
        return result
    }
}
