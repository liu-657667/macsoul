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

    static var supportingText: Color { Color.primary.opacity(0.72) }

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
        "演示数据，未连接系统采样": "Demo data; no system sampler connected",
        "今天挺轻松。": "Taking it easy today.",
        "我开始认真工作了。": "Time to get to work.",
        "我的脑子要爆炸了。": "My brain is about to explode.",
        "呼……终于安静了。": "Phew… finally quiet again.",
        "我的胃快撑爆了。": "My stomach is about to burst.",
        "我只剩一点力气了……": "I'm almost out of energy…",
        "让我安静待一会儿。": "Let me rest a little."
    ]

    private static let chineseText: [String: String] = [
        "Overview": "总览", "System": "系统", "Network": "网络", "AI Coding": "AI 编程",
        "Dev": "开发环境", "Cleaner": "清理", "Settings": "设置", "Soul": "灵魂",
        "MOCK DATA": "模拟数据", "MOCK DATA · No live sampling or quota provider": "模拟数据 · 未连接实时采样或配额服务",
        "CPU / Memory LIVE · other data MOCK": "处理器 / 内存实时 · 其他数据模拟",
        "CPU / MEMORY LIVE · OTHER MOCK": "处理器 / 内存实时 · 其他模拟",
        "CPU and memory: Live · Disk and battery: Mock": "处理器与内存：实时 · 磁盘与电池：模拟",
        "System metrics LIVE · other sections MOCK": "系统指标实时 · 其他板块模拟",
        "SYSTEM LIVE · OTHER MOCK": "系统实时 · 其他模拟",
        "System metrics: Live · AI, Network, Dev: Mock": "系统指标：实时 · AI、网络、开发环境：模拟",
        "SYSTEM + DEV LIVE · AI / NETWORK MOCK": "系统 / 开发环境实时 · AI / 网络模拟",
        "System and Dev: Live · AI and Network: Mock": "系统与开发环境：实时 · AI 与网络：模拟",
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
        "Normal · Live": "正常 · 实时", "Warning · Live": "警告 · 实时",
        "Critical · Live": "严重 · 实时", "Unknown · Live": "未知 · 实时",
        "Monitoring · Live": "监测中 · 实时",
        "Observing · Live": "观察中 · 实时", "Calm · Live": "平静 · 实时",
        "CPU calm · Live": "处理器平稳 · 实时", "CPU recovering · Live": "处理器恢复中 · 实时",
        "Stressed · Live": "压力较高 · 实时", "Overload · Live": "过载 · 实时",
        "Memory warning · Live": "内存警告 · 实时", "Memory critical · Live": "内存严重 · 实时",
        "Recovering · Live": "恢复中 · 实时",
        "Waiting for a valid system sample.": "等待有效的系统采样。",
        "System load is steady.": "系统负载平稳。",
        "CPU is steady; memory pressure is still being monitored.": "处理器负载平稳；内存压力仍在监测中。",
        "CPU is recovering; memory pressure is still being monitored.": "处理器负载正在恢复；内存压力仍在监测中。",
        "CPU load remains high.": "处理器负载仍较高。",
        "CPU load remains critical.": "处理器负载仍处于严重状态。",
        "Memory pressure remains elevated.": "内存压力仍较高。",
        "Memory pressure remains critical.": "内存压力仍处于严重状态。",
        "System load is recovering.": "系统负载正在恢复。",
        "Example region": "示例地区", "Example process · Mock": "示例进程 · 模拟",
        "21 · Mock": "21 · 模拟", "18 · Mock": "18 · 模拟",
        "Calm · Mock": "平静 · 模拟", "Busy · Mock": "忙碌 · 模拟",
        "Overload · Mock": "过载 · 模拟", "Memory pressure · Mock": "内存压力 · 模拟",
        "Low battery · Mock": "低电量 · 模拟", "Resting · Mock": "休息 · 模拟",
        "Near limit": "接近上限",
        "Recovering · Mock": "恢复中 · 模拟", "演示数据，未连接系统采样": "演示数据，未连接系统采样",
        "No live provider": "未连接实时服务", "No system sampler is connected.": "未连接系统采样器。",
        "No external probe is connected.": "未连接外部探测。",
        "Read-only scan": "只读扫描", "Not run": "未运行", "Cleaner scan not run": "尚未运行清理扫描",
        "Day 1 uses mock values. Real scanning is intentionally disabled.": "当前使用模拟数据，真实扫描尚未启用。",
        "Dev Environment": "开发环境", "Listening Ports": "监听端口",
        "Dev Environment · LIVE": "开发环境 · 实时", "Dev Environment · MOCK": "开发环境 · 模拟",
        "Runtimes": "运行时", "Refresh": "刷新", "Port": "端口", "Bind": "绑定地址",
        "Copy": "复制", "Copy Port": "复制端口", "Copy PID": "复制 PID", "Actions": "操作",
        "Current-user-visible TCP listeners": "当前用户可见的 TCP 监听端口",
        "No visible TCP listeners": "没有可见的 TCP 监听端口",
        "Developer TCP Listeners": "开发相关 TCP 监听端口",
        "No developer TCP listeners found": "未发现开发相关监听端口",
        "Show all user-visible listeners": "显示全部当前用户可见端口",
        "Available": "可用", "Not found": "未发现", "Detection timed out": "检测超时",
        "Unresolved default": "默认版本无法解析",
        "Collection failed": "采集失败", "Unrecognized output": "输出无法解析",
        "Current detection context": "当前检测上下文", "More in Dev": "更多请见开发环境",
        "Different detection contexts resolve different versions.": "不同检测上下文解析到了不同版本。",
        "Live developer environment": "实时开发环境",
        "Runtimes and TCP listeners": "运行时与 TCP 监听端口",
        "Live System includes System and Dev Environment. AI and Network remain Mock.": "实时系统模式包含系统指标和开发环境；AI 与网络仍为模拟数据。",
        "Quota Monitor · MOCK DATA": "配额监视 · 模拟数据",
        "Shows applicable 5-hour and 1-week used quota. No live provider is connected.": "显示适用的 5 小时与 1 周已用配额；未连接实时服务。",
        "System · MOCK DATA": "系统 · 模拟数据", "Network · MOCK DATA": "网络 · 模拟数据",
        "System · CPU / MEMORY LIVE": "系统 · 处理器 / 内存实时",
        "System · LIVE": "系统 · 实时",
        "Memory used / total": "内存已用 / 总量", "Disk · Mock": "磁盘 · 模拟", "Battery · Mock": "电池 · 模拟",
        "Disk used / total": "磁盘已用 / 总量", "Disk sampling…": "正在读取磁盘…",
        "Disk unavailable": "磁盘数据不可用", "Sampling…": "采样中…",
        "Charge state": "充电状态", "External power": "外部电源",
        "Charging": "充电中", "Discharging": "放电中", "Full": "已充满",
        "Connected": "已连接", "Disconnected": "未连接",
        "Top Developer Processes": "开发进程资源排行", "Process": "进程", "Memory": "内存",
        "Process sampling…": "正在采集进程…", "Process collection unavailable": "进程采集不可用",
        "No developer processes found": "未发现开发相关进程",
        "Process CPU is per logical CPU over two samples; a multicore process can exceed 100%. First CPU sample is unknown.": "进程 CPU 以两次采样的单个逻辑核心为 100%；多核进程可超过 100%。首次采样为未知。",
        "Disk uses root volume total minus available bytes; APFS and purgeable space may differ from Storage Settings.": "磁盘使用启动根卷总量减可用字节；APFS 和可清除空间可能使其与系统储存设置不同。",
        "Memory used estimate: physical RAM minus free and file-backed pages; pressure is independent.": "内存已用为物理内存减去空闲及文件映射页的估算值；内存压力单独监测。",
        "CPU is host-wide busy time between samples; first sample is unknown. Memory pressure stays unknown until macOS reports an event.": "处理器为两次采样间全机忙碌时间；首次采样未知。内存压力在 macOS 发出事件前保持未知。",
        "Runtimes — Mock": "运行环境 · 模拟", "Listening Ports — Mock": "监听端口 · 模拟",
        "Current build capabilities": "当前构建能力", "Data mode": "数据模式",
        "Bundled Mock": "内置模拟", "Live system sampling": "实时系统采样",
        "Partial Live + Mock": "部分实时 + 模拟", "CPU and memory only": "仅处理器与内存",
        "CPU, memory, disk, battery, processes": "处理器、内存、磁盘、电池、进程",
        "System data source": "系统数据来源", "Mode": "模式",
        "Developer Preview": "开发预览", "Live System": "实时系统",
        "Live System uses native CPU and memory only. Other sections keep Mock data.": "实时系统仅采集原生处理器与内存数据；其他板块继续使用模拟数据。",
        "Live System uses native system metrics. AI, Network and Dev keep Mock data.": "实时系统采集原生系统指标；AI、网络和开发环境继续使用模拟数据。",
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
