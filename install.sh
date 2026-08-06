#!/usr/bin/env bash
# Claudifications installer
# Builds and installs the native macOS app and the Claude Code hook.
#
# Usage: ./install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
APP_NAME="Claudifications.app"
APP_DEST="/Applications/$APP_NAME"

echo "=== Claudifications Installer ==="
echo ""

echo "Building $APP_NAME..."
make -C "$REPO_DIR" build
echo ""

echo "Installing $APP_NAME to /Applications..."
cp -R "$REPO_DIR/build/Release/$APP_NAME" "$APP_DEST"
echo "Installed: $APP_DEST"
echo ""

mkdir -p "$HOOK_DIR"
cp "$REPO_DIR/hooks/fleet-status.sh" "$HOOK_DIR/fleet-status.sh"
chmod +x "$HOOK_DIR/fleet-status.sh"
echo "Installed hook: $HOOK_DIR/fleet-status.sh"

cp "$REPO_DIR/hooks/usage-statusline.py" "$HOOK_DIR/usage-statusline.py"
chmod +x "$HOOK_DIR/usage-statusline.py"
echo "Installed status line: $HOOK_DIR/usage-statusline.py"
echo ""

echo "=== Next steps ==="
echo ""
echo "1. Launch Claudifications:"
echo "   open $APP_DEST"
echo ""
echo "2. Add the hooks to your ~/.claude/settings.json:"
echo "   (merge this into the existing 'hooks' key, or create it)"
echo ""
cat <<'JSON'
   {
     "hooks": {
       "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/fleet-status.sh waiting"}]}],
       "Notification": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/fleet-status.sh waiting"}]}],
       "PreToolUse": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/fleet-status.sh working"}]}]
     },
     "statusLine": {"type": "command", "command": "~/.claude/hooks/usage-statusline.py"}
   }
JSON
echo ""
echo "   The statusLine entry powers the plan-usage readout in the menu bar."
echo "   Claude Code allows only one status line — if you already have one,"
echo "   keep it and have it also run usage-statusline.py."
echo ""
echo "Done."
