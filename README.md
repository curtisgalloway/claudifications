# Claudifications

A native macOS app that watches all your running [Claude Code](https://claude.ai/code) CLI sessions and shows a floating panel whenever one is waiting for your input — so you can see at a glance which agents need attention and jump straight to them.

![Panel screenshot placeholder](docs/panel.png)

## What it does

- **Floating notification panel** (top-right, non-focus-stealing) lists every Claude session waiting for input, with project name, working directory, and how long it's been waiting
- **Sound alert** plays when the panel first appears, not on subsequent updates
- **Click to jump** directly to the right iTerm2 tab/pane
- **Dismiss** individual sessions (✕ per row) or all at once (✕ in header)
- **Menu bar icon** for quick access and preferences

## How it works

```
Claude Code session
  → Stop / Notification hook fires fleet-status.sh
  → Writes ~/.claude/fleet-status/<session_id>.json  { state: "waiting" }
  → Claudifications polls for file changes
  → Panel appears / updates
```

When you act on a session (click or dismiss), the state is updated to `"dismissed"` and the row disappears.

## Prerequisites

- macOS 13+
- [Claude Code CLI](https://claude.ai/code) with hooks support
- [iTerm2](https://iterm2.com) — optional, required for click-to-jump
- Xcode or `xcodegen` + `xcodebuild` to build from source

## Installation

```bash
git clone https://github.com/curtisgalloway/claudifications.git
cd claudifications
./install.sh
```

Then follow the printed next steps (launch the app and wire the hooks in `settings.json`).

### Manual build

```bash
make install   # builds and copies to /Applications
```

Then install the hook and wire `settings.json` manually:

**Install the hook**

```bash
mkdir -p ~/.claude/hooks
cp hooks/fleet-status.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/fleet-status.sh
```

**Wire the hook in `~/.claude/settings.json`**

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

## Optional: Suppress duplicate iTerm2 notifications

The Claude Code `Notification` hook can also trigger iTerm2's own notification system. To suppress the duplicate:

iTerm2 → Settings → Profiles → Terminal → Filter Alerts → uncheck **"Send escape sequence-generated alerts"**

## File layout

```
~/.claude/
  settings.json         ← hook wiring lives here
  hooks/
    fleet-status.sh     ← writes state files (this repo)
  fleet-status/
    <session_id>.json   ← runtime state, auto-managed
```

## Troubleshooting

**Panel never appears**
- Verify the hook fires: run `claude` in a terminal, let it stop, then check `ls ~/.claude/fleet-status/`
- Confirm `settings.json` has the hooks and is valid JSON

**iTerm2 jump doesn't work**
- Make sure iTerm2 has Automation permission: System Settings → Privacy & Security → Automation → Claudifications → iTerm2 ✓
- The jump uses `ITERM_SESSION_ID` from the environment when Claude Code starts — it only works in sessions launched from iTerm2

## License

Apache 2.0 — see [LICENSE](LICENSE).
