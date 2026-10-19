import AppKit
import SwiftUI
import Combine
import QuitAllCore

final class ActionItem: NSMenuItem {
    var handler: (() -> Void)?
    convenience init(_ title: String, key: String = "", _ h: @escaping () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self; handler = h
    }
    @objc func fire() { handler?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = SettingsModel.shared
    let controller = QuitController()
    lazy var panel = RunPanelController(controller: controller)
    var statusItem: NSStatusItem?
    let popover = NSPopover()
    let popoverRefresh = Local(0)
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var bag: Set<AnyCancellable> = []

    // MARK: ciclo de vida

    func applicationWillFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Lang.forced = model.s.language
        NSApp.mainMenu = MainMenu.build(target: self)
        // Los enlaces quitall://… llegan como Apple Event (antes de terminar de arrancar si nos lanzan con uno).
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        PackCatalog.isSpanish = { Lang.isSpanish }
        PackCatalog.accent = .brand
        if let dir = ProcessInfo.processInfo.environment["QUITALL_SNAPSHOT"] {
            Snapshot.run(model: model, controller: controller, dir: dir); NSApp.terminate(nil); return
        }
        model.onChange = { [weak self] old, new in self?.settingsChanged(old, new) }
        setupStatusItem()
        setupPopover()
        GlobalHotkey.shared.onPress = { [weak self] in self?.quitAll() }
        GlobalHotkey.shared.register(model.s.hotkeyEnabled ? model.s.hotkey : nil)
        controller.objectWillChange.sink { [weak self] in DispatchQueue.main.async { self?.panel.resizeAndPlace() } }.store(in: &bag)
        controller.onPhase = { [weak self] p in
            guard let self else { return }
            switch p {
            case .quitting, .overdue: self.panel.show()
            case .done: self.panel.show(); self.panel.hide(after: 7)
            case .undone: self.panel.show(); self.panel.hide(after: 4)
            case .idle: break
            }
        }
        if !model.s.onboardingDone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in showOnboarding() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !model.s.onboardingDone { showOnboarding() }
        else if model.s.reopenAction == .quitAll { quitAll() }
        else { showPopover() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let s = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, let u = URL(string: s), u.scheme == "quitall" else { return }
        let q = URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch u.host ?? "" {
        case "quit", "quitall", "":
            quitAll(profileName: q.first { $0.name == "profile" }?.value)
        case "undo": controller.undo()
        case "settings": showSettings()
        case "menu": showPopover()
        default: break
        }
    }

    // MARK: acciones

    func quitAll(profileName: String? = nil) {
        guard model.s.onboardingDone else { showOnboarding(); return }
        guard !controller.isBusy else { panel.show(); return }
        popover.performClose(nil)
        var profile = model.s.activeProfile
        if let n = profileName, let p = model.s.profile(named: n) { profile = p }
        controller.start(profile: profile, timeout: model.s.timeout)
    }

    func settingsChanged(_ old: Settings, _ new: Settings) {
        if old.language != new.language {
            Lang.forced = new.language
            NSApp.mainMenu = MainMenu.build(target: self)
            settingsWindow?.title = tr("QuitAll — Ajustes", "QuitAll — Settings")
            onboardingWindow?.title = tr("Bienvenido a QuitAll", "Welcome to QuitAll")
            if Integrations.serviceInstalled { try? Integrations.installService() }   // el título del Servicio va en su idioma
        }
        if old.hotkey != new.hotkey || old.hotkeyEnabled != new.hotkeyEnabled {
            GlobalHotkey.shared.register(new.hotkeyEnabled ? new.hotkey : nil)
        }
        if old.launchAtLogin != new.launchAtLogin, new.onboardingDone, let err = Integrations.setLaunchAtLogin(new.launchAtLogin) {
            let a = NSAlert()
            a.messageText = tr("No se pudo cambiar el inicio de sesión", "Couldn't change the login item")
            a.informativeText = err
            a.runModal()
        }
    }

    // MARK: barra de menús

    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "QuitAllStatusItem"
        if let b = item.button {
            let img = NSImage(systemSymbolName: "power", accessibilityDescription: "QuitAll")
            img?.isTemplate = true
            b.image = img
            b.toolTip = "QuitAll"
            b.target = self
            b.action = #selector(statusClicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverView(
            model: model, c: controller, refresh: popoverRefresh,
            quitAll: { [weak self] in self?.quitAll() },
            openSettings: { [weak self] in self?.popover.performClose(nil); self?.showSettings() },
            quitApp: { NSApp.terminate(nil) }))
    }

    @objc func statusClicked(_ sender: NSStatusBarButton) {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            let m = NSMenu()
            m.addItem(ActionItem(tr("Cerrar todo", "Quit all")) { [weak self] in self?.quitAll() })
            if controller.lastRun != nil { m.addItem(ActionItem(tr("Deshacer último cierre", "Undo last quit")) { [weak self] in self?.controller.undo() }) }
            m.addItem(.separator())
            m.addItem(ActionItem(tr("Ajustes…", "Settings…"), key: ",") { [weak self] in self?.showSettings() })
            m.addItem(ActionItem(tr("Acerca de QuitAll", "About QuitAll")) { [weak self] in self?.showAbout() })
            m.addItem(NSMenuItem(title: tr("Salir de QuitAll", "Quit QuitAll"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem?.menu = m
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
            return
        }
        if popover.isShown { popover.performClose(nil) } else { showPopover() }
    }

    func showPopover() {
        guard let b = statusItem?.button else { return }
        if !model.s.onboardingDone { showOnboarding(); return }
        popoverRefresh.v += 1
        controller.lastRun = UndoStore.load()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: ventanas

    @objc func showSettingsAction() { showSettings() }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: tr("QuitAll — Ajustes", "QuitAll — Settings"), view: SettingsView(model: model))
        }
        AppList.shared.load()
        present(settingsWindow!)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let v = OnboardingView(model: model) { [weak self] in self?.finishOnboarding() }
            onboardingWindow = makeWindow(title: tr("Bienvenido a QuitAll", "Welcome to QuitAll"), view: v)
        }
        present(onboardingWindow!)
    }

    func finishOnboarding() {
        model.s.onboardingDone = true
        if let err = Integrations.setLaunchAtLogin(model.s.launchAtLogin), model.s.launchAtLogin {
            NSLog("QuitAll: login item: \(err)")
        }
        onboardingWindow?.close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showPopover() }
    }

    func makeWindow<V: View>(title: String, view: V) -> NSWindow {
        let host = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: host)
        w.title = title
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        return w
    }

    func present(_ w: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        if w === settingsWindow { settingsWindow = nil }
        if w === onboardingWindow { onboardingWindow = nil }
        DispatchQueue.main.async { [self] in
            if ![settingsWindow, onboardingWindow].contains(where: { $0?.isVisible ?? false }) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: tr("Cierra todas las apps con un clic, menos las que elijas.\nSoftware libre (MIT).",
                                                    "Quit every app in one click, except the ones you pick.\nFree software (MIT)."))
        ])
    }
}
