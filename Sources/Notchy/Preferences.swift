import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class Preferences {
    enum OpenMode: String, CaseIterable, Identifiable {
        case hover
        case click

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hover: return String(localized: "Ao passar o mouse")
            case .click: return String(localized: "Ao clicar")
            }
        }
    }

    enum VerticalGesture: String, CaseIterable, Identifiable {
        case volume
        case openClose
        case off

        var id: String { rawValue }

        var title: String {
            switch self {
            case .volume: return String(localized: "Volume")
            case .openClose: return String(localized: "Abrir e fechar o notch")
            case .off: return String(localized: "Nada")
            }
        }
    }

    enum HapticLevel: String, CaseIterable, Identifiable {
        case off
        case light
        case medium
        case strong

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off: return String(localized: "Desligado")
            case .light: return String(localized: "Leve")
            case .medium: return String(localized: "Médio")
            case .strong: return String(localized: "Forte")
            }
        }
    }

    enum ScreenMode: String, CaseIterable, Identifiable {
        case automatic
        case main
        case notchOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic: return String(localized: "Tela com notch ou a principal")
            case .main: return String(localized: "Sempre na tela principal")
            case .notchOnly: return String(localized: "Só em telas com notch")
            }
        }
    }

    enum NotchSize: String, CaseIterable, Identifiable {
        case compact
        case regular
        case large

        var id: String { rawValue }

        var title: String {
            switch self {
            case .compact: return String(localized: "Compacto")
            case .regular: return String(localized: "Normal")
            case .large: return String(localized: "Grande")
            }
        }

        var width: CGFloat {
            switch self {
            case .compact: return 480
            case .regular: return 540
            case .large: return 620
            }
        }

        var contentHeight: CGFloat {
            switch self {
            case .compact: return 140
            case .regular: return 164
            case .large: return 204
            }
        }
    }

    enum Highlight: String, CaseIterable, Identifiable {
        case orange
        case blue
        case purple
        case pink
        case green
        case graphite

        var id: String { rawValue }

        var title: String {
            switch self {
            case .orange: return String(localized: "Laranja")
            case .blue: return String(localized: "Azul")
            case .purple: return String(localized: "Roxo")
            case .pink: return String(localized: "Rosa")
            case .green: return String(localized: "Verde")
            case .graphite: return String(localized: "Grafite")
            }
        }

        var color: Color {
            switch self {
            case .orange: return .claude
            case .blue: return Color(red: 0.25, green: 0.56, blue: 1)
            case .purple: return Color(red: 0.62, green: 0.42, blue: 0.98)
            case .pink: return Color(red: 0.98, green: 0.36, blue: 0.62)
            case .green: return Color(red: 0.24, green: 0.8, blue: 0.47)
            case .graphite: return Color(white: 0.72)
            }
        }
    }

    enum AnimationSpeed: String, CaseIterable, Identifiable {
        case fast
        case regular
        case relaxed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fast: return String(localized: "Rápida")
            case .regular: return String(localized: "Normal")
            case .relaxed: return String(localized: "Suave")
            }
        }

        var scale: Double {
            switch self {
            case .fast: return 0.7
            case .regular: return 1
            case .relaxed: return 1.5
            }
        }
    }

    static let allTabs = ["claude", "agenda", "weather", "clipboard", "bluetooth", "shelf"]
    static let layoutChanged = Notification.Name("NotchyLayoutChanged")

    @ObservationIgnored private let defaults = UserDefaults.standard

    var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: "alertsEnabled") }
    }

    var hapticLevel: HapticLevel {
        didSet { defaults.set(hapticLevel.rawValue, forKey: "hapticLevel") }
    }

    var openMode: OpenMode {
        didSet { defaults.set(openMode.rawValue, forKey: "openMode") }
    }

    var screenMode: ScreenMode {
        didSet {
            defaults.set(screenMode.rawValue, forKey: "screenMode")
            NotificationCenter.default.post(name: Self.layoutChanged, object: nil)
        }
    }

    var hideInFullscreen: Bool {
        didSet {
            defaults.set(hideInFullscreen, forKey: "hideInFullscreen")
            NotificationCenter.default.post(name: Self.layoutChanged, object: nil)
        }
    }

    var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: "hoverDelay") }
    }

    var swipeTracks: Bool {
        didSet { defaults.set(swipeTracks, forKey: "swipeTracks") }
    }

    var swipeRightNext: Bool {
        didSet { defaults.set(swipeRightNext, forKey: "swipeRightNext") }
    }

    var verticalGesture: VerticalGesture {
        didSet { defaults.set(verticalGesture.rawValue, forKey: "verticalGesture") }
    }

    var enabledTabs: Set<String> {
        didSet { defaults.set(Self.allTabs.filter(enabledTabs.contains), forKey: "enabledTabs") }
    }

    var meetingLead: Int {
        didSet { defaults.set(meetingLead, forKey: "meetingLead") }
    }

    var meetingCountdown: Bool {
        didSet { defaults.set(meetingCountdown, forKey: "meetingCountdown") }
    }

    var disabledBadges: Set<String> {
        didSet { defaults.set(BadgeApp.allCases.map(\.rawValue).filter(disabledBadges.contains), forKey: "disabledBadges") }
    }

    var notchSize: NotchSize {
        didSet { defaults.set(notchSize.rawValue, forKey: "notchSize") }
    }

    var highlight: Highlight {
        didSet { defaults.set(highlight.rawValue, forKey: "highlight") }
    }

    var animationSpeed: AnimationSpeed {
        didSet { defaults.set(animationSpeed.rawValue, forKey: "animationSpeed") }
    }

    var batteryAlerts: Bool {
        didSet { defaults.set(batteryAlerts, forKey: "batteryAlerts") }
    }

    var levelHUD: Bool {
        didSet { defaults.set(levelHUD, forKey: "levelHUD") }
    }

    var otherPlayers: Bool {
        didSet { defaults.set(otherPlayers, forKey: "otherPlayers") }
    }

    var youtubeEnabled: Bool {
        didSet { defaults.set(youtubeEnabled, forKey: "youtubeEnabled") }
    }

    var bluetoothAlerts: Bool {
        didSet { defaults.set(bluetoothAlerts, forKey: "bluetoothAlerts") }
    }

    var weatherCity: String {
        didSet {
            let value = weatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                defaults.removeObject(forKey: WeatherService.cityKey)
            } else {
                defaults.set(value, forKey: WeatherService.cityKey)
            }
        }
    }

    init() {
        let stored = UserDefaults.standard
        alertsEnabled = stored.object(forKey: "alertsEnabled") as? Bool ?? true
        hapticLevel = HapticLevel(rawValue: stored.string(forKey: "hapticLevel") ?? "") ?? .medium
        openMode = OpenMode(rawValue: stored.string(forKey: "openMode") ?? "") ?? .hover
        hoverDelay = stored.object(forKey: "hoverDelay") as? Double ?? 0
        screenMode = ScreenMode(rawValue: stored.string(forKey: "screenMode") ?? "") ?? .automatic
        hideInFullscreen = stored.object(forKey: "hideInFullscreen") as? Bool ?? true
        swipeTracks = stored.object(forKey: "swipeTracks") as? Bool ?? true
        swipeRightNext = stored.object(forKey: "swipeRightNext") as? Bool ?? true
        verticalGesture = VerticalGesture(rawValue: stored.string(forKey: "verticalGesture") ?? "") ?? .volume
        let known = Set(stored.stringArray(forKey: "knownTabs") ?? ["claude", "agenda", "weather", "clipboard"])
        let saved = Set(stored.stringArray(forKey: "enabledTabs") ?? Self.allTabs)
        enabledTabs = saved.union(Set(Self.allTabs).subtracting(known))
        stored.set(Self.allTabs, forKey: "knownTabs")
        youtubeEnabled = stored.object(forKey: "youtubeEnabled") as? Bool ?? true
        otherPlayers = stored.object(forKey: "otherPlayers") as? Bool ?? true
        levelHUD = stored.object(forKey: "levelHUD") as? Bool ?? true
        batteryAlerts = stored.object(forKey: "batteryAlerts") as? Bool ?? true
        notchSize = NotchSize(rawValue: stored.string(forKey: "notchSize") ?? "") ?? .regular
        highlight = Highlight(rawValue: stored.string(forKey: "highlight") ?? "") ?? .orange
        animationSpeed = AnimationSpeed(rawValue: stored.string(forKey: "animationSpeed") ?? "") ?? .regular
        bluetoothAlerts = stored.object(forKey: "bluetoothAlerts") as? Bool ?? true
        meetingLead = stored.object(forKey: "meetingLead") as? Int ?? 5
        meetingCountdown = stored.object(forKey: "meetingCountdown") as? Bool ?? true
        if let saved = stored.stringArray(forKey: "disabledBadges") {
            disabledBadges = Set(saved)
        } else {
            var legacy: Set<String> = []
            if stored.object(forKey: "whatsappEnabled") as? Bool == false { legacy.insert(BadgeApp.whatsapp.rawValue) }
            if stored.object(forKey: "clickupEnabled") as? Bool == false { legacy.insert(BadgeApp.clickup.rawValue) }
            disabledBadges = legacy
        }
        weatherCity = stored.string(forKey: WeatherService.cityKey) ?? ""
    }

    func isEnabled(_ app: BadgeApp) -> Bool {
        !disabledBadges.contains(app.rawValue)
    }

    func setEnabled(_ app: BadgeApp, _ enabled: Bool) {
        if enabled {
            disabledBadges.remove(app.rawValue)
        } else {
            disabledBadges.insert(app.rawValue)
        }
    }
}
