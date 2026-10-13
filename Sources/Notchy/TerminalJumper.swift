import AppKit

struct ProcessRow {
    let pid: Int32
    let ppid: Int32
    let tty: String?
    let args: String

    var isClaude: Bool {
        args.split(separator: " ").prefix(2).contains { token in
            (String(token) as NSString).lastPathComponent == "claude" || token.contains("@anthropic-ai/claude-code")
        }
    }
}

enum ProcessTable {
    static func snapshot() -> [Int32: ProcessRow] {
        guard let output = run("/bin/ps", ["-axo", "pid=,ppid=,tty=,args="]) else { return [:] }
        var rows: [Int32: ProcessRow] = [:]
        for line in output.split(separator: "\n") {
            let scanner = Scanner(string: String(line))
            scanner.charactersToBeSkipped = .whitespaces
            guard let pid = scanner.scanInt32(),
                  let ppid = scanner.scanInt32(),
                  let tty = scanner.scanUpToCharacters(from: .whitespaces) else { continue }
            let args = String(scanner.string[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            let device = ["??", "?", "-"].contains(tty) ? nil : (tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)")
            rows[pid] = ProcessRow(pid: pid, ppid: ppid, tty: device, args: args)
        }
        return rows
    }

    static func workingDirectories(of pids: [Int32]) -> [Int32: String] {
        guard !pids.isEmpty,
              let output = run("/usr/sbin/lsof", ["-a", "-d", "cwd", "-Fn", "-p", pids.map(String.init).joined(separator: ",")]) else { return [:] }
        var result: [Int32: String] = [:]
        var current: Int32?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                current = Int32(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = current {
                result[pid] = String(line.dropFirst())
            }
        }
        return result
    }

    private static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

enum TerminalJumper {
    private static let queue = DispatchQueue(label: "notchy.jump")

    private static let editors: Set<String> = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf",
        "dev.zed.Zed"
    ]

    private static let termPrograms: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "vscode": "com.microsoft.VSCode",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "ghostty": "com.mitchellh.ghostty",
        "WezTerm": "com.github.wez.wezterm"
    ]

    private static let fallbacks = ["com.apple.Terminal", "com.googlecode.iterm2"]

    static func jump(to session: ClaudeSession) {
        queue.async {
            let target = resolve(session)
            perform(target, session: session)
        }
    }

    private struct Target {
        var tty: String?
        var bundleID: String?
    }

    private static func resolve(_ session: ClaudeSession) -> Target {
        let table = ProcessTable.snapshot()
        var pid = session.claudePid.flatMap { table[$0]?.isClaude == true ? $0 : nil }

        if pid == nil, let tty = session.tty {
            pid = table.values.first { $0.isClaude && $0.tty == tty }?.pid
        }

        if pid == nil {
            let candidates = table.values.filter(\.isClaude).map(\.pid)
            let directories = ProcessTable.workingDirectories(of: candidates)
            let wanted = URL(fileURLWithPath: session.cwd).standardizedFileURL.path
            pid = candidates.first { candidate in
                guard let directory = directories[candidate] else { return false }
                return URL(fileURLWithPath: directory).standardizedFileURL.path == wanted
            }
        }

        var target = Target(tty: session.tty)
        if let pid {
            target.tty = table[pid]?.tty ?? session.tty
            target.bundleID = owningApp(of: pid, in: table)
        }
        if target.bundleID == nil {
            target.bundleID = session.app ?? session.termProgram.flatMap { termPrograms[$0] }
        }
        return target
    }

    private static func owningApp(of pid: Int32, in table: [Int32: ProcessRow]) -> String? {
        var current: Int32? = pid
        var hops = 0
        while let value = current, value > 1, hops < 20 {
            if let app = NSRunningApplication(processIdentifier: value),
               let bundleID = app.bundleIdentifier,
               app.activationPolicy == .regular {
                return bundleID
            }
            current = table[value]?.ppid
            hops += 1
        }
        return nil
    }

    private static func perform(_ target: Target, session: ClaudeSession) {
        if let tty = target.tty {
            let order = target.bundleID.map { [$0] } ?? fallbacks.filter(isRunning)
            for bundleID in order {
                if let script = selectScript(for: bundleID, tty: tty), runSelect(script) {
                    return
                }
            }
        }

        guard let bundleID = target.bundleID ?? fallbacks.first(where: isRunning) else {
            DispatchQueue.main.async { NSSound.beep() }
            return
        }

        DispatchQueue.main.async {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSSound.beep()
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            if editors.contains(bundleID) {
                NSWorkspace.shared.open([URL(fileURLWithPath: session.cwd)], withApplicationAt: appURL, configuration: configuration)
            } else {
                NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            }
        }
    }

    private static func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private static func runSelect(_ source: String) -> Bool {
        var found = false
        AppleScript.queue.sync {
            found = AppleScript.run(source)?.booleanValue ?? false
        }
        return found
    }

    private static func selectScript(for bundleID: String, tty: String) -> String? {
        switch bundleID {
        case "com.apple.Terminal":
            return """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected tab of w to t
                            set index of w to 1
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """
        case "com.googlecode.iterm2":
            return """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(tty)" then
                                select w
                                select t
                                select s
                                activate
                                return true
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            return false
            """
        default:
            return nil
        }
    }
}
