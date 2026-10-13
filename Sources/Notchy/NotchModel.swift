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
        case power(level: Int, charging: Bool)
    }

    enum Tab: String, CaseIterable {
        case claude
        case agenda
        case weather
        case clipboard
        case bluetooth
        case shelf

        var title: String {
            switch self {
            case .claude: return "Claude"
            case .agenda: return String(localized: "Agenda")
            case .weather: return String(localized: "Clima")
            case .clipboard: return String(localized: "Copiados")
            case .bluetooth: return "Bluetooth"
            case .shelf: return String(localized: "Bandeja")
            }
        }

        var settingsTitle: String {
            switch self {
            case .claude: return "Claude Code"
            default: return title
            }
        }
    }

    enum LevelKind: Equatable {
        case volume
        case brightness
    }

    struct LevelHUD: Equatable {
        let kind: LevelKind
        let level: Double
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
    static let expandedWidth: CGFloat = 540
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
    private(set) var hud: LevelHUD?
    @ObservationIgnored var onScreen = true
    private(set) var fileDrag = false

    @ObservationIgnored private var hudToken = UUID()
    @ObservationIgnored let mediaKeys = MediaKeyMonitor()

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
    let shelf = ShelfService()
    let power = PowerService()

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
            self.music.resumeOtherPlayers()
            self.power.refresh()
        }
        SystemActivity.shared.start()
        bluetooth.onConnect = { [weak self] device in
            self?.deviceConnected(device)
        }
        bluetooth.onLow = { [weak self] device, level in
            self?.deviceLow(device, level)
        }
        power.onEvent = { [weak self] event in
            self?.powerChanged(event)
        }
        calendar.onReminder = { [weak self] event, minutes in
            self?.remind(event, minutes)
        }
        Haptics.shared.preferences = prefs
        music.start()
        music.setOtherPlayers(prefs.otherPlayers)
        claude.start()
        weather.start()
        clipboard.start()
        badges.start()
        calendar.start(preferences: prefs)
        browser.start()
        bluetooth.start()
        power.start()
        permissions.start(calendar: calendar)
        mediaKeys.handler = { [weak self] key, isRepeat, modifiers in
            self?.handleMediaKey(key, fine: modifiers.contains(.shift) && modifiers.contains(.option)) ?? false
        }
        if prefs.levelHUD {
            mediaKeys.start()
        }
        if !UserDefaults.standard.bool(forKey: WelcomeWindow.seenKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    WelcomeWindow.shared.show(model: self)
                }
            }
        }
        flash(.info, title: String(localized: "Notchy ligado"), subtitle: prefs.openMode == .hover ? String(localized: "passe o mouse no notch") : String(localized: "clique no notch"))
    }

    func stop() {
        claude.stop()
        mediaKeys.stop()
        music.setOtherPlayers(false)
    }

    func setLevelHUD(_ enabled: Bool) {
        prefs.levelHUD = enabled
        if enabled {
            mediaKeys.start()
        } else {
            mediaKeys.stop()
        }
    }

    func setOtherPlayers(_ enabled: Bool) {
        prefs.otherPlayers = enabled
        music.setOtherPlayers(enabled)
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
        shelf.prune()
        weather.refreshIfStale()
        calendar.refresh()
        browser.refresh()
        state = .expanded
    }

    func collapse() {
        state = .collapsed
        fileDrag = false
    }

    var acceptsFileDrops: Bool { tabs.contains(.shelf) && video.video == nil && pendingApproval == nil && farewell == nil }

    func beginFileDrag() {
        guard acceptsFileDrops else { return }
        if state != .expanded {
            expand()
        }
        tab = .shelf
        fileDrag = true
    }

    func endFileDrag() {
        fileDrag = false
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
        video.play(id: source.videoID, start: start, title: source.cleanTitle, source: source, rate: source.rate ?? 1)
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
            browser.resume(source, at: time, rate: video.rate)
            video.stop()
            NotificationCenter.default.post(name: Preferences.layoutChanged, object: nil)
        }
    }

    private func deviceConnected(_ device: BluetoothDevice) {
        guard prefs.bluetoothAlerts else { return }
        flash(.device(device.symbol), title: device.name, subtitle: device.batteryText)
        Haptics.shared.perform(.subtle)
    }

    private func powerChanged(_ event: PowerService.Event) {
        guard prefs.batteryAlerts else { return }
        switch event {
        case .pluggedIn(let state):
            let title = state.charging ? String(localized: "Carregando") : String(localized: "Conectado ao carregador")
            flash(.power(level: state.level, charging: true), title: title, subtitle: state.summary)
            Haptics.shared.perform(.subtle)
        case .unplugged(let state):
            flash(.power(level: state.level, charging: false), title: String(localized: "Na bateria"), subtitle: state.summary)
        case .low(let level):
            flash(.warning, title: String(localized: "Bateria em \(level)%"), subtitle: String(localized: "conecte o carregador"))
            alert("Funk")
        }
    }

    private func deviceLow(_ device: BluetoothDevice, _ level: Int) {
        guard prefs.bluetoothAlerts else { return }
        flash(.warning, title: device.name, subtitle: String(localized: "bateria em \(level)%"))
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

    var volumeLevel: Double? { hud?.kind == .volume ? hud?.level : nil }

    func changeVolume(by steps: Int) {
        let current = volumeLevel ?? SystemVolume.get() ?? 0.5
        let next = Self.stepped(current, by: steps, divisions: SystemVolume.steps)
        SystemVolume.set(next)
        showLevel(.volume, next, from: current)
    }

    func handleMediaKey(_ key: MediaKeyMonitor.Key, fine: Bool) -> Bool {
        guard onScreen, farewell == nil else { return false }
        let divisions = fine ? SystemVolume.steps * 4 : SystemVolume.steps
        switch key {
        case .volumeUp, .volumeDown:
            guard SystemVolume.canSet, let current = SystemVolume.get() else { return false }
            let next = Self.stepped(current, by: key == .volumeUp ? 1 : -1, divisions: divisions)
            SystemVolume.set(next)
            showLevel(.volume, next, from: current)
            return true
        case .mute:
            guard let level = SystemVolume.toggleMute() else { return false }
            showLevel(.volume, level, from: nil)
            return true
        case .brightnessUp, .brightnessDown:
            guard let current = DisplayBrightness.get() else { return false }
            let next = Self.stepped(current, by: key == .brightnessUp ? 1 : -1, divisions: divisions)
            guard DisplayBrightness.set(next) else { return false }
            showLevel(.brightness, next, from: current)
            return true
        }
    }

    nonisolated static func stepped(_ current: Double, by steps: Int, divisions: Double) -> Double {
        let notch = (current * divisions).rounded()
        return min(max(notch + Double(steps), 0), divisions) / divisions
    }

    private func showLevel(_ kind: LevelKind, _ level: Double, from previous: Double?) {
        if let previous, level != previous, level == 0 || level == 1 {
            Haptics.shared.perform(.subtle)
        }
        hud = LevelHUD(kind: kind, level: level)
        let token = UUID()
        hudToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.hudToken == token else { return }
                self.hud = nil
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
            flash(.waiting, title: session.project, subtitle: String(localized: "precisa de você"))
            alert("Glass")
        case .finished(let session):
            flash(.done, title: session.project, subtitle: String(localized: "terminou"))
            alert("Tink")
        case .limit(let label, let percent):
            flash(.warning, title: String(localized: "Limite \(label)"), subtitle: String(localized: "\(percent)% usado"))
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
        flash(.meeting, title: event.title, subtitle: minutes <= 0 ? String(localized: "começando agora") : String(localized: "em \(minutes) min"))
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
        if peek != nil || hud != nil { return .peek }
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
        let pills = visibleBadges.map { EarBadge.width(for: $0.label) }
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
