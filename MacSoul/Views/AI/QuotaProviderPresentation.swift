import Foundation

extension MacSoulLanguage {
    func quotaStatus(_ detail: QuotaProviderDetail) -> String {
        if detail.authorizationRequired { return text("Observer authorization pending") }
        if let session = detail.codexSession {
            let copy: (String, String)
            switch session {
            case .checking: copy = ("Checking Codex CLI…", "正在检查 Codex CLI…")
            case .handshaking: copy = ("Checking session protocol…", "正在检查会话协议…")
            case .reading: copy = ("Reading quota baseline…", "正在读取配额基线…")
            case .available: copy = ("Current session quota available", "当前会话配额可用")
            case .quotaUnavailable: copy = ("Connected · Quota unavailable or unreported", "已连接 · 配额不可用或未报告")
            case .quotaRequestFailed: copy = ("Quota request failed", "配额请求失败")
            case .cliUnavailable: copy = ("Codex CLI missing or unable to launch", "未找到 Codex CLI 或无法启动")
            case .handshakeFailed: copy = ("Session handshake failed", "会话握手失败")
            case .handshakeTimeout: copy = ("Session handshake timed out", "会话握手超时")
            case .requestTimeout: copy = ("Quota request timed out", "配额请求超时")
            case .methodUnsupported: copy = ("Required read-only method unsupported", "不支持所需的只读方法")
            case .invalidResponse: copy = ("Incompatible session response", "会话响应结构不兼容")
            case .communicationFailure: copy = ("Session communication interrupted", "会话通信中断")
            case .stopped: copy = ("Stopped", "已停止")
            }
            let message = self == .english ? copy.0 : copy.1
            return detail.connection == .reconnecting ? message + " · " + text("Reconnecting…") : message
        }
        if let capability = detail.claudeCapability {
            switch capability {
            case .notInstalled: return text("Not detected")
            case .detectedUnauthenticated: return text("Detected · Not authenticated")
            case .detectedNoSubscriptionQuota: return text("Subscription quota unavailable")
            case .unsupportedVersion: return text("Unsupported installed version")
            case .noVerifiedSource: return text("Detected · No verified quota source")
            case .requestFailed: return text("Request failed")
            case .available: break
            }
        }
        switch detail.connection {
        case .connecting: return text("Connecting…")
        case .available: return text("LIVE")
        case .reconnecting: return text("Reconnecting…")
        case .unavailable: return text("Quota unavailable")
        case .malformed: return text("Malformed quota response")
        case .stopped: return text("Stopped")
        }
    }
}

extension QuotaItem {
    func presentationSource(detail: QuotaProviderDetail?) -> String? {
        guard provider == .claude, mode == .live else { return source }
        guard !entirelyUnavailable else { return nil }
        switch detail?.claudeCapability {
        case .notInstalled, .noVerifiedSource, .unsupportedVersion: return nil
        default: return source
        }
    }

    func presentationWindows(now: Date, presentation: QuotaPresentation) -> [QuotaDisplayWindow] {
        displayWindows(now: now).filter { row in
            if mode == .live && presentation == .summary, case .unreported = row.state { return false }
            return true
        }
    }
}

// Derived UI values only; the Provider and alerts retain canonical consumed usage.
extension QuotaWindow {
    var remainingPercent: Double { 100 - usedPercent }
    var remainingProgress: Double { remainingPercent / 100 }
}
