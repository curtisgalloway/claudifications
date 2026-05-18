// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private var panel: FloatingPanel?

    private static let width:        CGFloat = 340
    private static let itemHeight:   CGFloat = 54
    private static let headerHeight: CGFloat = 34

    func setup(store: SessionStore) {
        let rootView = SessionListView().environment(store)
        panel = FloatingPanel(rootView: rootView)
    }

    func update(sessionCount: Int) {
        guard let panel else { return }
        if sessionCount == 0 {
            panel.orderOut(nil)
            return
        }
        let frame = targetFrame(count: sessionCount)
        panel.setFrame(frame, display: true, animate: false)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func targetFrame(count: Int) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let sf = screen.visibleFrame
        let h = Self.headerHeight + CGFloat(count) * Self.itemHeight
        return NSRect(
            x: sf.maxX - Self.width - 10,
            y: sf.maxY - h - 10,
            width: Self.width,
            height: h
        )
    }
}
