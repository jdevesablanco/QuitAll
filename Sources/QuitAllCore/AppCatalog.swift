import AppKit

/// Grupos de los desplegables. Salen de `LSApplicationCategoryType` y se pueden cambiar a mano por app.
public enum AppCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case browsers, communication, productivity, music, video, design, developer, education, games, utilities, system, other
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .browsers: return tr("Navegadores", "Browsers")
        case .communication: return tr("Comunicación", "Communication")
        case .productivity: return tr("Productividad", "Productivity")
        case .music: return tr("Música y audio", "Music & Audio")
        case .video: return tr("Vídeo, foto y ocio", "Video, Photo & Entertainment")
        case .design: return tr("Diseño", "Design")
        case .developer: return tr("Desarrollo", "Developer Tools")
        case .education: return tr("Educación", "Education")
        case .games: return tr("Juegos", "Games")
        case .utilities: return tr("Utilidades", "Utilities")
        case .system: return tr("Sistema", "System")
        case .other: return tr("Otras", "Other")
        }
    }

    public var symbol: String {
        switch self {
        case .browsers: return "globe"
        case .communication: return "bubble.left.and.bubble.right"
        case .productivity: return "doc.text"
        case .music: return "music.note"
        case .video: return "play.rectangle"
        case .design: return "paintbrush"
        case .developer: return "hammer"
        case .education: return "graduationcap"
        case .games: return "gamecontroller"
        case .utilities: return "wrench.and.screwdriver"
        case .system: return "gearshape"
        case .other: return "square.grid.2x2"
        }
    }

    /// `public.app-category.*` → grupo.
    public static func from(lsCategory: String?) -> AppCategory? {
        guard let raw = lsCategory?.lowercased(), raw.hasPrefix("public.app-category.") else { return nil }
        let c = String(raw.dropFirst("public.app-category.".count))
        if c.hasSuffix("-games") || c == "games" { return .games }
        switch c {
        case "productivity", "business", "finance", "reference": return .productivity
        case "social-networking": return .communication
        case "music": return .music
        case "video", "photography", "entertainment": return .video
        case "graphics-design": return .design
        case "developer-tools": return .developer
        case "education": return .education
        case "utilities": return .utilities
        default: return .other
        }
    }

    /// Apps muy comunes cuya categoría declarada no ayuda (Slack dice «business», Mail «productivity»…).
    static let known: [String: AppCategory] = [
        "com.tinyspeck.slackmacgap": .communication, "us.zoom.xos": .communication, "com.microsoft.teams2": .communication,
        "com.microsoft.teams": .communication, "com.apple.mail": .communication, "com.apple.MobileSMS": .communication,
        "com.apple.FaceTime": .communication, "net.whatsapp.WhatsApp": .communication, "ru.keepcoder.Telegram": .communication,
        "com.hnc.Discord": .communication, "com.microsoft.Outlook": .communication, "org.whispersystems.signal-desktop": .communication,
        "com.spotify.client": .music, "com.apple.Music": .music, "com.apple.podcasts": .music, "com.apple.GarageBand10": .music,
        "com.apple.dt.Xcode": .developer, "com.microsoft.VSCode": .developer, "com.apple.Terminal": .developer,
        "com.googlecode.iterm2": .developer, "dev.warp.Warp-Stable": .developer,
    ]
}

/// Una app instalada o abierta, tal como la ve QuitAll.
public struct AppEntry: Identifiable, Hashable, Sendable {
    public var bundleID: String
    public var name: String
    public var url: URL
    public var lsCategory: String?
    public var detected: AppCategory          // categoría deducida (sin la elegida a mano)
    public var id: String { bundleID }

    public func category(overrides: [String: String]) -> AppCategory {
        overrides[bundleID].flatMap(AppCategory.init(rawValue:)) ?? detected
    }
}

