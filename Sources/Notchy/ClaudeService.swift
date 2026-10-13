import Foundation
import Observation

struct ClaudeSession: Identifiable, Decodable, Equatable {
    enum Status: String, Decodable {
        case idle
        case working
        case waiting
        case done
    }

    let id: String
    let cwd: String
    let status: Status
    let detail: String?
    let prompt: String?
    let promptAt: Double?
    let tty: String?
    let claudePid: Int32?
    let app: String?
    let termProgram: String?
    let updatedAt: Double

    var project: String { URL(fileURLWithPath: cwd).lastPathComponent }
    var updated: Date { Date(timeIntervalSince1970: updatedAt) }
    var promptDate: Date { Date(timeIntervalSince1970: promptAt ?? updatedAt) }

    var effectiveStatus: Status {
        let age = Date().timeIntervalSince(updated)
        switch status {
        case .working where age > 900: return .idle
        case .done where age > 600: return .idle
        default: return status
        }
    }

    var subtitle: String {
        switch effectiveStatus {
        case .working: return detail ?? "Trabalhando…"
        case .waiting: return detail ?? "Esperando você"
        case .done: return prompt.map { "Pronto · \($0)" } ?? "Pronto"
        case .idle: return prompt ?? "Ocioso"
        }
    }

    var rank: Int {
        switch effectiveStatus {
        case .waiting: return 0
        case .working: return 1
        case .done: return 2
        case .idle: return 3
        }
    }
}

struct ApprovalRequest: Identifiable, Decodable, Equatable {
    let id: String
    let sessionId: String
    let pid: Int32
    let cwd: String
    let tool: String
    let summary: String
    let body: String
    let createdAt: Double

    var project: String { URL(fileURLWithPath: cwd).lastPathComponent }
    var isAlive: Bool { kill(pid, 0) == 0 || errno == EPERM }
}

struct UsageWindow: Decodable, Equatable {
    let usedPercentage: Double
    let resetsAt: Double

    var resetDate: Date { Date(timeIntervalSince1970: resetsAt) }
    var isActive: Bool { resetsAt == 0 || resetDate > Date() }

    var resetText: String {
        let seconds = Int(resetDate.timeIntervalSinceNow)
        guard resetsAt > 0, seconds > 0 else { return "—" }
        if seconds >= 86400 { return "\(seconds / 86400)d\(seconds % 86400 / 3600)h" }
        if seconds >= 3600 { return "\(seconds / 3600)h\(String(format: "%02d", seconds % 3600 / 60))" }
        return "\(max(seconds / 60, 1))m"
    }
}

struct Usage: Equatable {
    var fiveHour: UsageWindow?
    var sevenDay: UsageWindow?

    var isEmpty: Bool { fiveHour == nil && sevenDay == nil }
}

private struct StatusRecord: Decodable {
    let sessionId: String
    let updatedAt: Double
    let context: Double?
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
}

enum ClaudeEvent {
    case needsYou(ClaudeSession)
    case finished(ClaudeSession)
    case approval(ApprovalRequest)
    case limit(label: String, percent: Int)
}

