import AppKit
import CoreGraphics

/// Lo que se hará con una app abierta.
public struct PlanItem: Identifiable, Hashable, Sendable {
    public var pid: pid_t
    public var bundleID: String
    public var name: String
    public var url: URL?
    public var rule: RuleAction                // la del perfil
    public var protection: Protection.Reason?  // si está protegida, se queda como está pase lo que pase
    public var id: pid_t { pid }

    public var action: RuleAction { protection == nil ? rule : .keep }

    public init(pid: pid_t, bundleID: String, name: String, url: URL?, rule: RuleAction, protection: Protection.Reason?) {
        self.pid = pid; self.bundleID = bundleID; self.name = name; self.url = url; self.rule = rule; self.protection = protection
    }
}

public enum Planner {
    public static func plan(profile: Profile, apps: [NSRunningApplication] = Running.regularApps()) -> [PlanItem] {
        apps.compactMap { a in
            guard let id = a.bundleIdentifier else { return nil }
            return PlanItem(pid: a.processIdentifier, bundleID: id, name: a.localizedName ?? id, url: a.bundleURL,
                            rule: profile.action(for: id), protection: Protection.reason(bundleID: id, url: a.bundleURL))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public static func summary(_ plan: [PlanItem]) -> (quit: Int, hide: Int, keep: Int) {
        (plan.filter { $0.action == .quit }.count, plan.filter { $0.action == .hide }.count, plan.filter { $0.action == .keep }.count)
    }
}

/// Una pulsación de «Cerrar todo»: oculta, pide cerrar con educación (como ⌘Q) y vigila quién se queda.
/// No bloquea: quien la usa llama a `tick()` periódicamente desde el run loop principal.
public final class QuitRun {
    public enum StuckReason: Sendable { case waitingForUser, notResponding }

    public let plan: [PlanItem]
    public let timeout: TimeInterval
    public private(set) var started = Date()
    public private(set) var quit: [PlanItem] = []       // confirmadas cerradas
    public private(set) var hidden: [PlanItem] = []
    public private(set) var pending: [PlanItem] = []    // se les pidió cerrar y siguen abiertas
    public private(set) var forced: [PlanItem] = []
    private var apps: [pid_t: NSRunningApplication] = [:]

    public init(plan: [PlanItem], timeout: TimeInterval) {
        self.plan = plan
        self.timeout = timeout
    }

    public var toQuit: [PlanItem] { plan.filter { $0.action == .quit } }
    public var isFinished: Bool { pending.isEmpty }
    /// Han pasado los N segundos y alguna sigue abierta: toca ofrecer «Forzar cierre».
    public var isOverdue: Bool { !pending.isEmpty && Date().timeIntervalSince(started) >= timeout }

    public func start() {
        started = Date()
        for it in plan {
            guard let a = NSRunningApplication(processIdentifier: it.pid) else { continue }
            apps[it.pid] = a
            switch it.action {
            case .hide:
                // hide() es asíncrono y isHidden puede ir con retraso: lo contamos como oculta si se pidió.
                _ = a.hide()
                hidden.append(it)
            case .quit:
                // terminate() = el mismo «Salir» que ⌘Q: cada app pregunta por sus documentos sin guardar.
                _ = a.terminate()
                pending.append(it)
            case .keep:
                break
            }
        }
        record()
    }

    /// Revisa quién se ha cerrado ya. Devuelve true si algo cambió.
    @discardableResult
    public func tick() -> Bool {
        let gone = pending.filter { !isAlive($0.pid) }
        guard !gone.isEmpty else { return false }
        pending.removeAll { g in gone.contains { $0.pid == g.pid } }
        quit += gone
        record()
        return true
    }

    public func forceQuit(_ pid: pid_t) {
        guard let it = pending.first(where: { $0.pid == pid }) else { return }
        _ = (apps[pid] ?? NSRunningApplication(processIdentifier: pid))?.forceTerminate()
        forced.append(it)
    }

    public func forceAll() { pending.forEach { forceQuit($0.pid) } }

    /// Dejar de insistir con esta app (el usuario prefiere que siga abierta).
    public func giveUp(_ pid: pid_t) { pending.removeAll { $0.pid == pid } }

    public func activate(_ pid: pid_t) {
        _ = (apps[pid] ?? NSRunningApplication(processIdentifier: pid))?.activate(options: [.activateAllWindows])
    }

    public static func isAlive(_ pid: pid_t) -> Bool {
        if let a = NSRunningApplication(processIdentifier: pid), !a.isTerminated { return kill(pid, 0) == 0 }
        return false
    }
    private func isAlive(_ pid: pid_t) -> Bool { QuitRun.isAlive(pid) }

    /// Pista honesta de por qué sigue abierta: si tiene ventanas en pantalla, casi seguro está preguntando si guardar.
    /// macOS no expone «tiene cambios sin guardar» de otras apps, así que no se puede saber con certeza.
    /// Solo para capturas de pantalla: fija el resultado sin tocar ninguna app.
    public func simulate(quit: [PlanItem], hidden: [PlanItem], pending: [PlanItem], waiting: Set<pid_t>) {
        self.quit = quit; self.hidden = hidden; self.pending = pending; simulatedWaiting = waiting
        started = Date().addingTimeInterval(-timeout)
    }
    private var simulatedWaiting: Set<pid_t>?

    public func reason(_ pid: pid_t) -> StuckReason {
        if let w = simulatedWaiting { return w.contains(pid) ? .waitingForUser : .notResponding }
        let wins = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        let has = wins.contains { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
        let active = apps[pid]?.isActive ?? false
        return (has || active) ? .waitingForUser : .notResponding
    }

    private func record() {
        guard !quit.isEmpty || !hidden.isEmpty else { return }
        UndoStore.save(LastRun(date: started,
                               quit: quit.map { .init(bundleID: $0.bundleID, name: $0.name, path: $0.url?.path) },
                               hidden: hidden.map { .init(bundleID: $0.bundleID, name: $0.name, path: $0.url?.path) }))
    }
}

// MARK: - Deshacer

public struct LastRun: Codable, Equatable, Sendable {
    public struct App: Codable, Equatable, Sendable {
        public var bundleID: String
        public var name: String
        public var path: String?
    }
    public var date: Date
    public var quit: [App]
    public var hidden: [App]
    public var isEmpty: Bool { quit.isEmpty && hidden.isEmpty }
}

public enum UndoStore {
    static var fileURL: URL { SettingsStore.directory.appendingPathComponent("last-run.json") }

    public static func load() -> LastRun? {
        guard let d = try? Data(contentsOf: fileURL), let r = try? JSONDecoder().decode(LastRun.self, from: d), !r.isEmpty else { return nil }
        return r
    }

    static func save(_ r: LastRun) {
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(r) { try? d.write(to: fileURL, options: .atomic) }
    }

    public static func clear() { try? FileManager.default.removeItem(at: fileURL) }

    /// Reabre las apps que cerró la última acción (en segundo plano) y vuelve a mostrar las que ocultó.
    /// Devuelve cuántas se reabrieron/mostraron. Las ventanas que recupere cada app dependen de ella y de
    /// «Cerrar ventanas al salir de una app» en Ajustes del Sistema.
    @discardableResult
    public static func undo(completion: (() -> Void)? = nil) -> Int {
        guard let r = load() else { completion?(); return 0 }
        var n = 0
        let group = DispatchGroup()
        for a in r.quit {
            let url = a.path.map { URL(fileURLWithPath: $0) }.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: a.bundleID)
            guard let url else { continue }
            if !NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleID).isEmpty { continue }
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = false
            cfg.addsToRecentItems = false
            group.enter()
            NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in group.leave() }
            n += 1
        }
        for a in r.hidden {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: a.bundleID) {
                app.unhide(); n += 1
            }
        }
        clear()
        group.notify(queue: .main) { completion?() }
        return n
    }
}
