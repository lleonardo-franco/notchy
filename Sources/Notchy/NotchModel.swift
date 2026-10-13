import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class NotchModel {
    enum State {
        case collapsed
        case expanded
    }

    enum Mode {
        case collapsed
        case peek
        case approval
        case expanded
        case farewell
        case closing
        case video
    }

    enum Farewell {
        case goodbye
        case closing
    }

    enum PeekStyle: Equatable {
        case waiting
        case done
        case warning
        case info
        case meeting
        case app(BadgeApp)
        case device(String)
    }

    enum Tab: String, CaseIterable {
        case claude
        case agenda
        case weather
        case clipboard
        case bluetooth

        var title: String {
            switch self {
            case .claude: return "Claude"
            case .agenda: return "Agenda"
            case .weather: return "Clima"
            case .clipboard: return "Copiados"
            case .bluetooth: return "Bluetooth"
            }
        }

        var settingsTitle: String {
            switch self {
            case .claude: return "Claude Code"
            case .agenda: return "Agenda"
            case .weather: return "Clima"
            case .clipboard: return "Copiados"
            case .bluetooth: return "Bluetooth"
            }
        }
    }

    struct Peek: Equatable {
        let id = UUID()
        let style: PeekStyle
        let title: String
        let subtitle: String
    }

    static let panelSize = CGSize(width: 680, height: 460)
    static let rowHeight: CGFloat = 40
    static let tabsHeight: CGFloat = 26
    static let contentHeight: CGFloat = 164
    static let expandedWidth: CGFloat = 500
    static let approvalWidth: CGFloat = 470
    static let approvalBoxHeight: CGFloat = 58

    private(set) var state: State = .collapsed
    private(set) var peek: Peek?
    private(set) var notchWidth: CGFloat = 190
    private(set) var notchHeight: CGFloat = 32
    private(set) var screenFrame: NSRect = .zero
    private(set) var tab: Tab = .weather
    private(set) var farewell: Farewell?
    private(set) var glowWidth: CGFloat = 0
    private(set) var glowOpacity: Double = 0
    private(set) var volumeLevel: Double?

    @ObservationIgnored private var volumeToken = UUID()

    let prefs = Preferences()
    let music = MusicService()
    let claude = ClaudeService()
    let weather = WeatherService()
    let clipboard = ClipboardService()
    let badges = BadgeService()
    let calendar = CalendarService()
    let browser = BrowserMediaService()
    let video = VideoPlayer()
    let bluetooth = BluetoothService()
    let permissions = PermissionCenter()

    func start() {
        claude.onEvent = { [weak self] event in
            self?.handle(event)
        }
        badges.onIncrease = { [weak self] app, label in
            self?.notify(app, label)
        }
        browser.isEnabled = { [weak self] in
            self?.prefs.youtubeEnabled ?? false
        }
        browser.isExpanded = { [weak self] in
            self?.state == .expanded
        }
        SystemActivity.shared.onResume { [weak self] in
            guard let self else { return }
            self.weather.refreshIfStale()
            self.browser.refresh()
            self.bluetooth.refresh()
            self.calendar.refresh()
        }
        SystemActivity.shared.start()
        bluetooth.onConnect = { [weak self] device in
            self?.deviceConnected(device)
        }
        bluetooth.onLow = { [weak self] device, level in
            self?.deviceLow(device, level)
        }
        calendar.onReminder = { [weak self] event, minutes in
            self?.remind(event, minutes)
        }
        Haptics.shared.preferences = prefs
        music.start()
        claude.start()
        weather.start()
        clipboard.start()
        badges.start()
        calendar.start(preferences: prefs)
        browser.start()
        bluetooth.start()
        permissions.start(calendar: calendar)
        if !UserDefaults.standard.bool(forKey: WelcomeWindow.seenKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    WelcomeWindow.shared.show(model: self)
                }
            }
        }
        flash(.info, title: "Notchy ligado", subtitle: prefs.openMode == .hover ? "passe o mouse no notch" : "clique no notch")
    }

    func stop() {
        claude.stop()
    }

    func configure(for screen: NSScreen) {
        screenFrame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            notchWidth = screen.frame.width - left.width - right.width
            notchHeight = screen.safeAreaInsets.top
        } else {
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notchWidth = 190
            notchHeight = menuBar > 0 ? menuBar : 24
        }
    }

    func expand() {
        peek = nil
        tab = preferredTab()
        weather.refreshIfStale()
        calendar.refresh()
        browser.refresh()
        state = .expanded
    }

    func collapse() {
        state = .collapsed
    }

    func select(_ next: Tab) {
        tab = next
        if next != .claude {
            UserDefaults.standard.set(next.rawValue, forKey: "tab")
        }
    }

    func openSettings() {
        state = .collapsed
        SettingsWindow.shared.show(model: self)
    }

    func openWelcome() {
        state = .collapsed
        WelcomeWindow.shared.show(model: self)
    }

    func playFarewell(then done: @escaping @MainActor () -> Void) {
        peek = nil
        state = .collapsed
        farewell = .goodbye
        video.stop()
        Haptics.shared.perform(.subtle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.farewell = .closing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    MainActor.assumeIsolated {
                        self.glowWidth = self.notchWidth + 60
                        withAnimation(.easeOut(duration: 0.2)) {
                            self.glowOpacity = 1
                        }
                        withAnimation(.easeInOut(duration: 0.9).delay(0.2)) {
                            self.glowWidth = 0
                        }
                        withAnimation(.easeIn(duration: 0.45).delay(0.7)) {
                            self.glowOpacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                            MainActor.assumeIsolated { done() }
                        }
                    }
                }
            }
        }
    }

    func flash(_ style: PeekStyle, title: String, subtitle: String) {
        guard state == .collapsed, farewell == nil, video.video == nil else { return }
        let next = Peek(style: style, title: title, subtitle: subtitle)
        peek = next
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            MainActor.assumeIsolated {
                if self?.peek == next {
                    self?.peek = nil
                }
            }
        }
    }

    func approve(_ request: ApprovalRequest) {
        claude.respond(to: request, with: "allow")
    }

    func deny(_ request: ApprovalRequest) {
        claude.respond(to: request, with: "deny")
    }

    func answerInTerminal(_ request: ApprovalRequest) {
        let session = claude.session(for: request)
        claude.respond(to: request, with: "terminal")
        if let session {
            TerminalJumper.jump(to: session)
        }
    }

    func open(_ session: ClaudeSession) {
        TerminalJumper.jump(to: session)
    }

    func open(_ app: BadgeApp) {
        badges.open(app)
    }

    func watchInNotch(_ source: BrowserVideo) {
        let start = source.time ?? YouTubeLink.start(source.url) ?? 0
        browser.pause(source)
        peek = nil
        state = .collapsed
        video.play(id: source.videoID, start: start, title: source.cleanTitle, source: source)
    }

    func closeVideo() {
        video.stop()
        NotificationCenter.default.post(name: Preferences.layoutChanged, object: nil)
    }

    func returnVideoToBrowser() {
        guard let source = video.video?.source else {
            video.openOnYouTube()
            video.stop()
            return
        }
        Task {
            let time = await video.currentTime()
            browser.resume(source, at: time)
            video.stop()
            NotificationCenter.default.post(name: Preferences.layoutChanged, object: nil)
        }
    }

    private func deviceConnected(_ device: BluetoothDevice) {
        guard prefs.bluetoothAlerts else { return }
        flash(.device(device.symbol), title: device.name, subtitle: device.batteryText)
        Haptics.shared.perform(.subtle)
    }

    private func deviceLow(_ device: BluetoothDevice, _ level: Int) {
        guard prefs.bluetoothAlerts else { return }
        flash(.warning, title: device.name, subtitle: "bateria em \(level)%")
        alert("Funk")
    }

    func nextTrack() {
        guard music.track != nil else { return }
        music.next()
        haptic()
    }

    func previousTrack() {
        guard music.track != nil else { return }
        music.previous()
        haptic()
    }

    func changeVolume(by steps: Int) {
        let current = volumeLevel ?? SystemVolume.get() ?? 0.5
        let notch = (current * SystemVolume.steps).rounded()
        let next = min(max(notch + Double(steps), 0), SystemVolume.steps) / SystemVolume.steps
        SystemVolume.set(next)
        if next != current, next == 0 || next == 1 {
            Haptics.shared.perform(.subtle)
        }
        volumeLevel = next
        let token = UUID()
        volumeToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.volumeToken == token else { return }
                self.volumeLevel = nil
            }
        }
    }

    private func preferredTab() -> Tab {
        let available = tabs
        if imminentEvent != nil, available.contains(.agenda) { return .agenda }
        if !activeSessions.isEmpty, available.contains(.claude) { return .claude }
        if let stored = Tab(rawValue: UserDefaults.standard.string(forKey: "tab") ?? ""), available.contains(stored) {
            return stored
        }
        return available.first ?? .weather
    }

    private func handle(_ event: ClaudeEvent) {
        switch event {
        case .approval:
            alert("Glass")
        case .needsYou(let session):
            flash(.waiting, title: session.project, subtitle: "precisa de você")
            alert("Glass")
        case .finished(let session):
            flash(.done, title: session.project, subtitle: "terminou")
            alert("Tink")
        case .limit(let label, let percent):
            flash(.warning, title: "Limite \(label)", subtitle: "\(percent)% usado")
            alert("Funk")
        }
    }

    private func notify(_ app: BadgeApp, _ label: String) {
        guard prefs.isEnabled(app) else { return }
        flash(.app(app), title: app.rawValue, subtitle: app.describe(label))
        alert("Pop")
    }

    private func remind(_ event: AgendaEvent, _ minutes: Int) {
        guard prefs.enabledTabs.contains(Tab.agenda.rawValue) else { return }
        flash(.meeting, title: event.title, subtitle: minutes <= 0 ? "começando agora" : "em \(minutes) min")
        alert("Glass")
    }

    private func alert(_ sound: String) {
        Haptics.shared.perform(.normal)
        guard prefs.alertsEnabled else { return }
        NSSound(named: NSSound.Name(sound))?.play()
    }

    private func haptic() {
        Haptics.shared.perform(.normal)
    }

    var tabs: [Tab] { Tab.allCases.filter { prefs.enabledTabs.contains($0.rawValue) } }

    var currentTab: Tab? { tabs.contains(tab) ? tab : tabs.first }

    var pendingApproval: ApprovalRequest? { claude.approvals.first }

    var mode: Mode {
        if let farewell { return farewell == .goodbye ? .farewell : .closing }
        if pendingApproval != nil { return .approval }
        if video.video != nil { return .video }
        if state == .expanded { return .expanded }
        if peek != nil || volumeLevel != nil { return .peek }
        return .collapsed
    }

    var shapeAnimation: Animation {
        switch farewell {
        case .goodbye: return .spring(response: 0.6, dampingFraction: 0.8)
        case .closing: return .easeInOut(duration: 0.6)
        case nil: return .spring(response: 0.38, dampingFraction: 0.82)
        }
    }

    var isWide: Bool { mode == .expanded || mode == .approval || mode == .video }

    var topRadius: CGFloat { isWide ? 14 : 6 }

    var bottomRadius: CGFloat {
        switch mode {
        case .expanded, .approval: return 24
        case .video: return 22
        case .peek, .farewell: return 16
        case .collapsed, .closing: return 10
        }
    }

    var activeSessions: [ClaudeSession] { claude.sessions.filter { $0.effectiveStatus != .idle } }

    var imminentEvent: AgendaEvent? {
        guard prefs.meetingCountdown, prefs.meetingLead > 0, prefs.enabledTabs.contains(Tab.agenda.rawValue) else { return nil }
        return calendar.imminent(within: prefs.meetingLead)
    }

    var visibleBadges: [BadgeItem] {
        BadgeApp.allCases.compactMap { app in
            guard prefs.isEnabled(app), let label = badges.badges[app.rawValue] else { return nil }
            return BadgeItem(app: app, label: label)
        }
    }

    var hasPrimaryEar: Bool { music.track != nil || !activeSessions.isEmpty || imminentEvent != nil }

    var earWidth: CGFloat {
        let base = notchHeight + 6
        let pills = visibleBadges.map { max(18, CGFloat($0.label.count) * 6.5 + 10) }
        guard !pills.isEmpty else { return base }
        let content = (hasPrimaryEar ? 32 : 0) + pills.reduce(0, +) + CGFloat(pills.count - 1) * 4 + 12
        return max(base, content)
    }

    var showsEars: Bool { hasPrimaryEar || !visibleBadges.isEmpty }

    var youTubeCard: BrowserVideo? {
        guard prefs.youtubeEnabled, let current = browser.current else { return nil }
        if current.playing == true || music.track == nil || !music.isPlaying {
            return current
        }
        return nil
    }

    var musicHeight: CGFloat { music.track == nil && youTubeCard == nil ? 32 : 72 }

    var videoWidth: CGFloat { video.large ? 520 : 360 }

    var videoHeight: CGFloat { ((videoWidth - 28) * 9 / 16).rounded() }

    var headphones: BluetoothDevice? {
        bluetooth.devices.first { $0.kind == .headphones && $0.hasBattery }
    }

    var accentColor: Color? {
        guard mode == .expanded, let accent = music.accent else { return nil }
        return Color(nsColor: accent)
    }

    var bodySize: CGSize {
        switch mode {
        case .approval:
            return CGSize(width: Self.approvalWidth, height: notchHeight + 8 + 20 + 6 + Self.approvalBoxHeight + 12 + 30 + 14)
        case .expanded:
            let tabsArea = tabs.isEmpty ? 0 : 12 + Self.tabsHeight + 8 + Self.contentHeight
            return CGSize(width: Self.expandedWidth, height: notchHeight + 8 + musicHeight + tabsArea + 14)
        case .peek:
            return CGSize(width: notchWidth + earWidth * 2 + 120, height: notchHeight + 30)
        case .farewell:
            return CGSize(width: notchWidth + earWidth * 2 + 130, height: notchHeight + 32)
        case .video:
            return CGSize(width: videoWidth, height: notchHeight + 6 + videoHeight + 8 + 32 + 12)
        case .closing:
            return CGSize(width: notchWidth, height: notchHeight)
        case .collapsed:
            return CGSize(width: notchWidth + (showsEars ? earWidth * 2 : 0), height: notchHeight)
        }
    }

    var size: CGSize { CGSize(width: bodySize.width + topRadius * 2, height: bodySize.height) }

    var notchFraction: CGFloat { min(notchHeight / max(size.height, 1), 0.5) }

    var shapeRect: NSRect {
        NSRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }

    var hoverRect: NSRect {
        let body = bodySize
        return NSRect(x: screenFrame.midX - body.width / 2, y: screenFrame.maxY - body.height - 2, width: body.width, height: body.height + 6)
    }

    var topRegion: NSRect {
        let height = notchHeight + 8 + musicHeight
        return NSRect(x: shapeRect.minX, y: screenFrame.maxY - height, width: shapeRect.width, height: height)
    }
}
