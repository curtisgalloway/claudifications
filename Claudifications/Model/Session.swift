// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Foundation

struct Session: Identifiable, Codable, Equatable {
    let sessionId: String
    var state: String
    let cwd: String
    let project: String
    /// Absent from records written by hooks older than the branch label, and
    /// empty when the session isn't in a git repo.
    let branch: String?
    let itermSessionId: String
    let timestamp: Date

    var id: String { sessionId }
    var isWaiting: Bool { state == "waiting" }

    /// The branch to show beside the project name, or nil when there is none
    /// worth showing.
    var displayBranch: String? {
        guard let branch, !branch.isEmpty else { return nil }
        return branch
    }

    var age: String {
        let minutes = Int(-timestamp.timeIntervalSinceNow / 60)
        if minutes < 1 { return "just now" }
        if minutes == 1 { return "1 min ago" }
        return "\(minutes) min ago"
    }

    enum CodingKeys: String, CodingKey {
        case sessionId    = "session_id"
        case state
        case cwd
        case project
        case branch
        case itermSessionId = "iterm_session_id"
        case timestamp
    }
}
