import AppKit
import Foundation

struct NowPlayingInfo: Equatable {
    var pid: Int32
    var bundleID: String?
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var elapsed: Double
    var timestamp: Date
    var rate: Double
    var playing: Bool
    var artwork: Data?

    func position(at date: Date) -> Double {
        guard playing else { return elapsed }
        let speed = rate > 0 ? rate : 1
        let value = elapsed + date.timeIntervalSince(timestamp) * speed
        return duration > 0 ? min(max(value, 0), duration) : max(value, 0)
    }

    static func from(_ info: [String: Any], pid: Int32, playing: Bool) -> NowPlayingInfo? {
        let title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }
        func number(_ key: String) -> Double? { (info[key] as? NSNumber)?.doubleValue }
        return NowPlayingInfo(
            pid: pid,
            bundleID: nil,
            title: title,
            artist: info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "",
            album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "",
            duration: number("kMRMediaRemoteNowPlayingInfoDuration") ?? 0,
            elapsed: number("kMRMediaRemoteNowPlayingInfoElapsedTime") ?? 0,
            timestamp: info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date ?? Date(),
            rate: number("kMRMediaRemoteNowPlayingInfoPlaybackRate") ?? 1,
            playing: playing,
            artwork: info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        )
    }
}

@MainActor
final class NowPlayingBridge {
    enum Command {
        case toggle
        case next
        case previous
        case seek(Double)

        var code: UInt32? {
            switch self {
            case .toggle: return 2
            case .next: return 4
            case .previous: return 5
            case .seek: return nil
            }
        }
    }

    private typealias InfoFunction = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void
    private typealias PIDFunction = @convention(c) (DispatchQueue, @escaping @convention(block) (Int32) -> Void) -> Void
    private typealias PlayingFunction = @convention(c) (DispatchQueue, @escaping @convention(block) (DarwinBoolean) -> Void) -> Void
    private typealias RegisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias UnregisterFunction = @convention(c) () -> Void
    private typealias CommandFunction = @convention(c) (UInt32, NSDictionary?) -> DarwinBoolean
    private typealias ElapsedFunction = @convention(c) (Double) -> Void

    private static let notifications = [
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
    ]

    private static let handle: UnsafeMutableRawPointer? = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)

    private static func function<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }

    var onUpdate: ((NowPlayingInfo?) -> Void)?

    private(set) var isRunning = false
    private var observers: [NSObjectProtocol] = []
    private var pending = false
    private var heartbeat: Timer?

    func start() {
        guard !isRunning,
              let register = Self.function("MRMediaRemoteRegisterForNowPlayingNotifications", as: RegisterFunction.self) else { return }
        isRunning = true
        register(DispatchQueue.main)
        observers = Self.notifications.map { name in
            NotificationCenter.default.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        heartbeat = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.refresh()
            }
        }
        refresh()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        heartbeat?.invalidate()
        heartbeat = nil
        Self.function("MRMediaRemoteUnregisterForNowPlayingNotifications", as: UnregisterFunction.self)?()
    }

    func refresh() {
        guard isRunning, !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            MainActor.assumeIsolated {
                self?.pending = false
                self?.publish()
            }
        }
    }

    func send(_ command: Command) {
        if case .seek(let seconds) = command {
            Self.function("MRMediaRemoteSetElapsedTime", as: ElapsedFunction.self)?(max(seconds, 0))
        } else if let code = command.code {
            _ = Self.function("MRMediaRemoteSendCommand", as: CommandFunction.self)?(code, nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func publish() {
        guard isRunning,
              let getInfo = Self.function("MRMediaRemoteGetNowPlayingInfo", as: InfoFunction.self),
              let getPID = Self.function("MRMediaRemoteGetNowPlayingApplicationPID", as: PIDFunction.self),
              let getPlaying = Self.function("MRMediaRemoteGetNowPlayingApplicationIsPlaying", as: PlayingFunction.self) else { return }
        getPID(DispatchQueue.main) { pid in
            getPlaying(DispatchQueue.main) { playing in
                getInfo(DispatchQueue.main) { dictionary in
                    let info = dictionary as? [String: Any] ?? [:]
                    MainActor.assumeIsolated { [weak self] in
                        self?.deliver(info, pid: pid, playing: playing.boolValue)
                    }
                }
            }
        }
    }

    private func deliver(_ info: [String: Any], pid: Int32, playing: Bool) {
        guard isRunning else { return }
        guard var current = NowPlayingInfo.from(info, pid: pid, playing: playing) else {
            onUpdate?(nil)
            return
        }
        current.bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        onUpdate?(current)
    }
}
