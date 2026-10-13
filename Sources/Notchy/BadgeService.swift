import AppKit
import ApplicationServices
import Observation
import SwiftUI

enum BadgeApp: String, CaseIterable, Identifiable {
    case whatsapp = "WhatsApp"
    case slack = "Slack"
    case telegram = "Telegram"
    case discord = "Discord"
    case clickup = "ClickUp"

    var id: String { rawValue }

    var bundleIDs: [String] {
        switch self {
        case .whatsapp: return ["net.whatsapp.WhatsApp", "desktop.WhatsApp"]
        case .slack: return ["com.tinyspeck.slackmacgap"]
        case .telegram: return ["ru.keepcoder.Telegram", "org.telegram.desktop"]
        case .discord: return ["com.hnc.Discord"]
        case .clickup: return ["com.clickup.desktop-app"]
        }
    }

    var dockTitles: [String] {
        switch self {
        case .telegram: return ["Telegram", "Telegram Desktop"]
        default: return [rawValue]
        }
    }

    var colors: [Color] {
        switch self {
        case .whatsapp: return [Color(red: 0.16, green: 0.84, blue: 0.42), Color(red: 0.05, green: 0.6, blue: 0.5)]
        case .slack: return [Color(red: 0.88, green: 0.12, blue: 0.35), Color(red: 0.38, green: 0.12, blue: 0.41)]
        case .telegram: return [Color(red: 0.18, green: 0.69, blue: 0.94), Color(red: 0.11, green: 0.53, blue: 0.84)]
        case .discord: return [Color(red: 0.42, green: 0.47, blue: 0.98), Color(red: 0.29, green: 0.33, blue: 0.86)]
        case .clickup: return [.clickup, .clickupPink]
        }
    }

    var symbol: String {
        switch self {
        case .whatsapp: return "message.fill"
        case .slack: return "number"
        case .telegram: return "paperplane.fill"
        case .discord: return "bubble.left.and.bubble.right.fill"
        case .clickup: return "bell.fill"
        }
    }

    func describe(_ label: String) -> String {
        let one = BadgeService.value(label) == 1
        let counted = label.contains(where: \.isNumber)
        switch self {
        case .whatsapp, .slack, .telegram:
            guard counted else { return String(localized: "mensagens novas") }
            return one ? String(localized: "1 mensagem") : String(localized: "\(label) mensagens")
        case .discord:
            guard counted else { return String(localized: "menções novas") }
            return one ? String(localized: "1 menção") : String(localized: "\(label) menções")
        case .clickup:
            guard counted else { return String(localized: "notificações novas") }
            return one ? String(localized: "1 notificação") : String(localized: "\(label) notificações")
        }
    }

    static func matching(dockTitle: String) -> BadgeApp? {
        allCases.first { $0.dockTitles.contains(dockTitle) }
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
        let running = NSWorkspace.shared.runningApplications.first { candidate in
            app.bundleIDs.contains(candidate.bundleIdentifier ?? "") || app.dockTitles.contains(candidate.localizedName ?? "")
        }
        let installed = app.bundleIDs.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.first
        guard let url = running?.bundleURL ?? installed else { return }
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

        let root = AXUIElementCreateApplication(dock.processIdentifier)
        var next: [String: String] = [:]
        for list in Self.children(of: root) {
            for item in Self.children(of: list) {
                guard let title = Self.attribute(item, kAXTitleAttribute as String) as? String,
                      let app = BadgeApp.matching(dockTitle: title),
                      let label = Self.attribute(item, "AXStatusLabel") as? String,
                      !label.isEmpty else { continue }
                next[app.rawValue] = label
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
