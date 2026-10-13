#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = os.path.join(os.path.expanduser("~"), ".notchy")
SESSIONS = os.path.join(ROOT, "sessions")
APPROVALS = os.path.join(ROOT, "approvals")
APP_PID = os.path.join(ROOT, "app.pid")
APPROVAL_TIMEOUT = float(os.environ.get("NOTCHY_APPROVAL_TIMEOUT", "120"))

VERBS = {
    "Read": "Lendo",
    "Write": "Escrevendo",
    "Edit": "Editando",
    "MultiEdit": "Editando",
    "NotebookEdit": "Editando",
}


def short(text, limit=70):
    text = " ".join(str(text or "").split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def clip(text, limit):
    text = str(text or "").strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def file_path(data):
    return data.get("file_path") or data.get("notebook_path") or data.get("path") or ""


def relative(path, cwd):
    if path and cwd and path.startswith(cwd.rstrip("/") + "/"):
        return os.path.relpath(path, cwd)
    return path


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
    if tool == "TodoWrite":
        return "Atualizando tarefas"
    if tool.startswith("mcp__"):
        parts = tool.split("__")
        return f"{parts[1]} · {parts[-1]}" if len(parts) > 2 else tool
    return tool


def details(tool, data, cwd):
    data = data if isinstance(data, dict) else {}
    if tool == "Bash":
        return clip(data.get("command"), 400)
    if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        path = relative(file_path(data), cwd)
        snippet = data.get("new_string") or data.get("content") or data.get("new_source") or ""
        return clip(f"{path}\n{snippet}" if snippet else path, 400)
    if tool == "WebFetch":
        return clip(data.get("url"), 400)
    if tool == "WebSearch":
        return clip(data.get("query"), 400)
    return clip(json.dumps(data, ensure_ascii=False), 400)


def load(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


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


def is_claude(args):
    for token in args.split()[:2]:
        if os.path.basename(token) == "claude" or "@anthropic-ai/claude-code" in token:
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


def inspect_parents():
    pid = os.getppid()
    tty = None
    claude = None
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
        if claude is None and is_claude(args):
            claude = pid
        if tty and claude:
            break
        pid = int(parent)
        if pid <= 1:
            break
    return tty, claude


def is_idle_notice(payload):
    kind = payload.get("notification_type", "")
    message = payload.get("message", "")
    return kind == "idle_prompt" or "waiting for your input" in message


def ask_notch(session, payload):
    if not app_running():
        return None
    tool = payload.get("tool_name") or "Ferramenta"
    data = payload.get("tool_input")
    cwd = payload.get("cwd") or ""
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
    })
    behavior = None
    deadline = time.time() + APPROVAL_TIMEOUT
    try:
        while time.time() < deadline:
            if os.path.exists(response_path):
                behavior = load(response_path).get("behavior")
                break
            if not app_running():
                break
            time.sleep(0.15)
    finally:
        remove(request_path)
        remove(response_path)
    return behavior


def touch(state, session, payload, event):
    now = time.time()
    state.update(
        id=session,
        cwd=payload.get("cwd") or state.get("cwd") or os.getcwd(),
        event=event,
        updatedAt=now,
    )
    state.setdefault("startedAt", now)
    state.setdefault("status", "idle")
    if event == "SessionStart" or not state.get("tty") or not alive(state.get("claudePid")):
        tty, claude = inspect_parents()
        state["tty"] = tty or state.get("tty")
        state["claudePid"] = claude
    state["app"] = os.environ.get("__CFBundleIdentifier") or state.get("app")
    state["termProgram"] = os.environ.get("TERM_PROGRAM") or state.get("termProgram")


def handle_permission(path, state, session, payload):
    state.update(status="waiting", detail=f"Permissão · {describe(payload.get('tool_name'), payload.get('tool_input'))}")
    save(path, state)
    behavior = ask_notch(session, payload)
    if behavior not in ("allow", "deny"):
        return
    state = load(path) or state
    state.update(
        status="working",
        detail="Pensando…" if behavior == "allow" else "Negado pelo notch",
        updatedAt=time.time(),
    )
    save(path, state)
    decision = {"behavior": "allow"} if behavior == "allow" else {
        "behavior": "deny",
        "message": "O usuário negou esta ação pelo Notchy.",
    }
    sys.stdout.write(json.dumps({
        "hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": decision}
    }))


def main():
    payload = json.load(sys.stdin)
    session = payload.get("session_id")
    event = payload.get("hook_event_name", "")
    if not session or event == "SubagentStop":
        return

    path = os.path.join(SESSIONS, f"{session}.json")

    if event == "SessionEnd":
        remove(path)
        return

    state = load(path)
    if event == "Notification" and is_idle_notice(payload) and state.get("status") == "done":
        return

    touch(state, session, payload, event)

    if event == "PermissionRequest":
        handle_permission(path, state, session, payload)
        return

    if event == "SessionStart":
        state.update(status="idle", detail=None)
    elif event == "UserPromptSubmit":
        state.update(status="working", detail="Pensando…", prompt=short(payload.get("prompt"), 80), promptAt=time.time())
    elif event == "PreToolUse":
        state.update(status="working", detail=describe(payload.get("tool_name"), payload.get("tool_input")))
    elif event == "PostToolUse":
        state.update(status="working", detail="Pensando…")
    elif event == "Notification":
        if is_idle_notice(payload):
            state.update(status="waiting", detail="Esperando sua resposta")
        elif state.get("status") != "waiting":
            state.update(status="waiting", detail=short(payload.get("message"), 70) or "Precisa de você")
    elif event == "Stop":
        state.update(status="done", detail=None)

    save(path, state)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
