import AppKit
import SwiftUI

@MainActor
final class WelcomeWindow {
    static let shared = WelcomeWindow()
    static let seenKey = "welcomeSeen-1.0"

    private var window: NSWindow?

    func show(model: NotchModel) {
        if window == nil {
            let controller = NSHostingController(rootView: WelcomeView(model: model) { [weak self] in
                self?.close()
            })
            let window = NSWindow(contentViewController: controller)
            window.title = "Bem-vindo ao Notchy"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 520, height: 680))
            window.center()
            self.window = window
        }
        model.permissions.refresh(calendar: model.calendar)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        window?.close()
    }
}

struct WelcomeView: View {
    let model: NotchModel
    let onFinish: () -> Void

    var body: some View {
        let permissions = model.permissions
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                Text("Bem-vindo ao Notchy")
                    .font(.system(size: 22, weight: .bold))
                Text("Seu notch, menos inútil. Libere só o que você for usar, dá para mudar depois nos ajustes.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            .padding(.top, 36)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 10) {
                    PermissionRow(
                        symbol: "hand.raised.fill",
                        tint: .blue,
                        title: "Acessibilidade",
                        detail: "Contador de notificações do WhatsApp e do ClickUp.",
                        state: permissions.accessibility ? .granted : .notDetermined
                    ) {
                        permissions.requestAccessibility()
                    }

                    ForEach(permissions.installedTargets) { target in
                        PermissionRow(
                            symbol: symbol(for: target),
                            tint: .orange,
                            title: "Controlar o \(target.name)",
                            detail: "Usado para \(target.purpose).",
                            state: permissions.automation[target.bundleID] ?? .notDetermined
                        ) {
                            permissions.requestAutomation(target, calendar: model.calendar)
                        }
                    }

                    PermissionRow(
                        symbol: "calendar",
                        tint: .red,
                        title: "Calendário",
                        detail: "Próximas reuniões, botão Entrar e contagem regressiva.",
                        state: calendarState
                    ) {
                        if model.calendar.access == .denied {
                            NSWorkspace.shared.open(CalendarService.privacyURL)
                        } else {
                            model.calendar.requestAccess()
                        }
                    }

                    PermissionRow(
                        symbol: "headphones",
                        tint: .purple,
                        title: "Bluetooth",
                        detail: "Bateria dos fones e de outros dispositivos.",
                        state: permissions.bluetooth
                    ) {
                        permissions.requestBluetooth()
                    }

                    PermissionRow(
                        symbol: "asterisk",
                        tint: .claude,
                        title: "Claude Code",
                        detail: "Status das sessões, aprovar pelo notch e uso da cota.",
                        state: permissions.hooksInstalled ? .granted : .notDetermined,
                        actionTitle: permissions.installingHooks ? "Instalando…" : "Instalar"
                    ) {
                        permissions.installHooks(calendar: model.calendar)
                    }

                    tips
                        .padding(.top, 8)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }

            HStack {
                Button("Abrir ajustes") {
                    onFinish()
                    model.openSettings()
                }
                Spacer()
                Button("Começar") {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(.bar)
        }
        .frame(width: 520, height: 680)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            permissions.refresh(calendar: model.calendar)
        }
    }

    private var calendarState: PermissionState {
        switch model.calendar.access {
        case .granted: return .granted
        case .denied: return .denied
        case .unknown: return .notDetermined
        }
    }

    private func symbol(for target: AutomationTarget) -> String {
        switch target.bundleID {
        case "com.apple.Safari", "com.google.Chrome": return "play.rectangle.fill"
        case "com.spotify.client", "com.apple.Music": return "music.note"
        default: return "terminal.fill"
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dicas rápidas")
                .font(.system(size: 13, weight: .semibold))
            tip("cursorarrow.motionlines", "Passe o mouse no notch para abrir.")
            tip("hand.draw", "Dois dedos para os lados trocam de música; para cima e para baixo mudam o volume.")
            tip("play.rectangle", "Com um vídeo do YouTube aberto, use \"Assistir no notch\".")
            tip("terminal", "No terminal: notchy, notchy stop, notchy settings, notchy doctor.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PermissionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let state: PermissionState
    var actionTitle: String = "Permitir"
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if state == .granted {
                Label("Pronto", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Button(state == .denied ? "Abrir Ajustes" : actionTitle, action: action)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }
}
