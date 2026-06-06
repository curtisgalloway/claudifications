// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Foundation

enum HookInstaller {
    private static let fm = FileManager.default
    private static let home = fm.homeDirectoryForCurrentUser
    static let hookDir = home.appendingPathComponent(".claude/hooks")
    static let hookFile = hookDir.appendingPathComponent("fleet-status.sh")
    static let settingsFile = home.appendingPathComponent(".claude/settings.json")

    static var isInstalled: Bool {
        fm.fileExists(atPath: hookFile.path)
    }

    static func install() throws {
        guard let src = Bundle.main.url(forResource: "fleet-status", withExtension: "sh") else {
            throw HookError.bundleResourceMissing
        }
        try fm.createDirectory(at: hookDir, withIntermediateDirectories: true)
        if fm.fileExists(atPath: hookFile.path) {
            try fm.removeItem(at: hookFile)
        }
        try fm.copyItem(at: src, to: hookFile)
        try fm.setAttributes([.posixPermissions: Int(0o755)], ofItemAtPath: hookFile.path)
        try mergeSettings(adding: true)
    }

    static func remove() throws {
        if fm.fileExists(atPath: hookFile.path) {
            try fm.removeItem(at: hookFile)
        }
        try mergeSettings(adding: false)
    }

    private static let hookEntries: [(event: String, command: String)] = [
        ("Stop",             "~/.claude/hooks/fleet-status.sh waiting"),
        ("Notification",     "~/.claude/hooks/fleet-status.sh waiting"),
        ("PreToolUse",       "~/.claude/hooks/fleet-status.sh working"),
        ("UserPromptSubmit", "~/.claude/hooks/fleet-status.sh working"),
        ("SessionEnd",       "~/.claude/hooks/fleet-status.sh ended"),
    ]

    private static func mergeSettings(adding: Bool) throws {
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

        var data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        data.append(UInt8(ascii: "\n"))
        try data.write(to: settingsFile)
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
