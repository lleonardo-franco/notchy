import AppKit
import Observation

enum MusicSource: Equatable {
    case spotify
    case music
    case system(String)

    static let scriptable: [MusicSource] = [.spotify, .music]

    var bundleID: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .music: return "com.apple.Music"
        case .system(let bundleID): return bundleID
        }
    }

    var key: String {
        switch self {
        case .spotify: return "spotify"
        case .music: return "music"
        case .system(let bundleID): return "system:" + bundleID
        }
    }

    var isScriptable: Bool {
        if case .system = self { return false }
        return true
    }

    var appName: String {
        switch self {
        case .spotify: return "Spotify"
        case .music: return "Music"
        case .system(let bundleID):
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            return url?.deletingPathExtension().lastPathComponent ?? ""
        }
    }

    var isRunning: Bool {
        if case .system(let bundleID) = self, bundleID.isEmpty { return true }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    var stateScript: String? {
        switch self {
        case .spotify:
            return """
            tell application "Spotify"
                if player state is stopped then return {}
                set t to current track
                return {id of t, name of t, artist of t, album of t, (duration of t) / 1000, player position, (player state is playing), artwork url of t}
            end tell
            """
        case .music:
            return """
            tell application "Music"
                if player state is stopped then return {}
                set t to current track
                return {persistent ID of t, name of t, artist of t, album of t, duration of t, player position, (player state is playing), ""}
            end tell
            """
        case .system:
            return nil
        }
    }
}

struct Track: Equatable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var source: MusicSource
}

struct PlaybackSnapshot {
    var id: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var position: Double
    var playing: Bool
    var artworkURL: String?
}

final class DistributedObserver: NSObject {
    private let handler: (Notification) -> Void

    init(name: String, handler: @escaping (Notification) -> Void) {
        self.handler = handler
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receive(_:)),
            name: Notification.Name(name),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func receive(_ note: Notification) {
        handler(note)
    }
}

@MainActor
@Observable
final class MusicService {
    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var artwork: NSImage?
    private(set) var accent: NSColor?

    @ObservationIgnored private var anchorPosition: Double = 0
    @ObservationIgnored private var anchorDate = Date()
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private var observers: [DistributedObserver] = []
    @ObservationIgnored private var workspaceObserver: NSObjectProtocol?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let nowPlaying = NowPlayingBridge()

