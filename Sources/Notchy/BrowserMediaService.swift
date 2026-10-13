import AppKit
import Observation

struct BrowserVideo: Equatable {
    enum Engine {
        case chromium
        case safari
    }

    let browser: String
    let engine: Engine
    let tabID: Int
    let windowID: Int
    let tabIndex: Int
    let url: String
    let title: String
    let videoID: String
    let isActive: Bool
    let playing: Bool?
    let time: Double?

    var cleanTitle: String {
        var text = title
        if text.hasSuffix(" - YouTube") {
            text = String(text.dropLast(" - YouTube".count))
        }
        if text.hasPrefix("("), let close = text.firstIndex(of: ")"), text[text.index(after: text.startIndex)..<close].allSatisfy(\.isNumber) {
            text = String(text[text.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        return text.isEmpty ? "Vídeo do YouTube" : text
    }

    var browserName: String {
        browser == "Google Chrome" ? "Chrome" : browser
    }

    var javascriptHint: String {
        switch engine {
        case .safari:
            return "Para pausar a aba e continuar do mesmo segundo, ative no Safari: Ajustes → Avançado → Mostrar recursos para desenvolvedores da Web e depois Desenvolvedor → Permitir JavaScript de Eventos Apple."
        case .chromium:
            return "Para pausar a aba e continuar do mesmo segundo, ative no \(browserName): Visualizar → Desenvolvedor → Permitir JavaScript de Eventos Apple."
        }
    }
}

enum YouTubeLink {
    static func videoID(_ string: String) -> String? {
        guard let url = URL(string: string), let host = url.host?.lowercased() else { return nil }
        let parts = url.pathComponents
        if host.hasSuffix("youtu.be") {
            return valid(parts.count > 1 ? parts[1] : nil)
        }
        guard host.hasSuffix("youtube.com") else { return nil }
        if parts.count >= 3, ["shorts", "live", "embed"].contains(parts[1]) {
            return valid(parts[2])
        }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        return valid(query?.first { $0.name == "v" }?.value)
    }

    static func start(_ string: String) -> Double? {
        guard let value = URLComponents(string: string)?.queryItems?.first(where: { $0.name == "t" })?.value else { return nil }
        if let seconds = Double(value.replacingOccurrences(of: "s", with: "")), !value.contains("m"), !value.contains("h") {
            return seconds
        }
        var total = 0.0
        var number = ""
        for character in value {
            if character.isNumber {
                number.append(character)
            } else if let amount = Double(number) {
                switch character {
                case "h": total += amount * 3600
                case "m": total += amount * 60
                case "s": total += amount
                default: break
                }
                number = ""
            }
        }
        return total > 0 ? total : nil
    }

    static func valid(_ id: String?) -> String? {
        guard let id, (6...20).contains(id.count),
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
              id.allSatisfy(\.isASCII) else { return nil }
        return id
    }
}

@MainActor
@Observable
final class BrowserMediaService {
    static let browsers: [(bundleID: String, name: String, engine: BrowserVideo.Engine)] = [
        ("com.apple.Safari", "Safari", .safari),
        ("com.google.Chrome", "Google Chrome", .chromium),
        ("com.brave.Browser", "Brave Browser", .chromium),
        ("com.microsoft.edgemac", "Microsoft Edge", .chromium),
        ("org.chromium.Chromium", "Chromium", .chromium)
    ]

    nonisolated private static let pauseScript = "(function(){var v=document.querySelector('video');if(v)v.pause()})()"
    nonisolated private static let stateScript = "(function(){var v=document.querySelector('video');return v?(v.paused?'0':'1')+'|'+v.currentTime:''})()"
    nonisolated private static let urlTest = #"u contains "youtube.com/watch" or u contains "youtu.be/" or u contains "youtube.com/shorts/" or u contains "youtube.com/live/""#

    private(set) var current: BrowserVideo?
    private(set) var blockedBrowsers: Set<String> = []

    @ObservationIgnored var isEnabled: () -> Bool = { true }
    @ObservationIgnored var isExpanded: () -> Bool = { false }
    @ObservationIgnored private var lastScan = Date.distantPast
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var busy = false

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.tick()
            }
        }
    }

