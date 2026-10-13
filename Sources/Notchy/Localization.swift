import Foundation

extension Locale {
    static var interface: Locale {
        Locale(identifier: Bundle.main.preferredLocalizations.first ?? "pt-BR")
    }
}
