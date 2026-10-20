import AppKit
import SwiftUI
import QuitAllCore

/// Estado observable de la última pulsación de «Cerrar todo» (lo pinta el panel flotante).
final class QuitController: ObservableObject {
    enum Phase { case idle, quitting, overdue, done, undone }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var run: QuitRun?
    @Published private(set) var undoCount = 0
    @Published var lastRun: LastRun? = UndoStore.load()
    private var timer: Timer?
    var onPhase: ((Phase) -> Void)?

    var isBusy: Bool { phase == .quitting || phase == .overdue }

    /// Solo para capturas de pantalla.
    func preview(_ r: QuitRun, _ p: Phase) { run = r; phase = p }

    func start(profile: Profile, timeout: Double) {
        timer?.invalidate()
        let r = QuitRun(plan: Planner.plan(profile: profile), timeout: timeout)
        run = r
        r.start()
        lastRun = UndoStore.load()
        set(r.isFinished ? .done : .quitting)
        guard !r.isFinished else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let r = run else { return }
        let changed = r.tick()
        if changed { lastRun = UndoStore.load(); objectWillChange.send() }
        if r.isFinished { timer?.invalidate(); timer = nil; set(.done) }
        else if r.isOverdue && phase == .quitting { set(.overdue) }
        else if changed { objectWillChange.send() }
    }

    func force(_ pid: pid_t) { run?.forceQuit(pid); objectWillChange.send() }
    func forceAll() { run?.forceAll(); objectWillChange.send() }
    func leaveOpen(_ pid: pid_t) { run?.giveUp(pid); objectWillChange.send(); tick() }
    func leaveAllOpen() { run?.pending.forEach { run?.giveUp($0.pid) }; tick() }
    func show(_ pid: pid_t) { run?.activate(pid) }

    func undo() {
        timer?.invalidate(); timer = nil
        undoCount = UndoStore.undo()
        lastRun = nil
        set(.undone)
    }

    func reset() { if !isBusy { set(.idle) } }

    private func set(_ p: Phase) { phase = p; onPhase?(p) }
}

/// Panel flotante arriba a la derecha (no roba el foco): progreso, apps que se resisten, Deshacer.
final class RunPanelController {
    let controller: QuitController
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    var openSettings: () -> Void = {}

    init(controller: QuitController) { self.controller = controller }

    func show() {
        hideWork?.cancel()
        if panel == nil {
            let host = NSHostingView(rootView: RunView(c: controller, close: { [weak self] in self?.hide() }, settings: { [weak self] in self?.hide(); self?.openSettings() }, hover: { [weak self] in self?.hoverChanged($0) }).tint(Color.brand))
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 120), styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                            backing: .buffered, defer: false)
            p.isFloatingPanel = true
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.contentView = host
            panel = p
        }
        let wasVisible = panel?.isVisible ?? false
        resizeAndPlace()
        guard let p = panel else { return }
        if !wasVisible {
            let target = p.frame
            p.setFrame(target.offsetBy(dx: target.width + 20, dy: 0), display: true)
            p.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.32; $0.timingFunction = CAMediaTimingFunction(name: .easeOut); p.animator().setFrame(target, display: true) }
        } else { p.orderFrontRegardless() }
    }

    func resizeAndPlace() {
        guard let p = panel, let v = p.contentView else { return }
        let size = v.fittingSize
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        p.setFrame(NSRect(x: vf.maxX - size.width + 2, y: vf.maxY - size.height + 2, width: size.width, height: size.height), display: true)
    }

    func hide() {
        hideWork?.cancel()
        guard let p = panel, p.isVisible else { controller.reset(); return }
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; $0.timingFunction = CAMediaTimingFunction(name: .easeIn); p.animator().setFrame(p.frame.offsetBy(dx: p.frame.width + 20, dy: 0), display: true) },
                                             completionHandler: { [weak self] in p.orderOut(nil); self?.controller.reset() })
    }

    /// Con el ratón encima el aviso no se va (como las notificaciones nativas).
    func hoverChanged(_ inside: Bool) {
        if inside { hideWork?.cancel() }
        else if controller.phase == .done || controller.phase == .undone { hide(after: 3) }
    }

    func hide(after s: Double) {
        hideWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: w)
    }

    /// Mientras el ratón está encima no se oculta solo.
    func keepWhileHovered() { hideWork?.cancel() }
}

