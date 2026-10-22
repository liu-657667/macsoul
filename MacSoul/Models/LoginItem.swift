import Foundation
import ServiceManagement
import Darwin
import CoreFoundation

// Read system state on refresh. Mutation is reachable only from an explicit
// Settings action; neither init, refresh nor Preview/Live starts registration.
enum LoginItemState: CaseIterable, Equatable {
    case enabled, disabled, requiresApproval, serviceNotFound, unknown
    var isRegistered: Bool { self == .enabled || self == .requiresApproval }
    var permitsChanges: Bool { self == .enabled || self == .disabled || self == .requiresApproval }
    func label(_ language: MacSoulLanguage) -> String {
        switch self {
        case .enabled: language == .english ? "Enabled" : "已启用"
        case .disabled: language == .english ? "Not registered" : "未注册"
        case .requiresApproval: language == .english ? "Approval required in System Settings" : "需要在系统设置中确认"
        case .serviceNotFound: language == .english ? "Login service not found" : "未找到登录服务"
        case .unknown: language == .english ? "Unknown login-item status" : "未知登录项状态"
        }
    }
    func explanation(_ language: MacSoulLanguage) -> String {
        switch self {
        case .enabled:
            language == .english ? "macOS reports that this app is enabled to launch at login." : "macOS 报告此 App 已启用登录时启动。"
        case .disabled:
            language == .english ? "macOS reports that this app is not registered. Registration requires a verified environment and an explicit action."
                : "macOS 报告此 App 尚未注册。注册需要已验证的环境及用户明确操作。"
        case .requiresApproval:
            language == .english ? "Registration is present, but macOS approval is still required. Review Login Items in System Settings, then refresh."
                : "已存在注册记录，但仍需 macOS 批准。请在系统设置中检查登录项，然后刷新。"
        case .serviceNotFound:
            language == .english ? "macOS could not find the login service. App identity, signing, installation or system registration may need attention; the cause has not been confirmed. Check the app, then refresh."
                : "macOS 未找到登录服务。App 身份、签名、安装副本或系统注册信息可能需要检查；原因尚未确认。检查后请刷新。"
        case .unknown:
            language == .english ? "This system status is not recognized. Login-item changes are disabled here; check System Settings and refresh."
                : "尚无法识别此系统状态。此处已禁用登录项变更；请检查系统设置并刷新。"
        }
    }
    static func map(_ status: SMAppService.Status) -> Self {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .serviceNotFound
        @unknown default: .unknown
        }
    }
}

// Independent from the native registration status. Phase 2A does not establish
// native eligibility from a path, build configuration or assumed signature.
enum LoginItemEligibility: CaseIterable, Equatable {
    case eligible, ineligible, unknown
    func explanation(_ language: MacSoulLanguage) -> String {
        switch self {
        case .eligible:
            language == .english ? "The environment is verified for login-item changes. Only an explicit action changes registration."
                : "环境已通过登录项变更资格验证。仅用户明确操作才会更改注册。"
        case .ineligible:
            language == .english ? "This environment is not eligible for login-item changes. Check the app's signing and installed copy; no change will be attempted here."
                : "此环境不具备登录项变更资格。请检查 App 签名及安装副本；此处不会尝试更改。"
        case .unknown:
            language == .english ? "This app's eligibility has not been verified. Changes are disabled here. Use System Settings to manage existing login items; Refresh only reads their status."
                : "尚未验证此 App 的变更资格，此处已禁用操作。现有登录项可在系统设置中管理；刷新仅重新读取状态。"
        }
    }
}

enum LoginItemOperationError: CaseIterable, Equatable {
    case invalidSignature, approvalDenied, alreadyRegistered, serviceNotFound, unregisterFailed, unknownFailure

