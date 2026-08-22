// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import Sparkle
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    convenience init(updater: SPUUpdater) {
        // Size the window from the form rather than a guessed contentRect: a
        // window shorter than its content is what puts a scroll bar on it.
        let content = NSHostingView(rootView: PreferencesView(updater: updater))
        content.layoutSubtreeIfNeeded()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: content.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claudifications"
        window.contentView = content
        window.center()
        self.init(window: window)
    }
}
