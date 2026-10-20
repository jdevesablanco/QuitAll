import SwiftUI
import AppKit
import QuitAllCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @StateObject private var tab = Local(0)
    @StateObject private var pack = PackStore()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                tabButton(0, tr("Apps", "Apps"), "square.grid.2x2")
                tabButton(1, tr("Perfiles", "Profiles"), "person.2")
                tabButton(2, tr("Lanzar", "Launch"), "keyboard")
                tabButton(3, tr("Combina bien con", "Pairs well with"), "puzzlepiece.extension")
                Spacer()
                LanguageSwitch(model: model)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            Group {
                switch tab.v {
                case 0: appsTab
                case 1: ProfilesEditor(model: model)
                case 2: launchTab
                default: packTab
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 580)
        .tint(Color.brand)
    }

    private func tabButton(_ i: Int, _ title: String, _ symbol: String) -> some View {
        Button { tab.v = i } label: {
            Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .foregroundStyle(tab.v == i ? Color.white : Color.primary)
                .background(Capsule().fill(tab.v == i ? Color.brand : Color.clear))
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }

    private var appsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("Qué no se cierra", "What doesn't quit")).font(.title3.bold())
                Spacer()
                ProfilePicker(model: model)
            }
            Text(tr("Todas las apps se cierran salvo las que marques como «Ocultar» o «Dejar». Finder, QuitAll y las piezas del sistema nunca se cierran. Usa ⋯ para cambiar la categoría de una app.",
                    "Every app quits except the ones you set to “Hide” or “Keep”. Finder, QuitAll and system components never quit. Use ⋯ to change an app's category."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            AppRulesView(model: model)
        }
    }

    private var launchTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Cómo lanzar «Cerrar todo»", "How to run “Quit all”")).font(.title3.bold())
            row(tr("Atajo global", "Global shortcut"), tr("Funciona en cualquier app, sin permisos especiales.", "Works in any app, no special permissions.")) {
                HotkeyRecorder(model: model)
            }
            row(tr("Menú Servicios", "Services menu"), tr("«QuitAll: cerrar todo» en el menú de la app activa → Servicios. Puedes darle un atajo en Ajustes del Sistema → Teclado → Funciones rápidas.",
                                                         "“QuitAll: Quit all” under the active app's menu → Services. You can give it a shortcut in System Settings → Keyboard → Keyboard Shortcuts.")) {
                Toggle("", isOn: Binding(get: { Integrations.serviceInstalled },
                                         set: { $0 ? try? Integrations.installService() : Integrations.removeService(); model.objectWillChange.send() }))
                    .labelsHidden().toggleStyle(.switch)
            }
            row(tr("Icono en la barra de menús", "Menu bar icon"), tr("Si lo quitas, usa QuitAll desde Spotlight, Alfred, Raycast o el Dock: al abrir la app se ejecuta «Cerrar todo» con tus excepciones. Para volver aquí, mantén ⇧ al abrirla o pulsa ⚙︎ en el aviso que sale tras cerrar.",
                                                                         "If you remove it, use QuitAll from Spotlight, Alfred, Raycast or the Dock: opening the app runs “Quit all” with your exceptions. To come back here, hold ⇧ while opening it, or click ⚙︎ in the notice shown after quitting.")) {
                Toggle("", isOn: $model.s.showMenuBarIcon).labelsHidden().toggleStyle(.switch)
            }
            row(tr("Al abrir QuitAll", "When you open QuitAll"), tr("Desde Spotlight, Alfred, Raycast, Launchpad, el Dock o Finder. Nunca al iniciar sesión. Con ⇧ pulsada abre estos Ajustes.", "From Spotlight, Alfred, Raycast, Launchpad, the Dock or Finder. Never at login. Holding ⇧ opens these Settings.")) {
                Picker("", selection: $model.s.reopenAction) {
                    Text(tr("Mostrar el menú", "Show the menu")).tag(ReopenAction.showMenu)
                    Text(tr("Cerrar todo", "Quit all")).tag(ReopenAction.quitAll)
                }.labelsHidden().fixedSize()
            }
            row(tr("Forzar cierre tras", "Offer force quit after"), tr("Segundos de espera antes de ofrecer «Forzar» a las apps que no se cierran.", "Seconds to wait before offering “Force” for apps that don't quit.")) {
                Stepper("\(Int(model.s.timeout)) s", value: $model.s.timeout, in: 3...60, step: 1).fixedSize()
            }
            row(tr("Abrir al iniciar sesión", "Open at login"), tr("Para que el atajo funcione siempre.", "So the shortcut always works.")) {
                Toggle("", isOn: $model.s.launchAtLogin).labelsHidden().toggleStyle(.switch)
            }
            Text(tr("También: open quitall://quit (o ?profile=Estudio), quitall://undo, y el comando `quitall` en Terminal o en Atajos («Ejecutar script de shell»). El clic derecho en el fondo del escritorio no se puede ampliar en macOS.",
                    "Also: open quitall://quit (or ?profile=Study), quitall://undo, and the `quitall` command in Terminal or Shortcuts (“Run Shell Script”). The desktop background right-click menu can't be extended on macOS."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                Text("QuitAll \(AppInfo.version) · MIT").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Link("GitHub", destination: URL(string: AppInfo.repoURL)!).font(.caption)
            }
        }
    }

    private func row<C: View>(_ title: String, _ detail: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control()
        }
    }

    private var packTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            PackAppsSection(store: pack)
        }
    }
}

