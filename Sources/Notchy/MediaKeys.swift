import AppKit
import CoreGraphics

@MainActor
enum DisplayBrightness {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

    nonisolated(unsafe) private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    private static func function<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: type)
    }

    static var display: CGDirectDisplayID {
        let ids = NSScreen.screens.compactMap { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID }
        return ids.first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
    }

    static func get() -> Double? {
        guard let read = function("DisplayServicesGetBrightness", as: GetFunction.self) else { return nil }
        var value: Float = 0
        guard read(display, &value) == 0 else { return nil }
        return Double(min(max(value, 0), 1))
    }

    @discardableResult
    static func set(_ level: Double) -> Bool {
        guard let write = function("DisplayServicesSetBrightness", as: SetFunction.self) else { return false }
        return write(display, Float(min(max(level, 0), 1))) == 0
    }
}

@MainActor
final class MediaKeyMonitor {
    enum Key {
        case volumeUp
        case volumeDown
        case mute
        case brightnessUp
        case brightnessDown

        init?(code: Int) {
            switch code {
            case 0: self = .volumeUp
            case 1: self = .volumeDown
            case 7: self = .mute
            case 2: self = .brightnessUp
            case 3: self = .brightnessDown
            default: return nil
            }
        }
    }

    var handler: ((Key, Bool, NSEvent.ModifierFlags) -> Bool)?

    private(set) var isRunning = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retry: Timer?
    private var handled: Set<Int> = []

    func start() {
        guard tap == nil else { return }
        if install() {
            retry?.invalidate()
            retry = nil
        } else if retry == nil {
            retry = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.install() else { return }
                    self.retry?.invalidate()
                    self.retry = nil
                }
            }
        }
    }

    func stop() {
        retry?.invalidate()
        retry = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        isRunning = false
        handled = []
    }

    private func install() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask = CGEventMask(1) << 14
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        source = loopSource
        isRunning = true
        return true
    }

    fileprivate func reenable() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    fileprivate func receive(code: Int, down: Bool, isRepeat: Bool, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let key = Key(code: code) else { return false }
        if !down {
            return handled.remove(code) != nil
        }
        if isRepeat, key == .mute {
            return handled.contains(code)
        }
        let consumed = handler?(key, isRepeat, modifiers) ?? false
        if consumed {
            handled.insert(code)
        } else {
            handled.remove(code)
        }
        return consumed
    }
}

private let mediaKeyCallback: CGEventTapCallBack = { _, type, event, info in
    guard let info else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(info).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { monitor.reenable() }
        return Unmanaged.passUnretained(event)
    }
    guard type.rawValue == 14,
          let system = NSEvent(cgEvent: event),
          system.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
    let data = system.data1
    let code = (data & 0xFFFF0000) >> 16
    let flags = data & 0x0000FFFF
    let down = ((flags & 0xFF00) >> 8) == 0xA
    let isRepeat = (flags & 0x1) == 1
    let modifiers = system.modifierFlags
    let consumed = MainActor.assumeIsolated {
        monitor.receive(code: code, down: down, isRepeat: isRepeat, modifiers: modifiers)
    }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
