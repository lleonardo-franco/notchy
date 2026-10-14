#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
ROOT = os.path.join(HOME, ".notchy")
HOOK = os.path.join(ROOT, "notchy-hook.py")
STATUSLINE = os.path.join(ROOT, "notchy-statusline.py")
ORIGINAL = os.path.join(ROOT, "statusline-original.json")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")
EVENTS = [
    "SessionStart",
    "SessionEnd",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "PostToolUseFailure",
    "PermissionRequest",
    "Notification",
    "Stop",
    "StopFailure",
    "SubagentStart",
    "SubagentStop",
    "TaskCreated",
    "TaskCompleted",
    "PreCompact",
    "PostCompact",
]
WITH_MATCHER = {"PreToolUse", "PostToolUse", "PostToolUseFailure", "PermissionRequest"}
AGENTS_CONFIG = os.path.join(ROOT, "agents.json")
AGENTS = {
    "codex": {
        "name": "Codex CLI",
        "path": os.path.join(HOME, ".codex", "hooks.json"),
        "events": ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop"],
    },
    "gemini": {
        "name": "Gemini CLI",
        "path": os.path.join(HOME, ".gemini", "settings.json"),
        "events": ["SessionStart", "SessionEnd", "BeforeAgent", "AfterAgent", "BeforeTool", "AfterTool", "Notification", "PreCompress"],
    },
    "copilot": {
        "name": "GitHub Copilot CLI",
        "path": os.path.join(os.environ.get("COPILOT_HOME") or os.path.join(HOME, ".copilot"), "hooks", "notchy.json"),
        "events": ["sessionStart", "sessionEnd", "userPromptSubmitted", "preToolUse", "postToolUse", "postToolUseFailure", "permissionRequest", "notification", "agentStop", "errorOccurred", "subagentStart", "subagentStop", "preCompact"],
    },
    "cursor": {
        "name": "Cursor",
        "path": os.path.join(HOME, ".cursor", "hooks.json"),
        "events": ["sessionStart", "sessionEnd", "beforeSubmitPrompt", "beforeShellExecution", "beforeMCPExecution", "afterShellExecution", "afterMCPExecution", "afterFileEdit", "stop", "subagentStart", "subagentStop", "preCompact"],
    },
}
TIMEOUTS = {"PermissionRequest": 150}
MARKERS = ("notchy-hook.py", "notchy-statusline.py")
HERE = os.path.dirname(os.path.abspath(__file__))


def language():
    value = os.environ.get("NOTCHY_LANG", "")
    if not value:
        try:
            output = subprocess.run(["defaults", "read", "-g", "AppleLanguages"], capture_output=True, text=True, timeout=3).stdout
            lines = [line.strip(' ",') for line in output.splitlines()[1:2]]
            value = lines[0] if lines else ""
        except (OSError, subprocess.SubprocessError):
            value = ""
    value = value or os.environ.get("LANG", "en")
    if value.startswith("pt"):
        return "pt"
    if value.startswith("es"):
        return "es"
    return "en"


LANGUAGE = language()


def say(pt, en, es):
    return {"pt": pt, "es": es}.get(LANGUAGE, en)


def ours(command):
    return any(marker in (command or "") for marker in MARKERS)


