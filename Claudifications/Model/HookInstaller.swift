// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Foundation

enum HookInstaller {
    private static let fm = FileManager.default
    private static let home = fm.homeDirectoryForCurrentUser
    static let hookDir = home.appendingPathComponent(".claude/hooks")
    static let hookFile = hookDir.appendingPathComponent("fleet-status.sh")
    static let statusLineFile = hookDir.appendingPathComponent("usage-statusline.py")
    static let settingsFile = home.appendingPathComponent(".claude/settings.json")

    static let statusLineCommand = "~/.claude/hooks/usage-statusline.py"

    /// What happened to the `statusLine` slot in settings.json. Claude Code
    /// allows exactly one status line, so an existing third-party one is left
    /// untouched and reported back for the caller to surface.
    enum StatusLineOutcome: Equatable {
        case installed
        case removed
        case unchanged
        case conflict(existing: String)
    }

    static var isInstalled: Bool {
        fm.fileExists(atPath: hookFile.path)
    }

    /// True only when both halves are in place: the script on disk *and* the
    /// settings.json entry pointing at it.
    static var isStatusLineInstalled: Bool {
        fm.fileExists(atPath: statusLineFile.path) && isOurStatusLine(configuredStatusLineCommand)
    }

    @discardableResult
    static func install() throws -> StatusLineOutcome {
        guard let hookSrc = Bundle.main.url(forResource: "fleet-status", withExtension: "sh"),
              let statusSrc = Bundle.main.url(forResource: "usage-statusline", withExtension: "py") else {
            throw HookError.bundleResourceMissing
        }
        try fm.createDirectory(at: hookDir, withIntermediateDirectories: true)
        try copy(hookSrc, to: hookFile)
        try copy(statusSrc, to: statusLineFile)
        return try mergeSettings(adding: true)
    }

    static func remove() throws {
        for file in [hookFile, statusLineFile] where fm.fileExists(atPath: file.path) {
            try fm.removeItem(at: file)
        }
        try mergeSettings(adding: false)
    }

    private static func copy(_ src: URL, to dest: URL) throws {
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: src, to: dest)
        try fm.setAttributes([.posixPermissions: Int(0o755)], ofItemAtPath: dest.path)
    }

    private static let hookEntries: [(event: String, command: String)] = [
        ("Stop",             "~/.claude/hooks/fleet-status.sh waiting"),
        ("Notification",     "~/.claude/hooks/fleet-status.sh waiting"),
        ("PreToolUse",       "~/.claude/hooks/fleet-status.sh working"),
        ("UserPromptSubmit", "~/.claude/hooks/fleet-status.sh working"),
        ("SessionEnd",       "~/.claude/hooks/fleet-status.sh ended"),
    ]

    private static var configuredStatusLineCommand: String? {
        guard let data = try? Data(contentsOf: settingsFile),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusLine = parsed["statusLine"] as? [String: Any] else { return nil }
        return statusLine["command"] as? String
    }

    private static func isOurStatusLine(_ command: String?) -> Bool {
        command?.contains("usage-statusline.py") == true
    }

    @discardableResult
    private static func mergeSettings(adding: Bool) throws -> StatusLineOutcome {
        var settings: [String: Any] = [:]
        if fm.fileExists(atPath: settingsFile.path),
           let data = try? Data(contentsOf: settingsFile),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = parsed
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        for (event, command) in hookEntries {
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.removeAll { isFleetEntry($0) }
            if adding {
                entries.append(["hooks": [["type": "command", "command": command]]])
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = entries
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        let existing = settings["statusLine"] as? [String: Any]
        let existingCommand = existing?["command"] as? String
        var outcome: StatusLineOutcome = .unchanged

        if adding {
            if existing == nil || isOurStatusLine(existingCommand) {
                settings["statusLine"] = ["type": "command", "command": statusLineCommand]
                outcome = .installed
            } else {
                // Someone else owns the single statusLine slot. Never overwrite
                // it — report back so the user can chain the two by hand.
                outcome = .conflict(existing: existingCommand ?? "a custom status line")
            }
        } else if isOurStatusLine(existingCommand) {
            settings.removeValue(forKey: "statusLine")
            outcome = .removed
        }

        var data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        data.append(UInt8(ascii: "\n"))
        try data.write(to: settingsFile)
        return outcome
    }

    private static func isFleetEntry(_ entry: [String: Any]) -> Bool {
        guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { ($0["command"] as? String)?.contains("fleet-status.sh") == true }
    }

    enum HookError: LocalizedError {
        case bundleResourceMissing
        var errorDescription: String? { "fleet-status.sh not found in app bundle" }
    }
}
