import SwiftUI
import AppKit
import QuitAllCore

/// SwiftUI también define `Settings` (escena): fijamos cuál es el nuestro.
typealias Settings = QuitAllCore.Settings

/// Estado local para vistas SwiftUI sin usar `@State` (en los SDK recientes es un macro que exige Xcode completo).
final class Local<T>: ObservableObject {
    @Published var v: T
    init(_ v: T) { self.v = v }
}

enum AppInfo {
    static let version = "1.0.0"
    static let repoURL = "https://github.com/jdevesablanco/QuitAll"
}

extension Color {
    /// Acento morado del pack.
    static let brand = Color(red: 0.50, green: 0.30, blue: 0.93)
    static let brandSoft = Color(red: 0.50, green: 0.30, blue: 0.93).opacity(0.12)
}

/// Ajustes observables: cada cambio se guarda en disco al instante.
final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    var onChange: ((Settings, Settings) -> Void)?
    @Published var s: Settings {
        didSet {
            guard s != oldValue else { return }
            SettingsStore.save(s)
            onChange?(oldValue, s)
        }
    }
    private init() { s = SettingsStore.load() }

    /// Regla del perfil activo para una app (las protegidas no se pueden cambiar).
    func rule(_ id: String) -> RuleAction { s.activeProfile.action(for: id) }
    func setRule(_ id: String, _ a: RuleAction) {
        var p = s.activeProfile
        p.rules[id] = a == .quit ? nil : a
        s.activeProfile = p
    }
    func ruleBinding(_ id: String) -> Binding<RuleAction> {
        Binding(get: { self.rule(id) }, set: { self.setRule(id, $0) })
    }
    func categoryBinding(_ e: AppEntry) -> Binding<AppCategory> {
        Binding(get: { e.category(overrides: self.s.categoryOverrides) },
                set: { self.s.categoryOverrides[e.bundleID] = $0 == e.detected ? nil : $0.rawValue })
    }
}

/// Iconos de app en caché (NSWorkspace los genera bajo demanda y no es gratis).
enum Icons {
    private static var cache: [String: NSImage] = [:]
    static func icon(_ url: URL?, id: String) -> NSImage {
        if let i = cache[id] { return i }
        let img: NSImage
        if let url { img = NSWorkspace.shared.icon(forFile: url.path) }
        else if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { img = NSWorkspace.shared.icon(forFile: u.path) }
        else { img = NSWorkspace.shared.icon(for: .applicationBundle) }
        img.size = NSSize(width: 64, height: 64)
        cache[id] = img
        return img
    }
}

extension RuleAction {
    var symbol: String {
        switch self { case .quit: return "xmark"; case .hide: return "eye.slash"; case .keep: return "pin.fill" }
    }
    var tint: Color {
        switch self { case .quit: return .red; case .hide: return .orange; case .keep: return .brand }
    }
    var short: String {
        switch self { case .quit: return tr("Cerrar", "Quit"); case .hide: return tr("Ocultar", "Hide"); case .keep: return tr("Dejar", "Keep") }
    }
}

/// Icono de la app (para tarjetas y cabeceras): el .icns si la app está empaquetada, si no un símbolo.
struct BrandMark: View {
    var size: CGFloat = 46
    var body: some View {
        Group {
            if let img = NSApp.applicationIconImage, Bundle.main.bundlePath.hasSuffix(".app") {
                Image(nsImage: img).resizable()
            } else {
                Image(systemName: "power").font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(LinearGradient(colors: [Color.brand, Color(red: 0.32, green: 0.22, blue: 0.80)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
        }.frame(width: size, height: size)
    }
}
