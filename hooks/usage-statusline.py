#!/usr/bin/env python3
"""Claude Code status line: directory + model/thinking + context window bar.

Wired as `statusLine` in ~/.claude/settings.json. Claude Code pipes the session
status JSON on stdin; its `rate_limits` block carries the same subscription
usage that /usage shows. We persist that to ~/.claude/claudifications/usage.json
for Claudifications' menu bar readout. Plan usage is deliberately NOT printed
on the line itself: the menu bar already shows it, and the status line's row
is better spent on per-session state.

The line leads with the session's directory so parallel sessions in different
terminal tabs are tellable apart at a glance; the model and thinking level
(which the default status line shows, and a custom one replaces) come next,
then a context window bar. The directory is printed even when usage is unavailable, so the
line is never blank.

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

# Cells in the context bar. 10 keeps each cell at a round 10% so the bar can
# be read without the number, and fits beside the directory on a narrow pane.
BAR_WIDTH = 10

# Widest directory label we'll print. Longer paths drop leading components
# rather than wrapping the status line onto a second row.
MAX_DIR_WIDTH = 40


def window(limits, key):
    w = limits.get(key)
    if not isinstance(w, dict):
        return None
    used, resets = w.get("used_percentage"), w.get("resets_at")
    if used is None or resets is None:
        return None
    return {"used_percentage": float(used), "resets_at": int(resets)}


def directory(data):
    """The session's directory, home-collapsed and trimmed to fit."""
    workspace = data.get("workspace")
    if not isinstance(workspace, dict):
        workspace = {}
    path = workspace.get("current_dir") or data.get("cwd") or workspace.get(
        "project_dir")
    if not isinstance(path, str) or not path:
        return None

    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        path = "~" + path[len(home):]

    if len(path) <= MAX_DIR_WIDTH:
        return path

    # Keep whole trailing components — the tail is what identifies the repo.
    kept = []
    width = 1  # the leading ellipsis
    for part in reversed(path.split(os.sep)):
        if not part:
            continue
        if width + 1 + len(part) > MAX_DIR_WIDTH and kept:
            break
        kept.insert(0, part)
        width += 1 + len(part)
    return os.sep.join(["…"] + kept)


def model_label(data):
    """Model name plus thinking level, e.g. "Fable 5 xhigh"."""
    model = data.get("model")
    if not isinstance(model, dict):
        return None
    name = model.get("display_name") or model.get("id")
    if not isinstance(name, str) or not name:
        return None

    thinking = data.get("thinking")
    if isinstance(thinking, dict) and thinking.get("enabled") is False:
        return name + " no thinking"
    effort = data.get("effort")
    level = effort.get("level") if isinstance(effort, dict) else None
    if isinstance(level, str) and level:
        return "%s %s" % (name, level)
    return name


def context_label(data):
    """Context window bar, e.g. "▓▓▓▓░░░░░░ 42%".

    used_percentage is input tokens only (fresh + cache reads + cache writes)
    over context_window_size, which is what Claude Code's own /context and the
    autocompact threshold are measured against. It is null before the first API
    response and briefly after /compact, in which case we print nothing.
    """
    ctx = data.get("context_window")
    if not isinstance(ctx, dict):
        return None
    used = ctx.get("used_percentage")
    if used is None:
        return None
    try:
        pct = float(used)
    except (TypeError, ValueError):
        return None
    pct = max(0.0, min(100.0, pct))
    filled = int(round(pct / 100.0 * BAR_WIDTH))
    bar = "\u2593" * filled + "\u2591" * (BAR_WIDTH - filled)
    return "%s %.0f%%" % (bar, pct)


def record(five, seven):
    """Publish plan usage for the Claudifications menu bar readout."""
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
    if five or seven:
        record(five, seven)

    parts = []
    where = directory(data)
    if where:
        parts.append(where)
    label = model_label(data)
    if label:
        parts.append(label)
    ctx = context_label(data)
    if ctx:
        parts.append(ctx)
    sys.stdout.write("  ".join(parts))


main()