struct RunView: View {
    @ObservedObject var c: QuitController
    var close: () -> Void
    var settings: () -> Void = {}
    var hover: (Bool) -> Void = { _ in }
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if c.phase == .overdue, let r = c.run, !r.pending.isEmpty { stuckList(r) }
            buttons
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(width: 344)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
        .overlay(alignment: .topLeading) {
            if hovering && !c.isBusy {
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 18, height: 18).background(Circle().fill(.regularMaterial))
                        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(.plain).offset(x: -6, y: -6).help(tr("Cerrar aviso", "Dismiss"))
            }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h }; hover(h) }
        .padding(12)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApp.applicationIconImage).resizable().interpolation(.high).frame(width: 38, height: 38)
                Group {
                    switch c.phase {
                    case .quitting: ProgressView().controlSize(.mini).frame(width: 16, height: 16).background(Circle().fill(.regularMaterial))
                    case .overdue: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.white, .orange)
                    case .undone: Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(.white, Color.brand)
                    default: Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, .green)
                    }
                }
                .font(.system(size: 15)).offset(x: 4, y: 4)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 4)
                    if hovering {
                        Button(action: settings) { Image(systemName: "gearshape").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) }
                            .buttonStyle(.plain).help(tr("Ajustes de QuitAll", "QuitAll settings"))
                    } else {
                        Text(tr("ahora", "now")).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                if !detail.isEmpty { Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
        }
    }

    private var title: String {
        guard let r = c.run else { return "QuitAll" }
        switch c.phase {
        case .quitting: return tr("Cerrando \(r.toQuit.count) apps…", "Quitting \(r.toQuit.count) apps…")
        case .overdue: return r.pending.count == 1 ? tr("1 app sigue abierta", "1 app is still open") : tr("\(r.pending.count) apps siguen abiertas", "\(r.pending.count) apps are still open")
        case .undone: return tr("Deshecho", "Undone")
        default:
            if r.toQuit.isEmpty && r.hidden.isEmpty { return tr("No había nada que cerrar", "Nothing to quit") }
            return tr("Listo", "Done")
        }
    }

    private var detail: String {
        guard let r = c.run else { return "" }
        switch c.phase {
        case .quitting: return tr("Cada app puede preguntarte si guardar los cambios.", "Each app may ask you to save changes.")
        case .overdue: return tr("Puede que te estén preguntando si guardar cambios. Respóndeles o fuerza el cierre (lo no guardado se pierde).",
                                 "They may be asking you to save changes. Answer them, or force quit (unsaved work is lost).")
        case .undone: return tr("Reabiertas o mostradas: \(c.undoCount). Cada app recupera sus ventanas a su manera.", "Reopened or shown: \(c.undoCount). Each app restores its windows its own way.")
        default:
            var parts: [String] = []
            if !r.quit.isEmpty { parts.append(tr("\(r.quit.count) cerradas", "\(r.quit.count) quit")) }
            if !r.hidden.isEmpty { parts.append(tr("\(r.hidden.count) ocultas", "\(r.hidden.count) hidden")) }
            let left = r.toQuit.count - r.quit.count
            if left > 0 { parts.append(tr("\(left) se quedaron abiertas", "\(left) stayed open")) }
            return parts.joined(separator: " · ")
        }
    }

    private func stuckList(_ r: QuitRun) -> some View {
        VStack(spacing: 6) {
            ForEach(r.pending) { it in
                HStack(spacing: 8) {
                    Image(nsImage: Icons.icon(it.url, id: it.bundleID)).resizable().frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(it.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(r.reason(it.pid) == .waitingForUser ? tr("¿Cambios sin guardar?", "Unsaved changes?") : tr("No responde", "Not responding"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Button(tr("Mostrar", "Show")) { c.show(it.pid) }.controlSize(.small)
                    Button(tr("Forzar", "Force")) { c.force(it.pid) }.controlSize(.small)
                    Button { c.leaveOpen(it.pid) } label: { Image(systemName: "pin") }.controlSize(.small)
                        .help(tr("Dejarla abierta", "Leave it open"))
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    @ViewBuilder private var buttons: some View {
        switch c.phase {
        case .overdue:
            HStack {
                Button(tr("Dejarlas abiertas", "Leave them open")) { c.leaveAllOpen() }
                Spacer()
                Button(tr("Forzar cierre de todas", "Force quit all")) { c.forceAll() }.buttonStyle(.borderedProminent).tint(.red)
            }.controlSize(.small)
        case .done:
            if let r = c.run, !(r.quit.isEmpty && r.hidden.isEmpty) {
                HStack {
                    Spacer()
                    Button(tr("Deshacer", "Undo")) { c.undo() }.buttonStyle(NativeNoticeButton())
                }
            }
        default: EmptyView()
        }
    }
}

/// Botón gris redondeado como los de las notificaciones de macOS.
struct NativeNoticeButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.20 : 0.10)))
    }
}
