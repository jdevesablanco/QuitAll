import AppKit
import QuitAllCore

let version = "1.0.0"
let usage = """
quitall — cierra todas las apps abiertas menos las que elijas.

USO
  quitall quit [--profile NOMBRE] [--timeout S] [--force] [--dry-run] [--only APP]...
                                   cierra (con educación) según el perfil; --force fuerza las que no respondan;
                                   --only limita la acción a esas apps (nombre o bundle ID)
  quitall plan [--profile NOMBRE]  muestra qué pasaría con cada app abierta, sin tocar nada
  quitall undo                     reabre las apps cerradas por la última acción y muestra las ocultas
  quitall rule <app> quit|hide|keep [--profile NOMBRE]
                                   cambia la regla de una app (nombre o bundle ID)
  quitall profiles                 lista los perfiles (* = activo)
  quitall apps                     lista las apps instaladas con su categoría y regla
  quitall settings [--reset]       muestra (o restablece) los ajustes
  quitall install                  copia QuitAll.app a /Applications y abre la configuración inicial
  quitall selftest                 prueba de humo (no cierra nada)
  quitall --version

La terminal desde la que lo lanzas no se cierra (añade --include-terminal si quieres que también).
Las mismas acciones desde fuera: open quitall://quit, quitall://quit?profile=Estudio, quitall://undo
"""

func fail(_ m: String, code: Int32 = 1) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(code) }

var args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { print(usage); exit(0) }
args.removeFirst()

var s = SettingsStore.load()
Lang.forced = s.language
var positional: [String] = []
var profileName: String?
var timeout: Double?
var only: [String] = []
var force = false, dryRun = false, includeTerminal = false, reset = false
var i = 0
func next(_ flag: String) -> String { i += 1; guard i < args.count else { fail("Falta valor para \(flag)") }; return args[i] }
while i < args.count {
    let a = args[i]
    switch a {
    case "--profile", "-p": profileName = next(a)
    case "--timeout": timeout = Double(next(a))
    case "--only": only.append(next(a))
    case "--force": force = true
    case "--dry-run", "-n": dryRun = true
    case "--include-terminal": includeTerminal = true
    case "--reset": reset = true
    case "--lang": s.language = AppLanguage(rawValue: next(a)) ?? s.language; Lang.forced = s.language
    case "--help", "-h": print(usage); exit(0)
    default: positional.append(a)
    }
    i += 1
}

func profile() -> Profile {
    guard let n = profileName else { return s.activeProfile }
    guard let p = s.profile(named: n) else { fail("No hay ningún perfil «\(n)». Perfiles: \(s.profiles.map(\.name).joined(separator: ", "))") }
    return p
}

/// Terminal que nos ha lanzado (Terminal, iTerm, Warp…): macOS pasa su bundle ID en esta variable.
let hostTerminal = ProcessInfo.processInfo.environment["__CFBundleIdentifier"]

func makePlan() -> [PlanItem] {
    var plan = Planner.plan(profile: profile())
    if !includeTerminal, let t = hostTerminal, let k = plan.firstIndex(where: { $0.bundleID == t }), plan[k].action == .quit {
        plan[k].rule = .keep
    }
    // --only: limita la acción a esas apps (útil para probar sin cerrar todo lo demás).
    if !only.isEmpty { plan = plan.filter { it in only.contains { $0.caseInsensitiveCompare(it.bundleID) == .orderedSame || $0.caseInsensitiveCompare(it.name) == .orderedSame } } }
    return plan
}

func symbol(_ it: PlanItem) -> String {
    if let p = it.protection { return "🔒 " + Protection.label(p) }
    switch it.action { case .quit: return "✕ " + tr("cerrar", "quit"); case .hide: return "◐ " + tr("ocultar", "hide"); case .keep: return "● " + tr("dejar", "keep") }
}

func printPlan(_ plan: [PlanItem]) {
    let w = (plan.map { $0.name.count }.max() ?? 10) + 2
    for it in plan { print(it.name.padding(toLength: w, withPad: " ", startingAt: 0) + symbol(it)) }
    let sm = Planner.summary(plan)
    print(tr("\(sm.quit) se cierran · \(sm.hide) se ocultan · \(sm.keep) se quedan", "\(sm.quit) quit · \(sm.hide) hidden · \(sm.keep) kept"))
}

func spin(_ seconds: Double, until done: () -> Bool) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end && !done() { RunLoop.current.run(until: Date().addingTimeInterval(0.25)) }
}

