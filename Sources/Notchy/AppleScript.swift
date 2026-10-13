import Foundation

enum AppleScript {
    static let queue = DispatchQueue(label: "notchy.applescript")

    static func run(_ source: String, timeout: Int = 4) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let wrapped = "with timeout of \(timeout) seconds\n\(source)\nend timeout"
        guard let script = NSAppleScript(source: wrapped) else { return nil }
        let result = script.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    static func runAsync(_ source: String, timeout: Int = 4, then completion: (@Sendable () -> Void)? = nil) {
        queue.async {
            _ = run(source, timeout: timeout)
            completion?()
        }
    }
}
