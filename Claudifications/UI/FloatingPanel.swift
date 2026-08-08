// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        contentView = NSHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Makes whatever it backs a drag handle for the panel. The hosting view
/// swallows the background drag `isMovableByWindowBackground` would otherwise
/// pick up, so the header hands the drag to AppKit itself.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
