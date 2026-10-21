import SwiftUI

/// A rounded card holding a stack of rows, with a hairline between each.
///
/// Callers list rows as plain children — the divider placement is this type's
/// job, so no pane can get it half-right:
///
/// ```swift
/// SettingsCard("Geometry", help: "Width applies to every outlined window") {
///     SettingRow("Show borders", detail: "…") { Toggle(…) }
///     SettingRow("Width") { … }
/// }
/// ```
///
/// Secondary instructions belong in `help`, beside the section title.
/// Keep values and essential status in the rows.
struct SettingsCard<Content: View>: View {
    private let title: String?
    private let help: String?
    private let reset: (() -> Void)?
    private let resetEnabled: Bool
    private let resetLabel: String
    private let resetHelp: String?
    private let content: Content

    init(
        _ title: String? = nil,
        help: String? = nil,
        reset: (() -> Void)? = nil,
        resetEnabled: Bool = true,
        resetLabel: String = "Reset",
        resetHelp: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.help = help
        self.reset = reset
        self.resetEnabled = resetEnabled
        self.resetLabel = resetLabel
        self.resetHelp = resetHelp
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            if let title { header(title) }

            Group(subviews: content) { rows in
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        if index > 0 {
                            Divider().padding(.leading, CardMetrics.dividerInset)
                        }
                        rows[index]
                    }
                }
            }
            .background(Color.cardSurface, in: card)
            .overlay(card.strokeBorder(Color.cardBorder, lineWidth: 1))
        }
    }

    private func header(_ title: String) -> some View {
        HStack(spacing: Metrics.small) {
            Text(title)
                .font(.cardTitle)
                .foregroundStyle(.secondary)
            if let help { HelpTooltip(text: help) }
            Spacer()
            if let reset {
                Button(action: reset) {
                    Label(resetLabel, systemImage: "arrow.counterclockwise")
                        .font(.meta)
                        .frame(height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!resetEnabled)
                .hoverHelp(resetHelp ?? "Restore the shipped \(title.lowercased()) settings")
                .accessibilityLabel("Reset \(title.lowercased())")
            }
        }
        .padding(.horizontal, Metrics.xs)
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
    }
}
