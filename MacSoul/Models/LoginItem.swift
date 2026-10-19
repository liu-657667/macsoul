import Foundation
import ServiceManagement

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
