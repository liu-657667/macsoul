import Foundation

extension MacSoulLanguage {
    // Cleaner copy is separate from model keys and from other feature wording.
    func cleanerText(_ key: String) -> String {
        self == .chinese ? Self.cleanerChinese[key] ?? text(key) : key
    }
    func cleanerBytes(_ bytes: Int64) -> String {
        let value = Double(bytes) / 1_073_741_824
        return value.formatted(.number.locale(locale).precision(.fractionLength(2))) + " GiB"
    }
    func cleanerMarkerBytes(_ bytes: Int64) -> String {
        // Small negative-cache markers must not round to a misleading 0.00 GiB.
        if bytes < 1024 { return "\(bytes) " + (self == .chinese ? "字节" : "bytes") }
        let divisor: Double = bytes < 1_048_576 ? 1024 : bytes < 1_073_741_824 ? 1_048_576 : 1_073_741_824
        let unit = bytes < 1_048_576 ? "KiB" : bytes < 1_073_741_824 ? "MiB" : "GiB"
        return (Double(bytes) / divisor).formatted(.number.locale(locale).precision(.fractionLength(2))) + " " + unit
    }
    func cleanerSummary(_ snapshot: CleanerSnapshot) -> String {
        if snapshot.state == .notRun || snapshot.state == .scanning { return cleanerText(snapshot.state.label) }
        guard let bytes = snapshot.estimatedBytes else { return cleanerText(snapshot.state.label) }
        let prefix = self == .chinese ? "\(snapshot.foundCount) 个类别" : "\(snapshot.foundCount) categories"
        let qualifier = snapshot.state == .available ? "Estimated disk usage" : "Incomplete estimate"
        return "\(cleanerText(snapshot.state.label)) · \(prefix) · \(cleanerText(qualifier)) \(cleanerBytes(bytes))"
    }
    func cleanerLocationState(_ state: CleanerLocationState) -> String {
        let label = switch state { case .resolved: "Resolved"; case .notFound: "Not found"; case .unresolved: "Unresolved"; case .unavailable: "Unavailable" }
        return cleanerText(label)
    }
    func cleanerResolutionDescription(_ resolution: ResolvedCleanerTarget) -> String {
        let source = text("Source") + ": " + cleanerText(resolution.source.label)
        var components: [String] = [source]
        if resolution.source.isFallback {
            components.append(cleanerText("Default / fallback"))
        }
        components.append(cleanerLocationState(resolution.state))
        return components.joined(separator: " · ")
    }
    func cleanerMavenLocationDescription(_ location: MavenRepositoryLocation) -> String {
        let stateKey: String
        switch location.state {
        case .resolved: stateKey = "Resolved"
        case .notFound: stateKey = "Not found"
        case .unresolved: stateKey = "Unresolved"
        case .unavailable: stateKey = "Unavailable"
        }
        let source = text("Source") + ": " + cleanerText(location.source.label)
        return [source, cleanerText(stateKey)].joined(separator: " · ")
    }
    func cleanerCounts(_ counts: CleanerCounters) -> String {
        self == .chinese
            ? "\(counts.fileCount) 个文件 · \(counts.directoryCount) 个目录 · 跳过 \(counts.skippedSymlinkCount) 个链接 · \(counts.inaccessibleCount) 项无法访问 · \(counts.fallbackFileCount) 项逻辑大小回退"
            : "\(counts.fileCount) files · \(counts.directoryCount) directories · \(counts.skippedSymlinkCount) links skipped · \(counts.inaccessibleCount) inaccessible · \(counts.fallbackFileCount) logical-size fallbacks"
    }
    func cleanerKind(_ kind: CleanerPreviewKind) -> String {
        let key = switch kind { case .directory: "Directory"; case .file: "File"; case .symlink: "Symbolic link · not followed"; case .other: "Other" }
        return cleanerText(key)
    }
    private static let cleanerChinese: [String: String] = [
        "View contents": "查看内容", "Content preview": "内容预览", "Close": "关闭", "Back": "返回",
        "Name": "名称", "Type": "类型", "Estimated Usage": "估算占用", "Sort": "排序",
        "Size descending": "按大小降序", "Name ascending": "按名称升序", "Open directory": "进入目录",
        "Directory": "文件夹", "File": "文件", "Symbolic link · not followed": "符号链接 · 未跟随", "Other": "其他",
        "Not followed": "未跟随", "Not estimated": "未估算", "Calculating…": "正在计算…", "Cancel preview": "取消预览",
        "Read-only preview. MacSoul does not modify or delete these files.": "只读预览。MacSoul 不会修改或删除这些文件。",
        "This directory is empty.": "此目录为空。", "No preview entries available.": "没有可显示的预览条目。",
        "Preview limited to 2,000 direct children. Other entries are omitted; size order applies only to the displayed entries.": "预览最多显示 2,000 个直系子项，其余条目未显示；大小排序仅适用于已显示条目。",
        "Sizes use the existing allocation estimate. Directory counts include descendants; links are not followed. Changing files and shared blocks can affect estimates.": "大小沿用已分配空间估算，不跟随符号链接。文件变化与共享数据块可能影响估算。",
        "This category estimates matching marker files only; other entries have no category size.": "此类别只估算匹配的标记文件，其余条目不显示类别占用大小。",
        "This preview reuses the last Docker statistics. Scan is required for new data; no VM filesystem is browsed.": "此预览复用最近的 Docker 统计。新数据需要点击扫描，不浏览虚拟机文件系统。",
        "Context": "上下文",
        "Xcode default location": "Xcode 默认位置", "Gradle default location": "Gradle 默认位置",
        "npm cache environment": "npm 缓存环境配置", "npm config": "npm 配置", "npm default location": "npm 默认位置",
        "Homebrew default location": "Homebrew 默认位置", "Default / fallback": "默认／回退位置",
        "Default candidate · discovery not run": "默认候选位置 · 尚未发现",
        "Summary combines file allocation estimates and local Docker logical usage; remote Docker is excluded.": "总量合计文件分配空间估算与本地 Docker 逻辑用量，不含远程 Docker。",
        "Docker not queried": "尚未查询 Docker", "Querying Docker…": "正在查询 Docker…",
        "Docker CLI not found": "未发现 Docker CLI", "Docker context unavailable": "Docker 上下文不可用",
        "CLI detected · Docker Engine unavailable or query failed": "已发现 CLI · Docker Engine 不可用或查询失败",
        "Remote Docker Context · excluded from local total": "远程 Docker 上下文 · 不计入本机总量",
        "Docker response unsupported or invalid": "Docker 返回格式不支持或无效",
        "Docker Engine": "Docker Engine", "Docker CLI": "Docker CLI",
        "Images": "镜像", "Containers": "容器", "Local Volumes": "本地卷", "Build Cache": "构建缓存",
        "Docker-reported reclaimable estimate": "Docker 报告的可回收估算", "Total logical usage": "逻辑用量合计",
        "Docker logical usage is not VM-file allocated space or a promise of safe deletion. No VM files are scanned.": "Docker 逻辑用量不是虚拟磁盘的实际分配空间，也不代表可以安全删除。不会扫描虚拟机文件。",
        "Remote storage was not queried and is excluded from this Mac’s total.": "未查询远程存储，不计入这台 Mac 的总量。",
        "Repository path unresolved": "仓库路径未解析",
        "Maven Failed Download Markers": "Maven 下载失败标记",
        "Maven Resolver markers for unsuccessful dependency or plugin resolution/downloads.": "Maven Resolver 在依赖或插件解析、下载未成功后留下的状态标记。",
        "Removing markers yourself may prompt another remote attempt; it does not guarantee a fix. This is negative-cache diagnostics, not a large-file cleanup.": "自行移除标记后可能重新尝试访问远程仓库，但不保证解决问题。这是失败下载与负缓存诊断，不是大文件清理。",
        "User Maven settings": "用户 Maven 配置", "Global Maven settings": "Maven 全局配置",
        "Explicit override": "显式覆盖", "Default Maven location": "Maven 默认位置",
        "Resolved": "已解析", "Unresolved": "未解析", "Unavailable": "不可用",
        "Repository discovery runs only when Scan is requested.": "点击扫描时才定位 Maven 仓库。",
        "Included in repository usage; not added to total again.": "已包含在仓库占用中，不重复计入总量。",
        "Read only": "只读", "Not scanned": "未扫描", "Scan": "开始扫描", "Rescan": "再次扫描",
        "Cancel scan": "取消扫描", "Scanning…": "扫描中…", "Complete": "完成",
        "Estimated disk usage": "估算占用空间", "Incomplete estimate": "未完成的估算",
        "Low risk": "低风险", "Caution": "谨慎", "High risk": "高风险",
        "Not found": "未找到", "Inaccessible": "无法访问", "Partial": "部分完成",
        "Cancelled": "已取消", "Scan failed": "扫描失败", "Reveal in Finder": "在 Finder 中显示",
        "Copy path": "复制路径", "Path copied": "路径已复制", "Impact": "影响", "Updated": "更新时间",
        "Read-only developer cache scan. MacSoul never deletes files.": "只读扫描开发缓存。MacSoul 不会删除任何文件。",
        "Only an explicit Scan starts traversal. Leaving this page does not cancel it. Preview, sleep or app exit cancels the scan.": "只有点击开始扫描才会遍历目录。离开本页不会取消；切换开发预览、系统睡眠或退出应用会取消扫描。",
        "Allocated file bytes where available, otherwise logical size; directories are not added. APFS clones, sparse files, hard links and shared data mean this estimate is not reclaimable space.": "优先统计文件已分配字节，缺失时退回逻辑大小，不累计目录字节。APFS 克隆、稀疏文件、硬链接和共享数据使估算值不等于可释放空间。",
        "Risk describes usual recovery cost if you remove the directory yourself; it is not a safety guarantee.": "风险描述的是自行删除目录后的通常恢复成本和影响，不是安全保证。",
        "Symlink roots (including linked ancestors) are not scanned. Internal links are skipped.": "根目录及祖先含符号链接时不扫描；内部符号链接会跳过。",
        "Preview uses Mock fixtures; no filesystem scan runs.": "预览使用模拟场景，不执行文件扫描。",
        "No Mock scan results in this fixture.": "当前模拟场景没有扫描结果。",
        "Xcode DerivedData": "Xcode 派生数据", "Gradle Cache": "Gradle 缓存",
        "Maven Local Repository": "Maven 本地仓库", "npm Cache": "npm 缓存", "Homebrew Download Cache": "Homebrew 下载缓存",
        "Derived build data produced by Xcode.": "Xcode 构建产生的派生数据。",
        "Removing it yourself causes reindexing and rebuilding; the first build may be slower.": "自行删除后会重新索引和构建，首次构建可能变慢。",
        "Gradle dependencies, build caches and transform results.": "Gradle 依赖、构建缓存与转换结果。",
        "Removing it yourself may require downloads and regeneration; offline builds may be affected.": "自行删除后可能需要重新下载及生成，离线构建可能受影响。",
        "Maven local dependency repository, including manually installed artifacts.": "Maven 本地依赖仓库，包含手动安装的本地构件。",
        "Removing it yourself may lose local artifacts and break offline builds; remote dependencies need downloading again.": "自行删除可能丢失本地构件并导致离线构建失败，远程依赖需重新下载。",
        "npm download cache only; user configuration is excluded.": "仅 npm 下载缓存，不包含用户配置。",
        "Removing it yourself usually requires downloads on the next install. No fallback to the whole .npm directory.": "自行删除后通常需在下次安装时重新下载，不回退扫描整个 .npm 目录。",
        "Homebrew download cache.": "Homebrew 下载缓存。",
        "Removing it yourself may require downloads for future installs or upgrades.": "自行删除后，后续安装或升级可能需要重新下载。"
    ]
}