    static func classify(_ error: Error, unregistering: Bool) -> Self {
        let error = error as NSError
        // Match the domain before interpreting the SDK's exported constants.
        // The modern domain is unavailable on our macOS 13 deployment target.
        var isServiceManagement = error.domain == (kSMErrorDomainFramework as String)
        if #available(macOS 15.0, *) {
            isServiceManagement = isServiceManagement || error.domain == SMAppServiceErrorDomain
        }
        if isServiceManagement {
            switch error.code {
            case kSMErrorInvalidSignature: return .invalidSignature
            case kSMErrorLaunchDeniedByUser: return .approvalDenied
            case kSMErrorAlreadyRegistered: return .alreadyRegistered
            case kSMErrorJobNotFound: return .serviceNotFound
            default: break
            }
        }
        return unregistering ? .unregisterFailed : .unknownFailure
    }

    func message(_ language: MacSoulLanguage) -> String {
        switch self {
        case .invalidSignature:
            language == .english ? "macOS rejected the app's signature for this operation. Use a correctly signed app, then refresh."
                : "macOS 拒绝了此次操作所用的 App 签名。请使用正确签名的 App，然后刷新。"
        case .approvalDenied:
            language == .english ? "macOS reported that launch approval was denied. Review Login Items in System Settings, then refresh."
                : "macOS 报告启动批准被拒绝。请在系统设置中检查登录项，然后刷新。"
        case .alreadyRegistered:
            language == .english ? "macOS reported that the login item is already registered. Refresh to read its current status."
                : "macOS 报告登录项已注册。请刷新以读取当前状态。"
        case .serviceNotFound:
            language == .english ? "macOS could not find the login item during the operation. Check the app and System Settings, then refresh."
                : "操作时 macOS 未找到登录项。请检查 App 和系统设置，然后刷新。"
        case .unregisterFailed:
            language == .english ? "Could not unregister the login item. Check System Settings and refresh; it may still be registered."
                : "无法取消注册登录项。请检查系统设置并刷新；该登录项可能仍已注册。"
        case .unknownFailure:
            language == .english ? "Could not change the login item. Check System Settings and refresh."
                : "无法更改登录项，请检查系统设置并刷新。"
        }
    }
}

@MainActor protocol LoginItemManaging {
    var state: LoginItemState { get }
    var eligibility: LoginItemEligibility { get }
    func register() throws
    func unregister() throws
}
@MainActor struct NativeLoginItemManager: LoginItemManaging {
    var state: LoginItemState { .map(SMAppService.mainApp.status) }
    // No native signature/installation validation is authorized in this phase.
    var eligibility: LoginItemEligibility { .unknown }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}
@MainActor final class LoginItemController: ObservableObject {
    @Published private(set) var state: LoginItemState
    @Published private(set) var eligibility: LoginItemEligibility
    @Published private(set) var operationError: LoginItemOperationError?
    var canChangeRegistration: Bool { state.permitsChanges && eligibility == .eligible }
    private let manager: any LoginItemManaging
    init(manager: any LoginItemManaging) {
        self.manager = manager
        state = manager.state
        eligibility = manager.eligibility
    }
    func refresh() {
        let observed = manager.state
        if observed != state { operationError = nil }
        state = observed
        eligibility = manager.eligibility
    }
    func setEnabled(_ enabled: Bool) {
        refresh()
        guard canChangeRegistration, enabled != state.isRegistered else { return }
        var failure: LoginItemOperationError?
        do {
            if enabled { try manager.register() } else { try manager.unregister() }
        } catch { failure = .classify(error, unregistering: !enabled) }
        // Observe even after a throw. Preserve this operation's failure alongside
        // its actual resulting state; a later external state change clears it.
        state = manager.state
        eligibility = manager.eligibility
        operationError = failure // Never retain raw NSError/userInfo or paths.
    }
}

