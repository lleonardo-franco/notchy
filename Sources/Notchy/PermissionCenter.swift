import AppKit
import ApplicationServices
import CoreBluetooth
import EventKit
import Observation

enum PermissionState: String {
    case granted
    case denied
    case notDetermined
    case notRunning
    case notInstalled

    var label: String {
        switch self {
        case .granted: return "Permitido"
        case .denied: return "Negado"
        case .notDetermined: return "Não pedido ainda"
        case .notRunning: return "Abra o app para pedir"
        case .notInstalled: return "Não instalado"
        }
    }
}

struct AutomationTarget: Identifiable, Hashable {
    let name: String
    let bundleID: String
    let purpose: String

    var id: String { bundleID }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

@MainActor
@Observable
final class PermissionCenter {
    static let targets = [
        AutomationTarget(name: "Safari", bundleID: "com.apple.Safari", purpose: "vídeos do YouTube"),
        AutomationTarget(name: "Google Chrome", bundleID: "com.google.Chrome", purpose: "vídeos do YouTube"),
        AutomationTarget(name: "Spotify", bundleID: "com.spotify.client", purpose: "música"),
        AutomationTarget(name: "Music", bundleID: "com.apple.Music", purpose: "música"),
        AutomationTarget(name: "Terminal", bundleID: "com.apple.Terminal", purpose: "ir para a sessão do Claude"),
        AutomationTarget(name: "iTerm", bundleID: "com.googlecode.iterm2", purpose: "ir para a sessão do Claude")
    ]

    static let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let automationURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
    static let bluetoothURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!

    private(set) var accessibility = false
    private(set) var bluetooth: PermissionState = .notDetermined
    private(set) var automation: [String: PermissionState] = [:]
    private(set) var hooksInstalled = false
    private(set) var installingHooks = false

    @ObservationIgnored private var bluetoothManager: CBCentralManager?
    @ObservationIgnored private var timer: Timer?

    var installedTargets: [AutomationTarget] {
        Self.targets.filter(\.isInstalled)
    }

    func start(calendar: CalendarService) {
        refresh(calendar: calendar)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.refresh(calendar: calendar)
            }
        }
    }

    func refresh(calendar: CalendarService) {
        accessibility = AXIsProcessTrusted()
        bluetooth = Self.bluetoothState()
        hooksInstalled = HooksInstaller.isInstalled
        let targets = installedTargets
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var states: [String: PermissionState] = [:]
            for target in targets {
                states[target.bundleID] = Self.automationState(target, ask: false)
            }
            let result = states
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.automation != result {
                        self.automation = result
                    }
                    self.writeStatus(calendar: calendar)
                }
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibility = AXIsProcessTrustedWithOptions(options)
        if !accessibility {
            NSWorkspace.shared.open(Self.accessibilityURL)
        }
    }

    func requestAutomation(_ target: AutomationTarget, calendar: CalendarService) {
        if automation[target.bundleID] == .denied {
            NSWorkspace.shared.open(Self.automationURL)
            return
        }
        let ask = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                _ = Self.automationState(target, ask: true)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.refresh(calendar: calendar) }
                }
            }
        }
        if target.isRunning {
            ask()
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                ask()
            }
        }
    }

    func requestBluetooth() {
        if bluetooth == .denied {
            NSWorkspace.shared.open(Self.bluetoothURL)
            return
        }
        bluetoothManager = CBCentralManager(delegate: nil, queue: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            MainActor.assumeIsolated {
                self?.bluetooth = Self.bluetoothState()
            }
        }
    }

    func installHooks(calendar: CalendarService) {
        guard !installingHooks else { return }
        installingHooks = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = HooksInstaller.install()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.installingHooks = false
                    self?.refresh(calendar: calendar)
                }
            }
        }
    }

    nonisolated private static func automationState(_ target: AutomationTarget, ask: Bool) -> PermissionState {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) != nil else { return .notInstalled }
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: target.bundleID)
        guard let address = descriptor.aeDesc else { return .notDetermined }
        let status = AEDeterminePermissionToAutomateTarget(address, typeWildCard, typeWildCard, ask)
        switch status {
        case OSStatus(noErr): return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(procNotFound): return .notRunning
        default: return .notDetermined
        }
    }

    private static func bluetoothState() -> PermissionState {
        switch CBManager.authorization {
        case .allowedAlways: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    private func writeStatus(calendar: CalendarService) {
        let calendarState: String
        switch calendar.access {
        case .granted: calendarState = PermissionState.granted.rawValue
        case .denied: calendarState = PermissionState.denied.rawValue
        case .unknown: calendarState = PermissionState.notDetermined.rawValue
        }
        let status: [String: Any] = [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "accessibility": accessibility ? "granted" : "notDetermined",
            "calendar": calendarState,
            "bluetooth": bluetooth.rawValue,
            "hooks": hooksInstalled,
            "automation": Dictionary(uniqueKeysWithValues: installedTargets.map { ($0.name, (automation[$0.bundleID] ?? .notDetermined).rawValue) })
        ]
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Notchy", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("status.json"), options: .atomic)
        }
    }
}

enum HooksInstaller {
    static var isInstalled: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let hook = home.appendingPathComponent(".notchy/notchy-hook.py")
        let settings = home.appendingPathComponent(".claude/settings.json")
        guard FileManager.default.fileExists(atPath: hook.path),
              let text = try? String(contentsOf: settings, encoding: .utf8) else { return false }
        return text.contains("notchy-hook.py")
    }

    static var bundledInstaller: URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("hooks/install.py"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func install() -> Bool {
        guard let script = bundledInstaller else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
