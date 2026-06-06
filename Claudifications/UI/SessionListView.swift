// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct SessionListView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    private var palette: PanelPalette { .palette(for: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(store.waitingSessions.enumerated()), id: \.element.id) { index, session in
                SessionRowView(session: session, index: index)
                if index < store.waitingSessions.count - 1 {
                    Divider()
                        .overlay(palette.separator)
                        .padding(.leading, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack {
            Text("Claude Agents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .textCase(.uppercase)
                .kerning(0.7)
            Spacer()
            Button {
                store.dismissAll()
            } label: {
                Text("✕")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.headerDismiss)
            }
            .buttonStyle(.plain)
            .help("Dismiss all")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.separator)
                .frame(height: 1)
        }
    }
}
