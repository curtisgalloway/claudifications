#!/usr/bin/env bash
# claude-fleet installer
# Sets up the hook and Hammerspoon config for Claude Fleet monitoring.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
HS_DIR="$HOME/.hammerspoon"

echo "=== Claude Fleet Installer ==="
echo ""

if command -v brew >/dev/null 2>&1; then
    if brew list --cask hammerspoon >/dev/null 2>&1; then
        echo "Hammerspoon: already installed"
    else
        printf "Hammerspoon is not installed. Install it now via Homebrew? [y/N] "
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                brew install --cask hammerspoon
                echo "Hammerspoon installed."
                ;;
            *)
                echo "Skipping Hammerspoon install."
                echo "  -> Install manually: brew install --cask hammerspoon"
                echo "     or download from https://www.hammerspoon.org"
                ;;
        esac
    fi
else
    if [ -d "/Applications/Hammerspoon.app" ]; then
        echo "Hammerspoon: found (installed without Homebrew)"
    else
        echo "Note: Homebrew not found. Install Hammerspoon manually if needed:"
        echo "  https://www.hammerspoon.org"
    fi
fi
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
echo "3. Reload Hammerspoon (or it will be done automatically if hs is in your PATH)"
echo ""
echo "4. Optional: suppress duplicate iTerm2 notifications:"
echo "   iTerm2 -> Settings -> Profiles -> Terminal -> Filter Alerts"
echo "   -> uncheck 'Send escape sequence-generated alerts'"
echo ""
if command -v hs >/dev/null 2>&1; then
    hs -c 'hs.reload()'
    echo "Hammerspoon config reloaded."
else
    echo "Reload Hammerspoon manually: click the menu bar icon -> Reload Config"
fi
echo ""
echo "Done."
