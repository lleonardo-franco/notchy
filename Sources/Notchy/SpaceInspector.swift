import AppKit
import ColorSync

enum SpaceInspector {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let functions: (MainConnection, CopySpaces)? = {
        let paths = [
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        ]
        for path in paths {
            guard let handle = dlopen(path, RTLD_NOW),
                  let connection = dlsym(handle, "CGSMainConnectionID") ?? dlsym(handle, "SLSMainConnectionID"),
                  let spaces = dlsym(handle, "CGSCopyManagedDisplaySpaces") ?? dlsym(handle, "SLSCopyManagedDisplaySpaces") else { continue }
            return (unsafeBitCast(connection, to: MainConnection.self), unsafeBitCast(spaces, to: CopySpaces.self))
        }
        return nil
    }()

    static func isFullscreen(_ screen: NSScreen) -> Bool {
        guard let loaded = functions,
              let displays = loaded.1(loaded.0())?.takeRetainedValue() as? [[String: Any]] else { return false }
        let identifier = uuid(of: screen)
        let match = displays.first { ($0["Display Identifier"] as? String)?.caseInsensitiveCompare(identifier ?? "") == .orderedSame }
            ?? (displays.count == 1 ? displays.first : displays.first { ($0["Display Identifier"] as? String) == "Main" })
        guard let current = match?["Current Space"] as? [String: Any],
              let type = current["type"] as? Int else { return false }
        return type == 4
    }

    private static func uuid(of screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }
}
