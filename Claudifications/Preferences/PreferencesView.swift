// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import Sparkle
import SwiftUI

struct PreferencesView: View {
    let updater: SPUUpdater
    @State private var automaticallyChecksForUpdates: Bool

    @AppStorage("notificationSound") private var selectedSound: String = SoundPlayer.defaultSound
    @AppStorage(JumpShortcutModifiers.storageKey)
    private var jumpModifiersRaw = JumpShortcutModifiers.defaultValue.rawValue
    @AppStorage(PanelAppearance.storageKey)
    private var appearanceRaw = PanelAppearance.defaultValue.rawValue
    @AppStorage(PanelPlacement.Key.corner)
    private var cornerRaw = PanelPlacement.default.corner.rawValue
    @AppStorage(PanelPlacement.Key.insetX)
    private var insetX = Double(PanelPlacement.presetInset.width)
    @AppStorage(PanelPlacement.Key.insetY)
    private var insetY = Double(PanelPlacement.presetInset.height)

    /// Stands in for "wherever you dragged it" — a placement no corner preset
    /// can express, so it is shown as the selection but never chosen from here.
    private static let customTag = "custom"

    init(updater: SPUUpdater) {
        self.updater = updater
        _automaticallyChecksForUpdates = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    private var jumpModifiers: JumpShortcutModifiers {
        JumpShortcutModifiers(rawValue: jumpModifiersRaw) ?? .defaultValue
    }

    private var isCustomPosition: Bool {
        PanelPlacement.isCustom(insetX: insetX, insetY: insetY)
    }

    /// Picking a corner snaps the panel back to the preset margin, discarding
    /// whatever inset a drag had left behind.
    private var position: Binding<String> {
        let corner = $cornerRaw, x = $insetX, y = $insetY
        let isCustom = isCustomPosition
        return Binding(
            get: { isCustom ? Self.customTag : corner.wrappedValue },
            set: { selected in
                guard selected != Self.customTag else { return }
                corner.wrappedValue = selected
                x.wrappedValue = Double(PanelPlacement.presetInset.width)
                y.wrappedValue = Double(PanelPlacement.presetInset.height)
                NotificationCenter.default.post(name: .panelPlacementDidChange, object: nil)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                        updater.automaticallyChecksForUpdates = newValue
                    }
            } header: {
                Text("Updates")
            }

            Section {
                HStack(spacing: 8) {
                    Picker("Sound", selection: $selectedSound) {
                        ForEach(SoundPlayer.availableSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    .onChange(of: selectedSound) { _, newValue in
                        SoundPlayer().play(named: newValue)
                    }

                    Button {
                        SoundPlayer().play(named: selectedSound)
                    } label: {
                        Image(systemName: "play.circle")
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedSound == SoundPlayer.noneOption)
                    .help("Play sound")
                }
            } header: {
                Text("Notification Sound")
            }

            Section {
                Picker("Modifier keys", selection: $jumpModifiersRaw) {
                    ForEach(JumpShortcutModifiers.allCases) { modifiers in
                        Text(modifiers.label).tag(modifiers.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 240)
            } header: {
                Text("Jump Shortcut")
            } footer: {
                if jumpModifiers != .off {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Press \(jumpModifiers.symbols)1 through \(jumpModifiers.symbols)9 anywhere to jump to the matching agent in the list.")
                        if let note = jumpModifiers.conflictNote {
                            Text("\(note) A global shortcut takes those over while Claudifications is running.")
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Theme", selection: $appearanceRaw) {
                    ForEach(PanelAppearance.allCases) { appearance in
                        Text(appearance.label).tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            } header: {
                Text("Appearance")
            }

            Section {
                Picker("Position", selection: position) {
                    ForEach(PanelCorner.allCases) { corner in
                        Text(corner.label).tag(corner.rawValue)
                    }
                    if isCustomPosition {
                        Divider()
                        Text("Custom (dragged)").tag(Self.customTag)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 260)
            } header: {
                Text("Panel Position")
            } footer: {
                Text("Drag the panel by its header to put it anywhere; it comes back where you left it.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}
