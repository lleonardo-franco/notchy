import AppKit
import Foundation
import Security

@MainActor
enum Diagnostics {
    static let newIssue = "https://github.com/lleonardo-franco/notchy/issues/new"

    static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    static var system: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion), \(macModel)"
    }

    static var macModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static var signature: String {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else { return "unknown" }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let details = info as? [String: Any] else { return "unknown" }
        if let certificates = details[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let leaf = certificates.first,
           let name = SecCertificateCopySubjectSummary(leaf) as String? {
            return name
        }
        return "ad-hoc"
    }

    static func report(_ model: NotchModel) -> String {
        let permissions = model.permissions
        var lines = [
            "Notchy: \(appVersion)",
            "System: \(system)",
            "Signature: \(signature)",
            "Language: \(Bundle.main.preferredLocalizations.first ?? "?")",
            "",
            "Permissions:",
            "  Accessibility: \(permissions.accessibility ? "granted" : "not granted")",
            "  Calendar: \(model.calendar.access)",
            "  Bluetooth: \(permissions.bluetooth)",
        ]
        for target in permissions.installedTargets {
            lines.append("  \(target.name): \(permissions.automation[target.bundleID].map { "\($0)" } ?? "unknown")")
        }
        lines += [
            "  Claude Code hooks: \(permissions.hooksInstalled ? "installed" : "not installed")",
            "",
            "Settings:",
            "  Open: \(model.prefs.openMode.rawValue), screen: \(model.prefs.screenMode.rawValue), size: \(model.prefs.notchSize.rawValue)",
            "  Tabs: \(model.tabs.map(\.rawValue).joined(separator: ", "))",
            "  Media keys: \(model.prefs.levelHUD ? (model.mediaKeys.isRunning ? "on" : "waiting for Accessibility") : "off")",
            "  Other players: \(model.prefs.otherPlayers ? "on" : "off")",
            "  Screens: \(NSScreen.screens.count), notch: \(NSScreen.screens.contains { $0.safeAreaInsets.top > 0 } ? "yes" : "no")"
        ]
        return lines.joined(separator: "\n")
    }

    static func issueURL(_ model: NotchModel) -> URL? {
        var components = URLComponents(string: newIssue)
        components?.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "version", value: appVersion),
            URLQueryItem(name: "macos", value: system),
            URLQueryItem(name: "doctor", value: report(model))
        ]
        return components?.url
    }

    static func reportProblem(_ model: NotchModel) {
        guard let url = issueURL(model) else { return }
        NSWorkspace.shared.open(url)
    }

    static func copyReport(_ model: NotchModel) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report(model), forType: .string)
    }
}
