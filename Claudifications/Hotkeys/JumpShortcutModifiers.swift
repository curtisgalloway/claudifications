// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Carbon.HIToolbox
import Foundation

/// The modifier-key combination used with digits 1–9 to jump to a waiting agent.
/// Shift-Command is deliberately not offered: ⇧⌘3/4/5 are the system screenshot
/// shortcuts and cannot be shadowed reliably.
///
/// Control-Option is the default because it is the only one of the four that no
/// common app already binds to 1–9 — see `conflictingApps`. There is no way to
/// discover this at runtime: `RegisterEventHotKey` reports `eventHotKeyExistsErr`
/// only for a duplicate within the same process, so it stays silent when another
/// application owns the combination.
enum JumpShortcutModifiers: String, CaseIterable, Identifiable {
    case optionCommand
    case controlOption
    case controlCommand
    case controlOptionCommand
    case off

    static let storageKey = "jumpShortcutModifiers"
    static let defaultValue: JumpShortcutModifiers = .controlOption

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

    /// Apps that already bind this combination to 1–9, so registering it here
    /// takes those commands over while Claudifications runs. Read off the menu
    /// bars of the stock apps rather than guessed — but it is a snapshot of a
    /// few apps, not an exhaustive list, so it reads as a caution.
    var conflictingApps: [String] {
        switch self {
        case .optionCommand: return ["Preview", "Messages", "Finder"]
        case .controlCommand: return ["Finder", "Messages", "Xcode"]
        case .controlOptionCommand: return ["Finder"]
        case .controlOption, .off: return []
        }
    }

    /// One-line caution for the picker, or nil when nothing is known to clash.
    var conflictNote: String? {
        let apps = conflictingApps
        guard !apps.isEmpty else { return nil }
        return "\(symbols)1–9 is already used by \(apps.formatted(.list(type: .and)))."
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
