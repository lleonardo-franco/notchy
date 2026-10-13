import Foundation
import Observation

@MainActor
@Observable
final class Preferences {
    enum OpenMode: String, CaseIterable, Identifiable {
        case hover
        case click

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hover: return "Ao passar o mouse"
            case .click: return "Ao clicar"
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
            case .volume: return "Volume"
            case .openClose: return "Abrir e fechar o notch"
            case .off: return "Nada"
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
            case .off: return "Desligado"
            case .light: return "Leve"
            case .medium: return "Médio"
            case .strong: return "Forte"
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
            case .automatic: return "Tela com notch ou a principal"
            case .main: return "Sempre na tela principal"
            case .notchOnly: return "Só em telas com notch"
            }
        }
    }

    static let allTabs = ["claude", "agenda", "weather", "clipboard", "bluetooth"]
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
