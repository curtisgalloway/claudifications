// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import Observation
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var store: SessionStore!
    private var soundPlayer: SoundPlayer!
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private var preferencesWindowController: PreferencesWindowController?
    private var hotkeyManager: HotkeyManager!

    private var installHooksItem: NSMenuItem!
    private var removeHooksItem: NSMenuItem!
    private var usageView: NSHostingView<UsageMenuView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = SessionStore()
        soundPlayer = SoundPlayer()
        panelController = PanelController()

        setupStatusItem()
        panelController.setup(store: store)

        store.onNewWaitingSession = { [weak self] in
            self?.soundPlayer.playNotification()
        }

        hotkeyManager = HotkeyManager()
        hotkeyManager.onJump = { [weak self] index in
            guard let self else { return }
            let waiting = self.store.waitingSessions
            guard index < waiting.count else { return }
            let session = waiting[index]
            self.store.dismiss(session)
            ITermBridge.jump(itermSessionId: session.itermSessionId)
        }
        hotkeyManager.start()

        store.start()
        observeStore()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
        store.stop()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button, let icon = NSImage(named: "MenuBarIcon") {
            let height: CGFloat = 20
            let aspect = icon.size.height > 0 ? icon.size.width / icon.size.height : 1
            icon.size = NSSize(width: height * aspect, height: height)
            icon.isTemplate = false
            icon.accessibilityDescription = "Claudifications"
            button.image = icon
        }

        let menu = NSMenu()
        menu.delegate = self

        usageView = NSHostingView(
            rootView: UsageMenuView(usage: nil, isStatusLineInstalled: false)
        )
        usageView.sizingOptions = [.intrinsicContentSize]
        resizeUsageView()
        let usageItem = NSMenuItem()
        usageItem.view = usageView
        usageItem.isEnabled = false
        menu.addItem(usageItem)
        menu.addItem(.separator())

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

        // Read on open rather than polling: the readout is only ever visible
        // while the menu is down, so a background timer would be wasted work.
        usageView.rootView = UsageMenuView(
            usage: PlanUsage.load(),
            isStatusLineInstalled: HookInstaller.isStatusLineInstalled
        )
        resizeUsageView()
    }

    /// NSMenu sizes a custom item from its view's frame, and reads that frame
    /// before SwiftUI has had a chance to lay out — so an intrinsic size alone
    /// leaves the item collapsed. Measure and set the frame explicitly instead.
    private func resizeUsageView() {
        usageView.layoutSubtreeIfNeeded()
        let height = usageView.fittingSize.height
        usageView.frame = NSRect(x: 0, y: 0, width: UsageMenuView.width, height: height)
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
        alert.informativeText = """
            Copies fleet-status.sh and usage-statusline.py to ~/.claude/hooks/, \
            then adds the hook entries and the plan-usage status line to \
            ~/.claude/settings.json.
            """
        alert.addButton(withTitle: installed ? "Reinstall" : "Install")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            if case .conflict(let existing) = try HookInstaller.install() {
                showStatusLineConflict(existing: existing)
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Claude Code supports exactly one status line, so an existing one is left
    /// in place — the plan-usage readout then needs wiring up by hand.
    private func showStatusLineConflict(existing: String) {
        let alert = NSAlert()
        alert.messageText = "Hooks installed — status line left alone"
        alert.informativeText = """
            You already have a status line configured:

                \(existing)

            Claude Code allows only one, so it was not replaced and the plan \
            usage readout will stay empty. To enable it, have your status line \
            also run:

                \(HookInstaller.statusLineCommand)
            """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func removeHooks() {
        let alert = NSAlert()
        alert.messageText = "Remove Claude Code hooks?"
        alert.informativeText = """
            Deletes fleet-status.sh and usage-statusline.py from ~/.claude/hooks/ \
            and removes the hook entries from ~/.claude/settings.json. The status \
            line is only cleared if it still points at Claudifications.
            """
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
