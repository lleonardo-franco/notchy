#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = os.path.join(os.path.expanduser("~"), ".notchy")
SESSIONS = os.path.join(ROOT, "sessions")
APPROVALS = os.path.join(ROOT, "approvals")
RULES = os.path.join(ROOT, "rules.json")
AGENTS_CONFIG = os.path.join(ROOT, "agents.json")
APP_PID = os.path.join(ROOT, "app.pid")
APPROVAL_TIMEOUT = float(os.environ.get("NOTCHY_APPROVAL_TIMEOUT", "120"))

EVENTS = {
    "claude": {
        "SessionStart": "start",
        "SessionEnd": "end",
        "UserPromptSubmit": "prompt",
        "PreToolUse": "pre_tool",
        "PostToolUse": "post_tool",
        "PostToolUseFailure": "tool_failure",
        "PermissionRequest": "permission",
        "Notification": "notification",
        "Stop": "stop",
        "StopFailure": "failure",
        "SubagentStart": "subagent_start",
        "SubagentStop": "subagent_stop",
        "TaskCreated": "task_created",
        "TaskCompleted": "task_completed",
        "PreCompact": "compact",
        "PostCompact": "compacted",
    },
    "codex": {
        "SessionStart": "start",
        "UserPromptSubmit": "prompt",
        "PreToolUse": "pre_tool",
        "PostToolUse": "post_tool",
        "Stop": "stop",
    },
    "gemini": {
        "SessionStart": "start",
        "SessionEnd": "end",
        "BeforeAgent": "prompt",
        "AfterAgent": "stop",
        "BeforeTool": "pre_tool",
        "AfterTool": "post_tool",
        "Notification": "notification",
        "PreCompress": "compact",
    },
    "copilot": {
        "sessionStart": "start",
        "sessionEnd": "end",
        "userPromptSubmitted": "prompt",
        "preToolUse": "pre_tool",
        "postToolUse": "post_tool",
        "postToolUseFailure": "tool_failure",
        "permissionRequest": "permission",
        "notification": "notification",
        "agentStop": "stop",
        "errorOccurred": "failure",
        "subagentStart": "subagent_start",
        "subagentStop": "subagent_stop",
        "preCompact": "compact",
    },
    "cursor": {
        "sessionStart": "start",
        "sessionEnd": "end",
        "beforeSubmitPrompt": "prompt",
        "beforeShellExecution": "permission",
        "beforeMCPExecution": "permission",
        "afterShellExecution": "post_tool",
        "afterMCPExecution": "post_tool",
        "afterFileEdit": "post_tool",
        "stop": "stop",
        "subagentStart": "subagent_start",
        "subagentStop": "subagent_stop",
        "preCompact": "compact",
    },
}

BINARIES = {
    "claude": ("claude", "@anthropic-ai/claude-code"),
    "codex": ("codex", "@openai/codex"),
    "gemini": ("gemini", "@google/gemini-cli"),
    "copilot": ("copilot", "@github/copilot"),
    "cursor": ("cursor-agent",),
}

SHELL_TOOLS = {"bash", "shell", "run_shell_command", "exec_command", "local_shell", "terminal", "run_in_terminal"}
TOOL_NAMES = {
    "write_file": "Write",
    "create": "Write",
    "replace": "Edit",
    "edit": "Edit",
    "edit_file": "Edit",
    "str_replace": "Edit",
    "read_file": "Read",
    "view": "Read",
    "glob": "Glob",
    "search_file_content": "Grep",
    "grep": "Grep",
    "web_fetch": "WebFetch",
    "google_web_search": "WebSearch",
    "write_todos": "TodoWrite",
}

VERBS = {
    "Read": "Lendo",
    "Write": "Escrevendo",
    "Edit": "Editando",
    "MultiEdit": "Editando",
    "NotebookEdit": "Editando",
}
EDIT_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")


