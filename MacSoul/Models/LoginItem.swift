import Foundation
import ServiceManagement

// Read system state on refresh. Mutation is reachable only from an explicit
// Settings action; neither init, refresh nor Preview/Live starts registration.
enum LoginItemState: Equatable {
    case enabled, disabled, requiresApproval, unavailable
    var isRegistered: Bool { self == .enabled || self == .requiresApproval }
    func label(_ language: MacSoulLanguage) -> String {
        switch self {
        case .enabled: language == .english ? "Enabled" : "已启用"
        case .disabled: language == .english ? "Disabled" : "已关闭"
        case .requiresApproval: language == .english ? "Approval required in System Settings" : "需要在系统设置中确认"
        case .unavailable: language == .english ? "Unavailable" : "不可用"
        }
    }
    static func map(_ status: SMAppService.Status) -> Self {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
}
@MainActor protocol LoginItemManaging {
    var state: LoginItemState { get }
    func register() throws
    func unregister() throws
}
@MainActor struct NativeLoginItemManager: LoginItemManaging {
    var state: LoginItemState { .map(SMAppService.mainApp.status) }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}
@MainActor final class LoginItemController: ObservableObject {
    @Published private(set) var state: LoginItemState
    @Published private(set) var operationFailed = false
    private let manager: any LoginItemManaging
    init(manager: any LoginItemManaging) {
        self.manager = manager
        state = manager.state
    }
    func refresh() { state = manager.state }
    func setEnabled(_ enabled: Bool) {
        refresh()
        guard state != .unavailable, enabled != state.isRegistered else { return }
        operationFailed = false
        do {
            if enabled { try manager.register() } else { try manager.unregister() }
        } catch { operationFailed = true } // No raw system error/personal path in UI/log.
        refresh() // Do not optimistically fabricate the requested state.
    }
}
