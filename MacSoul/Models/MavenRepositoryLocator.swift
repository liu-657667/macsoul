import Foundation

enum MavenRepositorySource: String, Sendable {
    case userSettings, globalSettings, environmentOverride, defaultLocation
    var label: String {
        switch self {
        case .userSettings: "User Maven settings"
        case .globalSettings: "Global Maven settings"
        case .environmentOverride: "Explicit override"
        case .defaultLocation: "Default Maven location"
        }
    }
}
enum MavenLocationState: String, Sendable { case resolved, notFound, unresolved, unavailable }
struct MavenRepositoryLocation: Equatable, Sendable {
    let url: URL?
    let source: MavenRepositorySource
    let state: MavenLocationState
}
struct MavenDiscovery: Sendable {
    let location: MavenRepositoryLocation
    let executable: URL?
    let mavenHome: URL?
    let userSettingsFound: Bool
    let globalSettingsFound: Bool
    // Project config, JVM/MAVEN_OPTS parsing and shell contexts are intentionally absent.
}
protocol MavenRepositoryLocating: Sendable { func discover() -> MavenDiscovery }

struct MavenRepositoryLocator: MavenRepositoryLocating {
    let home: URL
    let environment: [String: String]
    init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
         environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.home = home.standardized; self.environment = environment
    }
    func discover() -> MavenDiscovery {
        let fm = FileManager.default
        let executable = ExecutableResolver.resolve("mvn", path: String((environment["PATH"] ?? "").prefix(32768)))
        // Home is an installation context, never treated as the repository itself.
        let installation = [environment["MAVEN_HOME"], environment["M2_HOME"]].compactMap { $0 }
            .first { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0).standardized }
            ?? executable?.deletingLastPathComponent().deletingLastPathComponent()
        let user = home.appendingPathComponent(".m2/settings.xml")
        let global = installation?.appendingPathComponent("conf/settings.xml")
        let userFound = fm.fileExists(atPath: user.path)
        let globalFound = global.map { fm.fileExists(atPath: $0.path) } ?? false
        var location: MavenRepositoryLocation?
        for (url, source) in [(Optional(user), MavenRepositorySource.userSettings), (global, .globalSettings)] {
            guard let url, fm.fileExists(atPath: url.path) else { continue }
            switch readLocalRepository(url) {
            case .absent: continue
            case .unresolved: location = .init(url: nil, source: source, state: .unresolved)
            case .unavailable: location = .init(url: nil, source: source, state: .unavailable)
            case .value(let value): location = resolve(value, source: source)
            }
            break // an unusable higher-priority override is not a license to guess another root
        }
        if location == nil { location = resolve(home.appendingPathComponent(".m2/repository").path, source: .defaultLocation) }
        return MavenDiscovery(location: location!, executable: executable, mavenHome: installation,
            userSettingsFound: userFound, globalSettingsFound: globalFound)
    }
    private func resolve(_ value: String, source: MavenRepositorySource) -> MavenRepositoryLocation {
        let expanded = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "${user.home}", with: home.path)
        guard !expanded.contains("${"), expanded.hasPrefix("/"), !expanded.contains("\0") else {
            return .init(url: nil, source: source, state: .unresolved)
        }
        let root = URL(fileURLWithPath: expanded).standardized
        // A configured repository cannot expand this feature into a whole-machine/runtime scan.
        let forbidden = ["/", "/Applications", "/Library", "/System", "/Users", "/Volumes", home.path, home.appendingPathComponent("Library").path]
        let installs = [".sdkman/candidates", ".pyenv/versions", ".goenv/versions", ".nvm/versions", ".docker"]
        guard !forbidden.contains(root.path), !installs.contains(where: {
            let path = home.appendingPathComponent($0).path
            return root.path == path || root.path.hasPrefix(path + "/")
        }), root.lastPathComponent != "Docker.raw" else { return .init(url: nil, source: source, state: .unresolved) }
        do {
            var ancestor = root
            while ancestor.path != "/" {
                if try ancestor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                    return .init(url: root, source: source, state: .unavailable)
                }
                ancestor.deleteLastPathComponent()
            }
            let v = try root.resourceValues(forKeys: [.isDirectoryKey])
            return .init(url: root, source: source, state: v.isDirectory == true ? .resolved : .unavailable)
        } catch {
            let e = error as NSError
            let missing = e.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(e.code)
            return .init(url: root, source: source, state: missing ? .notFound : .unavailable)
        }
    }

    private enum SettingsValue { case absent, value(String), unresolved, unavailable }
    private func readLocalRepository(_ url: URL) -> SettingsValue {
        // Bounded read, no external entities. Only localRepository text is retained;
        // servers/credentials and raw parser errors are never stored, logged or published.
        var ancestor = url
        while ancestor.path != "/" {
            if (try? ancestor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true { return .unavailable }
            ancestor.deleteLastPathComponent()
        }
        guard let stream = InputStream(url: url) else { return .unavailable }
        stream.open(); defer { stream.close() }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while data.count <= 65_536 {
            let count = stream.read(&buffer, maxLength: min(buffer.count, 65_537 - data.count))
            if count < 0 { return .unavailable }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        guard data.count <= 65_536 else { return .unresolved }
        // Reject DTD/entities before XMLParser; no entity expansion or file/network loading.
        if data.range(of: Data("<!DOCTYPE".utf8), options: []) != nil || data.range(of: Data("<!ENTITY".utf8), options: []) != nil { return .unresolved }
        let parser = XMLParser(data: data), delegate = MavenSettingsDelegate()
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.ambiguous else { return .unresolved }
        guard let value = delegate.repository, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .absent }
        return .value(value)
    }
}
private final class MavenSettingsDelegate: NSObject, XMLParserDelegate {
    private var elements: [String] = []
    private var text = ""
    private(set) var repository: String?
    private(set) var ambiguous = false
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        ambiguous = true; parser.abortParsing()
    }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        ambiguous = true; parser.abortParsing()
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        elements.append(elementName)
        if elements.count > 64 { ambiguous = true; parser.abortParsing() }
        if elements == ["settings", "localRepository"] { text = "" }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if elements == ["settings", "localRepository"] {
            if text.utf8.count + string.utf8.count > 4096 { ambiguous = true; parser.abortParsing() }
            else { text += string }
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elements == ["settings", "localRepository"] {
            if repository != nil { ambiguous = true }
            repository = text
        }
        if !elements.isEmpty { elements.removeLast() }
    }
}
