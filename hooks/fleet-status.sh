#!/usr/bin/env bash
# Claude Code fleet status hook
# Called by Stop/Notification (state=waiting) and PreToolUse (state=working) hooks
# Writes session state to ~/.claude/fleet-status/<session_id>.json

STATE="$1"
STATUS_DIR="$HOME/.claude/fleet-status"
mkdir -p "$STATUS_DIR"

TMPFILE=$(mktemp)
cat > "$TMPFILE"

export FLEET_STATE="$STATE"
export FLEET_CWD="$PWD"
export FLEET_PROJECT
FLEET_PROJECT=$(basename "$PWD")
export FLEET_ITERM="${ITERM_SESSION_ID:-}"
export FLEET_INPUT="$TMPFILE"
export FLEET_STATUS_DIR="$STATUS_DIR"
export FLEET_TIMESTAMP
FLEET_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

python3 - <<'PYEOF'
import json, os, sys

with open(os.environ['FLEET_INPUT']) as f:
    try:
        hook_data = json.load(f)
    except Exception:
        hook_data = {}

session_id = hook_data.get('session_id', 'unknown')
if not session_id:
    session_id = 'unknown'

data = {
    'session_id': session_id,
    'state': os.environ['FLEET_STATE'],
    'cwd': os.environ['FLEET_CWD'],
    'project': os.environ['FLEET_PROJECT'],
    'iterm_session_id': os.environ['FLEET_ITERM'],
    'timestamp': os.environ['FLEET_TIMESTAMP'],
}

status_dir = os.environ['FLEET_STATUS_DIR']
out_path = os.path.join(status_dir, f"{session_id}.json")
with open(out_path, 'w') as f:
    json.dump(data, f)
PYEOF

rm -f "$TMPFILE"