def short(text, limit=70):
    text = " ".join(str(text or "").split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def clip(text, limit):
    text = str(text or "").strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def first(data, *keys):
    for key in keys:
        value = data.get(key)
        if value not in (None, ""):
            return value
    return None


def file_path(data):
    return data.get("file_path") or data.get("notebook_path") or data.get("path") or data.get("absolute_path") or ""


def relative(path, cwd):
    if path and cwd and path.startswith(cwd.rstrip("/") + "/"):
        return os.path.relpath(path, cwd)
    return path


def shell_command(value):
    if isinstance(value, list):
        parts = [str(part) for part in value]
        if len(parts) >= 3 and os.path.basename(parts[0]) in ("bash", "sh", "zsh") and parts[1] in ("-lc", "-c"):
            return parts[2]
        return " ".join(parts)
    return str(value or "")


def describe(tool, data):
    tool = tool or "Ferramenta"
    data = data if isinstance(data, dict) else {}
    if tool == "Bash":
        return f"$ {short(data.get('command'), 60)}"
    if tool in VERBS:
        return f"{VERBS[tool]} {os.path.basename(file_path(data))}"
    if tool in ("Grep", "Glob"):
        return f"Buscando {short(data.get('pattern'), 50)}"
    if tool == "WebFetch":
        return f"Abrindo {short(data.get('url'), 55)}"
    if tool == "WebSearch":
        return f"Pesquisando {short(data.get('query'), 50)}"
    if tool in ("Task", "Agent"):
        return f"Subagente: {short(data.get('description'), 50)}"
    if tool in ("TodoWrite", "TaskCreate", "TaskUpdate"):
        return "Atualizando tarefas"
    if tool.startswith("mcp__"):
        parts = tool.split("__")
        return f"{parts[1]} · {parts[-1]}" if len(parts) > 2 else tool
    return tool


def details(tool, data, cwd):
    data = data if isinstance(data, dict) else {}
    if tool == "Bash":
        return clip(data.get("command"), 400)
    if tool in EDIT_TOOLS:
        path = relative(file_path(data), cwd)
        snippet = data.get("new_string") or data.get("content") or data.get("new_source") or ""
        return clip(f"{path}\n{snippet}" if snippet else path, 400)
    if tool == "WebFetch":
        return clip(data.get("url"), 400)
    if tool == "WebSearch":
        return clip(data.get("query"), 400)
    return clip(json.dumps(data, ensure_ascii=False), 400)


def load(path, default=None):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {} if default is None else default


def save(path, data):
    folder = os.path.dirname(path)
    os.makedirs(folder, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=folder, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False)
    os.replace(tmp, path)


def remove(path):
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


def app_running():
    try:
        with open(APP_PID, encoding="utf-8") as handle:
            pid = int(handle.read().strip())
        os.kill(pid, 0)
        return True
    except PermissionError:
        return True
    except (OSError, ValueError):
        return False


def is_agent(args, agent):
    names = BINARIES.get(agent, ())
    for token in args.split()[:2]:
        if os.path.basename(token) in names or any("@" in name and name in token for name in names):
            return True
    return False


def alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except PermissionError:
        return True
    except (OSError, ValueError, TypeError):
        return False


def inspect_parents(agent):
    pid = os.getppid()
    tty = None
    owner = None
    for _ in range(10):
        try:
            out = subprocess.run(
                ["ps", "-o", "ppid=,tty=,args=", "-p", str(pid)],
                capture_output=True,
                text=True,
                timeout=1,
            ).stdout.strip()
        except Exception:
            break
        parts = out.split(None, 2)
        if len(parts) < 2:
            break
        parent, term = parts[0], parts[1]
        args = parts[2] if len(parts) > 2 else ""
        if tty is None and term not in ("??", "?", "-", ""):
            tty = term if term.startswith("/dev/") else f"/dev/{term}"
        if owner is None and is_agent(args, agent):
            owner = pid
        if tty and owner:
            break
        pid = int(parent)
        if pid <= 1:
            break
    return tty, owner


def parse_json(value):
    if isinstance(value, str):
        try:
            return json.loads(value)
        except ValueError:
            return {"value": value}
    return value if isinstance(value, dict) else {}


def canonical_tool(agent, name, payload):
    if agent == "cursor":
        if name in ("beforeShellExecution", "afterShellExecution"):
            return "Bash", {"command": payload.get("command") or ""}
        if name == "afterFileEdit":
            return "Edit", {"file_path": payload.get("file_path") or "", "edits": payload.get("edits") or []}
        tool = first(payload, "tool_name", "toolName") or "MCP"
        return f"mcp__{payload.get('server') or 'mcp'}__{tool}", parse_json(first(payload, "tool_input", "toolInput"))
    tool = first(payload, "tool_name", "toolName") or ""
    data = parse_json(first(payload, "tool_input", "toolArgs", "toolInput", "args"))
    if tool.lower() in SHELL_TOOLS:
        return "Bash", {**data, "command": shell_command(data.get("command") or data.get("cmd"))}
    mapped = TOOL_NAMES.get(tool) or TOOL_NAMES.get(tool.lower())
    if mapped:
        data = dict(data)
        if "file_path" not in data:
            data["file_path"] = file_path(data)
        if mapped == "Edit":
            data.setdefault("old_string", data.get("old_str") or "")
            data.setdefault("new_string", data.get("new_str") or "")
        if mapped == "Write":
            data.setdefault("content", data.get("file_text") or "")
        return mapped, data
    return tool, data


def lines(text):
    text = str(text or "")
    return text.count("\n") + 1 if text else 0


def count_edit(tool, data):
    if tool == "Write":
        return lines(data.get("content")), 0
    if tool == "Edit":
        edits = data.get("edits")
        if isinstance(edits, list) and edits:
            return (
                sum(lines(edit.get("new_string")) for edit in edits if isinstance(edit, dict)),
                sum(lines(edit.get("old_string")) for edit in edits if isinstance(edit, dict)),
            )
        return lines(data.get("new_string")), lines(data.get("old_string"))
    if tool == "MultiEdit":
        edits = data.get("edits") or []
        return (
            sum(lines(edit.get("new_string")) for edit in edits if isinstance(edit, dict)),
            sum(lines(edit.get("old_string")) for edit in edits if isinstance(edit, dict)),
        )
    if tool == "NotebookEdit":
        return lines(data.get("new_source")), 0
    return 0, 0


def session_key(agent, raw):
    raw = re.sub(r"[^A-Za-z0-9_.-]", "-", str(raw))
    return raw if agent == "claude" else f"{agent}-{raw}"


def is_idle_notice(payload):
    kind = first(payload, "notification_type", "notificationType") or ""
    message = payload.get("message", "")
    return kind == "idle_prompt" or "waiting for your input" in message


def agent_config(agent):
    return (load(AGENTS_CONFIG) or {}).get(agent) or {}


def load_rules():
    rules = load(RULES, [])
    return rules if isinstance(rules, list) else []


def rule_for(agent, cwd, tool, data):
    rule = {"agent": agent, "cwd": cwd, "tool": tool}
    if tool == "Bash":
        rule["command"] = str(data.get("command") or "")
    elif tool.startswith("mcp__"):
        rule["command"] = ""
    return rule


def matches(rule, candidate):
    return all(rule.get(key) == candidate.get(key) for key in ("agent", "cwd", "tool", "command"))


def remember(rule):
    rules = load_rules()
    if not any(matches(existing, rule) for existing in rules):
        rules.append({**rule, "createdAt": time.time()})
        save(RULES, rules)


def ask_notch(agent, session, cwd, tool, data):
    if not app_running():
        return None
    request_id = uuid.uuid4().hex
    request_path = os.path.join(APPROVALS, f"{request_id}.json")
    response_path = os.path.join(APPROVALS, f"{request_id}.response")
    save(request_path, {
        "id": request_id,
        "sessionId": session,
        "pid": os.getpid(),
        "cwd": cwd,
        "tool": tool,
        "summary": describe(tool, data),
        "body": details(tool, data, cwd),
        "createdAt": time.time(),
        "agent": agent,
        "command": data.get("command") if tool == "Bash" else None,
        "canEdit": agent == "claude" and tool == "Bash",
    })
    response = None
    deadline = time.time() + APPROVAL_TIMEOUT
    try:
        while time.time() < deadline:
            if os.path.exists(response_path):
                response = load(response_path)
                break
            if not app_running():
                break
            time.sleep(0.15)
    finally:
        remove(request_path)
        remove(response_path)
    return response


def permission_output(agent, behavior, data=None, command=None):
    message = "O usuário negou esta ação pelo Notchy."
    if agent == "claude":
        decision = {"behavior": behavior}
        if behavior == "deny":
            decision["message"] = message
        elif command is not None:
            decision["updatedInput"] = {**(data or {}), "command": command}
        return {"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}}
    if agent == "cursor":
        result = {"permission": behavior}
        if behavior == "deny":
            result.update(user_message=message, agent_message=message, userMessage=message, agentMessage=message)
        return result
    result = {"behavior": behavior}
    if behavior == "deny":
        result["message"] = message
    return result


def handle_permission(agent, name, path, state, session, cwd, tool, data):
    asks = agent != "cursor" or agent_config("cursor").get("approvals")
    candidate = rule_for(agent, cwd, tool, data)
    if any(matches(rule, candidate) for rule in load_rules()):
        state.update(status="working", detail=describe(tool, data), updatedAt=time.time())
        save(path, state)
        if asks:
            sys.stdout.write(json.dumps(permission_output(agent, "allow")))
        return
    if not asks:
        state.update(status="working", detail=describe(tool, data))
        save(path, state)
        return
    state.update(status="waiting", detail=f"Permissão · {describe(tool, data)}")
    save(path, state)
    response = ask_notch(agent, session, cwd, tool, data) or {}
    behavior = response.get("behavior")
    if behavior not in ("allow", "deny"):
        if agent == "cursor":
            sys.stdout.write(json.dumps({"permission": "ask"}))
        return
    edited = response.get("command")
    if behavior == "allow" and response.get("remember"):
        remember(rule_for(agent, cwd, tool, {**data, "command": edited} if edited else data))
    state = load(path) or state
    state.update(
        status="working",
        detail="Pensando…" if behavior == "allow" else "Negado pelo notch",
        updatedAt=time.time(),
    )
    save(path, state)
    command = edited if edited and tool == "Bash" and edited != data.get("command") else None
    sys.stdout.write(json.dumps(permission_output(agent, behavior, data, command)))


def track_tool(state, tool, data):
    turn = state.setdefault("turn", {"files": [], "commands": 0, "added": 0, "removed": 0})
    if tool == "Bash":
        turn["commands"] = turn.get("commands", 0) + 1
    elif tool in EDIT_TOOLS:
        path = file_path(data)
        if path and path not in turn["files"]:
            turn["files"] = (turn.get("files") or []) + [path]
        added, removed = count_edit(tool, data)
        turn["added"] = turn.get("added", 0) + added
        turn["removed"] = turn.get("removed", 0) + removed
    if tool == "TodoWrite":
        todos = data.get("todos")
        if isinstance(todos, list):
            done = sum(1 for todo in todos if isinstance(todo, dict) and todo.get("status") == "completed")
            state["tasks"] = {"done": done, "total": len(todos)}


def summarize(state):
    turn = state.pop("turn", None) or {}
    summary = {
        "files": len(turn.get("files") or []),
        "commands": turn.get("commands", 0),
        "added": turn.get("added", 0),
        "removed": turn.get("removed", 0),
    }
    state["summary"] = summary if any(summary.values()) else None


def failure_message(payload):
    error = payload.get("error")
    if isinstance(error, dict):
        error = error.get("message")
    return short(error or first(payload, "error_message", "message", "reason"), 70) or None


def notify(agent, state, payload):
    kind = str(first(payload, "notification_type", "notificationType") or "").lower()
    message = short(first(payload, "message", "title"), 70)
    if kind.startswith("quota_auto_resume"):
        if kind.endswith("fired"):
            state.update(status="working", detail="Cota renovada, retomando")
        return
    if kind in ("auth_success", "elicitation_complete", "elicitation_response", "agent_completed") or "complete" in kind:
        return
    if is_idle_notice(payload) or "idle" in kind:
        state.update(status="waiting", detail="Esperando sua resposta")
    elif kind.startswith("elicitation"):
        state.update(status="waiting", detail=message or "Pergunta para você")
    elif agent == "gemini" and kind == "toolpermission":
        tool, data = canonical_tool(agent, "", payload.get("details") or {})
        state.update(status="waiting", detail=f"Permissão · {describe(tool, data)}" if tool else message or "Precisa de você")
    elif agent in ("claude", "gemini") or "permission" in kind or "input" in kind:
        if state.get("status") != "waiting":
            state.update(status="waiting", detail=message or "Precisa de você")


def touch(state, agent, session, payload, cwd, fresh=False):
    now = time.time()
    state.update(id=session, agent=agent, cwd=cwd or state.get("cwd") or os.getcwd(), updatedAt=now)
    state.setdefault("startedAt", now)
    state.setdefault("status", "idle")
    mode = first(payload, "permission_mode", "permissionMode")
    if mode:
        state["mode"] = mode
    if fresh or not state.get("tty") or not alive(state.get("claudePid")):
        tty, owner = inspect_parents(agent)
        state["tty"] = tty or state.get("tty")
        state["claudePid"] = owner
    state["app"] = os.environ.get("__CFBundleIdentifier") or state.get("app")
    state["termProgram"] = os.environ.get("TERM_PROGRAM") or state.get("termProgram")


def handle(agent, name, payload):
    kind = EVENTS.get(agent, {}).get(name)
    raw = first(payload, "session_id", "sessionId", "conversation_id", "conversationId")
    if agent == "gemini":
        raw = raw or os.environ.get("GEMINI_SESSION_ID")
    if not kind or not raw:
        if agent == "cursor" and name in ("beforeShellExecution", "beforeMCPExecution") and agent_config("cursor").get("approvals"):
            sys.stdout.write(json.dumps({"permission": "ask"}))
        return
    session = session_key(agent, raw)
    path = os.path.join(SESSIONS, f"{session}.json")

    if kind == "end":
        remove(path)
        return

    roots = payload.get("workspace_roots") or []
    cwd = first(payload, "cwd") or (roots[0] if roots else None) or os.environ.get("GEMINI_CWD") or os.environ.get("CURSOR_PROJECT_DIR")
    state = load(path)
    if kind == "notification" and is_idle_notice(payload) and state.get("status") == "done":
        return

    touch(state, agent, session, payload, cwd, fresh=kind == "start")
    tool, data = canonical_tool(agent, name, payload)

    if kind == "permission":
        handle_permission(agent, name, path, state, session, state["cwd"], tool, data)
        return

    if kind == "start":
        state.update(status="idle", detail=None, tasks=None, subagents=0, summary=None, error=None)
    elif kind == "prompt":
        prompt = first(payload, "prompt", "initialPrompt")
        state.update(status="working", detail="Pensando…", prompt=short(prompt, 80), promptAt=time.time(), error=None, summary=None)
        state["turn"] = {"files": [], "commands": 0, "added": 0, "removed": 0}
    elif kind == "pre_tool":
        state.update(status="working", detail=describe(tool, data))
    elif kind == "post_tool":
        track_tool(state, tool, data)
        if agent == "cursor" and state.get("status") != "working":
            state["status"] = "working"
        state.update(detail="Pensando…")
    elif kind == "tool_failure":
        state.update(status="working", detail=f"Falhou · {describe(tool, data)}")
    elif kind == "notification":
        notify(agent, state, payload)
    elif kind == "stop":
        summarize(state)
        status = str(payload.get("status") or "").lower()
        if status == "error":
            state.update(status="failed", detail=None, error=failure_message(payload) or "Erro")
        elif status == "aborted":
            state.update(status="idle", detail=None)
        else:
            state.update(status="done", detail=None)
    elif kind == "failure":
        if payload.get("recoverable") is True:
            state.update(detail=f"Erro · {failure_message(payload) or ''}".rstrip(" ·"))
        else:
            summarize(state)
            state.update(status="failed", detail=None, error=failure_message(payload) or "Erro")
    elif kind == "subagent_start":
        state["subagents"] = max(int(state.get("subagents") or 0), 0) + 1
    elif kind == "subagent_stop":
        state["subagents"] = max(int(state.get("subagents") or 0) - 1, 0)
    elif kind == "task_created":
        tasks = state.get("tasks") or {"done": 0, "total": 0}
        tasks["total"] = tasks.get("total", 0) + 1
        state["tasks"] = tasks
    elif kind == "task_completed":
        tasks = state.get("tasks") or {"done": 0, "total": 0}
        tasks["done"] = min(tasks.get("done", 0) + 1, max(tasks.get("total", 0), tasks.get("done", 0) + 1))
        tasks["total"] = max(tasks.get("total", 0), tasks["done"])
        state["tasks"] = tasks
    elif kind == "compact":
        state.update(status="working", detail="Compactando o contexto…")
    elif kind == "compacted":
        state.update(compactedAt=time.time(), detail="Pensando…")

    save(path, state)


def main():
    args = sys.argv[1:]
    agent = args[0] if args and args[0] in EVENTS else "claude"
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except ValueError:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    name = args[1] if len(args) > 1 else first(payload, "hook_event_name", "hookEventName") or ""
    handle(agent, name, payload)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
