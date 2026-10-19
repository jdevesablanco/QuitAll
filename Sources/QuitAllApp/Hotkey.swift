import AppKit
import Carbon.HIToolbox
import SwiftUI
import QuitAllCore

/// Atajo global con `RegisterEventHotKey` de Carbon: funciona en cualquier app y no pide permiso de Accesibilidad.
final class GlobalHotkey {
    static let shared = GlobalHotkey()
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// Devuelve false si macOS no deja registrarlo (otra app ya usa esa combinación).
    @discardableResult
    func register(_ hk: Hotkey?) -> Bool {
        unregister()
        guard let hk else { return true }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { GlobalHotkey.shared.onPress?() }
                return noErr
            }, 1, &spec, nil, &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x5141_4C4C), id: 1)   // 'QALL'
        return RegisterEventHotKey(hk.keyCode, hk.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    static func carbonModifiers(_ f: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if f.contains(.command) { m |= Hotkey.cmd }
        if f.contains(.option) { m |= Hotkey.option }
        if f.contains(.control) { m |= Hotkey.control }
        if f.contains(.shift) { m |= Hotkey.shift }
        return m
    }

    static func keyName(_ e: NSEvent) -> String {
        let special: [UInt16: String] = [
            49: tr("Espacio", "Space"), 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        ]
        if let s = special[e.keyCode] { return s }
        return (e.charactersIgnoringModifiers ?? "?").uppercased()
    }
}

/// Botón que graba un atajo: pulsas y tecleas la combinación (⎋ cancela, ⌫ borra).
struct HotkeyRecorder: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var recording = Local(false)
    @StateObject private var monitor = Local<Any?>(nil)
    @StateObject private var warn = Local("")

    var body: some View {
        HStack(spacing: 8) {
            Button {
                recording.v ? stop() : start()
            } label: {
                Text(recording.v ? tr("Pulsa la combinación…", "Type the shortcut…") : (model.s.hotkeyEnabled ? model.s.hotkey.display : tr("Sin atajo", "No shortcut")))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(minWidth: 150)
                    .padding(.vertical, 5).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(recording.v ? Color.brand.opacity(0.18) : Color.gray.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(recording.v ? Color.brand : Color.gray.opacity(0.35), lineWidth: recording.v ? 2 : 1))
            }.buttonStyle(.plain)
            if model.s.hotkeyEnabled && !recording.v {
                Button { model.s.hotkeyEnabled = false } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).help(tr("Quitar atajo", "Remove shortcut"))
            }
            if !warn.v.isEmpty { Text(warn.v).font(.caption).foregroundStyle(.orange) }
        }
        .onDisappear { stop() }
    }

    private func start() {
        warn.v = ""
        recording.v = true
        GlobalHotkey.shared.unregister()
        monitor.v = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            let mods = GlobalHotkey.carbonModifiers(e.modifierFlags)
            if e.keyCode == 53 { stop(); return nil }                         // ⎋
            if e.keyCode == 51 && mods == 0 { model.s.hotkeyEnabled = false; stop(); return nil }   // ⌫
            let isF = (96...122).contains(Int(e.keyCode))
            guard mods & (Hotkey.cmd | Hotkey.control | Hotkey.option) != 0 || isF else {
                warn.v = tr("Usa ⌘, ⌃ o ⌥", "Use ⌘, ⌃ or ⌥"); return nil
            }
            model.s.hotkey = Hotkey(keyCode: UInt32(e.keyCode), modifiers: mods, key: GlobalHotkey.keyName(e))
            model.s.hotkeyEnabled = true
            stop()
            return nil
        }
    }

    private func stop() {
        if let m = monitor.v { NSEvent.removeMonitor(m) }
        monitor.v = nil
        if recording.v { recording.v = false }
        let ok = GlobalHotkey.shared.register(model.s.hotkeyEnabled ? model.s.hotkey : nil)
        if !ok { warn.v = tr("Otra app ya usa ese atajo", "Another app already uses it") }
    }
}
