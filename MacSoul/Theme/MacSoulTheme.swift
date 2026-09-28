import SwiftUI

enum MacSoulTheme {
    enum Spacing {
        static let compact: CGFloat = 4
        static let tight: CGFloat = 8
        static let regular: CGFloat = 12
        static let card: CGFloat = 16
        static let section: CGFloat = 24
    }

    enum Radius {
        static let tile: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum Size {
        static let soulGlyph: CGFloat = 64
        static let soulArtwork: CGFloat = 96
        static let soulPopover: CGFloat = 48
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.86)
    }

    static var secondaryBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static func windowBackgroundColor(for scheme: ColorScheme) -> NSColor {
        let name: NSAppearance.Name = scheme == .dark ? .darkAqua : .aqua
        guard let appearance = NSAppearance(named: name) else {
            return .windowBackgroundColor
        }
        var resolved = NSColor.windowBackgroundColor
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor.windowBackgroundColor.usingColorSpace(.deviceRGB) ?? .windowBackgroundColor
        }
        return resolved
    }
}

enum MacSoulAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Follow macOS"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var appAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

struct MacSoulAppearanceModifier: ViewModifier {
    @AppStorage("macsoul.appearance") private var appearance = MacSoulAppearance.system.rawValue

    func body(content: Content) -> some View {
        content
            .onAppear { apply(appearance) }
            .onChange(of: appearance) { apply($0) }
    }

    private func apply(_ value: String) {
        let selected = MacSoulAppearance(rawValue: value) ?? .system
        let requested = selected.appAppearance
        if NSApp.appearance?.name != requested?.name {
            NSApp.appearance = requested
        }
    }
}

extension View {
    func macSoulAppearance() -> some View { modifier(MacSoulAppearanceModifier()) }
}

enum MacSoulLanguage: String, CaseIterable, Identifiable {
    case english, chinese

    var id: String { rawValue }
    var label: String { self == .english ? "English" : "简体中文" }
    var locale: Locale { Locale(identifier: self == .english ? "en_US" : "zh_CN") }

    func text(_ key: String) -> String {
        if self == .english { return Self.englishOverrides[key] ?? key }
        return Self.chineseText[key] ?? key
    }

    func used(_ percent: Int) -> String {
        self == .english ? "\(percent)% used" : "已用 \(percent)%"
    }

    private static let englishOverrides = [
        "演示数据，未连接系统采样": "Demo data; no system sampler connected"
    ]

    private static let chineseText: [String: String] = [
        "Overview": "总览", "System": "系统", "Network": "网络", "AI Coding": "AI 编程",
        "Dev": "开发环境", "Cleaner": "清理", "Settings": "设置", "Soul": "灵魂",
        "MOCK DATA": "模拟数据", "MOCK DATA · No live sampling or quota provider": "模拟数据 · 未连接实时采样或配额服务",
        "CPU": "处理器", "Memory used": "内存已用", "Disk": "磁盘", "Battery": "电池",
        "Pressure": "内存压力", "Memory pressure": "内存压力", "Public IP": "公网 IP",
        "Region": "地区", "Proxy": "代理", "Proxy hint": "代理线索", "Tunnel": "隧道",
        "Tunnel hint": "隧道线索", "IP": "IP", "Unavailable": "不可用",
        "Not reported": "未报告", "Request failed": "请求失败", "Quota unavailable": "配额不可用",
        "Fresh": "新鲜", "Stale": "已过期", "Not applicable": "不适用",
        "1 week": "1 周", "5h": "5 小时", "Source": "来源", "Updated": "更新于",
        "Bundled fixture": "内置场景", "Bundled failure fixture": "内置失败场景",
        "MOCK": "模拟", "LIVE": "实时", "Normal · Mock": "正常 · 模拟",
        "Critical · Mock": "严重 · 模拟", "Unknown · Mock": "未知 · 模拟",
        "Example region": "示例地区", "Example process · Mock": "示例进程 · 模拟",
        "21 · Mock": "21 · 模拟", "18 · Mock": "18 · 模拟",
        "Calm · Mock": "平静 · 模拟", "Busy · Mock": "忙碌 · 模拟",
        "Overload · Mock": "过载 · 模拟", "Memory pressure · Mock": "内存压力 · 模拟",
        "Low battery · Mock": "低电量 · 模拟", "Resting · Mock": "休息 · 模拟",
        "Recovering · Mock": "恢复中 · 模拟", "演示数据，未连接系统采样": "演示数据，未连接系统采样",
        "No live provider": "未连接实时服务", "No system sampler is connected.": "未连接系统采样器。",
        "No external probe is connected.": "未连接外部探测。",
        "Read-only scan": "只读扫描", "Not run": "未运行", "Cleaner scan not run": "尚未运行清理扫描",
        "Day 1 uses mock values. Real scanning is intentionally disabled.": "当前使用模拟数据，真实扫描尚未启用。",
        "Dev Environment": "开发环境", "Listening Ports": "监听端口",
        "Quota Monitor · MOCK DATA": "配额监视 · 模拟数据",
        "Shows applicable 5-hour and 1-week used quota. No live provider is connected.": "显示适用的 5 小时与 1 周已用配额；未连接实时服务。",
        "System · MOCK DATA": "系统 · 模拟数据", "Network · MOCK DATA": "网络 · 模拟数据",
        "Runtimes — Mock": "运行环境 · 模拟", "Listening Ports — Mock": "监听端口 · 模拟",
        "Current build capabilities": "当前构建能力", "Data mode": "数据模式",
        "Bundled Mock": "内置模拟", "Live system sampling": "实时系统采样",
        "Live quota providers": "实时配额服务", "Cleaner deletion": "清理删除",
        "Not connected": "未连接", "Not available": "不可用",
        "The fixture selector changes local demo data. It does not enable live collection or account access.": "场景选择只切换本地演示数据，不会启用实时采集或账户访问。",
        "App appearance": "应用外观", "Appearance": "外观", "Follow macOS": "跟随 macOS",
        "Light": "浅色", "Dark": "深色",
        "Changes MacSoul windows only; the macOS appearance stays as it is.": "仅改变 MacSoul 窗口，不修改 macOS 外观。",
        "Developer preview scenarios": "开发预览场景", "Fixture": "场景",
        "Menu Bar artwork · DRAFT": "菜单栏图案 · 草稿",
        "18 pt template candidate is active; small-size artwork remains DRAFT.": "当前使用 18 点模板候选；小尺寸图案仍为草稿。",
        "Open MacSoul": "打开 MacSoul", "Quit MacSoul": "退出 MacSoul",
        "Normal": "正常", "Busy": "忙碌", "CPU overload": "CPU 过载",
        "CPU recovery": "CPU 恢复",
        "Low battery": "低电量", "Resting": "休息", "Quota 95%": "配额 95%",
        "Codex: Week only": "Codex：仅周配额", "Claude: Week only": "Claude：仅周配额",
        "Codex: 5h not reported": "Codex：5 小时未报告",
        "Claude: Week not reported": "Claude：周配额未报告",
        "Valid 0% quota": "有效的 0% 配额", "Quota request failed": "配额请求失败",
        "Stale / offline": "过期 / 离线", "No battery": "无电池"
    ]
}

private struct MacSoulLanguageKey: EnvironmentKey {
    static let defaultValue = MacSoulLanguage.english
}

extension EnvironmentValues {
    var macSoulLanguage: MacSoulLanguage {
        get { self[MacSoulLanguageKey.self] }
        set { self[MacSoulLanguageKey.self] = newValue }
    }
}
