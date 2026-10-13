#if DEBUG
import AppKit
import SwiftUI

final class ShowcaseWindow: NSWindow {
    override var backingScaleFactor: CGFloat { 2 }
}

@MainActor
enum Showcase {
    static let scene = CGSize(width: 1100, height: 400)
    static let scale: CGFloat = 2

    static func start(into folder: String) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        Task { @MainActor in
            let output = URL(fileURLWithPath: folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let screens = NSScreen.screens.map { "\($0.frame.size) @\($0.backingScaleFactor)x" }
            print("showcase screens: \(screens)")
            print("showcase language: \(Bundle.main.preferredLocalizations.first ?? "?")")
            let copy = ShowcaseCopy.current
            let files = makeFiles(copy)
            for shot in shots(copy: copy, files: files) {
                let model = makeModel(copy: copy, files: files)
                shot.prepare(model)
                await render(DemoDesktop(model: model, copy: copy, overlay: shot.overlay), size: scene, to: output.appendingPathComponent(shot.name + ".png"))
            }
            await renderSettings(copy: copy, files: files, to: output.appendingPathComponent("settings.png"))
            await renderWelcome(copy: copy, files: files, to: output.appendingPathComponent("welcome.png"))
            exit(0)
        }
    }

    struct Shot {
        let name: String
        var overlay: DemoOverlay = .none
        let prepare: (NotchModel) -> Void
    }

    static func shots(copy: ShowcaseCopy, files: [URL]) -> [Shot] {
        [
            Shot(name: "collapsed") { model in
                model.badges.demo(["WhatsApp": "3"])
                model.demo(expanded: false)
            },
            Shot(name: "music-claude") { model in
                model.demo(expanded: true, tab: .claude)
            },
            Shot(name: "approval") { model in
                model.claude.demo(
                    sessions: copy.sessions(),
                    approvals: [ApprovalRequest(
                        id: "demo",
                        sessionId: "api",
                        pid: ProcessInfo.processInfo.processIdentifier,
                        cwd: "/Users/demo/code/api-gateway",
                        tool: "Bash",
                        summary: "$ git push origin feature/rate-limit",
                        body: "git push origin feature/rate-limit",
                        createdAt: Date().timeIntervalSince1970
                    )],
                    usage: copy.usage,
                    contexts: ["notchy": 0.37]
                )
                model.demo(expanded: false)
            },
            Shot(name: "agenda") { model in
                model.demo(expanded: true, tab: .agenda)
            },
            Shot(name: "weather") { model in
                model.demo(expanded: true, tab: .weather)
            },
            Shot(name: "shelf-drop", overlay: .dragging(files[0])) { model in
                model.shelf.demo([])
                model.demo(expanded: true, tab: .shelf, fileDrag: true)
            },
            Shot(name: "shelf") { model in
                model.demo(expanded: true, tab: .shelf)
            },
            Shot(name: "bluetooth") { model in
                model.demo(expanded: true, tab: .bluetooth)
            },
            Shot(name: "clipboard") { model in
                model.demo(expanded: true, tab: .clipboard)
            },
            Shot(name: "volume") { model in
                model.demo(expanded: false, hud: NotchModel.LevelHUD(kind: .volume, level: 0.62))
            },
            Shot(name: "brightness") { model in
                model.demo(expanded: false, hud: NotchModel.LevelHUD(kind: .brightness, level: 0.8))
            },
            Shot(name: "peek-done") { model in
                model.demo(expanded: false, peek: NotchModel.Peek(style: .done, title: "landing-page", subtitle: String(localized: "terminou")))
            },
            Shot(name: "peek-battery") { model in
                let state = PowerState(level: 86, pluggedIn: true, charging: true, charged: false, minutesToEmpty: nil, minutesToFull: 38, adapterWatts: 70)
                model.demo(expanded: false, peek: NotchModel.Peek(style: .power(level: 86, charging: true), title: String(localized: "Carregando"), subtitle: state.summary))
            },
            Shot(name: "peek-airpods") { model in
                let device = copy.devices[0]
                model.demo(expanded: false, peek: NotchModel.Peek(style: .device(device.symbol), title: device.name, subtitle: device.batteryText))
            },
            Shot(name: "peek-meeting") { model in
                model.demo(expanded: false, peek: NotchModel.Peek(style: .meeting, title: copy.meeting, subtitle: String(localized: "em \(5) min")))
            }
        ]
    }

