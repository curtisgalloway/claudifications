// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct PreferencesView: View {
    @AppStorage("notificationSound") private var selectedSound: String = SoundPlayer.defaultSound

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Picker("Sound", selection: $selectedSound) {
                        ForEach(SoundPlayer.availableSounds, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)

                    Button("Preview") {
                        SoundPlayer().play(named: selectedSound)
                    }
                    .disabled(selectedSound == SoundPlayer.noneOption)
                }
            } header: {
                Text("Notification Sound")
            }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 120)
    }
}