struct ProfilePicker: View {
    @ObservedObject var model: SettingsModel
    var body: some View {
        Picker(tr("Perfil", "Profile"), selection: Binding(get: { model.s.activeProfile.id }, set: { model.s.activeProfileID = $0 })) {
            ForEach(model.s.profiles) { Text($0.name).tag($0.id) }
        }.fixedSize()
    }
}

/// Perfiles opcionales: cada uno con su propia lista de excepciones («Estudio», «Concentración»…).
struct ProfilesEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Perfiles", "Profiles")).font(.title3.bold())
            Text(tr("Opcional. Cada perfil guarda qué apps se ocultan o se quedan. El activo es el que usan el botón, el atajo y el Servicio; elígelo en el menú de la barra. Desde fuera: quitall://quit?profile=Nombre.",
                    "Optional. Each profile remembers which apps are hidden or kept. The active one is used by the button, the shortcut and the Service; pick it from the menu bar. From outside: quitall://quit?profile=Name."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 6) {
                ForEach(model.s.profiles) { p in
                    HStack(spacing: 10) {
                        Image(systemName: p.id == model.s.activeProfile.id ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(p.id == model.s.activeProfile.id ? Color.brand : Color.secondary)
                            .onTapGesture { model.s.activeProfileID = p.id }
                        TextField("", text: nameBinding(p.id)).textFieldStyle(.roundedBorder).frame(width: 220)
                        Text(tr("\(p.rules.count) excepciones", "\(p.rules.count) exceptions")).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { duplicate(p) } label: { Image(systemName: "plus.square.on.square") }.help(tr("Duplicar", "Duplicate"))
                        Button { model.s.profiles.removeAll { $0.id == p.id } } label: { Image(systemName: "trash") }
                            .disabled(model.s.profiles.count <= 1).help(tr("Borrar", "Delete"))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.045)))
                }
            }
            HStack {
                Text(tr("Añadir:", "Add:")).foregroundStyle(.secondary)
                ForEach([tr("Estudio", "Study"), tr("Concentración", "Focus"), tr("Presentación", "Presenting")], id: \.self) { n in
                    Button(n) { add(n) }.disabled(model.s.profile(named: n) != nil)
                }
                Button(tr("Otro…", "Other…")) { add(tr("Perfil \(model.s.profiles.count + 1)", "Profile \(model.s.profiles.count + 1)")) }
            }
            Spacer()
        }
    }

    private func nameBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { model.s.profiles.first { $0.id == id }?.name ?? "" },
                set: { v in if let i = model.s.profiles.firstIndex(where: { $0.id == id }) { model.s.profiles[i].name = v } })
    }

    private func add(_ name: String) {
        // Parte de las reglas del perfil activo: lo normal es retocar, no empezar de cero.
        let p = Profile(name: name, rules: model.s.activeProfile.rules)
        model.s.profiles.append(p)
        model.s.activeProfileID = p.id
    }

    private func duplicate(_ p: Profile) {
        model.s.profiles.append(Profile(name: p.name + tr(" (copia)", " (copy)"), rules: p.rules))
    }
}

struct LanguageSwitch: View {
    @ObservedObject var model: SettingsModel
    @Namespace private var ns
    private var isES: Bool { model.s.language == .es || (model.s.language == .auto && (Locale.preferredLanguages.first ?? "en").hasPrefix("es")) }

    private func seg(_ title: String, es: Bool) -> some View {
        let selected = isES == es
        return Button { withAnimation(.easeInOut(duration: 0.18)) { model.s.language = es ? .es : .en } } label: {
            Text(title).font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 22)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(nsColor: .controlColor))
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
                            .matchedGeometryEffect(id: "sel", in: ns)
                    }
                }
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 0) { seg("ES", es: true); seg("EN", es: false) }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.gray.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
            .help(tr("Idioma: español / inglés", "Language: Spanish / English"))
    }
}
