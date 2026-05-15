# Claude Fleet

A macOS tool that watches all your running [Claude Code](https://claude.ai/code) CLI sessions and shows a floating panel whenever one is waiting for your input — so you can see at a glance which agents need attention and jump straight to them.

![Panel screenshot placeholder](docs/panel.png)

## What it does

- **Floating notification panel** (top-right, non-focus-stealing) lists every Claude session waiting for input, with project name, working directory, and how long it's been waiting
- **Sound alert** (macOS "Bubble") plays when the panel first appears, not on subsequent updates
- **Click to jump** directly to the right iTerm2 tab/pane
- **Dismiss** individual sessions (✕ per row) or all at once (✕ in header)
- **Hotkey** `⌘⇧`` ` to show the panel on demand
- **Alfred integration** (optional) for keyboard-driven access

## How it works

```
Claude Code session
  → Stop / Notification hook fires fleet-status.sh
  → Writes ~/.claude/fleet-status/<session_id>.json  { state: "waiting" }
  → Hammerspoon pathwatcher sees the file change
  → Panel appears / updates
```

When you act on a session (click, dismiss, or start a new tool call), the state is updated to `"dismissed"` or `"working"` and the row disappears.

## Prerequisites

- macOS
- [Hammerspoon](https://www.hammerspoon.org) (`brew install --cask hammerspoon`)
- [Claude Code CLI](https://claude.ai/code) with hooks support
- [iTerm2](https://iterm2.com) — optional, required for click-to-jump
- [Alfred](https://www.alfredapp.com) — optional, for the Alfred workflow

## Installation

### Automated

```bash
git clone https://github.com/curtisgalloway/claude-fleet.git
cd claude-fleet
./install.sh
```

Then follow the printed next-steps (two manual edits: `init.lua` and `settings.json`).

### Manual

**1. Copy the Hammerspoon module**

```bash
cp claude-fleet.lua ~/.hammerspoon/
```

**2. Add to `~/.hammerspoon/init.lua`**

```lua
if fleet then fleet.stop() end
package.loaded["claude-fleet"] = nil
fleet = require("claude-fleet")
fleet.start()
```

The `stop()` / `package.loaded` dance ensures a clean reload when you hit *Reload Config*.

**3. Install the Claude Code hook**

```bash
mkdir -p ~/.claude/hooks
cp hooks/fleet-status.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/fleet-status.sh
```

**4. Wire the hook in `~/.claude/settings.json`**

Merge the following into your existing `settings.json` (create the file if it doesn't exist):

```json
{
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/fleet-status.sh waiting"}]}
    ],
    "Notification": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/fleet-status.sh waiting"}]}
    ],
    "PreToolUse": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/fleet-status.sh working"}]}
    ]
  }
}
```

**5. Reload Hammerspoon**

Click the Hammerspoon icon in the menu bar → *Reload Config*.

## Optional: Suppress duplicate iTerm2 notifications

The Claude Code `Notification` hook can also trigger iTerm2's own notification system. To suppress the duplicate:

iTerm2 → Settings → Profiles → Terminal → Filter Alerts → uncheck **"Send escape sequence-generated alerts"**

## Optional: Alfred integration

`alfred-fleet.py` is a [Script Filter](https://www.alfredapp.com/help/workflows/inputs/script-filter/) for Alfred workflows. It outputs the same waiting-session list in Alfred JSON format.

**Setup:**

1. Create a new Alfred Workflow with a *Script Filter* input
2. Set language to `/usr/bin/python3`, paste the contents of `alfred-fleet.py` (or reference it by path)
3. Connect it to a *Run Script* action that activates the iTerm2 session using the `{var:iterm_session_id}` variable:

```applescript
tell application "iTerm2"
    activate
    repeat with aWindow in windows
        repeat with aTab in tabs of aWindow
            repeat with aSession in sessions of aTab
                set sid to unique id of aSession
                if sid is "{var:iterm_session_id}" or sid ends with (":" & "{var:iterm_session_id}") then
                    select aWindow
                    tell aTab to select
                    tell aSession to select
                    return
                end if
            end repeat
        end repeat
    end repeat
end tell
```

## Customisation

All tunable constants are at the top of `claude-fleet.lua`:

| Constant | Default | Description |
|----------|---------|-------------|
| `PANEL_W` | `340` | Panel width in points |
| `ITEM_H` | `54` | Height per session row |
| `HEADER_H` | `34` | Height of the header bar |
| `STALE_HOURS` | `8` | Hours before a waiting entry is auto-pruned |

The sound name (`"Bubble"`) is resolved in `M.start()` — swap it for any name from `hs.sound.soundNames()`.

## File layout

```
~/.hammerspoon/
  claude-fleet.lua      ← Hammerspoon module (this repo)
  init.lua              ← your init, loads claude-fleet

~/.claude/
  settings.json         ← hook wiring lives here
  hooks/
    fleet-status.sh     ← writes state files (this repo)
  fleet-status/
    <session_id>.json   ← runtime state, auto-managed
```

## Troubleshooting

**Panel never appears**
- Check Hammerspoon console (menu bar → *Console*) for Lua errors
- Verify the hook fires: run `claude` in a terminal, let it stop, then check `ls ~/.claude/fleet-status/`
- Confirm `settings.json` has the hooks and is valid JSON

**"attempt to index a nil value" in Hammerspoon console**
- This can appear briefly during *Reload Config* and is harmless after reload completes
- If it persists, make sure your `init.lua` includes the `fleet.stop()` / `package.loaded` lines shown above

**iTerm2 jump doesn't work**
- Make sure iTerm2 has Automation permission: System Settings → Privacy & Security → Automation → Hammerspoon → iTerm2 ✓
- The jump uses `ITERM_SESSION_ID` from the environment when Claude Code starts — it only works in sessions launched from iTerm2

**Duplicate notifications**
- See the "Suppress duplicate iTerm2 notifications" section above

## License

Apache 2.0 — see [LICENSE](LICENSE).
