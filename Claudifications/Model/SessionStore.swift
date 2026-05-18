// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Foundation
import Observation

@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []
    var onNewWaitingSession: (() -> Void)?

    private let statusDir: URL
    private var pollTimer: DispatchSourceTimer?
    private var previousWaitingCount = 0

    private static let staleInterval: TimeInterval = 8 * 3600
    private static let pollInterval: TimeInterval = 0.5

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        statusDir = home.appendingPathComponent(".claude/fleet-status")
    }

    var waitingSessions: [Session] {
        sessions.filter { $0.isWaiting }.sorted { $0.timestamp < $1.timestamp }
    }

    func start() {
        try? FileManager.default.createDirectory(at: statusDir, withIntermediateDirectories: true)
        reload()
        startPolling()
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    func dismiss(_ session: Session) {
        write(session: session, state: "dismissed")
    }

    func dismissAll() {
        for s in waitingSessions { dismiss(s) }
    }

    func reload() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: statusDir, includingPropertiesForKeys: nil) else { return }

        let cutoff = Date().addingTimeInterval(-Self.staleInterval)
        var loaded: [Session] = []

        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let session = try? Self.decoder.decode(Session.self, from: data) else {
                try? fm.removeItem(at: url)
                continue
            }
            if session.timestamp < cutoff {
                try? fm.removeItem(at: url)
                continue
            }
            loaded.append(session)
        }

        let newCount = loaded.filter { $0.isWaiting }.count

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.sessions = loaded
            if newCount > self.previousWaitingCount {
                self.onNewWaitingSession?()
            }
            self.previousWaitingCount = newCount
        }
    }

    private func write(session: Session, state: String) {
        var updated = session
        updated.state = state
        let path = statusDir.appendingPathComponent("\(session.sessionId).json")
        if let data = try? Self.encoder.encode(updated) {
            try? data.write(to: path)
        }
        reload()
    }

    // Uses a timer rather than a directory kqueue watcher because kqueue NOTE_WRITE
    // on a directory only fires for directory-entry changes (create/delete/rename),
    // not for overwrites of existing files. Since the hook overwrites the same
    // <session_id>.json when state changes (working → waiting), a directory watcher
    // misses those transitions. A 500ms poll picks them up reliably.
    private func startPolling() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + Self.pollInterval, repeating: Self.pollInterval)
        timer.setEventHandler { [weak self] in
            self?.reload()
        }
        timer.resume()
        pollTimer = timer
    }
}
