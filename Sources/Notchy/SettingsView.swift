import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?

    func show(model: NotchModel) {
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "Ajustes do Notchy")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 500, height: 720))
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let model: NotchModel

    @State var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State var city = UserDefaults.standard.string(forKey: WeatherService.cityKey) ?? ""
    @State var accessibility = AXIsProcessTrusted()

    private static let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var body: some View {
        @Bindable var prefs = model.prefs
        Form {
            Section("Geral") {
                Toggle("Abrir ao iniciar o Mac", isOn: Binding {
                    launchAtLogin
                } set: { enabled in
                    setLaunchAtLogin(enabled)
                })
                Toggle("Som nos avisos", isOn: $prefs.alertsEnabled)
                LabeledContent("Vibração do trackpad") {
                    HStack(spacing: 8) {
                        Picker("Vibração do trackpad", selection: $prefs.hapticLevel) {
                            ForEach(Preferences.HapticLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                        .onChange(of: prefs.hapticLevel) { _, level in
                            Haptics.shared.perform(.normal, level: level)
                        }
                    }
                }
                Picker("Onde mostrar", selection: $prefs.screenMode) {
                    ForEach(Preferences.ScreenMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("Esconder quando um app estiver em tela cheia", isOn: $prefs.hideInFullscreen)
                Picker("Abrir o notch", selection: $prefs.openMode) {
                    ForEach(Preferences.OpenMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if prefs.openMode == .hover {
                    LabeledContent("Espera antes de abrir") {
                        HStack {
                            Slider(value: $prefs.hoverDelay, in: 0...0.8, step: 0.1)
                                .frame(width: 160)
                            (prefs.hoverDelay == 0 ? Text("na hora") : Text(verbatim: String(format: "%.1f s", prefs.hoverDelay)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
            }

            Section {
                Toggle("Deslizar para os lados troca de música", isOn: $prefs.swipeTracks)
                Picker("Deslizar para a direita", selection: $prefs.swipeRightNext) {
                    Text("Próxima música").tag(true)
                    Text("Música anterior").tag(false)
                }
                .disabled(!prefs.swipeTracks)
                Picker("Para cima e para baixo", selection: $prefs.verticalGesture) {
                    ForEach(Preferences.VerticalGesture.allCases) { gesture in
                        Text(gesture.title).tag(gesture)
                    }
                }
            } header: {
                Text("Gestos no trackpad")
            } footer: {
                Text("Use dois dedos com o cursor em cima do notch. No notch aberto, o volume responde em cima do player; nas listas, deslizar continua rolando.")
            }

            Section("Teste o trackpad") {
                HapticTestPad(prefs: model.prefs)
            }

            Section("Abas") {
                ForEach(NotchModel.Tab.allCases, id: \.self) { tab in
                    Toggle(tab.settingsTitle, isOn: tabBinding(tab))
                }
            }

            Section("Agenda e reuniões") {
                LabeledContent("Acesso ao Calendário") {
                    calendarStatus
                }
                Picker("Avisar antes da reunião", selection: $prefs.meetingLead) {
                    Text("Não avisar").tag(0)
                    Text("1 minuto").tag(1)
                    Text("5 minutos").tag(5)
                    Text("10 minutos").tag(10)
                    Text("15 minutos").tag(15)
                }
                Toggle("Contagem regressiva no notch recolhido", isOn: $prefs.meetingCountdown)
                    .disabled(prefs.meetingLead == 0)
            }

            Section {
                TextField("Cidade", text: $city, prompt: Text("Automática, pela sua conexão"))
                    .onSubmit(applyCity)
                HStack {
                    Text(weatherSummary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Aplicar", action: applyCity)
                }
            } header: {
                Text("Clima")
            } footer: {
                Text("Deixe vazio para descobrir a cidade pela sua conexão.")
            }

            Section {
                Toggle("Mostrar o que toca em qualquer app", isOn: Binding {
                    model.prefs.otherPlayers
                } set: { enabled in
                    model.setOtherPlayers(enabled)
                })
            } header: {
                Text("Música")
            } footer: {
                Text("Spotify e Music sempre aparecem. Com esta opção, o notch também mostra e controla o que toca no navegador, Podcasts, VLC e outros apps, nas versões do macOS que liberam o \"Tocando agora\" para outros apps.")
            }

            Section {
                Toggle("Oferecer vídeos do YouTube abertos no navegador", isOn: $prefs.youtubeEnabled)
                Toggle("Avisar quando fones conectarem e quando a bateria estiver baixa", isOn: $prefs.bluetoothAlerts)
            } header: {
                Text("Vídeo e Bluetooth")
            } footer: {
                Text("Vídeos: Safari, Chrome, Brave, Edge e Chromium. Para pausar a aba e continuar do mesmo segundo, ative \"Permitir JavaScript de Eventos Apple\" no menu Desenvolvedor do navegador (no Safari, mostre esse menu em Ajustes → Avançado).")
            }

            Section {
                ForEach(BadgeApp.allCases) { app in
                    Toggle(isOn: badgeBinding(app)) {
                        Label {
                            Text(app.rawValue)
                        } icon: {
                            AppIcon(bundleIDs: app.bundleIDs, size: 20, fallback: app.symbol)
                                .foregroundStyle(app.colors.first ?? .accentColor)
                        }
                    }
                }
                LabeledContent("Acessibilidade") {
                    accessibilityStatus
                }
            } header: {
                Text("Notificações")
            } footer: {
                Text("O número vem do ícone do app no Dock, então o app precisa estar aberto.")
            }

            Section {
                LabeledContent("Hooks do Claude Code") {
                    if model.permissions.hooksInstalled {
                        Label("Instalados", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Não instalados")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Status das sessões, aprovar pelo notch e uso da cota.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(hooksButtonTitle) {
                        model.permissions.installHooks(calendar: model.calendar)
                    }
                    .disabled(model.permissions.installingHooks || HooksInstaller.bundledInstaller == nil)
                }
            } header: {
                Text("Claude Code")
            } footer: {
                Text("Depois de instalar, reinicie as sessões do Claude Code que já estavam abertas.")
            }

            Section("Sobre") {
                LabeledContent("Versão", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                LabeledContent("No terminal", value: "notchy · stop · settings · doctor · update")
                HStack {
                    Button("Mostrar boas-vindas e permissões") {
                        model.openWelcome()
                    }
                    Spacer()
                    Link("Ver no GitHub", destination: URL(string: "https://github.com/lleonardo-franco/notchy")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 720)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibility = AXIsProcessTrusted()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    @ViewBuilder
    private var calendarStatus: some View {
        switch model.calendar.access {
        case .granted:
            Label("Permitido", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .unknown:
            Button("Permitir") {
                model.calendar.requestAccess()
            }
        case .denied:
            Button("Abrir Ajustes do Sistema") {
                NSWorkspace.shared.open(CalendarService.privacyURL)
            }
        }
    }

    @ViewBuilder
    private var accessibilityStatus: some View {
        if accessibility {
            Label("Ativada", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button("Ativar") {
                model.badges.requestTrust()
                NSWorkspace.shared.open(Self.accessibilityURL)
            }
        }
    }

    private var weatherSummary: String {
        guard let snapshot = model.weather.snapshot else {
            return model.weather.isLoading ? String(localized: "Carregando…") : String(localized: "Sem dados ainda")
        }
        return String(localized: "Agora: \(snapshot.city), \(Int(snapshot.temperature.rounded()))°")
    }

    private var hooksButtonTitle: LocalizedStringKey {
        if model.permissions.installingHooks { return "Instalando…" }
        return model.permissions.hooksInstalled ? "Reinstalar" : "Instalar"
    }

    private func applyCity() {
        model.prefs.weatherCity = city
        model.weather.refresh()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func tabBinding(_ tab: NotchModel.Tab) -> Binding<Bool> {
        Binding {
            model.prefs.enabledTabs.contains(tab.rawValue)
        } set: { enabled in
            if enabled {
                model.prefs.enabledTabs.insert(tab.rawValue)
            } else {
                model.prefs.enabledTabs.remove(tab.rawValue)
            }
        }
    }

    private func badgeBinding(_ app: BadgeApp) -> Binding<Bool> {
        Binding {
            model.prefs.isEnabled(app)
        } set: { enabled in
            model.prefs.setEnabled(app, enabled)
        }
    }
}