// LaunchAgent configuration is independent of SMAppService's native status.
// None of these states claims that a real login has been tested.
enum LaunchAgentState: CaseIterable, Equatable {
    case disabled, configuredForNextLogin, loaded, stalePath, conflict, unavailable
    var isConfigured: Bool { [.configuredForNextLogin, .loaded, .stalePath].contains(self) }
    var permitsChanges: Bool { self == .disabled || isConfigured }
    func label(_ language: MacSoulLanguage) -> String {
        let english: String, chinese: String
        switch self {
        case .disabled: (english, chinese) = ("Disabled", "未启用")
        case .configuredForNextLogin: (english, chinese) = ("Configured for next login", "已配置下次登录启动")
        case .loaded: (english, chinese) = ("Login configuration loaded", "登录启动配置已加载")
        case .stalePath: (english, chinese) = ("App path changed", "App 路径已变化")
        case .conflict: (english, chinese) = ("Login configuration conflict", "登录启动配置冲突")
        case .unavailable: (english, chinese) = ("Login configuration unavailable", "登录启动配置不可用")
        }
        return language == .english ? english : chinese
    }
    func explanation(_ language: MacSoulLanguage) -> String {
        let english: String, chinese: String
        switch self {
        case .disabled:
            (english, chinese) = ("Enable to open this installed copy at your next login. The app will not restart now.", "启用后将在下次登录时打开当前安装副本，不会立即重启 App。")
        case .configuredForNextLogin:
            (english, chinese) = ("The configuration is saved. Actual launch at your next login has not been verified.", "配置已保存，尚未验证下次实际登录时的启动结果。")
        case .loaded:
            (english, chinese) = ("macOS has loaded this configuration. This does not verify a successful login launch.", "macOS 已加载此配置；这不代表实际登录启动已经验证成功。")
        case .stalePath:
            (english, chinese) = ("The saved path differs from this copy or this copy is not installed. Turn off the verified old configuration, install this app in Applications, then enable again. No path is rewritten automatically.", "保存的路径与当前副本不同，或当前副本尚未安装。请关闭已核对的旧配置，将 App 安装到应用程序目录，再重新启用。不会自动改写路径。")
        case .conflict:
            (english, chinese) = ("The file or loaded job does not match MacSoul's configuration. Nothing will be overwritten or removed. Review the conflict, then refresh.", "文件或已加载的任务与 MacSoul 配置不符，不会覆盖或删除。请检查冲突后刷新。")
        case .unavailable:
            (english, chinese) = ("Use the MacSoul app installed directly in /Applications or your user Applications folder. Check file permissions and the current login session, then refresh.", "请使用直接安装在 /Applications 或用户 Applications 目录中的 MacSoul。请检查文件权限和当前登录会话，然后刷新。")
        }
        return language == .english ? english : chinese
    }
}

enum LaunchAgentFailure: Error, CaseIterable, Equatable {
    case conflict, unsafeFile, installation, observation, create, bootout, remove, cancelled, busy
    func message(_ language: MacSoulLanguage) -> String {
        let english: String, chinese: String
        switch self {
        case .conflict: (english, chinese) = ("Configuration changed or conflicts with another job; no overwrite or deletion was attempted.", "配置已变化或与其他任务冲突，未尝试覆盖或删除。")
        case .unsafeFile: (english, chinese) = ("The configuration path, owner or permissions are unsafe. Check them and refresh.", "配置路径、所有者或权限不安全，请检查后刷新。")
        case .installation: (english, chinese) = ("Install the official MacSoul copy in Applications before enabling login launch.", "启用登录启动前，请将正式 MacSoul 副本安装到应用程序目录。")
        case .observation: (english, chinese) = ("Could not verify the current login job. No unsafe change will be attempted.", "无法核对当前登录任务，不会尝试不安全的变更。")
        case .create: (english, chinese) = ("Could not finish saving the configuration. Refresh to inspect the actual state.", "无法完成配置保存，请刷新检查实际状态。")
        case .bootout: (english, chinese) = ("Could not unload the login job. The configuration was retained; refresh before trying again.", "无法卸载登录任务，配置已保留；重试前请刷新。")
        case .remove: (english, chinese) = ("Could not remove the configuration. The job may already be unloaded; the saved configuration may still launch at login.", "无法删除配置，任务可能已卸载，但保存的配置仍可能在登录时启动。")
        case .cancelled: (english, chinese) = ("Operation cancelled. Refresh shows the observed configuration; changes are never rolled back automatically.", "操作已取消。刷新显示实际配置，不会自动回滚。")
        case .busy: (english, chinese) = ("Another login configuration operation is in progress.", "另一项登录启动配置操作正在进行。")
        }
        return language == .english ? english : chinese
    }
}

struct LaunchAgentApp {
    let url: URL
    let bundleID: String?
    let home: URL
    var isProduction: Bool { bundleID == "local.macsoul.app" }
    func isInstallPath(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().path
        return url.isFileURL && url.path.hasPrefix("/") && !url.pathComponents.contains(where: { $0 == "." || $0 == ".." }) && url.pathExtension == "app"
            && !url.path.contains("\n") && !url.path.contains("\r") && !url.path.contains("\0")
            && (parent == "/Applications" || parent == home.appendingPathComponent("Applications").path)
    }
}
struct LaunchAgentFile: Equatable {
    let data: Data
    let identity: String // Native dev/inode/owner/mode/size/times; opaque in Fakes.
}
protocol LaunchAgentFiles {
    var directory: URL { get }
    func read() throws -> LaunchAgentFile?
    func create(_ data: Data) throws
    func remove(_ expected: LaunchAgentFile) throws
    // nil means absent, false means an existing invalid/foreign app.
    func appIsMacSoul(at url: URL) -> Bool?
}
struct LaunchAgentJob: Equatable {
    let source: String
    let program: String
    let arguments: [String]
}
protocol LaunchAgentJobs {
    func read() async throws -> LaunchAgentJob?
    func bootout() async throws
}
protocol LaunchAgentManaging {
    func readState() async -> LaunchAgentState
    func enable() async throws
    func disable() async throws
}