@MainActor
@Observable
final class ClaudeService {
    nonisolated static let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".notchy", isDirectory: true)
    nonisolated static let sessionsDirectory = root.appendingPathComponent("sessions", isDirectory: true)
    nonisolated static let approvalsDirectory = root.appendingPathComponent("approvals", isDirectory: true)
    nonisolated static let statusDirectory = root.appendingPathComponent("statusline", isDirectory: true)
    nonisolated static let pidFile = root.appendingPathComponent("app.pid")

    private(set) var sessions: [ClaudeSession] = []
    private(set) var approvals: [ApprovalRequest] = []
    private(set) var usage = Usage()
    private(set) var contexts: [String: Double] = [:]

    @ObservationIgnored var onEvent: (@MainActor (ClaudeEvent) -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var watchers: [DispatchSourceFileSystemObject] = []
    @ObservationIgnored private var lastStatus: [String: ClaudeSession.Status] = [:]
    @ObservationIgnored private var knownApprovals: Set<String> = []
    @ObservationIgnored private var answered: Set<String> = []
    @ObservationIgnored private var warned: Set<String> = []
    @ObservationIgnored private var primed = false

    func start() {
        let manager = FileManager.default
        for directory in [Self.sessionsDirectory, Self.approvalsDirectory, Self.statusDirectory] {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try? "\(getpid())".write(to: Self.pidFile, atomically: true, encoding: .utf8)

        refresh()
        watchers = [Self.sessionsDirectory, Self.approvalsDirectory, Self.statusDirectory].compactMap(makeWatcher)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.refresh()
            }
        }
    }

    func stop() {
        try? FileManager.default.removeItem(at: Self.pidFile)
    }

    func respond(to request: ApprovalRequest, with behavior: String) {
        answered.insert(request.id)
        approvals.removeAll { $0.id == request.id }
        let url = Self.approvalsDirectory.appendingPathComponent("\(request.id).response")
        if let data = try? JSONSerialization.data(withJSONObject: ["behavior": behavior]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func session(for request: ApprovalRequest) -> ClaudeSession? {
        sessions.first { $0.id == request.sessionId }
    }

    private func makeWatcher(_ url: URL) -> DispatchSourceFileSystemObject? {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        return source
    }

    private func refresh() {
        loadApprovals()
        loadSessions()
        loadUsage()
        detectEvents()
        primed = true
    }

    private func files(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    }

    private func age(of url: URL) -> TimeInterval {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        return Date().timeIntervalSince(date)
    }

    private func loadSessions() {
        let decoder = JSONDecoder()
        let now = Date()
        var found: [ClaudeSession] = []

        for file in files(in: Self.sessionsDirectory) where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(ClaudeSession.self, from: data) else { continue }
            let age = now.timeIntervalSince(session.updated)
            if age > 12 * 3600 {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if age <= 3 * 3600 {
                found.append(session)
            }
        }

        found.sort { lhs, rhs in
            lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.updatedAt > rhs.updatedAt
        }
        if found != sessions {
            sessions = found
        }
    }

    private func loadApprovals() {
        let decoder = JSONDecoder()
        var found: [ApprovalRequest] = []
        var present: Set<String> = []

        for file in files(in: Self.approvalsDirectory) {
            if file.pathExtension == "response" {
                if age(of: file) > 600 {
                    try? FileManager.default.removeItem(at: file)
                }
                continue
            }
            guard file.pathExtension == "json",
                  let data = try? Data(contentsOf: file),
                  let request = try? decoder.decode(ApprovalRequest.self, from: data) else { continue }
            present.insert(request.id)
            guard request.isAlive else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if !answered.contains(request.id) {
                found.append(request)
            }
        }

        answered.formIntersection(present)
        found.sort { $0.createdAt < $1.createdAt }
        if found != approvals {
            approvals = found
        }
    }

    private func loadUsage() {
        let decoder = JSONDecoder()
        var records: [StatusRecord] = []

        for file in files(in: Self.statusDirectory) where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let record = try? decoder.decode(StatusRecord.self, from: data) else { continue }
            if Date().timeIntervalSince1970 - record.updatedAt > 12 * 3600 {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            records.append(record)
        }

        var nextContexts: [String: Double] = [:]
        for record in records {
            if let context = record.context {
                nextContexts[record.sessionId] = context
            }
        }
        if nextContexts != contexts {
            contexts = nextContexts
        }

        let latest = records
            .filter { $0.fiveHour != nil || $0.sevenDay != nil }
            .max { $0.updatedAt < $1.updatedAt }
        let next = Usage(
            fiveHour: latest?.fiveHour.flatMap { $0.isActive ? $0 : nil },
            sevenDay: latest?.sevenDay.flatMap { $0.isActive ? $0 : nil }
        )
        if next != usage {
            usage = next
        }
    }

    private func detectEvents() {
        if primed {
            for request in approvals where !knownApprovals.contains(request.id) {
                onEvent?(.approval(request))
            }

            let approvalSessions = Set(approvals.map(\.sessionId))
            for session in sessions {
                let previous = lastStatus[session.id]
                guard previous != session.status else { continue }
                if session.status == .waiting, !approvalSessions.contains(session.id) {
                    onEvent?(.needsYou(session))
                } else if session.status == .done, previous == .working {
                    onEvent?(.finished(session))
                }
            }
        }

        checkLimit("de 5h", usage.fiveHour)
        checkLimit("semanal", usage.sevenDay)

        knownApprovals = Set(approvals.map(\.id))
        lastStatus = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.status) })
    }

    private func checkLimit(_ label: String, _ window: UsageWindow?) {
        guard let window else { return }
        let crossed = [95, 80].filter { threshold in
            window.usedPercentage >= Double(threshold)
                && warned.insert("\(label)-\(threshold)-\(Int(window.resetsAt))").inserted
        }
        if primed, !crossed.isEmpty {
            onEvent?(.limit(label: label, percent: Int(window.usedPercentage.rounded())))
        }
    }
}
