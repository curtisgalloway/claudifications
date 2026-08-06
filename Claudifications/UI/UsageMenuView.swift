// Copyright 2025 Curtis Galloway
// Licensed under the Apache License, Version 2.0

import SwiftUI

/// Plan-usage readout embedded at the top of the menu bar dropdown.
///
/// Uses semantic colors rather than `PanelPalette`: menus always follow the
/// system appearance, regardless of the panel's own appearance preference.
struct UsageMenuView: View {
    let usage: PlanUsage?
    let isStatusLineInstalled: Bool

    static let width: CGFloat = 262

    private let now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let usage, usage.hasReading {
                // Labels mirror /usage's own wording so the two can be read
                // against each other. Its third row, "Current week (Fable)",
                // has no equivalent in the status line payload.
                VStack(alignment: .leading, spacing: 9) {
                    if let w = usage.fiveHour { row(title: "Current session", window: w) }
                    if let w = usage.sevenDay { row(title: "Current week (all models)", window: w) }
                }
                .opacity(usage.isStale(asOf: now) ? 0.5 : 1)
            } else {
                placeholder
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(width: Self.width, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Plan Usage")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let usage, usage.hasReading {
                Text(Self.ageLabel(since: usage.updatedAt, now: now))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 7)
    }

    private func row(title: String, window: PlanUsage.Window) -> some View {
        let current = window.isCurrent(asOf: now)
        let tint = Self.tint(for: window.usedPercentage)
        let fraction = current ? min(max(window.usedPercentage / 100, 0), 1) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Text(current ? "\(Int(window.usedPercentage.rounded()))%" : "—")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(current ? tint : Color.secondary)
            }
            bar(fraction: fraction, tint: tint)
            Text(current
                 ? "resets in \(Self.countdown(to: window.resetsAt, from: now))"
                 : "window has reset — no reading since")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func bar(fraction: Double, tint: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(tint)
                    // Keep a nonzero sliver visible for very small percentages.
                    .frame(width: fraction > 0 ? max(geo.size.width * fraction, 3) : 0)
            }
        }
        .frame(height: 6)
    }

    private var placeholder: some View {
        Text(isStatusLineInstalled
             ? "No reading yet — open a Claude Code session."
             : "Install hooks to enable this readout.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 2)
    }

    // MARK: - Formatting

    private static func tint(for percentage: Double) -> Color {
        switch percentage {
        case ..<60:  return .green
        case ..<85:  return .orange
        default:     return .red
        }
    }

    private static func countdown(to date: Date, from now: Date) -> String {
        let minutes = Int(date.timeIntervalSince(now)) / 60
        if minutes < 1 { return "under a minute" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 {
            let rem = minutes % 60
            return rem == 0 ? "\(hours)h" : "\(hours)h \(rem)m"
        }
        let days = hours / 24
        let rem = hours % 24
        return rem == 0 ? "\(days)d" : "\(days)d \(rem)h"
    }

    private static func ageLabel(since date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        return "\(hours / 24) d ago"
    }
}