    private func tick() {
        let interval: TimeInterval = isExpanded() ? 3 : 10
        guard Date().timeIntervalSince(lastScan) >= interval - 0.5 else { return }
        refresh()
    }

    func isBlocked(_ video: BrowserVideo) -> Bool {
        blockedBrowsers.contains(video.browser)
    }

    func refresh() {
        guard isEnabled() else {
            if current != nil { current = nil }
            return
        }
        guard !busy else { return }
        lastScan = Date()
        let running = Self.browsers.filter {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).isEmpty
        }
        guard !running.isEmpty else {
            if current != nil { current = nil }
            return
        }
        busy = true
        let targets = running.map { ($0.name, $0.engine) }
        AppleScript.queue.async { [weak self] in
            var videos: [BrowserVideo] = []
            var blocked: Set<String> = []
            for (name, engine) in targets {
                let result = engine == .safari ? Self.scanSafari() : Self.scanChromium(name)
                videos += result.videos
                if result.blocked {
                    blocked.insert(name)
                }
            }
            let found = videos
            let noJavaScript = blocked
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply(found, blocked: noJavaScript) }
            }
        }
    }

    func pause(_ video: BrowserVideo) {
        Self.perform(video, javascript: Self.pauseScript, activate: false)
    }

    func resume(_ video: BrowserVideo, at time: Double) {
        let seconds = String(format: "%.2f", max(time, 0))
        Self.perform(video, javascript: "(function(){var v=document.querySelector('video');if(v){v.currentTime=\(seconds);v.play()}})()", activate: true)
    }

    private func apply(_ videos: [BrowserVideo], blocked: Set<String>) {
        busy = false
        let next = videos.first { $0.playing == true } ?? videos.first { $0.isActive }
        if next != current {
            current = next
        }
        if blocked != blockedBrowsers {
            blockedBrowsers = blocked
        }
    }

    nonisolated private static func perform(_ video: BrowserVideo, javascript: String, activate: Bool) {
        switch video.engine {
        case .chromium:
            performChromium(video, javascript: javascript, activate: activate)
        case .safari:
            performSafari(video, javascript: javascript, activate: activate)
        }
    }

    nonisolated private static func performChromium(_ video: BrowserVideo, javascript: String, activate: Bool) {
        let focus = activate ? """
                        set active tab index of w to i
                        set index of w to 1
                        activate
        """ : ""
        let script = """
        tell application "\(video.browser)"
            repeat with w in windows
                set i to 0
                repeat with t in tabs of w
                    set i to i + 1
                    if id of t is \(video.tabID) then
        \(focus)
                        try
                            execute t javascript "\(javascript)"
                        end try
                        return true
                    end if
                end repeat
            end repeat
        end tell
        return false
        """
        AppleScript.runAsync(script)
    }

    nonisolated private static func performSafari(_ video: BrowserVideo, javascript: String, activate: Bool) {
        let focus = activate ? """
                    set current tab of w to t
                    set index of w to 1
                    activate
        """ : ""
        let script = """
        tell application "Safari"
            set target to missing value
            set targetWindow to missing value
            try
                set w to first window whose id is \(video.windowID)
                set t to tab \(video.tabIndex) of w
                if URL of t contains "\(video.videoID)" then
                    set target to t
                    set targetWindow to w
                end if
            end try
            if target is missing value then
                repeat with w in windows
                    try
                        repeat with t in tabs of w
                            set u to URL of t
                            if u is not missing value and u contains "\(video.videoID)" then
                                set target to t
                                set targetWindow to w
                                exit repeat
                            end if
                        end repeat
                    end try
                    if target is not missing value then exit repeat
                end repeat
            end if
            if target is missing value then return false
            set w to targetWindow
            set t to target
        \(focus)
            try
                do JavaScript "\(javascript)" in t
            end try
            return true
        end tell
        """
        AppleScript.runAsync(script)
    }

    nonisolated private static func scanChromium(_ browser: String) -> (videos: [BrowserVideo], blocked: Bool) {
        let script = """
        tell application "\(browser)"
            set found to {}
            repeat with w in windows
                set activeID to id of active tab of w
                repeat with t in tabs of w
                    set u to URL of t
                    if \(urlTest) then
                        set info to ""
                        try
                            set info to execute t javascript "\(stateScript)"
                        on error
                            set info to "nojs"
                        end try
                        if info is missing value then set info to ""
                        set end of found to {u, title of t, id of t, (id of t is activeID), info}
                    end if
                end repeat
            end repeat
            return found
        end tell
        """
        guard let descriptor = AppleScript.run(script), descriptor.numberOfItems > 0 else { return ([], false) }
        var videos: [BrowserVideo] = []
        var blocked = false
        for index in 1...descriptor.numberOfItems {
            guard let item = descriptor.atIndex(index), item.numberOfItems >= 5,
                  let url = item.atIndex(1)?.stringValue,
                  let videoID = YouTubeLink.videoID(url) else { continue }
            let state = parseState(item.atIndex(5)?.stringValue ?? "")
            blocked = blocked || state.blocked
            videos.append(BrowserVideo(
                browser: browser,
                engine: .chromium,
                tabID: Int(item.atIndex(3)?.int32Value ?? 0),
                windowID: 0,
                tabIndex: 0,
                url: url,
                title: item.atIndex(2)?.stringValue ?? "",
                videoID: videoID,
                isActive: item.atIndex(4)?.booleanValue ?? false,
                playing: state.playing,
                time: state.time
            ))
        }
        return (videos, blocked)
    }

    nonisolated private static func scanSafari() -> (videos: [BrowserVideo], blocked: Bool) {
        let script = """
        tell application "Safari"
            set found to {}
            repeat with w in windows
                try
                    set wid to id of w
                    set ti to 0
                    repeat with t in tabs of w
                        set ti to ti + 1
                        set u to URL of t
                        if u is not missing value then
                            if \(urlTest) then
                                set info to ""
                                try
                                    set info to do JavaScript "\(stateScript)" in t
                                on error
                                    set info to "nojs"
                                end try
                                if info is missing value then set info to ""
                                set shown to false
                                try
                                    set shown to visible of t
                                end try
                                set end of found to {u, name of t, wid, ti, shown, info}
                            end if
                        end if
                    end repeat
                end try
            end repeat
            return found
        end tell
        """
        guard let descriptor = AppleScript.run(script), descriptor.numberOfItems > 0 else { return ([], false) }
        var videos: [BrowserVideo] = []
        var blocked = false
        for index in 1...descriptor.numberOfItems {
            guard let item = descriptor.atIndex(index), item.numberOfItems >= 6,
                  let url = item.atIndex(1)?.stringValue,
                  let videoID = YouTubeLink.videoID(url) else { continue }
            let state = parseState(item.atIndex(6)?.stringValue ?? "")
            blocked = blocked || state.blocked
            videos.append(BrowserVideo(
                browser: "Safari",
                engine: .safari,
                tabID: 0,
                windowID: Int(item.atIndex(3)?.int32Value ?? 0),
                tabIndex: Int(item.atIndex(4)?.int32Value ?? 0),
                url: url,
                title: item.atIndex(2)?.stringValue ?? "",
                videoID: videoID,
                isActive: item.atIndex(5)?.booleanValue ?? false,
                playing: state.playing,
                time: state.time
            ))
        }
        return (videos, blocked)
    }

    nonisolated private static func parseState(_ info: String) -> (playing: Bool?, time: Double?, blocked: Bool) {
        if info == "nojs" {
            return (nil, nil, true)
        }
        let parts = info.split(separator: "|")
        guard parts.count == 2 else { return (nil, nil, false) }
        return (parts[0] == "1", Double(parts[1]), false)
    }
}