    func start() {
        observers = [
            DistributedObserver(name: "com.spotify.client.PlaybackStateChanged") { [weak self] note in
                let state = note.userInfo?["Player State"] as? String
                MainActor.assumeIsolated { self?.handle(.spotify, state: state) }
            },
            DistributedObserver(name: "com.apple.Music.playerInfo") { [weak self] note in
                let state = note.userInfo?["Player State"] as? String
                MainActor.assumeIsolated { self?.handle(.music, state: state) }
            }
        ]

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            MainActor.assumeIsolated { self?.appTerminated(bundleID) }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.resync()
            }
        }

        nowPlaying.onUpdate = { [weak self] info in
            self?.applySystem(info)
        }

        for source in MusicSource.scriptable where source.isRunning {
            refresh(source)
        }
    }

    func setOtherPlayers(_ enabled: Bool) {
        if enabled {
            nowPlaying.start()
        } else {
            nowPlaying.stop()
            if case .system = track?.source {
                clear()
            }
        }
    }

    func resumeOtherPlayers() {
        nowPlaying.refresh()
    }

    func position(at date: Date) -> Double {
        guard let track else { return 0 }
        let raw = isPlaying ? anchorPosition + date.timeIntervalSince(anchorDate) : anchorPosition
        return min(max(raw, 0), track.duration)
    }

    func playPause() {
        anchorPosition = position(at: Date())
        anchorDate = Date()
        isPlaying.toggle()
        control(script: "playpause", system: .toggle)
    }

    func next() {
        control(script: "next track", system: .next)
    }

    func previous() {
        control(script: "previous track", system: .previous)
    }

    func seek(to seconds: Double) {
        guard let track else { return }
        let target = min(max(seconds, 0), max(track.duration - 0.5, 0))
        anchorPosition = target
        anchorDate = Date()
        control(script: "set player position to \(target)", system: .seek(target))
    }

    func openPlayer() {
        guard let source = track?.source,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func handle(_ source: MusicSource, state: String?) {
        if state == "Stopped" {
            if track?.source == source {
                clear()
            }
            return
        }
        refresh(source)
    }

    private func resync() {
        guard let source = track?.source else { return }
        guard source.isScriptable else {
            nowPlaying.refresh()
            return
        }
        if source.isRunning {
            refresh(source)
        } else {
            clear()
        }
    }

    private func appTerminated(_ bundleID: String?) {
        if let track, track.source.bundleID == bundleID {
            clear()
        }
    }

    private func clear() {
        track = nil
        isPlaying = false
        artwork = nil
        accent = nil
        artworkKey = nil
    }

    private func control(script command: String, system: NowPlayingBridge.Command) {
        guard let source = track?.source else { return }
        guard source.isScriptable else {
            nowPlaying.send(system)
            return
        }
        guard source.isRunning else { return }
        AppleScript.runAsync("tell application \"\(source.appName)\" to \(command)") { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                MainActor.assumeIsolated { self?.refresh(source) }
            }
        }
    }

    private func refresh(_ source: MusicSource) {
        guard source.isRunning, let script = source.stateScript else { return }
        AppleScript.queue.async { [weak self] in
            let snapshot = Self.parse(AppleScript.run(script))
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply(snapshot, from: source) }
            }
        }
    }

    private func apply(_ snapshot: PlaybackSnapshot?, from source: MusicSource) {
        guard let snapshot else {
            if track?.source == source {
                clear()
            }
            return
        }

        if let current = track, current.source != source, isPlaying, !snapshot.playing {
            return
        }

        let next = Track(
            id: snapshot.id,
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            duration: snapshot.duration,
            source: source
        )
        if track != next {
            track = next
        }
        if isPlaying != snapshot.playing {
            isPlaying = snapshot.playing
        }
        anchorPosition = snapshot.position
        anchorDate = Date()

        let key = "\(source.key):\(snapshot.id)"
        if artworkKey != key {
            artworkKey = key
            artwork = nil
            accent = nil
            loadArtwork(for: source, url: snapshot.artworkURL, key: key)
        }
    }

    private func loadArtwork(for source: MusicSource, url: String?, key: String) {
        switch source {
        case .spotify:
            guard let url, let remote = URL(string: url) else { return }
            URLSession.shared.dataTask(with: remote) { [weak self] data, _, _ in
                guard let data else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.setArtwork(data, key: key) }
                }
            }.resume()
        case .music:
            AppleScript.queue.async { [weak self] in
                guard let data = AppleScript.run("tell application \"Music\" to get raw data of artwork 1 of current track")?.data else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.setArtwork(data, key: key) }
                }
            }
        case .system:
            break
        }
    }

    private func applySystem(_ info: NowPlayingInfo?) {
        guard let info, info.pid != ProcessInfo.processInfo.processIdentifier else {
            if case .system = track?.source {
                clear()
            }
            return
        }
        let bundleID = info.bundleID ?? ""
        if let native = MusicSource.scriptable.first(where: { $0.bundleID == bundleID }) {
            if case .system = track?.source {
                clear()
            }
            refresh(native)
            return
        }

        let source = MusicSource.system(bundleID)
        if let current = track, current.source != source, isPlaying, !info.playing {
            return
        }

        let next = Track(
            id: [bundleID, info.title, info.artist, info.album].joined(separator: "|"),
            title: info.title,
            artist: info.artist,
            album: info.album,
            duration: info.duration,
            source: source
        )
        if track != next {
            track = next
        }
        if isPlaying != info.playing {
            isPlaying = info.playing
        }
        anchorPosition = info.position(at: Date())
        anchorDate = Date()

        let key = "\(source.key):\(next.id)"
        if artworkKey != key {
            artworkKey = key
            artwork = nil
            accent = nil
        }
        if artwork == nil, let data = info.artwork {
            setArtwork(data, key: key)
        }
    }

    private func setArtwork(_ data: Data, key: String) {
        guard key == artworkKey, let image = NSImage(data: data) else { return }
        artwork = image
        accent = image.dominantColor()
    }

    nonisolated private static func parse(_ descriptor: NSAppleEventDescriptor?) -> PlaybackSnapshot? {
        guard let descriptor, descriptor.numberOfItems >= 8 else { return nil }
        func text(_ index: Int) -> String { descriptor.atIndex(index)?.stringValue ?? "" }
        func number(_ index: Int) -> Double { descriptor.atIndex(index)?.doubleValue ?? 0 }
        let artwork = text(8)
        return PlaybackSnapshot(
            id: text(1),
            title: text(2),
            artist: text(3),
            album: text(4),
            duration: number(5),
            position: number(6),
            playing: descriptor.atIndex(7)?.booleanValue ?? false,
            artworkURL: artwork.isEmpty ? nil : artwork
        )
    }
}