    static func makeModel(copy: ShowcaseCopy, files: [URL]) -> NotchModel {
        let model = NotchModel()
        model.demoScreen(NSRect(origin: .zero, size: scene), notchWidth: 186, notchHeight: 32)
        model.music.demo(
            Track(id: "demo", title: "Late Night Drive", artist: "Aurora Fields", album: "Neon Coast", duration: 245, source: .music),
            artwork: artwork(),
            playing: true,
            position: 75
        )
        model.claude.demo(sessions: copy.sessions(), usage: copy.usage, contexts: ["notchy": 0.37, "api": 0.61])
        model.calendar.demo(copy.events())
        model.weather.demo(copy.weather())
        model.bluetooth.demo(copy.devices)
        model.power.demo(PowerState(level: 86, pluggedIn: true, charging: true, charged: false, minutesToEmpty: nil, minutesToFull: 38, adapterWatts: 70))
        model.shelf.demo(Array(files.prefix(4)))
        model.clipboard.demo(copy.clips(files: files))
        model.badges.demo([:])
        return model
    }

    static func artwork() -> NSImage {
        NSImage(size: NSSize(width: 400, height: 400), flipped: false) { rect in
            NSGradient(colors: [
                NSColor(red: 0.98, green: 0.42, blue: 0.36, alpha: 1),
                NSColor(red: 0.72, green: 0.22, blue: 0.62, alpha: 1),
                NSColor(red: 0.18, green: 0.12, blue: 0.42, alpha: 1)
            ])?.draw(in: rect, angle: -70)
            NSColor(red: 1, green: 0.82, blue: 0.45, alpha: 0.95).setFill()
            NSBezierPath(ovalIn: NSRect(x: 130, y: 170, width: 140, height: 140)).fill()
            NSColor(red: 0.1, green: 0.06, blue: 0.25, alpha: 0.9).setFill()
            let hills = NSBezierPath()
            hills.move(to: NSPoint(x: 0, y: 0))
            hills.line(to: NSPoint(x: 0, y: 150))
            hills.curve(to: NSPoint(x: 220, y: 170), controlPoint1: NSPoint(x: 70, y: 210), controlPoint2: NSPoint(x: 150, y: 120))
            hills.curve(to: NSPoint(x: 400, y: 190), controlPoint1: NSPoint(x: 290, y: 220), controlPoint2: NSPoint(x: 350, y: 150))
            hills.line(to: NSPoint(x: 400, y: 0))
            hills.close()
            hills.fill()
            NSColor(red: 1, green: 0.6, blue: 0.5, alpha: 0.5).setStroke()
            for index in 0..<6 {
                let line = NSBezierPath()
                let y = CGFloat(20 + index * 18)
                line.move(to: NSPoint(x: 200 - CGFloat(index) * 6, y: y))
                line.line(to: NSPoint(x: 200 + CGFloat(index) * 6, y: y))
                line.lineWidth = 3
                line.stroke()
            }
            return true
        }
    }

    static func makeFiles(_ copy: ShowcaseCopy) -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NotchyShowcase", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return copy.files.map { name in
            let url = folder.appendingPathComponent(name)
            switch url.pathExtension {
            case "png":
                let image = artwork()
                if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?.write(to: url)
                }
            case "pdf":
                let data = NSMutableData()
                var box = CGRect(x: 0, y: 0, width: 595, height: 842)
                if let consumer = CGDataConsumer(data: data as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: &box, nil) {
                    context.beginPDFPage(nil)
                    context.setFillColor(NSColor.systemIndigo.cgColor)
                    context.fill(CGRect(x: 0, y: 600, width: 595, height: 242))
                    context.endPDFPage()
                    context.closePDF()
                }
                try? (data as Data).write(to: url)
            default:
                try? Data("Notchy".utf8).write(to: url)
            }
            return url
        }
    }

    static func render<Content: View>(_ view: Content, size: CGSize, to url: URL) async {
        let hosting = NSHostingView(rootView: view.environment(\.locale, ShowcaseCopy.locale))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = ShowcaseWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hosting
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(900))
        hosting.layoutSubtreeIfNeeded()
        save(hosting, size: size, to: url)
        window.orderOut(nil)
    }

    static func renderSettings(copy: ShowcaseCopy, files: [URL], to url: URL) async {
        let model = makeModel(copy: copy, files: files)
        let controller = NSHostingController(rootView: SettingsView(model: model).environment(\.locale, ShowcaseCopy.locale))
        let window = ShowcaseWindow(contentViewController: controller)
        window.title = String(localized: "Ajustes do Notchy")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 500, height: 720))
        window.setFrameOrigin(.zero)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        try? await Task.sleep(for: .milliseconds(1200))
        if let frame = window.contentView?.superview {
            save(frame, size: frame.bounds.size, to: url)
        }
        window.orderOut(nil)
    }

    static func renderWelcome(copy: ShowcaseCopy, files: [URL], to url: URL) async {
        let model = makeModel(copy: copy, files: files)
        model.permissions.refresh(calendar: model.calendar)
        let controller = NSHostingController(rootView: WelcomeView(model: model) {}.environment(\.locale, ShowcaseCopy.locale))
        let window = ShowcaseWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 680))
        window.setFrameOrigin(.zero)
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(for: .milliseconds(1200))
        if let frame = window.contentView?.superview {
            save(frame, size: frame.bounds.size, to: url)
        }
        window.orderOut(nil)
    }

    static func save(_ view: NSView, size: CGSize, to url: URL) {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("showcase wrote \(url.lastPathComponent) \(rep.pixelsWide)x\(rep.pixelsHigh)")
    }
}

