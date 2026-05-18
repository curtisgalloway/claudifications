// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct SessionListView: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(store.waitingSessions.enumerated()), id: \.element.id) { index, session in
                SessionRowView(session: session)
                if index < store.waitingSessions.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.leading, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 44/255, green: 44/255, blue: 48/255, opacity: 0.97))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack {
            Text("Claude Agents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.53))
                .textCase(.uppercase)
                .kerning(0.7)
            Spacer()
            Button {
                store.dismissAll()
            } label: {
                Text("✕")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.4))
            }
            .buttonStyle(.plain)
            .help("Dismiss all")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}
