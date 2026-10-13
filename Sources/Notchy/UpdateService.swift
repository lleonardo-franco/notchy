import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UpdateService {
    struct Release: Equatable {
        let version: String
        let page: URL
    }

    nonisolated static let latestAPI = URL(string: "https://api.github.com/repos/lleonardo-franco/notchy/releases/latest")!
    nonisolated static let releasesPage = URL(string: "https://github.com/lleonardo-franco/notchy/releases/latest")!
    static let notifiedKey = "notifiedUpdate"

    private(set) var available: Release?
    private(set) var checking = false
    private(set) var lastChecked: Date?
    private(set) var failed = false

    @ObservationIgnored var onFound: ((Release) -> Void)?
    @ObservationIgnored private var timer: Timer?

    var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func start() {
        check()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !SystemActivity.shared.paused else { return }
                if let lastChecked = self.lastChecked, Date().timeIntervalSince(lastChecked) < 20 * 3600 { return }
                self.check()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func check() {
        guard !checking else { return }
        checking = true
        failed = false
        var request = URLRequest(url: Self.latestAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Notchy/\(current)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            let release = data.flatMap(Self.parse)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.finish(release) }
            }
        }.resume()
    }

    func updateInTerminal() {
        AppleScript.runAsync("""
        tell application "Terminal"
            activate
            do script "notchy update"
        end tell
        """, timeout: 10)
    }

    func openNotes() {
        NSWorkspace.shared.open(available?.page ?? Self.releasesPage)
    }

    private func finish(_ release: Release?) {
        checking = false
        lastChecked = Date()
        guard let release else {
            failed = true
            return
        }
        guard Self.isNewer(release.version, than: current) else {
            available = nil
            return
        }
        available = release
        if UserDefaults.standard.string(forKey: Self.notifiedKey) != release.version {
            UserDefaults.standard.set(release.version, forKey: Self.notifiedKey)
            onFound?(release)
        }
    }

    nonisolated static func parse(_ data: Data) -> Release? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              object["draft"] as? Bool != true,
              object["prerelease"] as? Bool != true else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let page = (object["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage
        return Release(version: version, page: page)
    }

    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let left = numbers(candidate)
        let right = numbers(current)
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    nonisolated private static func numbers(_ version: String) -> [Int] {
        version.split(separator: "-").first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? []
    }
}
