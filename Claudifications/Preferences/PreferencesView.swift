// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct PreferencesView: View {
    @AppStorage("notificationSound") private var selectedSound: String = SoundPlayer.defaultSound
    @AppStorage(JumpShortcutModifiers.storageKey)
    private var jumpModifiersRaw = JumpShortcutModifiers.defaultValue.rawValue
    @AppStorage(PanelAppearance.storageKey)
    private var appearanceRaw = PanelAppearance.defaultValue.rawValue

    private var jumpModifiers: JumpShortcutModifiers {
        JumpShortcutModifiers(rawValue: jumpModifiersRaw) ?? .defaultValue
    }

    var body: some View {
        Form {
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
                    Text("Press \(jumpModifiers.symbols)1 through \(jumpModifiers.symbols)9 anywhere to jump to the matching agent in the list.")
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
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 320)
    }
}