def load_json(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    return json.loads(text) if text.strip() else {}


def write_json(path, data, backup=True):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if backup and os.path.exists(path):
        shutil.copy2(path, f"{path}.bak-{int(time.time())}")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(tmp, path)


def load_settings():
    return load_json(SETTINGS)


def write_settings(data):
    write_json(SETTINGS, data)


def without_notchy(groups):
    result = []
    for group in groups:
        hooks = [hook for hook in group.get("hooks", []) if not ours(hook.get("command"))]
        if hooks:
            result.append({**group, "hooks": hooks})
    return result


def flat_without_notchy(entries):
    return [entry for entry in entries if not ours(entry.get("command") or entry.get("bash"))]


def hook_command(agent, event):
    return f'python3 "{HOOK}" {agent} {event}'


def agent_enabled(agent):
    spec = AGENTS[agent]
    if not os.path.exists(spec["path"]):
        return False
    try:
        with open(spec["path"], encoding="utf-8") as handle:
            return "notchy-hook.py" in handle.read()
    except OSError:
        return False


def set_agent_options(agent, options):
    config = load_json(AGENTS_CONFIG)
    if options is None:
        config.pop(agent, None)
    else:
        config[agent] = options
    write_json(AGENTS_CONFIG, config, backup=False)


def enable_agent(agent, approvals=False):
    spec = AGENTS[agent]
    path = spec["path"]
    if agent == "copilot":
        hooks = {}
        for event in spec["events"]:
            hooks[event] = [{"type": "command", "bash": hook_command(agent, event), "timeoutSec": 150 if event == "permissionRequest" else 10}]
        write_json(path, {"version": 1, "hooks": hooks}, backup=False)
    elif agent == "cursor":
        data = load_json(path)
        data.setdefault("version", 1)
        hooks = data.setdefault("hooks", {})
        for event in spec["events"]:
            hooks[event] = flat_without_notchy(hooks.get(event, [])) + [{"command": hook_command(agent, event)}]
        write_json(path, data)
    else:
        data = load_json(path)
        hooks = data.setdefault("hooks", {})
        for event in spec["events"]:
            entry = {"hooks": [{"type": "command", "command": hook_command(agent, event)}]}
            if agent == "gemini":
                entry["hooks"][0]["name"] = "notchy"
            hooks[event] = without_notchy(hooks.get(event, [])) + [entry]
        write_json(path, data)
    set_agent_options(agent, {"approvals": bool(approvals)} if agent == "cursor" else {})
    print(say("{}: conectado ao Notchy ({})", "{}: connected to Notchy ({})", "{}: conectado a Notchy ({})").format(spec["name"], path))


def disable_agent(agent, quiet=False):
    spec = AGENTS[agent]
    path = spec["path"]
    if agent == "copilot":
        if os.path.exists(path):
            os.remove(path)
    elif os.path.exists(path):
        data = load_json(path)
        hooks = data.get("hooks", {})
        for event in list(hooks):
            groups = flat_without_notchy(hooks[event]) if agent == "cursor" else without_notchy(hooks[event])
            if groups:
                hooks[event] = groups
            else:
                del hooks[event]
        if not hooks:
            data.pop("hooks", None)
        write_json(path, data)
    if os.path.isdir(ROOT):
        set_agent_options(agent, None)
    if not quiet:
        print(say("{}: desconectado do Notchy", "{}: disconnected from Notchy", "{}: desconectado de Notchy").format(spec["name"]))


def list_agents():
    claude = any(ours(hook.get("command")) for groups in load_settings().get("hooks", {}).values() for group in groups for hook in group.get("hooks", []))
    rows = [("claude", "Claude Code", claude)] + [(key, spec["name"], agent_enabled(key)) for key, spec in AGENTS.items()]
    for key, name, enabled in rows:
        status = say("conectado", "connected", "conectado") if enabled else say("desconectado", "not connected", "desconectado")
        print(f"  {name:<22}{status:<16}{key}")


def agents_command(args):
    action = args[0] if args else "list"
    names = [name for name in args[1:] if not name.startswith("--")]
    if action == "list":
        list_agents()
        return
    if not names:
        print(say("Diga quais agentes: {}", "Say which agents: {}", "Indica qué agentes: {}").format(", ".join(AGENTS)))
        sys.exit(1)
    unknown = [name for name in names if name not in AGENTS]
    if unknown:
        print(say("Agente desconhecido: {}. Opções: {}", "Unknown agent: {}. Options: {}", "Agente desconocido: {}. Opciones: {}").format(", ".join(unknown), ", ".join(AGENTS)))
        sys.exit(1)
    if action == "enable":
        for folder in ("sessions", "approvals"):
            os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
        copy_script("notchy-hook.py", HOOK)
    for name in names:
        if action == "enable":
            enable_agent(name, approvals="--approvals" in args)
        elif action == "disable":
            disable_agent(name)
        else:
            print(say("Use enable, disable ou list.", "Use enable, disable or list.", "Usa enable, disable o list."))
            sys.exit(1)


def copy_script(name, target):
    shutil.copy2(os.path.join(HERE, name), target)
    os.chmod(target, 0o755)


def install():
    for folder in ("sessions", "approvals", "statusline"):
        os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
    copy_script("notchy-hook.py", HOOK)
    copy_script("notchy-statusline.py", STATUSLINE)

    settings = load_settings()
    hooks = settings.setdefault("hooks", {})
    command = f'python3 "{HOOK}"'
    for event in EVENTS:
        entry = {"hooks": [{"type": "command", "command": command, "timeout": TIMEOUTS.get(event, 5)}]}
        if event in WITH_MATCHER:
            entry = {"matcher": "*", **entry}
        hooks[event] = without_notchy(hooks.get(event, [])) + [entry]

    current = settings.get("statusLine")
    if isinstance(current, dict) and current.get("command") and not ours(current.get("command")):
        with open(ORIGINAL, "w", encoding="utf-8") as handle:
            json.dump(current, handle, indent=2)
    base = current if isinstance(current, dict) else {}
    settings["statusLine"] = {**base, "type": "command", "command": f'python3 "{STATUSLINE}"'}

    write_settings(settings)
    print(say("Hooks e status line instalados em {}", "Hooks and status line installed in {}", "Hooks y status line instalados en {}").format(ROOT))
    if os.path.exists(ORIGINAL):
        print(say("Sua status line antiga continua aparecendo: o Notchy só lê os dados e repassa para ela.", "Your previous status line still shows up: Notchy only reads the data and passes it along.", "Tu status line anterior sigue apareciendo: Notchy solo lee los datos y se los pasa."))


def uninstall():
    settings = load_settings()
    hooks = settings.get("hooks", {})
    for event in list(hooks):
        groups = without_notchy(hooks[event])
        if groups:
            hooks[event] = groups
        else:
            del hooks[event]
    if not hooks:
        settings.pop("hooks", None)

    if ours((settings.get("statusLine") or {}).get("command")):
        if os.path.exists(ORIGINAL):
            with open(ORIGINAL, encoding="utf-8") as handle:
                settings["statusLine"] = json.load(handle)
        else:
            settings.pop("statusLine", None)

    write_settings(settings)
    for agent in AGENTS:
        if agent_enabled(agent):
            disable_agent(agent, quiet=True)
    shutil.rmtree(ROOT, ignore_errors=True)
    print(say("Hooks e status line do Notchy removidos.", "Notchy's hooks and status line removed.", "Hooks y status line de Notchy eliminados."))


if __name__ == "__main__":
    if "--uninstall" in sys.argv:
        uninstall()
    elif "--agents" in sys.argv:
        agents_command(sys.argv[sys.argv.index("--agents") + 1:])
    else:
        install()
