#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.join(os.path.expanduser("~"), ".notchy")
FOLDER = os.path.join(ROOT, "statusline")
ORIGINAL = os.path.join(ROOT, "statusline-original.json")


def window(data, key):
    value = (data.get("rate_limits") or {}).get(key)
    if not isinstance(value, dict) or value.get("used_percentage") is None:
        return None
    return {
        "usedPercentage": float(value["used_percentage"]),
        "resetsAt": float(value.get("resets_at") or 0),
    }


def record(data):
    session = data.get("session_id")
    if not session:
        return
    context = (data.get("context_window") or {}).get("used_percentage")
    os.makedirs(FOLDER, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=FOLDER, suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump({
            "sessionId": session,
            "updatedAt": time.time(),
            "context": float(context) if context is not None else None,
            "model": (data.get("model") or {}).get("display_name"),
            "fiveHour": window(data, "five_hour"),
            "sevenDay": window(data, "seven_day"),
        }, handle)
    os.replace(tmp, os.path.join(FOLDER, f"{session}.json"))


def original_command():
    try:
        with open(ORIGINAL, encoding="utf-8") as handle:
            return (json.load(handle) or {}).get("command")
    except (OSError, ValueError):
        return None


def default_line(data):
    parts = []
    model = (data.get("model") or {}).get("display_name")
    if model:
        parts.append(model)
    context = (data.get("context_window") or {}).get("used_percentage")
    if context is not None:
        parts.append(f"{float(context):.0f}% ctx")
    for label, key in (("5h", "five_hour"), ("7d", "seven_day")):
        value = window(data, key)
        if value:
            parts.append(f"{label} {value['usedPercentage']:.0f}%")
    return " · ".join(parts)


def main():
    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except ValueError:
        data = {}
    try:
        record(data)
    except Exception:
        pass
    command = original_command()
    if command:
        try:
            result = subprocess.run(command, shell=True, input=raw, capture_output=True, text=True, timeout=5)
            sys.stdout.write(result.stdout)
            return
        except Exception:
            pass
    print(default_line(data))


if __name__ == "__main__":
    main()
