import Foundation

extension MacSoulLanguage {
    func quotaStatus(_ detail: QuotaProviderDetail) -> String {
        if detail.authorizationRequired { return text("Observer authorization pending") }
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
