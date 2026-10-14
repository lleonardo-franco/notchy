import contextlib
import importlib.util
import io
import json
import os
import tempfile
import threading
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = importlib.util.spec_from_file_location("notchy_hook", os.path.join(HERE, "..", "notchy-hook.py"))
hook = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(hook)


class HookTestCase(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        root = self.folder.name
        hook.ROOT = root
        hook.SESSIONS = os.path.join(root, "sessions")
        hook.APPROVALS = os.path.join(root, "approvals")
        hook.RULES = os.path.join(root, "rules.json")
        hook.AGENTS_CONFIG = os.path.join(root, "agents.json")
        hook.APP_PID = os.path.join(root, "app.pid")
        hook.APPROVAL_TIMEOUT = 5
        hook.inspect_parents = lambda agent: ("/dev/ttys001", None)

    def tearDown(self):
        self.folder.cleanup()

    def run_hook(self, agent, name, payload):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            hook.handle(agent, name, payload)
        text = output.getvalue()
        return json.loads(text) if text else None

    def state(self, session):
        return hook.load(os.path.join(hook.SESSIONS, f"{session}.json"))

    def app_answers(self, response):
        with open(hook.APP_PID, "w") as handle:
            handle.write(str(os.getpid()))

        def answer():
            deadline = time.time() + 4
            while time.time() < deadline:
                if os.path.isdir(hook.APPROVALS):
                    for name in os.listdir(hook.APPROVALS):
                        if name.endswith(".json"):
                            request = hook.load(os.path.join(hook.APPROVALS, name))
                            self.requests.append(request)
                            hook.save(os.path.join(hook.APPROVALS, name.replace(".json", ".response")), response)
                            return
                time.sleep(0.05)

        self.requests = []
        thread = threading.Thread(target=answer)
        thread.start()
        return thread


class ClaudeTests(HookTestCase):
    def test_turn_summary_and_tasks(self):
        base = {"session_id": "s1", "cwd": "/work/app"}
        self.run_hook("claude", "UserPromptSubmit", {**base, "prompt": "fix it", "permission_mode": "plan"})
        self.run_hook("claude", "PostToolUse", {**base, "tool_name": "Edit", "tool_input": {"file_path": "/work/app/a.swift", "old_string": "a\nb", "new_string": "a\nb\nc"}})
        self.run_hook("claude", "PostToolUse", {**base, "tool_name": "Write", "tool_input": {"file_path": "/work/app/b.swift", "content": "x\ny"}})
        self.run_hook("claude", "PostToolUse", {**base, "tool_name": "Bash", "tool_input": {"command": "swift test"}})
        self.run_hook("claude", "PostToolUse", {**base, "tool_name": "TodoWrite", "tool_input": {"todos": [{"status": "completed"}, {"status": "pending"}, {"status": "in_progress"}]}})
        self.run_hook("claude", "SubagentStart", base)
        self.run_hook("claude", "SubagentStart", base)
        self.run_hook("claude", "SubagentStop", base)
        state = self.state("s1")
        self.assertEqual(state["tasks"], {"done": 1, "total": 3})
        self.assertEqual(state["subagents"], 1)
        self.assertEqual(state["mode"], "plan")
        self.run_hook("claude", "Stop", base)
        state = self.state("s1")
        self.assertEqual(state["status"], "done")
        self.assertEqual(state["summary"], {"files": 2, "commands": 1, "added": 5, "removed": 2})
        self.assertNotIn("turn", state)

    def test_task_events(self):
        base = {"session_id": "s2", "cwd": "/work"}
        for _ in range(3):
            self.run_hook("claude", "TaskCreated", base)
        self.run_hook("claude", "TaskCompleted", base)
        self.assertEqual(self.state("s2")["tasks"], {"done": 1, "total": 3})

    def test_failure_and_compaction(self):
        base = {"session_id": "s3", "cwd": "/work"}
        self.run_hook("claude", "UserPromptSubmit", {**base, "prompt": "go"})
        self.run_hook("claude", "PreCompact", base)
        self.assertEqual(self.state("s3")["detail"], "Compactando o contexto…")
        self.run_hook("claude", "PostCompact", base)
        self.assertIn("compactedAt", self.state("s3"))
        self.run_hook("claude", "StopFailure", {**base, "error": "rate_limit"})
        state = self.state("s3")
        self.assertEqual(state["status"], "failed")
        self.assertEqual(state["error"], "rate_limit")

    def test_quota_resume_notification(self):
        base = {"session_id": "s4", "cwd": "/work"}
        self.run_hook("claude", "Notification", {**base, "notification_type": "quota_auto_resume_fired", "message": "resumed"})
        self.assertEqual(self.state("s4")["status"], "working")

    def test_permission_allow_with_edit_and_remember(self):
        base = {"session_id": "s5", "cwd": "/work/api"}
        payload = {**base, "tool_name": "Bash", "tool_input": {"command": "rm -rf build", "description": "clean"}}
        thread = self.app_answers({"behavior": "allow", "command": "rm -rf build/tmp", "remember": True})
        output = self.run_hook("claude", "PermissionRequest", payload)
        thread.join()
        self.assertTrue(self.requests[0]["canEdit"])
        self.assertEqual(self.requests[0]["agent"], "claude")
        decision = output["hookSpecificOutput"]["decision"]
        self.assertEqual(decision["behavior"], "allow")
        self.assertEqual(decision["updatedInput"], {"command": "rm -rf build/tmp", "description": "clean"})
        rules = hook.load_rules()
        self.assertEqual(rules[0]["command"], "rm -rf build/tmp")
        again = self.run_hook("claude", "PermissionRequest", {**base, "tool_name": "Bash", "tool_input": {"command": "rm -rf build/tmp"}})
        self.assertEqual(again["hookSpecificOutput"]["decision"], {"behavior": "allow"})

    def test_permission_deny(self):
        thread = self.app_answers({"behavior": "deny"})
        output = self.run_hook("claude", "PermissionRequest", {"session_id": "s6", "cwd": "/w", "tool_name": "WebFetch", "tool_input": {"url": "https://example.com"}})
        thread.join()
        self.assertEqual(output["hookSpecificOutput"]["decision"]["behavior"], "deny")
        self.assertEqual(self.state("s6")["detail"], "Negado pelo notch")

    def test_no_app_means_no_decision(self):
        output = self.run_hook("claude", "PermissionRequest", {"session_id": "s7", "cwd": "/w", "tool_name": "Bash", "tool_input": {"command": "ls"}})
        self.assertIsNone(output)


class AgentTests(HookTestCase):
    def test_codex_shell_command_list(self):
        base = {"session_id": "abc", "cwd": "/work"}
        self.run_hook("codex", "PreToolUse", {**base, "tool_name": "shell", "tool_input": {"command": ["bash", "-lc", "npm test"]}})
        state = self.state("codex-abc")
        self.assertEqual(state["detail"], "$ npm test")
        self.assertEqual(state["agent"], "codex")
        self.run_hook("codex", "Stop", base)
        self.assertEqual(self.state("codex-abc")["status"], "done")

    def test_gemini_tools_and_turns(self):
        base = {"session_id": "g1", "cwd": "/work"}
        self.run_hook("gemini", "BeforeAgent", {**base, "prompt": "refactor"})
        self.run_hook("gemini", "AfterTool", {**base, "tool_name": "replace", "tool_input": {"file_path": "/work/a.py", "old_string": "x", "new_string": "y\nz"}})
        self.run_hook("gemini", "Notification", {**base, "notification_type": "ToolPermission", "message": "ok?", "details": {"tool_name": "run_shell_command", "tool_input": {"command": "make"}}})
        self.assertEqual(self.state("gemini-g1")["detail"], "Permissão · $ make")
        self.run_hook("gemini", "AfterAgent", base)
        state = self.state("gemini-g1")
        self.assertEqual(state["status"], "done")
        self.assertEqual(state["summary"]["added"], 2)

    def test_copilot_permission(self):
        thread = self.app_answers({"behavior": "allow"})
        output = self.run_hook("copilot", "permissionRequest", {"sessionId": "c1", "cwd": "/w", "toolName": "bash", "toolArgs": json.dumps({"command": "git status"})})
        thread.join()
        self.assertEqual(output, {"behavior": "allow"})
        self.assertFalse(self.requests[0]["canEdit"])
        self.assertEqual(self.requests[0]["command"], "git status")

    def test_copilot_error(self):
        base = {"sessionId": "c2", "cwd": "/w"}
        self.run_hook("copilot", "errorOccurred", {**base, "recoverable": False, "error": {"message": "boom"}})
        self.assertEqual(self.state("copilot-c2")["status"], "failed")

    def test_cursor_tracks_without_approvals(self):
        base = {"conversation_id": "k1", "workspace_roots": ["/work/site"]}
        output = self.run_hook("cursor", "beforeShellExecution", {**base, "command": "npm run dev", "cwd": "/work/site"})
        self.assertIsNone(output)
        self.assertEqual(self.state("cursor-k1")["detail"], "$ npm run dev")
        self.run_hook("cursor", "stop", {**base, "status": "error"})
        self.assertEqual(self.state("cursor-k1")["status"], "failed")

    def test_cursor_approvals(self):
        hook.save(hook.AGENTS_CONFIG, {"cursor": {"approvals": True}})
        thread = self.app_answers({"behavior": "deny"})
        output = self.run_hook("cursor", "beforeShellExecution", {"conversation_id": "k2", "command": "rm -rf /", "cwd": "/w"})
        thread.join()
        self.assertEqual(output["permission"], "deny")

    def test_cursor_falls_back_to_ask(self):
        hook.save(hook.AGENTS_CONFIG, {"cursor": {"approvals": True}})
        output = self.run_hook("cursor", "beforeShellExecution", {"conversation_id": "k3", "command": "ls", "cwd": "/w"})
        self.assertEqual(output, {"permission": "ask"})

    def test_session_end_removes_state(self):
        base = {"session_id": "e1", "cwd": "/w"}
        self.run_hook("gemini", "SessionStart", base)
        self.assertTrue(self.state("gemini-e1"))
        self.run_hook("gemini", "SessionEnd", base)
        self.assertEqual(self.state("gemini-e1"), {})


if __name__ == "__main__":
    unittest.main()