enum DemoOverlay {
    case none
    case dragging(URL)
}

struct DemoDesktop: View {
    let model: NotchModel
    let copy: ShowcaseCopy
    let overlay: DemoOverlay

    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper()
            MenuBar(copy: copy, notchWidth: model.notchWidth, height: model.notchHeight)
            NotchView(model: model)
            if case .dragging(let url) = overlay {
                DraggedFile(url: url)
                    .offset(x: -70, y: 215)
            }
        }
        .frame(width: Showcase.scene.width, height: Showcase.scene.height)
        .clipped()
    }
}

struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.06, blue: 0.2), Color(red: 0.2, green: 0.1, blue: 0.36), Color(red: 0.55, green: 0.2, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color(red: 0.98, green: 0.5, blue: 0.35).opacity(0.75), .clear], center: UnitPoint(x: 0.85, y: 0.95), startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.7), .clear], center: UnitPoint(x: 0.1, y: 0.15), startRadius: 10, endRadius: 560)
            RadialGradient(colors: [Color(red: 0.6, green: 0.3, blue: 0.95).opacity(0.45), .clear], center: UnitPoint(x: 0.5, y: 0.75), startRadius: 10, endRadius: 420)
        }
    }
}

struct MenuBar: View {
    let copy: ShowcaseCopy
    let notchWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                Image(systemName: "applelogo")
                    .font(.system(size: 14, weight: .medium))
                Text("Finder")
                    .fontWeight(.bold)
                ForEach(copy.menus, id: \.self) { item in
                    Text(item)
                }
            }
            .padding(.leading, 18)
            Spacer(minLength: notchWidth + 40)
            HStack(spacing: 18) {
                Image(systemName: "battery.75percent")
                Image(systemName: "wifi")
                Image(systemName: "magnifyingglass")
                Image(systemName: "switch.2")
                Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
            }
            .padding(.trailing, 18)
        }
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(1)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.18))
    }
}

struct DraggedFile: View {
    let url: URL

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 58, height: 58)
                .opacity(0.85)
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            Image(systemName: "cursorarrow")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 1)
                .offset(x: 10, y: 12)
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .offset(x: -36, y: -40)
        }
    }
}

struct ShowcaseCopy {
    let menus: [String]
    let meeting: String
    let lunch: String
    let planning: String
    let city: String
    let files: [String]
    let doneprompt: String
    let clipText: String

    static var language: String { Bundle.main.preferredLocalizations.first ?? "pt-BR" }

    static var locale: Locale {
        switch language {
        case "en": return Locale(identifier: "en_US")
        case "es": return Locale(identifier: "es_ES")
        default: return Locale(identifier: "pt_BR")
        }
    }

    static var current: ShowcaseCopy {
        switch language {
        case "en":
            return ShowcaseCopy(
                menus: ["File", "Edit", "View", "Go", "Window", "Help"],
                meeting: "Design review",
                lunch: "Lunch with the team",
                planning: "Sprint planning",
                city: "London",
                files: ["Launch deck.pdf", "Hero banner.png", "Release notes.txt", "Press kit.zip", "Invoice 0142.pdf"],
                doneprompt: "make the hero section responsive",
                clipText: "Ship it on Thursday, the changelog is ready"
            )
        case "es":
            return ShowcaseCopy(
                menus: ["Archivo", "Edición", "Visualización", "Ir", "Ventana", "Ayuda"],
                meeting: "Revisión de diseño",
                lunch: "Comida con el equipo",
                planning: "Planificación del sprint",
                city: "Madrid",
                files: ["Presentación.pdf", "Banner principal.png", "Notas de la versión.txt", "Kit de prensa.zip", "Factura 0142.pdf"],
                doneprompt: "haz responsive la sección principal",
                clipText: "Lo publicamos el jueves, el changelog ya está listo"
            )
        default:
            return ShowcaseCopy(
                menus: ["Arquivo", "Editar", "Visualizar", "Ir", "Janela", "Ajuda"],
                meeting: "Revisão de design",
                lunch: "Almoço com o time",
                planning: "Planejamento da sprint",
                city: "São Paulo",
                files: ["Apresentação.pdf", "Banner da home.png", "Notas da versão.txt", "Kit de imprensa.zip", "Nota fiscal 0142.pdf"],
                doneprompt: "deixa o hero da home responsivo",
                clipText: "Sai na quinta, o changelog já está pronto"
            )
        }
    }