// Uses the existing bounded/cancellable runner, never a shell or open command.
struct NativeLaunchAgentJobs: LaunchAgentJobs {
    let runner: any ShellRunning
    let uid: UInt32
    static let label = "local.macsoul.launchagent"
    var target: String { "gui/\(uid)/\(Self.label)" }
    private func command(_ arguments: [String]) -> ShellCommand {
        ShellCommand(executableURL: URL(fileURLWithPath: "/bin/launchctl"), arguments: arguments,
                     timeout: 3, stdoutLimit: 64 * 1024, stderrLimit: 8 * 1024)
    }
    func read() async throws -> LaunchAgentJob? {
        do {
            let overrides = try await runner.run(command(["print-disabled", "gui/\(uid)"]))
            guard !overrides.outputTruncated, overrides.stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("disabled services = {"), overrides.stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") else { throw LaunchAgentFailure.observation }
            let entries = overrides.stdout.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("\"\(Self.label)\" => ") }
            guard entries.count <= 1, entries.isEmpty || entries[0] == "\"\(Self.label)\" => false" else { throw LaunchAgentFailure.observation }
            let result = try await runner.run(command(["print", target]))
            guard !result.outputTruncated else { throw LaunchAgentFailure.observation }
            return try Self.parse(result.stdout, target: target)
        } catch ShellRunnerError.nonZeroExit(_, _, let stderr) {
            // Do not interpret arbitrary nonzero statuses as absence. Confirm
            // the GUI domain exists and require the exact missing-service text.
            guard stderr.contains("Could not find service \"\(Self.label)\"") else { throw LaunchAgentFailure.observation }
            do { _ = try await runner.run(command(["print", "gui/\(uid)"])) }
            catch ShellRunnerError.cancelled { throw LaunchAgentFailure.cancelled }
            catch { throw LaunchAgentFailure.observation }
            return nil
        } catch ShellRunnerError.cancelled { throw LaunchAgentFailure.cancelled }
    }
    static func parse(_ output: String, target: String) throws -> LaunchAgentJob {
        // print is diagnostic output, not a stable API. Unknown formats fail closed.
        let lines = output.components(separatedBy: .newlines)
        let rootClosures = lines.indices.filter { lines[$0] == "}" }
        guard lines.first == "\(target) = {", rootClosures.count == 1,
              rootClosures.first == lines.lastIndex(where: { !$0.isEmpty }) else { throw LaunchAgentFailure.observation }
        let paths = lines.filter { $0.hasPrefix("\tpath = ") }
        let programs = lines.filter { $0.hasPrefix("\tprogram = ") }
        let starts = lines.indices.filter { lines[$0] == "\targuments = {" }
        guard paths.count == 1, programs.count == 1, starts.count == 1,
              let start = starts.first, let end = lines.indices.first(where: { $0 > start && lines[$0] == "\t}" })
        else { throw LaunchAgentFailure.observation }
        let args = lines[(start + 1)..<end].map { String($0.dropFirst(2)) }
        guard lines[(start + 1)..<end].allSatisfy({ $0.hasPrefix("\t\t") }), args.count == 3 else { throw LaunchAgentFailure.observation }
        return LaunchAgentJob(source: String(paths[0].dropFirst(8)), program: String(programs[0].dropFirst(11)), arguments: args)
    }
    func bootout() async throws {
        do { _ = try await runner.run(command(["bootout", target])) }
        catch ShellRunnerError.cancelled { throw LaunchAgentFailure.cancelled }
        catch { throw LaunchAgentFailure.bootout }
    }
}

