// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: FloatingPanel?
    private var placement = PanelPlacement.load()
    private var sessionCount = 0
    /// The frame we set ourselves. A `windowDidMove` reporting anything else is
    /// the user dragging the panel; one that matches is our own resize.
    private var appliedFrame: NSRect?
    private var observers: [NSObjectProtocol] = []

    private static let width:        CGFloat = 340
    private static let itemHeight:   CGFloat = 54
    private static let headerHeight: CGFloat = 34

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func setup(store: SessionStore) {
        let rootView = PanelRootView().environment(store)
        let panel = FloatingPanel(rootView: rootView)
        panel.delegate = self
        self.panel = panel

        observe(.panelPlacementDidChange) { [weak self] in
            self?.placement = .load()
            self?.reposition()
        }
        // A disconnected display would otherwise strand the panel off screen.
        observe(NSApplication.didChangeScreenParametersNotification) { [weak self] in
            self?.reposition()
        }
    }

    func update(sessionCount: Int) {
        self.sessionCount = sessionCount
        guard let panel else { return }
        if sessionCount == 0 {
            panel.orderOut(nil)
            return
        }
        // Defer setFrame to the next run loop pass to avoid triggering
        // layoutSubtreeIfNeeded while SwiftUI is already mid-layout.
        DispatchQueue.main.async { [weak self] in
            self?.applyFrame(revealing: true)
        }
    }

    // MARK: - NSWindowDelegate

    /// Remember where the user dragged the panel to, as an inset from whichever
    /// screen corner it landed nearest, so the list still grows inward from
    /// there and the spot survives a resolution change.
    func windowDidMove(_ notification: Notification) {
        guard let panel, panel.frame != appliedFrame else { return }
        let screen = panel.screen ?? placementScreen
        let (corner, inset) = PanelCorner.nearest(to: panel.frame, in: screen.visibleFrame)
        placement = PanelPlacement(corner: corner, inset: inset, displayID: screen.displayID)
        placement.save()
        appliedFrame = panel.frame
    }

    // MARK: - Placement

    private func reposition() {
        applyFrame(revealing: false)
    }

    private func applyFrame(revealing: Bool) {
        guard let panel, sessionCount > 0 else { return }
        let frame = targetFrame(count: sessionCount)
        appliedFrame = frame
        panel.setFrame(frame, display: false, animate: false)
        if revealing, !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func targetFrame(count: Int) -> NSRect {
        let size = NSSize(
            width: Self.width,
            height: Self.headerHeight + CGFloat(count) * Self.itemHeight
        )
        let visible = placementScreen.visibleFrame
        let origin = placement.corner.origin(size: size, inset: placement.inset, in: visible)
        return NSRect(origin: origin, size: size).nudged(into: visible)
    }

    /// The display the placement was recorded on, falling back to the main
    /// screen once that display is gone.
    private var placementScreen: NSScreen {
        let stored = placement.displayID.flatMap { id in
            NSScreen.screens.first { $0.displayID == id }
        }
        return stored ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func observe(_ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
        let token = NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in handler() }
        }
        observers.append(token)
    }
}

private extension NSRect {
    /// Slid back inside `bounds` when it would otherwise hang off an edge —
    /// a long session list, or a display that got smaller.
    func nudged(into bounds: NSRect) -> NSRect {
        var rect = self
        rect.origin.x = min(max(minX, bounds.minX), max(bounds.minX, bounds.maxX - width))
        rect.origin.y = min(max(minY, bounds.minY), max(bounds.minY, bounds.maxY - height))
        return rect
    }
}