    func sessions() -> [ClaudeSession] {
        let now = Date().timeIntervalSince1970
        return [
            ClaudeSession(id: "notchy", cwd: "/Users/demo/code/notchy", status: .working, detail: "$ swift test", prompt: nil, promptAt: now - 154, tty: nil, claudePid: nil, app: nil, termProgram: nil, updatedAt: now),
            ClaudeSession(id: "api", cwd: "/Users/demo/code/api-gateway", status: .waiting, detail: nil, prompt: nil, promptAt: now - 610, tty: nil, claudePid: nil, app: nil, termProgram: nil, updatedAt: now),
            ClaudeSession(id: "landing", cwd: "/Users/demo/code/landing-page", status: .done, detail: nil, prompt: doneprompt, promptAt: now - 900, tty: nil, claudePid: nil, app: nil, termProgram: nil, updatedAt: now - 30)
        ]
    }

    var usage: Usage {
        let now = Date().timeIntervalSince1970
        return Usage(
            fiveHour: UsageWindow(usedPercentage: 42, resetsAt: now + 2 * 3600 + 13 * 60),
            sevenDay: UsageWindow(usedPercentage: 18, resetsAt: now + 3 * 86400 + 5 * 3600)
        )
    }

    func events() -> [AgendaEvent] {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return [
            AgendaEvent(id: "1", title: meeting, start: now.addingTimeInterval(40 * 60), end: now.addingTimeInterval(85 * 60), calendarName: "Work", red: 0.35, green: 0.55, blue: 1, meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")),
            AgendaEvent(id: "2", title: lunch, start: now.addingTimeInterval(150 * 60), end: now.addingTimeInterval(210 * 60), calendarName: "Home", red: 0.3, green: 0.8, blue: 0.45, meetingURL: nil),
            AgendaEvent(id: "3", title: planning, start: tomorrow.addingTimeInterval(10 * 3600), end: tomorrow.addingTimeInterval(11 * 3600), calendarName: "Work", red: 0.35, green: 0.55, blue: 1, meetingURL: URL(string: "https://zoom.us/j/0000000000"))
        ]
    }

    func weather() -> WeatherSnapshot {
        let now = Date()
        let hour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
        let codes = [2, 1, 1, 0, 2, 3, 61, 3]
        let temperatures: [Double] = [24, 25, 26, 26, 25, 23, 21, 20]
        let rain = [0, 0, 0, 5, 10, 30, 70, 40]
        let hours = (0..<8).map { index in
            HourForecast(date: hour.addingTimeInterval(Double(index + 1) * 3600), temperature: temperatures[index], code: codes[index], isDay: true, rain: rain[index])
        }
        return WeatherSnapshot(city: city, temperature: 24, feelsLike: 25, code: 2, isDay: true, high: 27, low: 17, hours: hours, timeZone: .current, updated: now)
    }

    var devices: [BluetoothDevice] {
        [
            BluetoothDevice(name: "AirPods Pro", kind: .headphones, left: 82, right: 79, caseLevel: 64, main: nil),
            BluetoothDevice(name: "Magic Keyboard", kind: .keyboard, left: nil, right: nil, caseLevel: nil, main: 71),
            BluetoothDevice(name: "Magic Mouse", kind: .mouse, left: nil, right: nil, caseLevel: nil, main: 38)
        ]
    }

    func clips(files: [URL]) -> [ClipItem] {
        let now = Date()
        var items = [
            ClipItem(kind: .text("https://github.com/lleonardo-franco/notchy"), date: now.addingTimeInterval(-40)),
            ClipItem(kind: .image(Showcase.artwork()), date: now.addingTimeInterval(-320)),
            ClipItem(kind: .text(clipText), date: now.addingTimeInterval(-900))
        ]
        if let file = files.last {
            items.append(ClipItem(kind: .file(file), date: now.addingTimeInterval(-1800)))
        }
        items.append(ClipItem(kind: .text("brew tap lleonardo-franco/notchy"), date: now.addingTimeInterval(-3600)))
        return items
    }
}
#endif
