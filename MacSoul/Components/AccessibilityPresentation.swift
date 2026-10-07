import Foundation

// Read-only metric groups speak the same values as their visible text/bars.
// Non-numeric states never become 0% or 100% for accessibility.
enum AccessibilityPresentation {
    static func metricValue(metric: PercentMetric, language: MacSoulLanguage,
                            override: String? = nil, empty: String = "Unavailable",
                            attention: String? = nil) -> String {
        let value = language.text(override ?? (metric.usedPercent == nil ? empty : metric.label))
        return value + (attention.map { " · " + language.text($0) } ?? "")
    }
    static func quotaValue(window: QuotaDisplayWindow, now: Date, language: MacSoulLanguage,
                           presentation: QuotaPresentation) -> String {
        QuotaWindowView.statusLabel(for: window, now: now, language: language, presentation: presentation)
    }
}
