import SwiftUI
import AppKit
import QuitAllCore

/// Primer uso: 3 pasos (qué hace → qué no se cierra → cómo lanzarlo) y pantalla final con el pack.
struct OnboardingView: View {
    @ObservedObject var model: SettingsModel
    var finish: () -> Void
    let startDone: Bool
    @StateObject private var stepBox: Local<Int>
    @StateObject private var serviceBox = Local(true)
    @StateObject private var doneBox: Local<Bool>
    @StateObject private var dirBox = Local(1)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: SettingsModel, startStep: Int = 0, startDone: Bool = false, finish: @escaping () -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.finish = finish
        self.startDone = startDone
        _stepBox = StateObject(wrappedValue: Local(startStep))
        _doneBox = StateObject(wrappedValue: Local(startDone))
    }

    private var step: Int { get { stepBox.v } nonmutating set { stepBox.v = newValue } }

    private func go(_ delta: Int) {
        dirBox.v = delta
        let anim: Animation? = reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.86)
        withAnimation(anim) { step += delta }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tr("Paso \(step + 1) de 3", "Step \(step + 1) of 3")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                LanguageSwitch(model: model)
            }.padding(.horizontal, 28).padding(.top, 16)
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.3))
                        Capsule().fill(Color.brand)
                            .scaleEffect(x: i <= step ? 1 : 0.0001, y: 1, anchor: .leading)
                            .opacity(i <= step ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45).delay(dirBox.v > 0 ? 0 : 0.08 * Double(2 - i)), value: step)
                    }
                    .frame(height: i == step ? 6 : 4)
                    .shadow(color: Color.brand.opacity(i == step ? 0.55 : 0), radius: 4)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: step)
                }
            }.padding(.horizontal, 28).padding(.top, 8)

            ZStack(alignment: .topLeading) {
                Group {
                    switch step {
                    case 0: stepIntro
                    case 1: stepApps
                    default: stepLaunch
                    }
                }
                .id(step)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: dirBox.v > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: dirBox.v > 0 ? .leading : .trailing).combined(with: .opacity)))
            }
            .padding(.horizontal, 28).padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()

            Divider()
            HStack {
                if step > 0 { Button(tr("Atrás", "Back")) { go(-1) } }
                Spacer()
                if step < 2 {
                    Button(tr("Siguiente", "Next")) { go(1) }.keyboardShortcut(.defaultAction)
                } else {
                    Button(tr("Empezar", "Get started")) { apply() }.keyboardShortcut(.defaultAction)
                }
            }.padding(16)
        }
        .frame(width: 700, height: 600)
        .tint(Color.brand)
        .overlay {
            if doneBox.v { OnboardingDoneView(finish: finish, startPhase: startDone ? 3 : 0).transition(.opacity) }
        }
    }

    // 1
    var stepIntro: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Cierra todo con un clic", "Quit everything in one click")).font(.title2.bold())
            Text(tr("QuitAll vive en la barra de menús (sin icono en el Dock). Un clic en su icono y «Cerrar todo» deja tu Mac limpio, salvo las apps que tú elijas.",
                    "QuitAll lives in the menu bar (no Dock icon). One click on its icon and “Quit all” leaves your Mac clean, except the apps you choose."))
                .fixedSize(horizontal: false, vertical: true)
            menuBarMock
            HStack(alignment: .top, spacing: 10) {
                actionCard(.quit, tr("Se cierran con educación, como con ⌘Q: cada app te pregunta si guardar.", "Quit politely, like ⌘Q: each app asks you to save."))
                actionCard(.hide, tr("Siguen abiertas pero desaparecen de la vista.", "Stay open but get out of sight."))
                actionCard(.keep, tr("No se tocan: la música sigue sonando.", "Untouched: your music keeps playing."))
            }.fixedSize(horizontal: false, vertical: true)
            Label {
                Text(tr("Si alguna no se cierra en unos segundos, te digo cuál y puedes forzarla. Y con «Deshacer» se reabre todo lo que se cerró.",
                        "If one doesn't quit within a few seconds, I'll tell you which and you can force it. “Undo” reopens everything that was quit."))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
            } icon: { Image(systemName: "arrow.uturn.backward.circle").foregroundStyle(Color.brand) }
            Label {
                Text(tr("Finder, QuitAll y las piezas del sistema nunca se cierran.", "Finder, QuitAll and system components never quit."))
                    .font(.callout)
            } icon: { Image(systemName: "lock.circle").foregroundStyle(Color.brand) }
        }
    }

    private func actionCard(_ a: RuleAction, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: a.symbol).font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 20, height: 20).background(Circle().fill(a.tint))
                Text(a.title).font(.system(size: 13, weight: .semibold))
            }
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    var menuBarMock: some View {
        HStack(spacing: 14) {
            Spacer()
            Image(systemName: "power").padding(4).background(RoundedRectangle(cornerRadius: 5).fill(Color.brand.opacity(0.35)))
            Image(systemName: "wifi"); Image(systemName: "battery.75")
            Text(tr("lun 9:41", "Mon 9:41")).font(.system(size: 12))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12).frame(height: 28)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.18)))
    }

    // 2
    var stepApps: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("¿Qué no se cierra?", "What shouldn't quit?")).font(.title2.bold())
            Text(tr("Abre una categoría y elige «Ocultar» o «Dejar» para las apps que quieras conservar. Las demás se cierran. Lo puedes cambiar luego (y tener perfiles distintos, p. ej. «Estudio»).",
                    "Open a category and pick “Hide” or “Keep” for the apps you want to spare. The rest quit. You can change it later (and keep separate profiles, e.g. “Study”)."))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            AppRulesView(model: model, compact: true)
                .padding(.bottom, 10)
        }
    }

    // 3
    var stepLaunch: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Lánzalo como prefieras", "Run it your way")).font(.title2.bold())
            option("cursorarrow.click", tr("Icono de la barra de menús", "Menu bar icon"), tr("Siempre disponible.", "Always available.")) {
                Image(systemName: "checkmark").foregroundStyle(Color.brand)
            }
            option("keyboard", tr("Atajo de teclado global", "Global keyboard shortcut"), tr("Haz clic y pulsa otra combinación para cambiarlo.", "Click and type another combination to change it.")) {
                HotkeyRecorder(model: model)
            }
            option("filemenu.and.selection", tr("Menú Servicios", "Services menu"), tr("«QuitAll: cerrar todo» en el menú de cualquier app → Servicios.", "“QuitAll: Quit all” in any app's menu → Services.")) {
                Toggle("", isOn: $serviceBox.v).labelsHidden().toggleStyle(.switch)
            }
            option("power", tr("Abrir al iniciar sesión", "Open at login"), tr("Para que el atajo funcione desde que enciendes el Mac.", "So the shortcut works as soon as you log in.")) {
                Toggle("", isOn: $model.s.launchAtLogin).labelsHidden().toggleStyle(.switch)
            }
            VStack(alignment: .leading, spacing: 4) {
                Label(tr("¿Y el clic derecho en el escritorio?", "What about right-clicking the desktop?"), systemImage: "info.circle").font(.callout.bold())
                Text(tr("macOS no permite añadir opciones al menú del fondo del escritorio (ni con Acciones rápidas ni con extensiones de Finder, que además no funcionan si el Escritorio está en iCloud). Por eso QuitAll usa el atajo, la barra de menús y Servicios. Y abrir QuitAll desde Spotlight o el Dock cierra todo al momento (se cambia en Ajustes → Lanzar).",
                        "macOS doesn't let apps add items to the desktop background menu (not with Quick Actions nor Finder extensions, which also fail when Desktop is in iCloud). So QuitAll uses the shortcut, the menu bar and Services. And opening QuitAll from Spotlight or the Dock quits everything right away (change it in Settings → Launch)."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
        }
    }

    private func option<C: View>(_ symbol: String, _ title: String, _ detail: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(Color.brand).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
    }

    func apply() {
        if serviceBox.v { try? Integrations.installService() }
        withAnimation(.easeInOut(duration: 0.35)) { doneBox.v = true }
    }
}

