# Agent notes

Orientation for coding agents working in this repo. Everything here is a fact
you would otherwise have to rediscover by reading several files or by breaking
something first.

## Build

```bash
make generate   # xcodegen: project.yml -> Claudifications.xcodeproj
make build      # -> build/Release/Claudifications.app
make install    # build, then replace /Applications/Claudifications.app
```

`make build` runs `generate` first, so a plain `make build` is usually enough.

**`Claudifications.xcodeproj/project.pbxproj` is generated but tracked.** Adding
a source file means the pbxproj changes too; commit that hunk along with the
file. Two branches that each add a file will conflict there — resolve by taking
either side and re-running `make generate`.

Pipe build output to a file rather than through `head`: closing the pipe
SIGPIPEs `xcodebuild` mid-stream and you get a log that looks like a silent
failure.

```bash
make build > /tmp/build.log 2>&1; echo "exit=$?"; grep -c "error:" /tmp/build.log
```

## Signing

Local builds are **ad-hoc signed with the hardened runtime on** (`project.yml`).
The hardened runtime is deliberately enabled for local builds too, so an
entitlement Apple would reject fails on your machine rather than mid-release.

`Claudifications/Claudifications.entitlements` is load-bearing: click-to-jump
drives iTerm2 through `NSAppleScript`, which the hardened runtime blocks
outright without `com.apple.security.automation.apple-events`.

Release builds are re-signed with a Developer ID and notarized in
`.github/workflows/release.yml`, on tag push only. A local ad-hoc bundle also
carries `get-task-allow`, which notarization rejects — CI's re-sign drops it and
asserts that it is gone.

## Running it to see a change

It is a menu-bar app (`LSUIElement`) with a floating panel — there is no window
to launch into, and no test suite. To actually see a change:

1. **Quit the installed instance first.** Two copies both render a panel and
   the screenshots become useless.
   ```bash
   pkill -f '/Applications/Claudifications.app'
   open build/Release/Claudifications.app
   ```
   Put it back when you are done: `open /Applications/Claudifications.app`.

2. **Seed sessions.** The panel lists files in `~/.claude/fleet-status/`, one
   JSON record per session, polled every 500 ms:
   ```json
   {"session_id": "zz-preview-a", "state": "waiting", "cwd": "~/src/foo",
    "project": "foo", "branch": "main", "iterm_session_id": "",
    "timestamp": "2026-08-08T18:56:00Z"}
   ```
   Stored `state` is `waiting` / `working` / `dismissed`, and only `waiting`
   shows. (`ended` is not a stored value — the hook deletes the file instead.)
   `timestamp` is ISO 8601; records older than 8 hours are swept, as is any
   file that fails to decode — a malformed record deletes itself rather than
   erroring.

   Use an obvious prefix (`zz-preview-*`) for seeded files and delete them
   afterwards. Real sessions live in the same directory, including the one
   driving you.

3. **Reset preferences** between runs — they are plain user defaults:
   ```bash
   defaults delete net.curtisg.claudifications <key>
   ```

Clicking a row jumps iTerm2 to that pane *and* marks the session dismissed.
Don't click rows you didn't seed: you will silently clear a real notification
someone was waiting on.

## Driving the UI without a person

SwiftUI's accessibility tree does not respond to `entire contents` here, so
element-by-name scripting mostly fails. What does work:

```bash
# geometry of every window (AX coords: top-left origin)
osascript -e 'tell application "System Events" to tell process "Claudifications" to get {name, position, size} of every window'
```

Menu-bar items are reachable by name (`click menu item "Preferences…" of menu 1
of menu bar item 1 of menu bar 1`). For anything inside the SwiftUI form, fall
back to clicking coordinates derived from a screenshot, and do the raise, the
click, and the capture **in one `osascript`** — the window loses front position
between separate invocations.

Synthetic drags need real mouse events; `System Events` cannot express them:

```bash
uv run --with pyobjc-framework-Quartz python - <<'EOF'
import time, Quartz

def post(kind, x, y):
    Quartz.CGEventPost(Quartz.kCGHIDEventTap,
        Quartz.CGEventCreateMouseEvent(None, kind, (x, y), Quartz.kCGMouseButtonLeft))

x0, y0, x1, y1 = 1670, 58, 400, 300          # panel header -> somewhere else
post(Quartz.kCGEventMouseMoved, x0, y0); time.sleep(0.3)
post(Quartz.kCGEventLeftMouseDown, x0, y0); time.sleep(0.3)
for i in range(1, 31):                        # synthesize intermediate motion
    post(Quartz.kCGEventLeftMouseDragged,
         x0 + (x1 - x0) * i / 30, y0 + (y1 - y0) * i / 30)
    time.sleep(0.02)
post(Quartz.kCGEventLeftMouseUp, x1, y1)
EOF
```

Global event coordinates span all displays and go negative to the left of the
main one, which is how the multi-display paths get exercised.

## Layout

```
Claudifications/
  App/          NSApplicationDelegate, status item, menu
  Model/        SessionStore (polling), Session, PlanUsage, HookInstaller
  UI/           FloatingPanel + PanelController (placement), SessionListView, theme
  Preferences/  PreferencesView (Form) + its window controller
  Bridge/       ITermBridge — AppleScript jump into iTerm2
  Hotkeys/      global ⌥⌘1–9 handler
  Audio/        SoundPlayer
hooks/          shipped as app resources and copied to ~/.claude/hooks by Install Hooks
```

The copies in `~/.claude/hooks/` are installed artifacts — edit the scripts
here in `hooks/` and reinstall (or re-copy), or at minimum sync any direct
edit back immediately; the installed copies drift otherwise.

Swift sources carry a two-line `// Copyright` + `// Licensed under the Apache
License, Version 2.0` header; scripts, docs, and config files carry none. Match
whichever the neighbours use.
