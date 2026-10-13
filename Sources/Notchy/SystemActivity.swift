import AppKit
import Observation

@MainActor
@Observable
final class SystemActivity {
    static let shared = SystemActivity()

    private(set) var paused = false

    @ObservationIgnored private var asleep = false
    @ObservationIgnored private var screensAsleep = false
    @ObservationIgnored private var locked = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var resumeHandlers: [@MainActor () -> Void] = []

    func onResume(_ handler: @escaping @MainActor () -> Void) {
        resumeHandlers.append(handler)
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.asleep = true }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.asleep = false }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.locked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.locked = false }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ change: @escaping @MainActor (SystemActivity) -> Void) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                change(self)
                self.update()
            }
        })
    }

    private func update() {
        let next = asleep || screensAsleep || locked
        guard next != paused else { return }
        paused = next
        if !next {
            for handler in resumeHandlers {
                handler()
            }
        }
    }
}
