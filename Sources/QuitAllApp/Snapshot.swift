import SwiftUI
import AppKit
import QuitAllCore

/// Modo de verificación visual: `QUITALL_SNAPSHOT=/ruta QuitAll` renderiza las pantallas a PNG y sale (sin ventanas).
enum Snapshot {
    static var active = false
    static var privacy = false

    /// Capturas reales para el README: `QUITALL_SCREENSHOTS=/dir QuitAll` abre el onboarding en modo oscuro, en inglés y en
    /// español, captura su propia ventana (no necesita permiso de grabación de pantalla) y sale. Usar con QUITALL_CONFIG_DIR.
    @MainActor static func screenshots(model: SettingsModel, dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        privacy = true
        AppList.shared.loadNow()
        var jobs: [(String, AppLanguage, Int, Bool)] = []
        for (code, lang) in [("en", AppLanguage.en), ("es", AppLanguage.es)] {
            for step in 0..<3 { jobs.append(("onb-\(code)-\(step + 1)", lang, step, false)) }
            jobs.append(("onb-\(code)-done", lang, 2, true))
        }
        func next(_ i: Int) {
            guard i < jobs.count else { NSApp.terminate(nil); return }
            let (name, lang, step, done) = jobs[i]
            model.s.language = lang; Lang.forced = lang
            let w = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(model: model, startStep: step, startDone: done) {}))
            w.title = tr("Bienvenido a QuitAll", "Welcome to QuitAll")
            w.styleMask = [.titled, .closable, .miniaturizable]
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
