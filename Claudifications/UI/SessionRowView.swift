// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct SessionRowView: View {
    let session: Session
    @Environment(SessionStore.self) private var store
    @State private var isHovered = false

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
