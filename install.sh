#!/usr/bin/env bash
# claude-fleet installer
# Sets up the hook and Hammerspoon config for Claude Fleet monitoring.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
HS_DIR="$HOME/.hammerspoon"

echo "=== Claude Fleet Installer ==="
echo ""

mkdir -p "$HOOK_DIR"
cp "$REPO_DIR/hooks/fleet-status.sh" "$HOOK_DIR/fleet-status.sh"
chmod +x "$HOOK_DIR/fleet-status.sh"
echo "Installed hook: $HOOK_DIR/fleet-status.sh"

if [ ! -f "$HS_DIR/claude-fleet.lua" ]; then
    cp "$REPO_DIR/claude-fleet.lua" "$HS_DIR/claude-fleet.lua"
    echo "Installed: $HS_DIR/claude-fleet.lua"
else
    echo "Skipped (already exists): $HS_DIR/claude-fleet.lua"
    echo "  -> To update: cp $REPO_DIR/claude-fleet.lua $HS_DIR/claude-fleet.lua"
fi

echo ""
echo "=== Next steps ==="
echo ""
echo "1. Add these lines to your ~/.hammerspoon/init.lua:"
echo ""
echo '   if fleet then fleet.stop() end'
echo '   package.loaded["claude-fleet"] = nil'
echo '   fleet = require("claude-fleet")'
echo '   fleet.start()'
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
     }
   }
JSON
echo ""
echo "3. Reload Hammerspoon: click the menu bar icon -> Reload Config"
echo ""
echo "4. Optional: suppress duplicate iTerm2 notifications:"
echo "   iTerm2 -> Settings -> Profiles -> Terminal -> Filter Alerts"
echo "   -> uncheck 'Send escape sequence-generated alerts'"
echo ""
echo "Done."
