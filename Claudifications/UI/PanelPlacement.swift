// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit

extension Notification.Name {
    /// Posted when the placement preference changes, so the panel can move
    /// straight away instead of waiting for the session list to change.
    static let panelPlacementDidChange = Notification.Name("panelPlacementDidChange")
}

/// A screen corner the floating panel can be anchored to. The panel keeps a
/// fixed inset from that corner's two edges and grows away from them, so the
/// spot it was put in stays put as sessions come and go.
enum PanelCorner: String, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }

    private var isLeading: Bool { self == .topLeft || self == .bottomLeft }
    private var isTop:     Bool { self == .topLeft || self == .topRight }

    /// Where a panel of `size` sits when anchored here, `inset` in from the
    /// corner's two edges of `visible`.
    func origin(size: NSSize, inset: CGSize, in visible: NSRect) -> NSPoint {
        NSPoint(
            x: isLeading ? visible.minX + inset.width
                         : visible.maxX - size.width - inset.width,
            y: isTop ? visible.maxY - size.height - inset.height
                     : visible.minY + inset.height
        )
    }

    /// The corner of `visible` that `frame` sits nearest, plus the inset that
    /// reproduces `frame` from it. Used to record where a drag ended.
    static func nearest(to frame: NSRect, in visible: NSRect) -> (corner: PanelCorner, inset: CGSize) {
        let leading = frame.midX < visible.midX
        let top = frame.midY >= visible.midY
        let corner: PanelCorner = top
            ? (leading ? .topLeft : .topRight)
            : (leading ? .bottomLeft : .bottomRight)
        let inset = CGSize(
            width:  leading ? frame.minX - visible.minX : visible.maxX - frame.maxX,
            height: top ? visible.maxY - frame.maxY : frame.minY - visible.minY
        )
        return (corner, inset)
    }
}

/// Where the panel sits: a corner, how far in from it, and which display.
/// Persisted so a dragged panel comes back where it was left.
struct PanelPlacement: Equatable {
    /// The margin the four corner presets pin the panel at. An inset that
    /// differs from this is one the user dragged to.
    static let presetInset = CGSize(width: 10, height: 10)

    static let `default` = PanelPlacement(corner: .topRight)

    var corner: PanelCorner
    var inset: CGSize = presetInset
    /// The display it was placed on, or nil to follow the main screen.
    var displayID: CGDirectDisplayID?

    enum Key {
        static let corner = "panelCorner"
        static let insetX = "panelInsetX"
        static let insetY = "panelInsetY"
        static let display = "panelDisplayID"
    }

    /// True when the panel was dragged rather than snapped to a preset.
    static func isCustom(insetX: Double, insetY: Double) -> Bool {
        insetX != presetInset.width || insetY != presetInset.height
    }

    static func load(from defaults: UserDefaults = .standard) -> PanelPlacement {
        let corner = (defaults.string(forKey: Key.corner)
            .flatMap(PanelCorner.init(rawValue:))) ?? Self.default.corner
        // `object(forKey:)` rather than `double(forKey:)` so an absent key
        // falls back to the preset margin instead of pinning to zero.
        let x = defaults.object(forKey: Key.insetX) as? Double ?? presetInset.width
        let y = defaults.object(forKey: Key.insetY) as? Double ?? presetInset.height
        let display = defaults.object(forKey: Key.display) as? NSNumber
        return PanelPlacement(
            corner: corner,
            inset: CGSize(width: x, height: y),
            displayID: display?.uint32Value
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(corner.rawValue, forKey: Key.corner)
        defaults.set(Double(inset.width), forKey: Key.insetX)
        defaults.set(Double(inset.height), forKey: Key.insetY)
        if let displayID {
            defaults.set(NSNumber(value: displayID), forKey: Key.display)
        } else {
            defaults.removeObject(forKey: Key.display)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
