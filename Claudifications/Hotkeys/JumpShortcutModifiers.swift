// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Carbon.HIToolbox
import Foundation

/// The modifier-key combination used with digits 1–9 to jump to a waiting agent.
/// Shift-Command is deliberately not offered: ⇧⌘3/4/5 are the system screenshot
/// shortcuts and cannot be shadowed reliably.
enum JumpShortcutModifiers: String, CaseIterable, Identifiable {
    case optionCommand
    case controlOption
    case controlCommand
    case controlOptionCommand
    case off

    static let storageKey = "jumpShortcutModifiers"
    static let defaultValue: JumpShortcutModifiers = .optionCommand

    static var current: JumpShortcutModifiers {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return JumpShortcutModifiers(rawValue: raw) ?? defaultValue
    }

    var id: String { rawValue }

    /// Modifier symbols in canonical macOS order (⌃⌥⇧⌘).
    var symbols: String {
        switch self {
        case .optionCommand: return "⌥⌘"
        case .controlOption: return "⌃⌥"
        case .controlCommand: return "⌃⌘"
        case .controlOptionCommand: return "⌃⌥⌘"
        case .off: return ""
        }
    }

    var label: String {
        switch self {
        case .optionCommand: return "⌥⌘  Option-Command"
        case .controlOption: return "⌃⌥  Control-Option"
        case .controlCommand: return "⌃⌘  Control-Command"
        case .controlOptionCommand: return "⌃⌥⌘  Control-Option-Command"
        case .off: return "Off"
        }
    }

    /// Carbon modifier mask for RegisterEventHotKey, or nil when disabled.
    var carbonFlags: UInt32? {
        switch self {
        case .optionCommand: return UInt32(optionKey | cmdKey)
        case .controlOption: return UInt32(controlKey | optionKey)
        case .controlCommand: return UInt32(controlKey | cmdKey)
        case .controlOptionCommand: return UInt32(controlKey | optionKey | cmdKey)
        case .off: return nil
        }
    }
}
