// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit

@MainActor
enum ITermBridge {
    static func jump(itermSessionId: String) {
        guard !itermSessionId.isEmpty,
              let uuid = extractUUID(from: itermSessionId) else {
            activate()
            return
        }

        let script = """
            tell application "iTerm2"
                repeat with aWindow in windows
                    repeat with aTab in tabs of aWindow
                        repeat with aSession in sessions of aTab
                            if unique id of aSession is "\(uuid)" then
                                select aWindow
                                tell aTab to select
                                tell aSession to select
                                activate
                                return
                            end if
                        end repeat
                    end repeat
                end repeat
                activate
            end tell
            """
        run(script)
    }

    private static func activate() {
        run(#"tell application "iTerm2" to activate"#)
    }

    private static func extractUUID(from itermId: String) -> String? {
        let parts = itermId.split(separator: ":")
        guard parts.count >= 2 else { return itermId.isEmpty ? nil : itermId }
        return String(parts[1])
    }

    private static func run(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            print("[ITermBridge] AppleScript error: \(error)")
        }
    }
}
