import Foundation
import IOKit.ps
import Testing
@testable import Notchy

@MainActor
struct PowerTests {
    func battery(_ level: Int, plugged: Bool, charging: Bool = false) -> PowerState {
        PowerState(level: level, pluggedIn: plugged, charging: charging, charged: false, minutesToEmpty: nil, minutesToFull: nil, adapterWatts: nil)
    }

    @Test func readsAnInternalBattery() {
        let description: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey: 80,
            kIOPSMaxCapacityKey: 100,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSIsChargingKey: true,
            kIOPSTimeToFullChargeKey: 45,
            kIOPSTimeToEmptyKey: -1
        ]
        let state = PowerState.from(description, adapter: [kIOPSPowerAdapterWattsKey: 67])
        #expect(state?.level == 80)
        #expect(state?.pluggedIn == true)
        #expect(state?.charging == true)
        #expect(state?.minutesToFull == 45)
        #expect(state?.minutesToEmpty == nil)
        #expect(state?.adapterWatts == 67)
    }

    @Test func ignoresOtherPowerSources() {
        let ups: [String: Any] = [kIOPSTypeKey: "UPS", kIOPSCurrentCapacityKey: 50, kIOPSMaxCapacityKey: 100]
        #expect(PowerState.from(ups, adapter: nil) == nil)
    }

    @Test func onBatteryIgnoresAdapterAndTimeToFull() {
        let description: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey: 4200,
            kIOPSMaxCapacityKey: 5000,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: 190,
            kIOPSTimeToFullChargeKey: 30
        ]
        let state = PowerState.from(description, adapter: [kIOPSPowerAdapterWattsKey: 96])
        #expect(state?.level == 84)
        #expect(state?.pluggedIn == false)
        #expect(state?.minutesToEmpty == 190)
        #expect(state?.minutesToFull == nil)
        #expect(state?.adapterWatts == nil)
    }

    @Test func plugAndUnplugEvents() {
        var warned: Set<Int> = []
        let plugged = battery(50, plugged: true, charging: true)
        let unplugged = battery(50, plugged: false)
        #expect(PowerService.events(from: unplugged, to: plugged, warned: &warned) == [.pluggedIn(plugged)])
        #expect(PowerService.events(from: plugged, to: unplugged, warned: &warned) == [.unplugged(unplugged)])
        #expect(PowerService.events(from: unplugged, to: unplugged, warned: &warned).isEmpty)
    }

    @Test func lowBatteryWarnsOncePerThreshold() {
        var warned: Set<Int> = []
        #expect(PowerService.events(from: battery(21, plugged: false), to: battery(20, plugged: false), warned: &warned) == [.low(20)])
        #expect(PowerService.events(from: battery(21, plugged: false), to: battery(20, plugged: false), warned: &warned).isEmpty)
        #expect(PowerService.events(from: battery(11, plugged: false), to: battery(10, plugged: false), warned: &warned) == [.low(10)])
        _ = PowerService.events(from: battery(10, plugged: false), to: battery(10, plugged: true), warned: &warned)
        #expect(warned.isEmpty)
    }

    @Test func summaryStartsWithTheLevel() {
        #expect(battery(73, plugged: false).summary.hasPrefix("73%"))
        var charging = battery(40, plugged: true, charging: true)
        charging.adapterWatts = 70
        #expect(charging.summary.contains("70 W"))
    }
}
