// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import AppKit
import Foundation

final class SoundPlayer {
    static let noneOption = "None"

    static let availableSounds: [String] = {
        let url = URL(fileURLWithPath: "/System/Library/Sounds")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        )) ?? []
        let names = files
            .filter { $0.pathExtension.lowercased() == "aiff" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        return [noneOption] + names
    }()

    static var defaultSound: String {
        // Prefer Funk; fall back to first available non-None sound.
        if availableSounds.contains("Funk") { return "Funk" }
        return availableSounds.first(where: { $0 != noneOption }) ?? noneOption
    }

    func playNotification() {
        let name = UserDefaults.standard.string(forKey: "notificationSound")
                   ?? SoundPlayer.defaultSound
        play(named: name)
    }

    func play(named name: String) {
        guard name != SoundPlayer.noneOption else { return }
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        NSSound(contentsOf: url, byReference: false)?.play()
    }
}
