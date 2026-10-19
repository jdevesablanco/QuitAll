import SwiftUI
import AppKit
import QuitAllCore

/// Lista de apps (instaladas + abiertas) cargada una vez en segundo plano.
final class AppList: ObservableObject {
    static let shared = AppList()
    @Published private(set) var apps: [AppEntry] = []
    @Published private(set) var loaded = false
    @Published private(set) var running: Set<String> = []

    func load(force: Bool = false) {
        refreshRunning()
        guard force || !loaded else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let all = AppCatalog.all()
            DispatchQueue.main.async { self.apps = all; self.loaded = true }
        }
    }

    /// Carga síncrona (modo instantánea, sin run loop).
    func loadNow() { apps = AppCatalog.all(); loaded = true; refreshRunning() }

    func refreshRunning() { running = Set(Running.regularApps().compactMap(\.bundleIdentifier)) }
}

/// Las apps que NO se cierran, en desplegables por categoría: logo + nombre + regla.
struct AppRulesView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var list = AppList.shared
    var compact = false
    @StateObject private var query = Local("")
    @StateObject private var onlyRunning = Local(false)
    @StateObject private var expanded = Local<Set<AppCategory>>(Snapshot.active ? [.music] : [])

    private func visible(_ e: AppEntry) -> Bool {
        if onlyRunning.v && !list.running.contains(e.bundleID) { return false }
        let q = query.v.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || e.name.localizedCaseInsensitiveContains(q) || e.bundleID.localizedCaseInsensitiveContains(q)
    }

    private var groups: [(AppCategory, [AppEntry])] {
        let ov = model.s.categoryOverrides
        let d = Dictionary(grouping: list.apps.filter(visible)) { $0.category(overrides: ov) }
        return AppCategory.allCases.compactMap { c in d[c].map { (c, $0) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(tr("Buscar app", "Search apps"), text: $query.v).textFieldStyle(.plain)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
                Toggle(tr("Solo abiertas", "Open only"), isOn: $onlyRunning.v).toggleStyle(.checkbox)
            }
            if !list.loaded {
                HStack { Spacer(); ProgressView().controlSize(.small); Text(tr("Buscando apps…", "Finding apps…")).foregroundStyle(.secondary); Spacer() }
                    .frame(maxHeight: .infinity)
            } else {
                if Snapshot.active {
                    // ImageRenderer no pinta ScrollView: en modo instantánea, lista plana.
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(groups.prefix(7), id: \.0) { cat, apps in section(cat, apps) }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(groups, id: \.0) { cat, apps in section(cat, apps) }
                        }.padding(.trailing, 6)
                    }
                }
            }
        }
        .onAppear { list.load() }
    }

    private func isOpen(_ c: AppCategory) -> Bool { expanded.v.contains(c) || !query.v.isEmpty }

    private func section(_ cat: AppCategory, _ apps: [AppEntry]) -> some View {
        let exceptions = apps.filter { !Protection.isProtected($0.bundleID, url: $0.url) && model.rule($0.bundleID) != .quit }
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if expanded.v.contains(cat) { expanded.v.remove(cat) } else { expanded.v.insert(cat) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen(cat) ? 90 : 0))
                    Image(systemName: cat.symbol).foregroundStyle(Color.brand).frame(width: 18)
                    Text(cat.title).font(.system(size: 13, weight: .semibold))
                    Text("\(apps.count)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    // Vista previa: iconos de las que no se cierran.
                    HStack(spacing: -5) {
                        ForEach(exceptions.prefix(5)) { e in
                            Image(nsImage: Icons.icon(e.url, id: e.bundleID)).resizable().frame(width: 18, height: 18)
                        }
                    }
                    if !exceptions.isEmpty {
                        Text(tr("\(exceptions.count) no se cierran", "\(exceptions.count) not quit")).font(.caption).foregroundStyle(Color.brand)
                    }
                }
                .padding(.vertical, 7).padding(.horizontal, 10)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            if isOpen(cat) {
                VStack(spacing: 0) {
                    ForEach(apps) { e in row(e) }
                }.padding(.bottom, 4)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.045)))
    }

    private func row(_ e: AppEntry) -> some View {
        let prot = Protection.reason(bundleID: e.bundleID, url: e.url)
        return HStack(spacing: 8) {
            Image(nsImage: Icons.icon(e.url, id: e.bundleID)).resizable().frame(width: 22, height: 22)
            Text(e.name).lineLimit(1)
            if list.running.contains(e.bundleID) {
                Circle().fill(Color.green).frame(width: 6, height: 6).help(tr("Abierta ahora", "Open now"))
            }
            Spacer(minLength: 6)
            if let prot {
                Label(Protection.label(prot), systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
            } else {
                RulePicker(rule: model.ruleBinding(e.bundleID), compact: compact)
            }
            Menu {
                Picker(tr("Categoría", "Category"), selection: model.categoryBinding(e)) {
                    ForEach(AppCategory.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                if model.s.categoryOverrides[e.bundleID] != nil {
                    Button(tr("Volver a la categoría automática", "Reset to automatic category")) { model.s.categoryOverrides[e.bundleID] = nil }
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help(tr("Cambiar categoría", "Change category"))
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
    }
}

/// Selector Cerrar / Ocultar / Dejar como cápsulas de color.
struct RulePicker: View {
    @Binding var rule: RuleAction
    var compact = false
    var body: some View {
        HStack(spacing: 2) {
            ForEach(RuleAction.allCases) { a in
                Button { withAnimation(.easeOut(duration: 0.12)) { rule = a } } label: {
                    HStack(spacing: 3) {
                        Image(systemName: a.symbol).font(.system(size: 9, weight: .bold))
                        if !compact || rule == a { Text(a.short).font(.system(size: 11, weight: .medium)) }
                    }
                    .padding(.horizontal, 7).frame(height: 20)
                    .foregroundStyle(rule == a ? Color.white : Color.secondary)
                    .background(Capsule().fill(rule == a ? a.tint : Color.clear))
                    .contentShape(Capsule())
                }.buttonStyle(.plain).help(a.title)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }
}