/// Pantalla final: animación de «todo listo» + «Combina bien con» (PackCatalog).
struct OnboardingDoneView: View {
    var finish: () -> Void
    var startPhase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var phase: Local<Int>          // 0 inicio · 1 anillo · 2 check · 3 contenido
    @StateObject private var pack = PackStore()

    init(finish: @escaping () -> Void, startPhase: Int = 0) {
        self.finish = finish
        self.startPhase = startPhase
        _phase = StateObject(wrappedValue: Local(startPhase))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            badge
            Text(tr("¡Todo listo!", "All set!"))
                .font(.system(size: 26, weight: .bold)).padding(.top, 6)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 10)
            Text(tr("Haz clic en el icono ⏻ de la barra de menús y pulsa «Cerrar todo».", "Click the ⏻ icon in the menu bar and press “Quit all”."))
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.top, 4).padding(.horizontal, 70)
                .opacity(phase.v >= 3 ? 1 : 0)
            PackAppsSection(store: pack, compact: true)
                .padding(.top, 18).padding(.horizontal, 44)
                .opacity(phase.v >= 3 ? 1 : 0).offset(y: phase.v >= 3 ? 0 : 18)
            Spacer(minLength: 8)
            Divider()
            HStack {
                Spacer()
                Button(tr("Terminar", "Finish")) { finish() }.keyboardShortcut(.defaultAction)
            }.padding(16)
        }
        .frame(width: 700, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { if startPhase == 0 { run() } }
    }

    private func run() {
        if reduceMotion { phase.v = 3; return }
        withAnimation(.easeOut(duration: 0.5)) { phase.v = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { phase.v = 2 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { withAnimation(.easeOut(duration: 0.55)) { phase.v = 3 } }
    }

    private var badge: some View {
        ZStack {
            Circle().fill(Color.brand.opacity(0.12)).frame(width: 84, height: 84)
                .scaleEffect(phase.v >= 1 ? 1 : 0.6).opacity(phase.v >= 1 ? 1 : 0)
            Circle().trim(from: 0, to: phase.v >= 1 ? 1 : 0)
                .stroke(Color.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90)).frame(width: 84, height: 84)
            DoneCheck().trim(from: 0, to: phase.v >= 2 ? 1 : 0)
                .stroke(Color.brand, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 34, height: 25)
        }
        .frame(height: 110)
    }
}

struct DoneCheck: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}
