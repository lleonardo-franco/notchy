import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = NotchModel()
    private let panel = NotchPanel()
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var collapseWork: DispatchWorkItem?
    private var quitting = false
    private var signalSource: DispatchSourceSignal?
    private var hoverStart: Date?
    private var suppressHover = false
    private var tracker = SwipeTracker()
    private var currentScreen: NSScreen?
    private var hidden = false
    private var dragBaseline = NSPasteboard(name: .drag).changeCount
    private var ownDrag = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = FirstMouseHostingView(rootView: NotchView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        layoutPanel()
        model.start()
        listenForTermination()

        addGlobal([.mouseMoved, .leftMouseDragged]) { [weak self] _ in self?.trackMouse() }
        addLocal([.mouseMoved, .leftMouseDragged]) { [weak self] _ in self?.trackMouse() }
        addGlobal([.leftMouseDown]) { [weak self] _ in
            self?.ownDrag = false
            self?.handleClick()
        }
        addLocal([.leftMouseDown]) { [weak self] _ in self?.ownDrag = true }
        addGlobal([.scrollWheel]) { [weak self] event in self?.handleScroll(event) }
        addLocal([.scrollWheel]) { [weak self] event in self?.handleScroll(event) }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.trackMouse()
            }
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutPanel() }
        })

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleVisibilityCheck() }
        })

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleVisibilityCheck() }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: Preferences.layoutChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutPanel() }
        })

        SystemActivity.shared.onResume { [weak self] in
            self?.layoutPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        model.openSettings()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "notchy" {
            switch url.host {
            case "settings": model.openSettings()
            case "welcome": model.openWelcome()
            default: break
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !quitting else { return .terminateNow }
        quitting = true
        cancelCollapse()
        panel.ignoresMouseEvents = true
        model.playFarewell {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func addGlobal(_ mask: NSEvent.EventTypeMask, _ handler: @escaping @MainActor (NSEvent) -> Void) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { handler(event) }
        }) {
            monitors.append(monitor)
        }
    }

    private func addLocal(_ mask: NSEvent.EventTypeMask, _ handler: @escaping @MainActor (NSEvent) -> Void) {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            MainActor.assumeIsolated { handler(event) }
            return event
        }) {
            monitors.append(monitor)
        }
    }

    private func listenForTermination() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard self?.quitting == false else { return }
                NSApp.terminate(nil)
            }
        }
        source.resume()
        signalSource = source
    }

    private func targetScreen() -> NSScreen? {
        let notchScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        switch model.prefs.screenMode {
        case .automatic: return notchScreen ?? NSScreen.screens.first
        case .main: return NSScreen.screens.first
        case .notchOnly: return notchScreen
        }
    }

    private func layoutPanel() {
        currentScreen = targetScreen()
        if let screen = currentScreen {
            model.configure(for: screen)
            let size = NotchModel.panelSize
            let frame = screen.frame
            panel.setFrame(
                NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height),
                display: true
            )
        }
        updateVisibility()
    }

    private func scheduleVisibilityCheck() {
        updateVisibility()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
    }

    private func updateVisibility() {
        guard let screen = currentScreen else {
            setHidden(true)
            return
        }
        let fullscreen = model.prefs.hideInFullscreen && model.video.video == nil && SpaceInspector.isFullscreen(screen)
        setHidden(fullscreen)
    }

    private func setHidden(_ value: Bool) {
        model.onScreen = !value
        if value {
            if !hidden {
                hidden = true
                cancelCollapse()
                model.collapse()
                panel.orderOut(nil)
            }
        } else {
            hidden = false
            panel.orderFrontRegardless()
        }
    }

    private var isCollapsed: Bool {
        model.mode == .collapsed || model.mode == .peek
    }

    private func fileDragActive() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        guard NSEvent.pressedMouseButtons & 1 == 1 else {
            dragBaseline = pasteboard.changeCount
            ownDrag = false
            return false
        }
        guard !ownDrag, pasteboard.changeCount != dragBaseline else { return false }
        return pasteboard.types?.contains(.fileURL) == true
    }

    private func trackMouse() {
        guard !hidden else { return }
        let point = NSEvent.mouseLocation
        let dragging = fileDragActive()
        if !dragging, model.fileDrag {
            model.endFileDrag()
        }
        switch model.mode {
        case .approval:
            cancelCollapse()
            panel.ignoresMouseEvents = !model.shapeRect.contains(point)
        case .expanded:
            let inside = model.shapeRect.insetBy(dx: -8, dy: -8).contains(point)
            panel.ignoresMouseEvents = !inside
            if inside {
                cancelCollapse()
                if dragging, !model.fileDrag {
                    model.beginFileDrag()
                }
            } else if collapseWork == nil {
                scheduleCollapse()
            }
        case .video:
            cancelCollapse()
            hoverStart = nil
            panel.ignoresMouseEvents = !model.shapeRect.contains(point)
        case .farewell, .closing:
            panel.ignoresMouseEvents = true
        case .collapsed, .peek:
            panel.ignoresMouseEvents = true
            if dragging, model.acceptsFileDrops, model.hoverRect.insetBy(dx: -24, dy: -12).contains(point) {
                expand()
                model.beginFileDrag()
                return
            }
            if suppressHover {
                if !model.hoverRect.insetBy(dx: -10, dy: -10).contains(point) {
                    suppressHover = false
                }
                return
            }
            guard model.prefs.openMode == .hover, model.hoverRect.contains(point) else {
                hoverStart = nil
                return
            }
            let delay = model.prefs.hoverDelay
            if delay <= 0 {
                expand()
            } else if let start = hoverStart {
                if Date().timeIntervalSince(start) >= delay {
                    expand()
                }
            } else {
                hoverStart = Date()
            }
        }
    }

    private func handleClick() {
        guard !hidden else { return }
        guard isCollapsed, model.hoverRect.contains(NSEvent.mouseLocation) else { return }
        expand()
    }

    private func handleScroll(_ event: NSEvent) {
        guard !hidden else { return }
        let point = NSEvent.mouseLocation
        let region = isCollapsed ? model.hoverRect.insetBy(dx: -12, dy: -6) : model.shapeRect
        guard region.contains(point) else {
            tracker.reset()
            return
        }

        let prefs = model.prefs
        if model.mode == .video {
            guard let output = tracker.feed(event, continuousVertical: true) else { return }
            switch output {
            case .horizontal(let right):
                model.video.seek(by: right == prefs.swipeRightNext ? 10 : -10)
                Haptics.shared.perform(.normal)
            case .volume(let steps):
                if prefs.verticalGesture == .volume {
                    model.changeVolume(by: steps)
                }
            case .vertical:
                break
            }
            return
        }
        guard let output = tracker.feed(event, continuousVertical: prefs.verticalGesture == .volume) else { return }
        let overControls = isCollapsed || model.topRegion.contains(point)

        switch output {
        case .horizontal(let right):
            guard prefs.swipeTracks, model.music.track != nil else { return }
            if right == prefs.swipeRightNext {
                model.nextTrack()
            } else {
                model.previousTrack()
            }
        case .volume(let steps):
            guard overControls else { return }
            model.changeVolume(by: steps)
        case .vertical(let down):
            guard prefs.verticalGesture == .openClose else { return }
            if down, isCollapsed {
                expand()
            } else if !down, model.mode == .expanded, model.topRegion.contains(point) {
                cancelCollapse()
                suppressHover = true
                hoverStart = nil
                model.collapse()
                panel.ignoresMouseEvents = true
            }
        }
    }

    private func expand() {
        hoverStart = nil
        suppressHover = false
        cancelCollapse()
        model.expand()
        panel.ignoresMouseEvents = false
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }

    private func scheduleCollapse() {
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.collapseWork = nil
                self.model.collapse()
                self.panel.ignoresMouseEvents = true
            }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}
