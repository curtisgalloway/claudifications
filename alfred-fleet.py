#!/usr/bin/env python3
"""Alfred Script Filter — lists waiting Claude CLI agents.

Output: Alfred JSON (items array).
Run action receives iterm_session_id via Alfred variable {var:iterm_session_id}.
"""
import json
import time
from pathlib import Path

STATUS_DIR = Path.home() / ".claude" / "fleet-status"
STALE_HOURS = 8
cutoff = time.time() - STALE_HOURS * 3600

items = []

if STATUS_DIR.exists():
    for path in STATUS_DIR.glob("*.json"):
        try:
            data = json.loads(path.read_text())
        except Exception:
            continue

        if data.get("state") != "waiting":
            continue

        ts_str = data.get("timestamp", "")
        try:
            import datetime
            ts = datetime.datetime.fromisoformat(ts_str.replace("Z", "+00:00")).timestamp()
        except Exception:
            ts = 0

        if ts < cutoff:
            continue

        ago = int((time.time() - ts) / 60)
        ago_str = "just now" if ago < 1 else f"{ago} min ago"

        project = data.get("project", "unknown")
        cwd = data.get("cwd", "")
        iterm_id = data.get("iterm_session_id", "")

        items.append({
            "title": project,
            "subtitle": f"{cwd}  •  {ago_str}",
            "arg": iterm_id,
            "variables": {
                "iterm_session_id": iterm_id,
                "cwd": cwd,
            },
            "icon": {"path": "icon.png"},
        })

if not items:
    items.append({
        "title": "No waiting Claude agents",
        "subtitle": "All agents are working or idle",
        "valid": False,
    })

print(json.dumps({"items": items}))
