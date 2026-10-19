import AppKit
import QuitAllCore

/// Menú principal (solo se ve con una ventana abierta: Ajustes u onboarding). Necesario para ⌘C/⌘V/⌘W.
enum MainMenu {
    static func build(target: AppDelegate) -> NSMenu {
        let main = NSMenu()
        func add(_ menu: NSMenu, _ title: String, _ sel: Selector?, _ key: String = "", mods: NSEvent.ModifierFlags = .command, target t: AnyObject? = nil) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.target = t
            menu.addItem(i)
        }
        func container(_ title: String) -> NSMenu {
            let item = NSMenuItem(); main.addItem(item)
            let m = NSMenu(title: title); item.submenu = m
            return m
        }
        let app = container("QuitAll")
        add(app, tr("Acerca de QuitAll", "About QuitAll"), #selector(AppDelegate.showAbout), target: target)
        app.addItem(.separator())
        add(app, tr("Ajustes…", "Settings…"), #selector(AppDelegate.showSettingsAction), ",", target: target)
        app.addItem(.separator())
        add(app, tr("Ocultar QuitAll", "Hide QuitAll"), #selector(NSApplication.hide(_:)), "h")
        add(app, tr("Salir de QuitAll", "Quit QuitAll"), #selector(NSApplication.terminate(_:)), "q")

        let edit = container(tr("Edición", "Edit"))
        add(edit, tr("Deshacer", "Undo"), Selector(("undo:")), "z")
        add(edit, tr("Rehacer", "Redo"), Selector(("redo:")), "z", mods: [.command, .shift])
        edit.addItem(.separator())
        add(edit, tr("Cortar", "Cut"), #selector(NSText.cut(_:)), "x")
        add(edit, tr("Copiar", "Copy"), #selector(NSText.copy(_:)), "c")
        add(edit, tr("Pegar", "Paste"), #selector(NSText.paste(_:)), "v")
        add(edit, tr("Seleccionar todo", "Select All"), #selector(NSText.selectAll(_:)), "a")

        let win = container(tr("Ventana", "Window"))
        add(win, tr("Minimizar", "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m")
        add(win, tr("Cerrar", "Close"), #selector(NSWindow.performClose(_:)), "w")
        return main
    }
}
