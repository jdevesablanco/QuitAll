import Foundation

/// Prueba de humo sin efectos: no cierra ni oculta nada.
public enum SelfTest {
    public static func run() -> (ok: Bool, log: String) {
        var log: [String] = []
        var ok = true
        func check(_ cond: Bool, _ what: String) { log.append((cond ? "✓ " : "✗ ") + what); if !cond { ok = false } }

        check(AppCategory.from(lsCategory: "public.app-category.music") == .music, "categoría: música")
        check(AppCategory.from(lsCategory: "public.app-category.developer-tools") == .developer, "categoría: desarrollo")
        check(AppCategory.from(lsCategory: "public.app-category.puzzle-games") == .games, "categoría: juegos")
        check(AppCategory.from(lsCategory: "public.app-category.weather") == .other, "categoría: otras")
        check(AppCategory.from(lsCategory: nil) == nil, "categoría: sin dato")

        check(Protection.isProtected("com.apple.finder"), "Finder protegido")
        check(Protection.isProtected(Protection.selfBundleID), "QuitAll protegida")
        check(Protection.isProtected("com.apple.dock"), "Dock protegido")
        check(!Protection.isProtected("com.apple.TextEdit"), "TextEdit no protegido")

        var p = Profile(name: "Test")
        check(p.action(for: "x.y") == .quit, "sin regla → cerrar")
        p.rules["x.y"] = .hide
        check(p.action(for: "x.y") == .hide, "regla ocultar")

        var s = Settings()
        s.profiles.append(p); s.activeProfileID = p.id; s.timeout = 500
        let data = (try? JSONEncoder().encode(s)) ?? Data()
        let back = try? JSONDecoder().decode(Settings.self, from: data)
        check(back?.activeProfile.name == "Test", "ajustes: ida y vuelta")
        check(back?.timeout == 60, "ajustes: tiempo de espera acotado")
        check((try? JSONDecoder().decode(Settings.self, from: Data("{}".utf8)))?.profiles.count == 1, "ajustes: JSON vacío → perfil por defecto")
        check(Hotkey.default.display == "⌃⌥⌘Q", "atajo por defecto")
        let old = try? JSONDecoder().decode(Settings.self, from: Data(#"{"reopenAction":"showMenu"}"#.utf8))
        check(old?.reopenAction == .quitAll, "abrir la app = cerrar todo (también con ajustes antiguos)")
        var m = Settings(); m.reopenAction = .showMenu; m.showMenuBarIcon = false
        let m2 = (try? JSONEncoder().encode(m)).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
        check(m2?.reopenAction == .showMenu && m2?.showMenuBarIcon == false, "ajustes: «al abrir» e icono se guardan")
        check(Settings.defaultProfile().action(for: "com.spotify.client") == .hide, "música por defecto: ocultar")

        let plan = Planner.plan(profile: Profile(name: "Todo"))
        let finder = plan.first { $0.bundleID == "com.apple.finder" }
        check(finder == nil || finder?.action == .keep, "plan: Finder nunca se cierra")
        check(plan.allSatisfy { $0.protection == nil || $0.action == .keep }, "plan: protegidas se quedan")
        let apps = AppCatalog.all(includeRunning: false)
        check(!apps.isEmpty, "catálogo: \(apps.count) apps instaladas")
        return (ok, log.joined(separator: "\n"))
    }
}
