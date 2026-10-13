import Foundation
import IOKit.ps
import Observation

struct PowerState: Equatable {
    var level: Int
    var pluggedIn: Bool
    var charging: Bool
    var charged: Bool
    var minutesToEmpty: Int?
    var minutesToFull: Int?
    var adapterWatts: Int?

    var summary: String {
        var parts = ["\(level)%"]
        if pluggedIn {
            if let adapterWatts {
                parts.append("\(adapterWatts) W")
            }
            if charged || level >= 100 {
                parts.append(String(localized: "carregada"))
            } else if charging, let minutesToFull {
                parts.append(String(localized: "cheio em \(Self.duration(minutesToFull))"))
            } else if charging {
                parts.append(String(localized: "carregando"))
            }
        } else if let minutesToEmpty {
            parts.append(String(localized: "\(Self.duration(minutesToEmpty)) restantes"))
        }
        return parts.joined(separator: " · ")
    }

    static func duration(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = .interface
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }

    static func from(_ description: [String: Any], adapter: [String: Any]?) -> PowerState? {
        guard (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { return nil }
        let pluggedIn = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        func minutes(_ key: String) -> Int? {
            guard let value = description[key] as? Int, value > 0 else { return nil }
            return value
        }
        return PowerState(
            level: Int((Double(current) / Double(maximum) * 100).rounded()),
            pluggedIn: pluggedIn,
            charging: description[kIOPSIsChargingKey] as? Bool ?? false,
            charged: description[kIOPSIsChargedKey] as? Bool ?? false,
            minutesToEmpty: pluggedIn ? nil : minutes(kIOPSTimeToEmptyKey),
            minutesToFull: pluggedIn ? minutes(kIOPSTimeToFullChargeKey) : nil,
            adapterWatts: pluggedIn ? adapter?[kIOPSPowerAdapterWattsKey] as? Int : nil
        )
    }
}

@MainActor
@Observable
final class PowerService {
    enum Event: Equatable {
        case pluggedIn(PowerState)
        case unplugged(PowerState)
        case low(Int)
    }

    private(set) var state: PowerState?

    @ObservationIgnored var onEvent: ((Event) -> Void)?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var warned: Set<Int> = []

    func start() {
        state = Self.read()
        guard source == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let loop = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<PowerService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.update() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), loop, .defaultMode)
        source = loop
    }

    func refresh() {
        update()
    }

    private func update() {
        let previous = state
        let next = Self.read()
        if next != state {
            state = next
        }
        guard let previous, let next else { return }
        for event in Self.events(from: previous, to: next, warned: &warned) {
            onEvent?(event)
        }
    }

    nonisolated static func events(from previous: PowerState, to next: PowerState, warned: inout Set<Int>) -> [Event] {
        var events: [Event] = []
        if next.pluggedIn, !previous.pluggedIn {
            events.append(.pluggedIn(next))
        } else if !next.pluggedIn, previous.pluggedIn {
            events.append(.unplugged(next))
        }
        if next.pluggedIn {
            warned = []
        } else if let threshold = [10, 20].first(where: { next.level <= $0 && previous.level > $0 }), warned.insert(threshold).inserted {
            events.append(.low(threshold))
        }
        return events
    }

    nonisolated static func read() -> PowerState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        for item in list {
            guard let description = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                  let state = PowerState.from(description, adapter: adapter) else { continue }
            return state
        }
        return nil
    }
}

#if DEBUG
extension PowerService {
    func demo(_ state: PowerState?) {
        self.state = state
    }
}
#endif
