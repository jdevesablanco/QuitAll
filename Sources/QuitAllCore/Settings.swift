import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto, es, en
    public var id: String { rawValue }
}

public enum Lang {
    /// Idioma elegido por el usuario (la app y la CLI lo fijan al arrancar). `.auto` = el del sistema.
    nonisolated(unsafe) public static var forced: AppLanguage = .auto
    public static var isSpanish: Bool {
        switch forced {
        case .es: return true
        case .en: return false
        case .auto: return (Locale.preferredLanguages.first ?? "en").hasPrefix("es")
        }
    }
}

/// Texto bilingüe mínimo: español o inglés según el ajuste de idioma (o el del sistema).
public func tr(_ es: String, _ en: String) -> String { Lang.isSpanish ? es : en }

// MARK: - Reglas

/// Qué le pasa a una app abierta al pulsar «Cerrar todo».
public enum RuleAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case quit, hide, keep
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .quit: return tr("Cerrar", "Quit")
        case .hide: return tr("Ocultar", "Hide")
        case .keep: return tr("Dejar como está", "Leave as is")
        }
    }
    public var next: RuleAction {
        switch self { case .quit: return .hide; case .hide: return .keep; case .keep: return .quit }
    }
}

/// Un perfil = una lista de excepciones. Las apps que no aparecen en `rules` se cierran.
public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var rules: [String: RuleAction]   // bundle ID → acción

    public init(id: UUID = UUID(), name: String, rules: [String: RuleAction] = [:]) {
        self.id = id; self.name = name; self.rules = rules
    }

    public func action(for bundleID: String) -> RuleAction { rules[bundleID] ?? .quit }
}

/// Atajo global (códigos de Carbon: `keyCode` virtual y modificadores `cmdKey|optionKey|…`).
public struct Hotkey: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var key: String           // la tecla tal como se mostró al grabarla («Q», «F5»…)

    public init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.key = key
    }

    // Constantes de Carbon (HIToolbox/Events.h) para no depender de Carbon en el núcleo.
    public static let cmd: UInt32 = 1 << 8, shift: UInt32 = 1 << 9, option: UInt32 = 1 << 11, control: UInt32 = 1 << 12
    /// ⌃⌥⌘Q: libre en macOS (⌃⌘Q bloquea la pantalla y ⌥⇧⌘Q cierra sesión, por eso no usamos esos).
    public static let `default` = Hotkey(keyCode: 12, modifiers: control | option | cmd, key: "Q")

    public var display: String {
        var s = ""
        if modifiers & Hotkey.control != 0 { s += "⌃" }
        if modifiers & Hotkey.option != 0 { s += "⌥" }
        if modifiers & Hotkey.shift != 0 { s += "⇧" }
        if modifiers & Hotkey.cmd != 0 { s += "⌘" }
        return s + key
    }
}

/// Qué hace la app cuando la abres otra vez (Dock, Spotlight, Launchpad) estando ya en marcha.
public enum ReopenAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case showMenu, quitAll
    public var id: String { rawValue }
}

// MARK: - Settings

/// Todas las opciones. Se guardan en JSON y las comparten la app y la CLI.
public struct Settings: Codable, Equatable, Sendable {
    public var profiles: [Profile] = [Settings.defaultProfile()]
    public var activeProfileID: UUID?
    /// Segundos de espera tras pedir el cierre antes de ofrecer «Forzar cierre».
    public var timeout: Double = 8
    public var hotkeyEnabled: Bool = true
    public var hotkey: Hotkey = .default
    public var reopenAction: ReopenAction = .showMenu
    /// Categoría elegida a mano para una app (bundle ID → `AppCategory.rawValue`).
    public var categoryOverrides: [String: String] = [:]
    public var language: AppLanguage = .auto
    public var launchAtLogin: Bool = true
    public var onboardingDone: Bool = false

    public init() {}

    public var activeProfile: Profile {
        get { profiles.first { $0.id == activeProfileID } ?? profiles.first ?? Settings.defaultProfile() }
        set {
            if let i = profiles.firstIndex(where: { $0.id == newValue.id }) { profiles[i] = newValue }
            else { profiles.append(newValue); activeProfileID = newValue.id }
        }
    }

    public func profile(named name: String) -> Profile? {
        profiles.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    /// Perfil inicial: la música sigue sonando (las apps de música se dejan como están). Todo lo demás se cierra.
    public static func defaultProfile() -> Profile {
        Profile(name: tr("General", "General"), rules: [
            "com.apple.Music": .keep, "com.spotify.client": .keep, "com.apple.podcasts": .keep,
        ])
    }

    public init(from decoder: Decoder) throws {
        // Decodificación tolerante: las claves que falten (versiones antiguas) toman el valor por defecto.
        self.init()
        let c = try decoder.container(keyedBy: Keys.self)
        func get<T: Decodable>(_ k: Keys, _ v: inout T) { if let x = try? c.decodeIfPresent(T.self, forKey: k) { v = x } }
        get(.profiles, &profiles); get(.activeProfileID, &activeProfileID); get(.timeout, &timeout)
        get(.hotkeyEnabled, &hotkeyEnabled); get(.hotkey, &hotkey); get(.reopenAction, &reopenAction)
        get(.categoryOverrides, &categoryOverrides); get(.language, &language)
        get(.launchAtLogin, &launchAtLogin); get(.onboardingDone, &onboardingDone)
        if profiles.isEmpty { profiles = [Settings.defaultProfile()] }
        timeout = min(max(timeout, 2), 60)
    }

    enum Keys: String, CodingKey {
        case profiles, activeProfileID, timeout, hotkeyEnabled, hotkey, reopenAction, categoryOverrides
        case language, launchAtLogin, onboardingDone
    }
}

// MARK: - Persistencia

public enum SettingsStore {
    public static var directory: URL {
        // QUITALL_CONFIG_DIR aísla los ajustes (pruebas, CI, instalación limpia simulada).
        if let d = ProcessInfo.processInfo.environment["QUITALL_CONFIG_DIR"], !d.isEmpty { return URL(fileURLWithPath: d, isDirectory: true) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("QuitAll", isDirectory: true)
    }
    public static var fileURL: URL { directory.appendingPathComponent("settings.json") }

    public static func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return s
    }

    public static func save(_ s: Settings) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(s) { try? d.write(to: fileURL, options: .atomic) }
    }
}
