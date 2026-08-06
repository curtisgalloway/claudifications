#!/usr/bin/env python3
"""Claude Code status line that records Claude.ai plan usage.

Wired as `statusLine` in ~/.claude/settings.json. Claude Code pipes the session
status JSON on stdin; its `rate_limits` block carries the same subscription
usage that /usage shows. We persist that to ~/.claude/claudifications/usage.json
for Claudifications' menu bar readout, and echo a compact summary back so the
terminal status line isn't left blank.

This deliberately does NOT live in ~/.claude/fleet-status/: the app sweeps that
directory and deletes every .json that doesn't parse as a session record, which
would take this file with it. Plan usage is account-wide state, not per-session
state, so it gets its own directory.

This is plain Python rather than the bash+python of fleet-status.sh because the
status line re-runs on every render, so it skips the extra shell spawn.
"""

import json
import os
import sys
import tempfile
import time

STATUS_DIR = os.path.join(os.path.expanduser("~"), ".claude", "claudifications")
OUT_PATH = os.path.join(STATUS_DIR, "usage.json")


def window(limits, key):
    w = limits.get(key)
    if not isinstance(w, dict):
        return None
    used, resets = w.get("used_percentage"), w.get("resets_at")
    if used is None or resets is None:
        return None
    return {"used_percentage": float(used), "resets_at": int(resets)}


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return

    limits = data.get("rate_limits") or {}
    five, seven = window(limits, "five_hour"), window(limits, "seven_day")

    # rate_limits is absent for non-subscribers and before a session's first API
    # response. Leave any previously written (still useful) file alone rather
    # than replacing good data with nothing.
    if five is None and seven is None:
        return

    payload = {"updated_at": int(time.time())}
    if five:
        payload["five_hour"] = five
    if seven:
        payload["seven_day"] = seven

    # Write via rename: the app polls this path and must never read a half-file.
    try:
        os.makedirs(STATUS_DIR, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=STATUS_DIR, prefix=".usage-")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(payload, f)
            os.replace(tmp, OUT_PATH)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
    except Exception:
        pass

    parts = []
    if five:
        parts.append("5h %.0f%%" % five["used_percentage"])
    if seven:
        parts.append("7d %.0f%%" % seven["used_percentage"])
    sys.stdout.write("  ".join(parts))


main()
