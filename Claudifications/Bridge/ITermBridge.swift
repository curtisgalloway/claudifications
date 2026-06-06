// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit

@MainActor
enum ITermBridge {
    private static let bundleID = "com.googlecode.iterm2"

    /// Reveals the session via iTerm2's URL scheme, which accepts the full
    /// ITERM_SESSION_ID ("w0t0p0:UUID") directly. Falls back to just
    /// activating iTerm2 when no session id is available.
    static func jump(itermSessionId: String) {
        guard !itermSessionId.isEmpty, let url = revealURL(for: itermSessionId) else {
            activate()
            return
        }
        NSWorkspace.shared.open(url)
        // Reveal selects the window/tab/pane but is not guaranteed to raise
        // a minimized window; an explicit activate covers that case.
        activate()
    }

    private static func revealURL(for itermSessionId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "iterm2"
        components.host = ""
        components.path = "/reveal"
        components.queryItems = [URLQueryItem(name: "sessionid", value: itermSessionId)]
        return components.url
    }

    private static func activate() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
