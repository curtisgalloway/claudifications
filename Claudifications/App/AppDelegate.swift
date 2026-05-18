// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: SessionStore!
    private var soundPlayer: SoundPlayer!
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = SessionStore()
        soundPlayer = SoundPlayer()
        panelController = PanelController()

        setupStatusItem()
        panelController.setup(store: store)

        store.onNewWaitingSession = { [weak self] in
            self?.soundPlayer.playNotification()
        }

        store.start()
        observeStore()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Claudifications")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Store observation

    @MainActor private func observeStore() {
        withObservationTracking {
            let count = store.waitingSessions.count
            panelController.update(sessionCount: count)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeStore()
            }
        }
    }
}
