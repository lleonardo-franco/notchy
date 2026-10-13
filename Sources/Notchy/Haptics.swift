import AppKit
import IOKit

@MainActor
final class Haptics {
    enum Emphasis {
        case subtle
        case normal
    }

    static let shared = Haptics()

    weak var preferences: Preferences?

    private typealias CreateFunction = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias OpenFunction = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias ActuateFunction = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float32, Float32) -> Int32
    private typealias CloseFunction = @convention(c) (UnsafeMutableRawPointer) -> Int32

    private let createActuator: CreateFunction?
    private let openActuator: OpenFunction?
    private let actuateActuator: ActuateFunction?
    private let closeActuator: CloseFunction?
    private var actuator: UnsafeMutableRawPointer?

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)
        func load<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: type)
        }
        createActuator = load("MTActuatorCreateFromDeviceID", as: CreateFunction.self)
        openActuator = load("MTActuatorOpen", as: OpenFunction.self)
        actuateActuator = load("MTActuatorActuate", as: ActuateFunction.self)
        closeActuator = load("MTActuatorClose", as: CloseFunction.self)
    }

    func perform(_ emphasis: Emphasis = .normal) {
        perform(emphasis, level: preferences?.hapticLevel ?? .medium)
    }

    func perform(_ emphasis: Emphasis, level: Preferences.HapticLevel) {
        guard let actuation = Self.actuation(for: emphasis, level: level) else { return }
        if fire(actuation) { return }
        reset()
        if fire(actuation) { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private static func actuation(for emphasis: Emphasis, level: Preferences.HapticLevel) -> Int32? {
        switch (level, emphasis) {
        case (.off, _): return nil
        case (.light, _): return 3
        case (.medium, .subtle): return 3
        case (.medium, .normal): return 4
        case (.strong, .subtle): return 4
        case (.strong, .normal): return 6
        }
    }

    private func fire(_ actuation: Int32) -> Bool {
        guard let actuateActuator, let actuator = currentActuator() else { return false }
        return actuateActuator(actuator, actuation, 0, 0, 2) == 0
    }

    private func currentActuator() -> UnsafeMutableRawPointer? {
        if let actuator { return actuator }
        guard let createActuator, let openActuator, let deviceID = Self.trackpadID(),
              let reference = createActuator(deviceID) else { return nil }
        guard openActuator(reference) == 0 else {
            Unmanaged<AnyObject>.fromOpaque(reference).release()
            return nil
        }
        actuator = reference
        return reference
    }

    private func reset() {
        if let actuator {
            _ = closeActuator?(actuator)
            Unmanaged<AnyObject>.fromOpaque(actuator).release()
        }
        actuator = nil
    }

    private static func trackpadID() -> UInt64? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleMultitouchDevice"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var unmanaged: Unmanaged<CFMutableDictionary>?
            let status = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
            IOObjectRelease(service)
            if status == KERN_SUCCESS,
               let properties = unmanaged?.takeRetainedValue() as? [String: Any],
               (properties["ActuationSupported"] as? Bool) == true,
               (properties["MT Built-In"] as? Bool) == true,
               let identifier = (properties["Multitouch ID"] as? NSNumber)?.uint64Value {
                return identifier
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }
}
