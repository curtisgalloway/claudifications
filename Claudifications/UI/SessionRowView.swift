// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct SessionRowView: View {
    let session: Session
    let index: Int
    @Environment(SessionStore.self) private var store
    @State private var isHovered = false
    @AppStorage(JumpShortcutModifiers.storageKey)
    private var jumpModifiersRaw = JumpShortcutModifiers.defaultValue.rawValue

    private var shortcutHint: String? {
        let modifiers = JumpShortcutModifiers(rawValue: jumpModifiersRaw) ?? .defaultValue
        guard modifiers != .off, index < 9 else { return nil }
        return "\(modifiers.symbols)\(index + 1)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 245/255, green: 158/255, blue: 11/255))
                .frame(width: 8, height: 8)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.project)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .underline(isHovered)
                Text("\(session.cwd) • \(session.age)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.53))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture {
                store.dismiss(session)
                ITermBridge.jump(itermSessionId: session.itermSessionId)
            }

            if let hint = shortcutHint {
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.53))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                    )
                    .help("Press \(hint) to jump to this agent")
            }

            Button {
                store.dismiss(session)
            } label: {
                Text("✕")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.33))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .help("Dismiss")
        }
        .frame(height: 54)
        .background(isHovered ? Color.white.opacity(0.07) : .clear)
    }
}
