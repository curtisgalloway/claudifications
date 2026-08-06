// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Foundation

/// Account-wide Claude.ai subscription usage, as reported by Claude Code's
/// status line payload and persisted by usage-statusline.py.
///
/// Claude Code only puts `rate_limits` in that payload for subscribers, and
/// only after a session's first API response — so this can legitimately be
/// missing even when everything is installed correctly.
struct PlanUsage: Equatable {
    struct Window: Equatable {
        let usedPercentage: Double
        let resetsAt: Date

        /// False once `resetsAt` has passed: the window rolled over after this
        /// sample was taken, so the recorded percentage no longer describes it.
        func isCurrent(asOf now: Date = Date()) -> Bool { resetsAt > now }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let updatedAt: Date

    var hasReading: Bool { fiveHour != nil || sevenDay != nil }

    /// The status line only runs while a session is on screen, so the file goes
    /// quiet whenever no session is open. Past this age the numbers are shown
    /// dimmed rather than presented as live.
    private static let staleInterval: TimeInterval = 15 * 60

    func isStale(asOf now: Date = Date()) -> Bool {
        now.timeIntervalSince(updatedAt) > Self.staleInterval
    }

    // MARK: - Loading

    /// Deliberately outside ~/.claude/fleet-status/: `SessionStore` sweeps that
    /// directory and deletes every .json that isn't a valid session record.
    static let file = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claudifications/usage.json")

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    static func load() -> PlanUsage? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? decoder.decode(PlanUsage.self, from: data)
    }
}

extension PlanUsage: Decodable {
    enum CodingKeys: String, CodingKey {
        case fiveHour  = "five_hour"
        case sevenDay  = "seven_day"
        case updatedAt = "updated_at"
    }
}

extension PlanUsage.Window: Decodable {
    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt       = "resets_at"
    }
}