actor LaunchAgentManager: LaunchAgentManaging {
    static let filename = "local.macsoul.launchagent.plist"
    let app: LaunchAgentApp
    let files: any LaunchAgentFiles
    let jobs: any LaunchAgentJobs
    private var mutating = false
    init(app: LaunchAgentApp, files: any LaunchAgentFiles, jobs: any LaunchAgentJobs) {
        self.app = app; self.files = files; self.jobs = jobs
    }
    static func native() -> LaunchAgentManager {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Test-host Settings may be instantiated by SwiftUI. Keep the default
        // composition fail closed before any real Home or launchctl access.
        let testHost = NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        return LaunchAgentManager(app: .init(url: Bundle.main.bundleURL, bundleID: testHost ? nil : Bundle.main.bundleIdentifier, home: home),
                                  files: NativeLaunchAgentFiles(home: home, uid: getuid()),
                                  jobs: NativeLaunchAgentJobs(runner: ShellRunner(), uid: getuid()))
    }
    static func plist(for path: String) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["Label": NativeLaunchAgentJobs.label,
            "ProgramArguments": ["/usr/bin/open", "-a", path], "RunAtLoad": true, "KeepAlive": false], format: .xml, options: 0)
    }
    private func configuredPath(_ data: Data) throws -> String {
        guard let p = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              Set(p.keys) == Set(["Label", "ProgramArguments", "RunAtLoad", "KeepAlive"]),
              p["Label"] as? String == NativeLaunchAgentJobs.label,
              let args = p["ProgramArguments"] as? [String], args.count == 3, Array(args.prefix(2)) == ["/usr/bin/open", "-a"],
              let on = p["RunAtLoad"] as? NSNumber, CFGetTypeID(on) == CFBooleanGetTypeID(), on.boolValue,
              let keep = p["KeepAlive"] as? NSNumber, CFGetTypeID(keep) == CFBooleanGetTypeID(), !keep.boolValue,
              args[2].hasPrefix("/"), URL(fileURLWithPath: args[2]).path == args[2],
              app.isInstallPath(URL(fileURLWithPath: args[2])), files.appIsMacSoul(at: URL(fileURLWithPath: args[2])) != false
        else { throw LaunchAgentFailure.conflict }
        return args[2]
    }
    private func observe() async throws -> (LaunchAgentState, LaunchAgentFile?, LaunchAgentJob?) {
        guard app.isProduction else { throw LaunchAgentFailure.installation }
        let file = try files.read()
        let path = try file.map { try configuredPath($0.data) }
        let job = try await jobs.read()
        if let job {
            guard job.source == files.directory.appendingPathComponent(Self.filename).path,
                  job.program == "/usr/bin/open", job.arguments.count == 3,
                  Array(job.arguments.prefix(2)) == ["/usr/bin/open", "-a"],
                  job.arguments[2].hasPrefix("/"), URL(fileURLWithPath: job.arguments[2]).path == job.arguments[2],
                  app.isInstallPath(URL(fileURLWithPath: job.arguments[2])),
                  files.appIsMacSoul(at: URL(fileURLWithPath: job.arguments[2])) != false,
                  path == nil || path == job.arguments[2]
            else { throw LaunchAgentFailure.conflict }
        }
        let saved = path ?? job?.arguments.last
        let installed = app.isInstallPath(app.url) && files.appIsMacSoul(at: app.url) == true
        if let saved {
            return (saved != app.url.path || !installed ? .stalePath : (job == nil ? .configuredForNextLogin : .loaded), file, job)
        }
        return (installed ? .disabled : .unavailable, nil, nil)
    }
    func readState() async -> LaunchAgentState {
        do { return try await observe().0 }
        catch LaunchAgentFailure.conflict { return .conflict }
        catch { return .unavailable }
    }
    func enable() async throws {
        guard !mutating else { throw LaunchAgentFailure.busy }; mutating = true; defer { mutating = false }
        try Task.checkCancellation()
        let (state, _, _) = try await observe()
        try Task.checkCancellation()
        if state == .configuredForNextLogin || state == .loaded { return }
        guard state == .disabled else { throw state == .stalePath ? LaunchAgentFailure.conflict : LaunchAgentFailure.installation }
        try files.create(Self.plist(for: app.url.path))
        guard let readback = try files.read(), try configuredPath(readback.data) == app.url.path else { throw LaunchAgentFailure.create }
    }
    func disable() async throws {
        guard !mutating else { throw LaunchAgentFailure.busy }; mutating = true; defer { mutating = false }
        try Task.checkCancellation()
        let (_, file, job) = try await observe()
        try Task.checkCancellation()
        if job != nil {
            // Recheck file identity and the exact loaded job immediately before mutation.
            guard try await jobs.read() == job, try files.read() == file else { throw LaunchAgentFailure.conflict }
            try Task.checkCancellation()
            try await jobs.bootout()
            guard try await jobs.read() == nil else { throw LaunchAgentFailure.bootout }
        }
        try Task.checkCancellation()
        if let file { try files.remove(file) }
        guard try files.read() == nil, try await jobs.read() == nil else { throw LaunchAgentFailure.remove }
    }
}

