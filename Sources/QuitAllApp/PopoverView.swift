import SwiftUI
import AppKit
import QuitAllCore

/// Lo que se abre al hacer clic en el icono de la barra de menús.
struct PopoverView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var c: QuitController
    var refresh: Local<Int>          // se incrementa cada vez que se abre el popover (recalcula el plan)
    var quitAll: () -> Void
    var openSettings: () -> Void
    var quitApp: () -> Void
    @ObservedObject private var tick: Local<Int>

    init(model: SettingsModel, c: QuitController, refresh: Local<Int>, quitAll: @escaping () -> Void, openSettings: @escaping () -> Void, quitApp: @escaping () -> Void) {
        self.model = model; self.c = c; self.refresh = refresh
        self.quitAll = quitAll; self.openSettings = openSettings; self.quitApp = quitApp
        _tick = ObservedObject(wrappedValue: refresh)
    }

    private var plan: [PlanItem] { _ = tick.v; return Snapshot.fakePlan(model.s.activeProfile) ?? Planner.plan(profile: model.s.activeProfile) }

    var body: some View {
        let plan = self.plan
        let sm = Planner.summary(plan)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                BrandMark(size: 22)
                Text("QuitAll").font(.system(size: 14, weight: .bold))
                Spacer()
                if model.s.profiles.count > 1 {
                    Picker("", selection: Binding(get: { model.s.activeProfile.id }, set: { model.s.activeProfileID = $0 })) {
                        ForEach(model.s.profiles) { Text($0.name).tag($0.id) }
                    }.labelsHidden().fixedSize().controlSize(.small)
                }
            }

            if plan.isEmpty {
                Text(tr("No hay apps abiertas.", "No apps are open.")).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(46), spacing: 6), count: 6), spacing: 8) {
                    ForEach(plan) { it in appTile(it) }
                }
                Text(tr("Toca una app para cambiar qué le pasa: cerrar → ocultar → dejar.", "Tap an app to change what happens: quit → hide → keep."))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button(action: quitAll) {
                HStack {
                    Image(systemName: "power")
                    Text(sm.quit == 0 ? tr("Cerrar todo", "Quit all") : tr("Cerrar todo (\(sm.quit))", "Quit all (\(sm.quit))"))
                    Spacer()
                    if model.s.hotkeyEnabled { Text(model.s.hotkey.display).font(.system(size: 11, design: .rounded)).opacity(0.75) }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LinearGradient(colors: [Color.brand, Color(red: 0.36, green: 0.22, blue: 0.84)], startPoint: .leading, endPoint: .trailing)))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(c.isBusy)
            .opacity(c.isBusy ? 0.6 : 1)

            Text(summaryText(sm)).font(.caption).foregroundStyle(.secondary)

            if let last = c.lastRun, !c.isBusy {
                Button { c.undo() } label: {
                    Label(tr("Deshacer: reabrir \(last.quit.count) y mostrar \(last.hidden.count)", "Undo: reopen \(last.quit.count), show \(last.hidden.count)"),
                          systemImage: "arrow.uturn.backward")
                }.buttonStyle(.link).font(.callout)
            }

            Divider()
            HStack {
                Button(tr("Ajustes…", "Settings…"), action: openSettings).buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(tr("Salir de QuitAll", "Quit QuitAll"), action: quitApp).buttonStyle(.plain).foregroundStyle(.secondary)
            }.font(.callout)
        }
        .padding(14)
        .frame(width: 340)
        .tint(Color.brand)
    }

    private func summaryText(_ sm: (quit: Int, hide: Int, keep: Int)) -> String {
        var p = [tr("\(sm.quit) se cierran", "\(sm.quit) quit")]
        if sm.hide > 0 { p.append(tr("\(sm.hide) se ocultan", "\(sm.hide) hidden")) }
        if sm.keep > 0 { p.append(tr("\(sm.keep) se quedan", "\(sm.keep) kept")) }
        return p.joined(separator: " · ") + " — " + model.s.activeProfile.name
    }

    private func appTile(_ it: PlanItem) -> some View {
        Button {
            guard it.protection == nil else { return }
            model.setRule(it.bundleID, it.rule.next)
            refresh.v += 1
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: Icons.icon(it.url, id: it.bundleID)).resizable().frame(width: 38, height: 38)
                    .opacity(it.action == .quit ? 0.55 : 1)
                    .saturation(it.action == .quit ? 0.4 : 1)
                Image(systemName: it.protection != nil ? "lock.fill" : it.action.symbol)
                    .font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(it.protection != nil ? Color.gray : it.action.tint))
                    .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                    .offset(x: 3, y: 3)
            }
            .frame(width: 46, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(it.name) — \(it.protection.map(Protection.label) ?? it.action.title)")
    }
}
