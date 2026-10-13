#!/usr/bin/env python3
import json
import os
import shutil
import sys
import time

HOME = os.path.expanduser("~")
ROOT = os.path.join(HOME, ".notchy")
HOOK = os.path.join(ROOT, "notchy-hook.py")
STATUSLINE = os.path.join(ROOT, "notchy-statusline.py")
ORIGINAL = os.path.join(ROOT, "statusline-original.json")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")
EVENTS = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Notification", "Stop"]
WITH_MATCHER = {"PreToolUse", "PostToolUse", "PermissionRequest"}
TIMEOUTS = {"PermissionRequest": 150}
MARKERS = ("notchy-hook.py", "notchy-statusline.py")
HERE = os.path.dirname(os.path.abspath(__file__))


def ours(command):
    return any(marker in (command or "") for marker in MARKERS)


def load_settings():
    if not os.path.exists(SETTINGS):
        return {}
    with open(SETTINGS, encoding="utf-8") as handle:
        return json.load(handle)


def write_settings(data):
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    if os.path.exists(SETTINGS):
        shutil.copy2(SETTINGS, f"{SETTINGS}.bak-{int(time.time())}")
    tmp = SETTINGS + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(tmp, SETTINGS)


def without_notchy(groups):
    result = []
    for group in groups:
        hooks = [hook for hook in group.get("hooks", []) if not ours(hook.get("command"))]
        if hooks:
            result.append({**group, "hooks": hooks})
    return result


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
    print(f"Hooks e status line instalados em {ROOT}")
    if os.path.exists(ORIGINAL):
        print("Sua status line antiga continua aparecendo: o Notchy só lê os dados e repassa para ela.")


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
    shutil.rmtree(ROOT, ignore_errors=True)
    print("Hooks e status line do Notchy removidos.")


if __name__ == "__main__":
    if "--uninstall" in sys.argv:
        uninstall()
    else:
        install()
