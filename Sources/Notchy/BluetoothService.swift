import AppKit
import CoreAudio
import Observation

struct BluetoothDevice: Identifiable, Equatable {
    enum Kind {
        case headphones
        case keyboard
        case mouse
        case trackpad
        case gamepad
        case other
    }

    let name: String
    let kind: Kind
    let left: Int?
    let right: Int?
    let caseLevel: Int?
    let main: Int?

    var id: String { name }

    var lowest: Int? {
        [left, right, main].compactMap { $0 }.min() ?? caseLevel
    }

    var hasBattery: Bool { lowest != nil }

    var symbol: String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        switch kind {
        case .headphones: return "headphones"
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .gamepad: return "gamecontroller"
        case .other: return "dot.radiowaves.left.and.right"
        }
    }

    var batteryText: String {
        var parts: [String] = []
        if let left { parts.append(String(localized: "E \(left)%")) }
        if let right { parts.append(String(localized: "D \(right)%")) }
        if let caseLevel { parts.append(String(localized: "estojo \(caseLevel)%")) }
        if parts.isEmpty, let main { parts.append("\(main)%") }
        return parts.isEmpty ? String(localized: "conectado") : parts.joined(separator: " · ")
    }
}

@MainActor
@Observable
final class BluetoothService {
    private(set) var devices: [BluetoothDevice] = []

    @ObservationIgnored var onConnect: (@MainActor (BluetoothDevice) -> Void)?
    @ObservationIgnored var onLow: (@MainActor (BluetoothDevice, Int) -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var primed = false
    @ObservationIgnored private var scanning = false
    @ObservationIgnored private var warned: Set<String> = []

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.refresh()
            }
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refreshSoon() }
        }
    }

    func refresh() {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = Self.scan()
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply(found) }
            }
        }
    }

    private func refreshSoon() {
        for delay in [2.5, 8.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    private func apply(_ found: [BluetoothDevice]) {
        scanning = false
        let previous = Dictionary(uniqueKeysWithValues: devices.map { ($0.name, $0) })
        if primed {
            for device in found {
                let before = previous[device.name]
                if before == nil, device.kind == .headphones || device.hasBattery {
                    onConnect?(device)
                } else if before?.hasBattery == false, device.hasBattery, device.kind == .headphones {
                    onConnect?(device)
                }
            }
        }
        for device in found {
            guard let level = device.lowest else { continue }
            if level <= 20 {
                if warned.insert(device.name).inserted, primed {
                    onLow?(device, level)
                }
            } else if level >= 30 {
                warned.remove(device.name)
            }
        }
        primed = true
        if found != devices {
            devices = found
        }
    }

    nonisolated private static func scan() -> [BluetoothDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }

        var devices: [BluetoothDevice] = []
        collect(json, into: &devices)
        return devices.sorted { lhs, rhs in
            if (lhs.kind == .headphones) != (rhs.kind == .headphones) { return lhs.kind == .headphones }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    nonisolated private static func collect(_ node: Any, into devices: inout [BluetoothDevice]) {
        if let dictionary = node as? [String: Any] {
            for (key, value) in dictionary {
                if key == "device_connected", let entries = value as? [[String: Any]] {
                    for entry in entries {
                        for (name, raw) in entry {
                            guard let properties = raw as? [String: Any] else { continue }
                            devices.append(device(name: name, properties))
                        }
                    }
                } else if key != "device_not_connected" {
                    collect(value, into: &devices)
                }
            }
        } else if let array = node as? [Any] {
            for item in array {
                collect(item, into: &devices)
            }
        }
    }

    nonisolated private static func device(name: String, _ properties: [String: Any]) -> BluetoothDevice {
        func level(_ key: String) -> Int? {
            guard let text = properties[key] as? String else { return nil }
            return Int(text.filter(\.isNumber))
        }
        let minor = (properties["device_minorType"] as? String ?? "").lowercased()
        let lower = name.lowercased()
        let kind: BluetoothDevice.Kind
        if minor.contains("headphone") || minor.contains("headset") || minor.contains("speaker") || lower.contains("airpods") || lower.contains("buds") {
            kind = .headphones
        } else if minor.contains("keyboard") {
            kind = .keyboard
        } else if minor.contains("mouse") {
            kind = .mouse
        } else if minor.contains("trackpad") {
            kind = .trackpad
        } else if minor.contains("gamepad") || minor.contains("joystick") || lower.contains("controller") {
            kind = .gamepad
        } else {
            kind = .other
        }
        return BluetoothDevice(
            name: name,
            kind: kind,
            left: level("device_batteryLevelLeft"),
            right: level("device_batteryLevelRight"),
            caseLevel: level("device_batteryLevelCase"),
            main: level("device_batteryLevelMain") ?? level("device_batteryLevel")
        )
    }
}

#if DEBUG
extension BluetoothService {
    func demo(_ devices: [BluetoothDevice]) {
        self.devices = devices
    }
}
#endif
