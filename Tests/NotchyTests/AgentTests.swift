import Foundation
import Testing
@testable import Notchy

struct AgentTests {
    @Test func decodesExtendedSession() throws {
        let json = """
        {"id":"codex-1","cwd":"/work/api","status":"failed","updatedAt":\(Date().timeIntervalSince1970),
         "agent":"codex","mode":"plan","tasks":{"done":2,"total":5},"subagents":1,
         "summary":{"files":3,"commands":2,"added":40,"removed":7},"error":"rate limit"}
        """
        let session = try JSONDecoder().decode(ClaudeSession.self, from: Data(json.utf8))
        #expect(session.codingAgent == .codex)
        #expect(session.status == .failed)
        #expect(session.tasks == TaskProgress(done: 2, total: 5))
        #expect(session.summary?.added == 40)
        #expect(session.subtitle.contains("rate limit"))
        #expect(session.rank == 1)
    }

    @Test func decodesLegacySession() throws {
        let json = """
        {"id":"s","cwd":"/w","status":"done","updatedAt":\(Date().timeIntervalSince1970),"prompt":"fix"}
        """
        let session = try JSONDecoder().decode(ClaudeSession.self, from: Data(json.utf8))
        #expect(session.codingAgent == .claude)
        #expect(session.summary == nil)
        #expect(session.subtitle.hasSuffix("fix"))
    }

    @Test func summaryText() {
        let summary = TurnSummary(files: 2, commands: 1, added: 12, removed: 3)
        #expect(summary.text.contains("+12 −3"))
        #expect(TurnSummary(files: 0, commands: 0, added: 0, removed: 0).text.isEmpty)
    }

    @Test func forecastsExhaustion() {
        let now = Date()
        let window = UsageWindow(usedPercentage: 60, resetsAt: now.addingTimeInterval(3 * 3600).timeIntervalSince1970)
        let date = window.exhaustion(length: 5 * 3600, now: now)
        #expect(date != nil)
        if let date {
            #expect(abs(date.timeIntervalSince(now) - 4800) < 1)
        }
    }

    @Test func noForecastWhenItLasts() {
        let now = Date()
        let window = UsageWindow(usedPercentage: 10, resetsAt: now.addingTimeInterval(3600).timeIntervalSince1970)
        #expect(window.exhaustion(length: 5 * 3600, now: now) == nil)
        let fresh = UsageWindow(usedPercentage: 5, resetsAt: now.addingTimeInterval(5 * 3600 - 60).timeIntervalSince1970)
        #expect(fresh.exhaustion(length: 5 * 3600, now: now) == nil)
    }

    @Test func recognizesAgentProcesses() {
        #expect(CodingAgent.matches("/opt/homebrew/bin/codex"))
        #expect(CodingAgent.matches("node /usr/local/lib/node_modules/@google/gemini-cli/dist/index.js"))
        #expect(CodingAgent.matches("claude --resume"))
        #expect(!CodingAgent.matches("/bin/zsh -l"))
    }

    @Test func decodesApprovalWithAgent() throws {
        let json = """
        {"id":"a","sessionId":"s","pid":1,"cwd":"/w","tool":"Bash","summary":"$ ls","body":"ls","createdAt":0,
         "agent":"copilot","command":"ls","canEdit":false}
        """
        let request = try JSONDecoder().decode(ApprovalRequest.self, from: Data(json.utf8))
        #expect(request.codingAgent == .copilot)
        #expect(request.canEdit == false)
    }
}