func findApp(_ q: String) -> (id: String, name: String)? {
    let all = AppCatalog.all()
    if let e = all.first(where: { $0.bundleID.caseInsensitiveCompare(q) == .orderedSame }) { return (e.bundleID, e.name) }
    if let e = all.first(where: { $0.name.compare(q, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) { return (e.bundleID, e.name) }
    if q.contains(".") { return (q, q) }
    return nil
}

do {
    switch cmd {
    case "--version", "version": print("quitall \(version)")
    case "selftest":
        let r = SelfTest.run(); print(r.log); exit(r.ok ? 0 : 1)
    case "plan":
        printPlan(makePlan())
    case "quit":
        let plan = makePlan()
        if dryRun { printPlan(plan); exit(0) }
        let run = QuitRun(plan: plan, timeout: timeout ?? s.timeout)
        run.start()
        print(tr("Cerrando \(run.toQuit.count) apps…", "Quitting \(run.toQuit.count) apps…"))
        spin(run.timeout) { run.tick(); return run.isFinished }
        if !run.isFinished && force {
            run.forceAll()
            spin(3) { run.tick(); return run.isFinished }
        }
        print(tr("Cerradas: \(run.quit.count) · ocultas: \(run.hidden.count)", "Quit: \(run.quit.count) · hidden: \(run.hidden.count)"))
        if !run.isFinished {
            print(tr("Siguen abiertas (puede que pregunten si guardar cambios):", "Still open (they may be asking to save changes):"))
            for p in run.pending {
                let why = run.reason(p.pid) == .waitingForUser ? tr("esperando tu respuesta", "waiting for you") : tr("no responde", "not responding")
                print("  \(p.name) — \(why)")
            }
            print(tr("Usa --force para forzar el cierre (se pierde lo no guardado).", "Use --force to force quit (unsaved changes are lost)."))
            exit(2)
        }
    case "undo":
        guard UndoStore.load() != nil else { print(tr("No hay nada que deshacer.", "Nothing to undo.")); exit(0) }
        var done = false
        let n = UndoStore.undo { done = true }
        spin(20) { done }
        print(tr("Reabiertas o mostradas: \(n)", "Reopened or shown: \(n)"))
    case "rule":
        guard positional.count == 2, let action = RuleAction(rawValue: positional[1]) else { fail(usage) }
        guard let app = findApp(positional[0]) else { fail(tr("No encuentro la app «\(positional[0])».", "Can't find app “\(positional[0])”.")) }
        var p = profile()
        p.rules[app.id] = action == .quit ? nil : action
        s.activeProfile = p
        if profileName == nil { s.activeProfileID = p.id }
        SettingsStore.save(s)
        print("\(app.name) → \(action.title) (\(p.name))")
    case "profiles":
        for p in s.profiles { print((p.id == s.activeProfile.id ? "* " : "  ") + p.name + "  (\(p.rules.count) " + tr("excepciones", "exceptions") + ")") }
    case "apps":
        let p = profile()
        for e in AppCatalog.all() {
            let c = e.category(overrides: s.categoryOverrides).title
            print("\(e.name)\t\(c)\t\(Protection.isProtected(e.bundleID, url: e.url) ? "🔒" : p.action(for: e.bundleID).title)\t\(e.bundleID)")
        }
    case "settings":
        if reset { SettingsStore.save(Settings()); print(tr("Ajustes restablecidos.", "Settings reset.")); exit(0) }
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try e.encode(s), encoding: .utf8)!)
    case "install":
        // El ejecutable real vive dentro de QuitAll.app/Contents/Resources/quitall (brew enlaza a él).
        let u = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        guard let r = u.path.range(of: ".app/") else { fail(tr("No encuentro QuitAll.app junto a este ejecutable (¿compilaste solo la CLI?)", "Can't find QuitAll.app next to this binary (did you build only the CLI?)")) }
        let appPath = String(u.path[..<r.lowerBound]) + ".app"
        // En /Applications: en macOS 27, Bartender no consigue colocar el icono de la barra de menús de las apps que se
        // ejecutan desde ~/Applications. Solo si /Applications no se puede escribir se usa ~/Applications.
        let fm = FileManager.default
        let userCopy = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications/QuitAll.app")
        let dest = fm.isWritableFile(atPath: "/Applications") ? URL(fileURLWithPath: "/Applications/QuitAll.app") : userCopy
        if dest.path == userCopy.path {
            print(tr("Aviso: no se puede escribir en /Applications; se instala en ~/Applications (Bartender podría no mostrar el icono).",
                     "Note: /Applications isn't writable; installing into ~/Applications (Bartender may not show the icon)."))
        }
        if appPath != dest.path {
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Si ya estaba abierta, la cerramos antes de reemplazarla.
            for a in NSRunningApplication.runningApplications(withBundleIdentifier: Protection.selfBundleID) { a.terminate() }
            spin(3) { NSRunningApplication.runningApplications(withBundleIdentifier: Protection.selfBundleID).isEmpty }
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(atPath: appPath, toPath: dest.path)
        }
        let lsr = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        // La copia antigua en ~/Applications (instalaciones anteriores) sobra: se quita para que no haya dos.
        if dest.path != userCopy.path, fm.fileExists(atPath: userCopy.path) {
            let p = Process(); p.executableURL = URL(fileURLWithPath: lsr); p.arguments = ["-u", userCopy.path]; try? p.run(); p.waitUntilExit()
            try? fm.removeItem(at: userCopy)
        }
        for (exe, a) in [(lsr, ["-f", dest.path]), ("/usr/bin/open", [dest.path])] {
            let p = Process(); p.executableURL = URL(fileURLWithPath: exe); p.arguments = a; try p.run(); p.waitUntilExit()
        }
        print(tr("QuitAll instalada en \(dest.path)", "QuitAll installed at \(dest.path)"))
    default: print(usage)
    }
} catch {
    fail("Error: \(error.localizedDescription)")
}