@MainActor final class LaunchAgentController: ObservableObject {
    @Published private(set) var state: LaunchAgentState = .unavailable
    @Published private(set) var operationError: LaunchAgentFailure?
    @Published private(set) var isBusy = false
    private let manager: any LaunchAgentManaging
    init(manager: any LaunchAgentManaging) { self.manager = manager }
    func refresh() async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        let next = await manager.readState()
        if next != state { operationError = nil }
        state = next
    }
    func setEnabled(_ enabled: Bool) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        var failure: LaunchAgentFailure?
        do {
            try Task.checkCancellation()
            if enabled { try await manager.enable() } else { try await manager.disable() }
        } catch is CancellationError { failure = .cancelled }
        catch let error as LaunchAgentFailure { failure = error }
        catch { failure = .observation }
        state = await manager.readState()
        operationError = failure
    }
}

// Only the fixed basename is writable. Directory descriptors, exclusive create,
// no-follow/nonblocking reads and identity checks reject unknown replacements.
struct NativeLaunchAgentFiles: LaunchAgentFiles {
    let home: URL
    let uid: UInt32
    var directory: URL { home.appendingPathComponent("Library/LaunchAgents", isDirectory: true) }
    private var name: String { LaunchAgentManager.filename }
    private func identity(_ s: stat) -> String {
        "\(s.st_dev):\(s.st_ino):\(s.st_uid):\(s.st_gid):\(s.st_mode):\(s.st_nlink):\(s.st_size):\(s.st_mtimespec.tv_sec):\(s.st_mtimespec.tv_nsec):\(s.st_ctimespec.tv_sec):\(s.st_ctimespec.tv_nsec)"
    }
    private func directoryFD(create: Bool) throws -> Int32? {
        guard home.isFileURL, home.path.hasPrefix("/"), !home.pathComponents.contains(where: { $0 == "." || $0 == ".." }) else { throw LaunchAgentFailure.unsafeFile }
        var fd = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw LaunchAgentFailure.unsafeFile }
        var transfer = false
        defer { if !transfer { Darwin.close(fd) } }
        let homeParts = home.pathComponents.filter { $0 != "/" }
        let parts = homeParts + ["Library", "LaunchAgents"]
        for (index, component) in parts.enumerated() {
            var next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            if next < 0, errno == ENOENT, index >= homeParts.count {
                if !create { return nil }
                guard mkdirat(fd, component, 0o700) == 0 else { throw LaunchAgentFailure.create }
                next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            }
            guard next >= 0 else { throw LaunchAgentFailure.unsafeFile }
            Darwin.close(fd); fd = next
            var s = stat()
            guard fstat(fd, &s) == 0, s.st_mode & S_IFMT == S_IFDIR else { throw LaunchAgentFailure.unsafeFile }
            if index >= homeParts.count - 1 {
                guard s.st_uid == uid, s.st_mode & 0o022 == 0 else { throw LaunchAgentFailure.unsafeFile }
            }
        }
        transfer = true
        return fd
    }
    private func checkDirectory(_ fd: Int32) throws {
        guard let current = try directoryFD(create: false) else { throw LaunchAgentFailure.unsafeFile }
        defer { Darwin.close(current) }
        var a = stat(), b = stat()
        guard fstat(fd, &a) == 0, fstat(current, &b) == 0, a.st_dev == b.st_dev, a.st_ino == b.st_ino else { throw LaunchAgentFailure.unsafeFile }
    }
    private func read(at directoryFD: Int32) throws -> LaunchAgentFile? {
        var before = stat()
        if fstatat(directoryFD, name, &before, AT_SYMLINK_NOFOLLOW) != 0 {
            if errno == ENOENT { return nil }
            throw LaunchAgentFailure.unsafeFile
        }
        guard before.st_mode & S_IFMT == S_IFREG, before.st_uid == uid,
              before.st_mode & 0o7777 == 0o600, before.st_nlink == 1, before.st_size >= 0, before.st_size <= 16384
        else { throw LaunchAgentFailure.unsafeFile }
        let fd = openat(directoryFD, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw LaunchAgentFailure.unsafeFile }
        defer { Darwin.close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0, identity(opened) == identity(before) else { throw LaunchAgentFailure.unsafeFile }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0, errno == EINTR { continue }
            guard count >= 0, data.count + max(count, 0) <= 16384 else { throw LaunchAgentFailure.unsafeFile }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        var after = stat(), named = stat()
        guard fstat(fd, &after) == 0, fstatat(directoryFD, name, &named, AT_SYMLINK_NOFOLLOW) == 0,
              identity(after) == identity(before), identity(named) == identity(before), data.count == before.st_size
        else { throw LaunchAgentFailure.unsafeFile }
        try checkDirectory(directoryFD)
        return LaunchAgentFile(data: data, identity: identity(after))
    }
    func read() throws -> LaunchAgentFile? {
        guard let fd = try directoryFD(create: false) else { return nil }
        defer { Darwin.close(fd) }
        return try read(at: fd)
    }
    func create(_ data: Data) throws {
        guard data.count <= 16384, let fd = try directoryFD(create: true) else { throw LaunchAgentFailure.create }
        defer { Darwin.close(fd) }
        try checkDirectory(fd)
        let file = openat(fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw errno == EEXIST ? LaunchAgentFailure.conflict : .create }
        defer { Darwin.close(file) }
        let success = data.withUnsafeBytes { bytes -> Bool in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(file, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { return false }; offset += count
            }
            return true
        }
        guard success, fsync(file) == 0, fsync(fd) == 0, let saved = try read(at: fd), saved.data == data else { throw LaunchAgentFailure.create }
        // Failure intentionally retains any partial file; never delete an unknown replacement.
    }
    func remove(_ expected: LaunchAgentFile) throws {
        guard let fd = try directoryFD(create: false) else { throw LaunchAgentFailure.remove }
        defer { Darwin.close(fd) }
        guard try read(at: fd) == expected else { throw LaunchAgentFailure.conflict }
        try checkDirectory(fd)
        // POSIX has no inode-conditional unlink. The private owner-only directory
        // and immediate recheck narrow, but cannot eliminate, same-UID races.
        guard unlinkat(fd, name, 0) == 0, fsync(fd) == 0 else { throw LaunchAgentFailure.remove }
    }
    private func readAppInfo(_ url: URL, expected: stat) -> Data? {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }; defer { Darwin.close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0, identity(opened) == identity(expected) else { return nil }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0, errno == EINTR { continue }
            guard count >= 0, data.count + max(count, 0) <= 65536 else { return nil }
            if count == 0 { break }; data.append(contentsOf: buffer.prefix(count))
        }
        var after = stat(), named = stat()
        guard fstat(fd, &after) == 0, lstat(url.path, &named) == 0,
              identity(after) == identity(expected), identity(named) == identity(expected) else { return nil }
        return data
    }
    func appIsMacSoul(at url: URL) -> Bool? {
        var s = stat()
        if lstat(url.path, &s) != 0 { return errno == ENOENT ? nil : false }
        guard s.st_mode & S_IFMT == S_IFDIR else { return false }
        var path = URL(fileURLWithPath: "/")
        for component in url.pathComponents where component != "/" {
            path.appendPathComponent(component)
            guard lstat(path.path, &s) == 0, s.st_mode & S_IFMT == S_IFDIR else { return false }
        }
        for folder in ["Contents", "Contents/MacOS"] {
            guard lstat(url.appendingPathComponent(folder).path, &s) == 0, s.st_mode & S_IFMT == S_IFDIR else { return false }
        }
        let info = url.appendingPathComponent("Contents/Info.plist")
        guard lstat(info.path, &s) == 0, s.st_mode & S_IFMT == S_IFREG, s.st_size < 65536,
              let data = readAppInfo(info, expected: s),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              plist["CFBundleIdentifier"] as? String == "local.macsoul.app",
              let executable = plist["CFBundleExecutable"] as? String, !executable.isEmpty, !executable.contains("/"),
              executable != ".", executable != "..", !executable.contains("\0")
        else { return false }
        let main = url.appendingPathComponent("Contents/MacOS").appendingPathComponent(executable)
        return lstat(main.path, &s) == 0 && s.st_mode & S_IFMT == S_IFREG && s.st_mode & 0o111 != 0
    }
}
