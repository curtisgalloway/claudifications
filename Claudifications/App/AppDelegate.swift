// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: SessionStore!
    private var soundPlayer: SoundPlayer!
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private var preferencesWindowController: PreferencesWindowController?

    private var installHooksItem: NSMenuItem!
    private var removeHooksItem: NSMenuItem!

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
        menu.delegate = self

        menu.addItem(NSMenuItem(title: "About Claudifications", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(.separator())

        installHooksItem = NSMenuItem(title: "Install Hooks…", action: #selector(installHooks), keyEquivalent: "")
        menu.addItem(installHooksItem)

        removeHooksItem = NSMenuItem(title: "Remove Hooks", action: #selector(removeHooks), keyEquivalent: "")
        menu.addItem(removeHooksItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        let installed = HookInstaller.isInstalled
        installHooksItem.title = installed ? "Reinstall Hooks" : "Install Hooks…"
        removeHooksItem.isEnabled = installed
    }

    // MARK: - Actions

    @objc private func showAbout() {
        let tagline = NSAttributedString(
            string: "Organize your Claude notifications",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: tagline])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func installHooks() {
        let installed = HookInstaller.isInstalled
        let alert = NSAlert()
        alert.messageText = installed ? "Reinstall Claude Code hooks?" : "Install Claude Code hooks?"
        alert.informativeText = "Copies fleet-status.sh to ~/.claude/hooks/ and adds hook entries to ~/.claude/settings.json."
        alert.addButton(withTitle: installed ? "Reinstall" : "Install")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try HookInstaller.install()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func removeHooks() {
        let alert = NSAlert()
        alert.messageText = "Remove Claude Code hooks?"
        alert.informativeText = "Deletes fleet-status.sh from ~/.claude/hooks/ and removes the hook entries from ~/.claude/settings.json."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[0].hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try HookInstaller.remove()
        } catch {
            NSAlert(error: error).runModal()
        }
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
