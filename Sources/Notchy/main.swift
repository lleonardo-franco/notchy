import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    #if DEBUG
    if let folder = ProcessInfo.processInfo.environment["NOTCHY_SHOWCASE"] {
        app.setActivationPolicy(.accessory)
        Showcase.start(into: folder)
        app.run()
        return
    }
    #endif
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