public enum AppCatalog {
    /// Carpetas donde buscar apps instaladas (un nivel de subcarpetas: Utilidades, «Adobe …», etc.).
    static var searchRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["/Applications", "/System/Applications", home.appendingPathComponent("Applications").path]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Bundle IDs de los navegadores: las apps que saben abrir https (LSApplicationCategoryType no tiene «navegador»).
    static let browserIDs: Set<String> = {
        guard let u = URL(string: "https://example.com") else { return [] }
        return Set(NSWorkspace.shared.urlsForApplications(toOpen: u).compactMap { Bundle(url: $0)?.bundleIdentifier })
    }()

    public static func entry(at url: URL) -> AppEntry? {
        guard let b = Bundle(url: url), let id = b.bundleIdentifier else { return nil }
        let info = b.infoDictionary ?? [:]
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        let ls = info["LSApplicationCategoryType"] as? String
        return AppEntry(bundleID: id, name: name, url: url, lsCategory: ls, detected: detect(id: id, url: url, ls: ls))
    }

    static func detect(id: String, url: URL, ls: String?) -> AppCategory {
        if let k = AppCategory.known[id] { return k }
        if browserIDs.contains(id) && id != "com.apple.finder" { return .browsers }
        let p = url.path
        if p.hasPrefix("/System/Library/") || p.hasPrefix("/System/Applications/Utilities/") || id == "com.apple.systempreferences" { return .system }
        if let c = AppCategory.from(lsCategory: ls) { return c }
        return id.hasPrefix("com.apple.") ? .system : .other
    }

    /// Apps instaladas + las abiertas ahora (aunque vivan en otra carpeta), sin duplicados, ordenadas por nombre.
    public static func all(includeRunning: Bool = true) -> [AppEntry] {
        var seen: [String: AppEntry] = [:]
        let fm = FileManager.default
        func add(_ u: URL) { if let e = entry(at: u), seen[e.bundleID] == nil { seen[e.bundleID] = e } }
        for root in searchRoots {
            guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for u in items {
                if u.pathExtension == "app" { add(u); continue }
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue,
                   let sub = try? fm.contentsOfDirectory(at: u, includingPropertiesForKeys: nil) {
                    sub.filter { $0.pathExtension == "app" }.forEach(add)
                }
            }
        }
        if includeRunning { for a in Running.regularApps() { if let u = a.bundleURL { add(u) } } }
        return seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Protección

public enum Protection {
    public static let selfBundleID = "com.jdevesablanco.quitall"

    /// Nunca se cierran: Finder, QuitAll y piezas del sistema que, si se cierran, se relanzan o dejan el Mac raro.
    static let fixed: Set<String> = [
        "com.apple.finder", selfBundleID, "com.apple.dock", "com.apple.systemuiserver", "com.apple.loginwindow",
        "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.Spotlight", "com.apple.WindowManager",
        "com.apple.SecurityAgent", "com.apple.coreservices.uiagent", "com.apple.UserNotificationCenter",
        "com.apple.ScreenContinuity", "com.apple.universalcontrol",
    ]

    public enum Reason: Sendable { case finder, quitAll, system }

    public static func reason(bundleID: String, url: URL?) -> Reason? {
        if bundleID == "com.apple.finder" { return .finder }
        if bundleID == selfBundleID || bundleID == Bundle.main.bundleIdentifier { return .quitAll }
        if fixed.contains(bundleID) { return .system }
        if let p = url?.path, p.hasPrefix("/System/Library/CoreServices/") { return .system }
        return nil
    }

    public static func isProtected(_ bundleID: String, url: URL? = nil) -> Bool { reason(bundleID: bundleID, url: url) != nil }

    public static func label(_ r: Reason) -> String {
        switch r {
        case .finder: return tr("Finder siempre sigue abierto", "Finder always stays open")
        case .quitAll: return tr("Es esta app", "This app")
        case .system: return tr("Protegida (sistema)", "Protected (system)")
        }
    }
}

// MARK: - Apps abiertas

public enum Running {
    /// Apps «de verdad» abiertas: las que tienen icono en el Dock (no agentes de barra de menús ni procesos de fondo).
    public static func regularApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleIdentifier != nil
                && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
    }
}
