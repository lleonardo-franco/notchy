import AppKit
import SwiftUI

enum CodingAgent: String, CaseIterable, Identifiable {
    case claude
    case codex
    case gemini
    case copilot
    case cursor

    var id: String { rawValue }

    init(key: String?) {
        self = CodingAgent(rawValue: key ?? "") ?? .claude
    }

    var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex CLI"
        case .gemini: return "Gemini CLI"
        case .copilot: return "GitHub Copilot CLI"
        case .cursor: return "Cursor"
        }
    }

    var badge: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .copilot: return "Copilot"
        case .cursor: return "Cursor"
        }
    }

    var color: Color {
        switch self {
        case .claude: return .claude
        case .codex: return Color(red: 0.62, green: 0.66, blue: 0.72)
        case .gemini: return Color(red: 0.42, green: 0.6, blue: 1)
        case .copilot: return Color(red: 0.7, green: 0.5, blue: 1)
        case .cursor: return Color(red: 0.85, green: 0.85, blue: 0.85)
        }
    }

    var binaries: [String] {
        switch self {
        case .claude: return ["claude", "@anthropic-ai/claude-code"]
        case .codex: return ["codex", "@openai/codex"]
        case .gemini: return ["gemini", "@google/gemini-cli"]
        case .copilot: return ["copilot", "@github/copilot"]
        case .cursor: return ["cursor-agent"]
        }
    }

    var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch self {
        case .claude: return home.appendingPathComponent(".claude/settings.json")
        case .codex: return home.appendingPathComponent(".codex/hooks.json")
        case .gemini: return home.appendingPathComponent(".gemini/settings.json")
        case .copilot:
            let base = ProcessInfo.processInfo.environment["COPILOT_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".copilot")
            return base.appendingPathComponent("hooks/notchy.json")
        case .cursor: return home.appendingPathComponent(".cursor/hooks.json")
        }
    }

    var canApprove: Bool {
        switch self {
        case .claude, .copilot, .cursor: return true
        case .codex, .gemini: return false
        }
    }

    var isConnected: Bool {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return false }
        return text.contains("notchy-hook.py")
    }

    static var connectedSummary: String {
        let names = allCases.filter { $0 != .claude && $0.isConnected }.map(\.rawValue)
        return names.isEmpty ? "none" : names.joined(separator: ", ")
    }

    static func matches(_ args: String) -> Bool {
        args.split(separator: " ").prefix(2).contains { token in
            let name = (String(token) as NSString).lastPathComponent
            return allCases.contains { agent in
                agent.binaries.contains { binary in
                    binary.hasPrefix("@") ? token.contains(binary) : name == binary
                }
            }
        }
    }
}

enum AgentInstaller {
    static func run(_ arguments: [String]) -> Bool {
        guard let script = HooksInstaller.bundledInstaller else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func set(_ agent: CodingAgent, enabled: Bool, approvals: Bool = false) -> Bool {
        guard agent != .claude else { return enabled ? HooksInstaller.install() : false }
        var arguments = ["--agents", enabled ? "enable" : "disable", agent.rawValue]
        if enabled, approvals {
            arguments.append("--approvals")
        }
        return run(arguments)
    }

    static var cursorApprovals: Bool {
        let url = ClaudeService.root.appendingPathComponent("agents.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cursor = object["cursor"] as? [String: Any] else { return false }
        return cursor["approvals"] as? Bool ?? false
    }
}

struct PermissionRule: Codable, Identifiable, Equatable {
    var agent: String
    var cwd: String
    var tool: String
    var command: String?
    var createdAt: Double?

    var id: String { [agent, cwd, tool, command ?? ""].joined(separator: "\u{1F}") }

    var project: String { URL(fileURLWithPath: cwd).lastPathComponent }

    var summary: String {
        if tool == "Bash", let command, !command.isEmpty { return "$ \(command)" }
        return tool
    }
}

struct TaskProgress: Decodable, Equatable {
    var done: Int
    var total: Int
}

struct TurnSummary: Decodable, Equatable {
    var files: Int
    var commands: Int
    var added: Int
    var removed: Int

    var text: String {
        var parts: [String] = []
        if files > 0 {
            parts.append(files == 1 ? String(localized: "1 arquivo") : String(localized: "\(files) arquivos"))
        }
        if added > 0 || removed > 0 {
            parts.append("+\(added) −\(removed)")
        }
        if commands > 0 {
            parts.append(commands == 1 ? String(localized: "1 comando") : String(localized: "\(commands) comandos"))
        }
        return parts.joined(separator: " · ")
    }
}

extension UsageWindow {
    func exhaustion(length: TimeInterval, now: Date = Date()) -> Date? {
        guard resetsAt > 0, usedPercentage > 0, usedPercentage < 100 else { return nil }
        let reset = resetDate
        let elapsed = length - reset.timeIntervalSince(now)
        guard elapsed >= 600, elapsed <= length else { return nil }
        let rate = usedPercentage / elapsed
        let finish = now.addingTimeInterval((100 - usedPercentage) / rate)
        return finish < reset ? finish : nil
    }
}

struct AgentBadge: View {
    let agent: CodingAgent

    var body: some View {
        Text(agent.badge)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(agent.color)
            .padding(.horizontal, 5)
            .frame(height: 15)
            .background(Capsule().fill(agent.color.opacity(0.16)))
            .fixedSize()
    }
}

struct ModeBadge: View {
    let mode: String

    var body: some View {
        if let style {
            Text(style.title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(style.color)
                .padding(.horizontal, 5)
                .frame(height: 15)
                .background(Capsule().fill(style.color.opacity(0.16)))
                .fixedSize()
                .help(style.help)
        }
    }

    private var style: (title: String, color: Color, help: String)? {
        switch mode {
        case "plan":
            return (String(localized: "plano"), Color(red: 0.4, green: 0.65, blue: 1), String(localized: "Modo de planejamento: o agente só planeja, sem alterar nada"))
        case "acceptEdits":
            return (String(localized: "edições auto"), .orange, String(localized: "Aceita edições de arquivo sem perguntar"))
        case "bypassPermissions", "yolo", "dangerously-skip-permissions":
            return (String(localized: "sem permissões"), .red, String(localized: "Roda tudo sem pedir permissão"))
        default:
            return nil
        }
    }
}
