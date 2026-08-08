// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys (modifiers + 1…9) that jump to the Nth waiting
/// session. Uses Carbon RegisterEventHotKey, which works system-wide without
/// requiring Accessibility permission. Re-registers automatically when the
/// modifier preference changes.
final class HotkeyManager {
    /// Called on the main queue with the 0-based index into waitingSessions.
    var onJump: ((Int) -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var defaultsObserver: NSObjectProtocol?
    private var registeredModifiers: JumpShortcutModifiers?

    private static let signature: OSType = 0x436C_6679 // "Clfy"

    // Virtual key codes for the digit row, 1 through 9.
    private static let digitKeyCodes: [UInt32] = [
        UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3),
        UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6),
        UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9),
    ]

    func start() {
        installEventHandler()
        register(JumpShortcutModifiers.current)

        // UserDefaults.didChangeNotification fires on every defaults write, so
        // compare against what is currently registered before churning.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let current = JumpShortcutModifiers.current
            if current != self.registeredModifiers {
                self.unregister()
                self.register(current)
            }
        }
    }

    func stop() {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }

    // MARK: - Registration

    private func register(_ modifiers: JumpShortcutModifiers) {
        registeredModifiers = modifiers
        guard let flags = modifiers.carbonFlags else { return }
        for (index, keyCode) in Self.digitKeyCodes.enumerated() {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(keyCode, flags, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            // Not worth surfacing: `status` only reports eventHotKeyExistsErr for
            // a duplicate registration inside this process, and returns noErr when
            // another application already owns the combination. It cannot be used
            // to warn about conflicts — JumpShortcutModifiers.conflictingApps
            // carries what is actually known.
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
            }
        }
    }

    private func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    // MARK: - Event handling

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard hotKeyID.signature == HotkeyManager.signature else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                let index = Int(hotKeyID.id) - 1
                DispatchQueue.main.async {
                    manager.onJump?(index)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
