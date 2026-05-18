// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Foundation

struct Session: Identifiable, Codable, Equatable {
    let sessionId: String
    var state: String
    let cwd: String
    let project: String
    let itermSessionId: String
    let timestamp: Date

    var id: String { sessionId }
    var isWaiting: Bool { state == "waiting" }

    var age: String {
        let minutes = Int(-timestamp.timeIntervalSinceNow / 60)
        if minutes < 1 { return "just now" }
        if minutes == 1 { return "1 min ago" }
        return "\(minutes) min ago"
    }

    // Extracts the UUID from ITERM_SESSION_ID format "w0t0p0:UUID" or "w0t0p0:UUID:depth"
    var itermUUID: String? {
        guard !itermSessionId.isEmpty else { return nil }
        let parts = itermSessionId.split(separator: ":")
        return parts.count >= 2 ? String(parts[1]) : itermSessionId
    }

    enum CodingKeys: String, CodingKey {
        case sessionId    = "session_id"
        case state
        case cwd
        case project
        case itermSessionId = "iterm_session_id"
        case timestamp
    }
}
