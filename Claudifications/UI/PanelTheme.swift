// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

/// The appearance preference for the floating panel: follow the system,
/// or force light/dark.
enum PanelAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "panelAppearance"
    static let defaultValue: PanelAppearance = .system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// The color scheme to force, or nil to follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The panel's color palette, resolved from the effective color scheme.
struct PanelPalette {
    let background: Color
    let primaryText: Color
    let secondaryText: Color
    let headerDismiss: Color
    let rowDismiss: Color
    let separator: Color
    let hover: Color
    let badgeBackground: Color

    static func palette(for scheme: ColorScheme) -> PanelPalette {
        scheme == .light ? .light : .dark
    }

    static let dark = PanelPalette(
        background: Color(red: 44/255, green: 44/255, blue: 48/255, opacity: 0.97),
        primaryText: .white,
        secondaryText: Color(white: 0.53),
        headerDismiss: Color(white: 0.4),
        rowDismiss: Color(white: 0.33),
        separator: Color.white.opacity(0.08),
        hover: Color.white.opacity(0.07),
        badgeBackground: Color.white.opacity(0.08)
    )

    static let light = PanelPalette(
        background: Color(red: 246/255, green: 246/255, blue: 248/255, opacity: 0.97),
        primaryText: Color(white: 0.1),
        secondaryText: Color(white: 0.42),
        headerDismiss: Color(white: 0.5),
        rowDismiss: Color(white: 0.6),
        separator: Color.black.opacity(0.1),
        hover: Color.black.opacity(0.05),
        badgeBackground: Color.black.opacity(0.06)
    )
}

/// Root view for the floating panel: applies the appearance preference as a
/// color-scheme override (or follows the system when set to .system).
struct PanelRootView: View {
    @AppStorage(PanelAppearance.storageKey)
    private var appearanceRaw = PanelAppearance.defaultValue.rawValue

    var body: some View {
        let appearance = PanelAppearance(rawValue: appearanceRaw) ?? .defaultValue
        if let scheme = appearance.colorScheme {
            SessionListView().environment(\.colorScheme, scheme)
        } else {
            SessionListView()
        }
    }
}
