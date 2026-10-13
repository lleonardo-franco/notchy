import AppKit
import ApplicationServices
import Observation
import SwiftUI

enum BadgeApp: String, CaseIterable, Identifiable {
    case whatsapp = "WhatsApp"
    case clickup = "ClickUp"

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .whatsapp: return [Color(red: 0.16, green: 0.84, blue: 0.42), Color(red: 0.05, green: 0.6, blue: 0.5)]
        case .clickup: return [.clickup, .clickupPink]
        }
    }

    var symbol: String {
        switch self {
        case .whatsapp: return "message.fill"
        case .clickup: return "bell.fill"
        }
    }

    func describe(_ label: String) -> String {
        guard label.contains(where: \.isNumber) else {
            return self == .whatsapp ? "mensagens novas" : "notificações novas"
        }
        let one = BadgeService.value(label) == 1
        switch self {
        case .whatsapp: return one ? "1 mensagem" : "\(label) mensagens"
        case .clickup: return one ? "1 notificação" : "\(label) notificações"
        }
    }
}

struct BadgeItem: Identifiable, Equatable {
    let app: BadgeApp
    let label: String

    var id: String { app.rawValue }
}

@MainActor
@Observable
final class BadgeService {
    private(set) var badges: [String: String] = [:]
    private(set) var trusted = false

    @ObservationIgnored var onIncrease: (@MainActor (BadgeApp, String) -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var primed = false

    func start() {
        let promptKey = "accessibilityPrompted-\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")"
        if AXIsProcessTrusted() {
            trusted = true
        } else if !UserDefaults.standard.bool(forKey: promptKey) {
            UserDefaults.standard.set(true, forKey: promptKey)
            requestTrust()
        }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.poll()
            }
        }
    }

    func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(options)
    }

    func open(_ app: BadgeApp) {
        let running = NSWorkspace.shared.runningApplications.first { $0.localizedName == app.rawValue }
        let url = running?.bundleURL ?? URL(fileURLWithPath: "/Applications/\(app.rawValue).app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func poll() {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted != trusted {
            trusted = isTrusted
        }
        guard isTrusted,
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }

        let watched = Set(BadgeApp.allCases.map(\.rawValue))
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        var next: [String: String] = [:]
        for list in Self.children(of: root) {
            for item in Self.children(of: list) {
                guard let title = Self.attribute(item, kAXTitleAttribute as String) as? String,
                      watched.contains(title),
                      let label = Self.attribute(item, "AXStatusLabel") as? String,
                      !label.isEmpty else { continue }
                next[title] = label
            }
        }

        if primed {
            for (name, label) in next where Self.value(label) > Self.value(badges[name]) {
                if let app = BadgeApp(rawValue: name) {
                    onIncrease?(app, label)
                }
            }
        }
        primed = true

        if next != badges {
            badges = next
        }
    }

    nonisolated static func value(_ label: String?) -> Int {
        guard let label, !label.isEmpty else { return 0 }
        return Int(label.filter(\.isNumber)) ?? 1
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}
