import SwiftUI
import AppKit
import QuitAllCore

/// Modo de verificación visual: `QUITALL_SNAPSHOT=/ruta QuitAll` renderiza las pantallas a PNG y sale (sin ventanas).
enum Snapshot {
    static var active = false
    static var privacy = false
    static var expand: Set<AppCategory> = [.music]

    /// Apps de Apple «abiertas» para las capturas del menú (en vez de las que tenga abiertas quien las genera).
    static let demoApps = ["com.apple.Safari", "com.apple.mail", "com.apple.iCal", "com.apple.Notes", "com.apple.Music", "com.apple.MobileSMS",
                           "com.apple.Preview", "com.apple.TextEdit", "com.apple.Photos", "com.apple.podcasts", "com.apple.finder", "com.apple.systempreferences"]
    static func demoPlan(_ profile: Profile) -> [PlanItem] {
        demoApps.enumerated().compactMap { i, id in
            guard let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
            let name = FileManager.default.displayName(atPath: u.path).replacingOccurrences(of: ".app", with: "")
            return PlanItem(pid: pid_t(-100 - i), bundleID: id, name: name, url: u, rule: profile.action(for: id), protection: Protection.reason(bundleID: id, url: u))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    static func fakePlan(_ profile: Profile) -> [PlanItem]? { privacy ? demoPlan(profile) : nil }

    /// Capturas reales para el README: `QUITALL_SCREENSHOTS=/dir QuitAll` abre el onboarding en modo oscuro, en inglés y en
    /// español, captura su propia ventana (no necesita permiso de grabación de pantalla) y sale. Usar con QUITALL_CONFIG_DIR.
    @MainActor static func screenshots(model: SettingsModel, dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        privacy = true
        AppList.shared.loadNow()
        // Reglas de ejemplo: Notas se queda, Mensajes y la música se ocultan; el resto se cierra.
        var p = model.s.activeProfile
        p.rules = ["com.apple.Music": .hide, "com.apple.podcasts": .hide, "com.apple.MobileSMS": .hide, "com.apple.Notes": .keep]
        model.s.activeProfile = p
        let controller = QuitController()
        enum Kind { case onboarding(Int, Bool), popover, settings, panelDone, panelStuck }
        var jobs: [(String, AppLanguage, Kind)] = []
        for (code, lang) in [("en", AppLanguage.en), ("es", AppLanguage.es)] {
            for step in 0..<3 { jobs.append(("onb-\(code)-\(step + 1)", lang, .onboarding(step, false))) }
            jobs.append(("onb-\(code)-done", lang, .onboarding(2, true)))
            jobs.append(("menu-\(code)", lang, .popover))
            jobs.append(("apps-\(code)", lang, .settings))
            jobs.append(("run-\(code)", lang, .panelDone))
            jobs.append(("stuck-\(code)", lang, .panelStuck))
        }
        func demoRun(stuck: Bool) -> QuitRun {
            let plan = demoPlan(model.s.activeProfile)
            let r = QuitRun(plan: plan, timeout: 8)
            let quit = plan.filter { $0.action == .quit }
            let pending = stuck ? quit.filter { ["com.apple.TextEdit", "com.apple.Preview"].contains($0.bundleID) } : []
            r.simulate(quit: quit.filter { q in !pending.contains { $0.pid == q.pid } }, hidden: plan.filter { $0.action == .hide },
                       pending: pending, waiting: Set(pending.filter { $0.bundleID == "com.apple.TextEdit" }.map(\.pid)))
            return r
        }
        func next(_ i: Int) {
            guard i < jobs.count else { NSApp.terminate(nil); return }
            let (name, lang, kind) = jobs[i]
            model.s.language = lang; Lang.forced = lang
            let root: AnyView
            var titled = true
            switch kind {
            case .onboarding(let step, let done):
                expand = [.music]
                root = AnyView(OnboardingView(model: model, startStep: step, startDone: done) {})
            case .popover:
                titled = false
                root = AnyView(PopoverView(model: model, c: controller, refresh: Local(0), quitAll: {}, openSettings: {}, quitApp: {})
                    .background(Color(nsColor: .windowBackgroundColor)))
            case .settings:
                expand = [.browsers, .communication, .productivity]
                root = AnyView(SettingsView(model: model))
            case .panelDone, .panelStuck:
                titled = false
                let stuck: Bool = { if case .panelStuck = kind { return true } else { return false } }()
                controller.preview(demoRun(stuck: stuck), stuck ? .overdue : .done)
                root = AnyView(RunView(c: controller, close: {}).tint(Color.brand).padding(16).background(Color(nsColor: .windowBackgroundColor)))
            }
            let w = NSWindow(contentViewController: NSHostingController(rootView: root))
            switch kind {
            case .onboarding: w.title = tr("Bienvenido a QuitAll", "Welcome to QuitAll")
            case .settings: w.title = tr("QuitAll — Ajustes", "QuitAll — Settings")
            default: break
            }
            w.styleMask = titled ? [.titled, .closable, .miniaturizable] : [.borderless]
            w.appearance = NSAppearance(named: .darkAqua)
            w.isReleasedWhenClosed = false
            // En una pantalla Retina si la hay: así la captura sale nítida a 2x.
            if let sc = NSScreen.screens.first(where: { $0.backingScaleFactor >= 2 }) {
                let f = sc.visibleFrame
                w.setFrameOrigin(NSPoint(x: f.midX - w.frame.width / 2, y: f.midY - w.frame.height / 2))
            } else { w.center() }
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let v = w.contentView?.superview, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: rep)
                    if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png")) }
                }
                w.close()
                next(i + 1)
            }
        }
        next(0)
    }
    @MainActor static func run(model: SettingsModel, controller: QuitController, dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        active = true
        AppList.shared.loadNow()
        let cases: [(String, AnyView)] = [
            ("paso1", AnyView(OnboardingView(model: model, startStep: 0) {})),
            ("paso2", AnyView(OnboardingView(model: model, startStep: 1) {})),
            ("paso3", AnyView(OnboardingView(model: model, startStep: 2) {})),
            ("final", AnyView(OnboardingView(model: model, startStep: 2, startDone: true) {})),
            ("popover", AnyView(PopoverView(model: model, c: controller, refresh: Local(0), quitAll: {}, openSettings: {}, quitApp: {}))),
            ("ajustes", AnyView(SettingsView(model: model))),
        ]
        for (name, v) in cases {
            let r = ImageRenderer(content: v.background(Color(nsColor: .windowBackgroundColor)))
            r.scale = 2
            guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
    }
}
