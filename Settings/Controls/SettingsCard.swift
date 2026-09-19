import SwiftUI

/// A rounded card holding a stack of rows, with a hairline between each.
///
/// Callers list rows as plain children — the divider placement is this type's
/// job, so no pane can get it half-right:
///
/// ```swift
/// SettingsCard("Geometry") {
///     SettingRow("Show borders", detail: "…") { Toggle(…) }
///     SettingRow("Width") { … }
/// }
/// ```
struct SettingsCard<Content: View>: View {
    private let title: String?
    private let footnote: String?
    private let reset: (() -> Void)?
    private let resetEnabled: Bool
    private let content: Content

    init(
        _ title: String? = nil,
        footnote: String? = nil,
        reset: (() -> Void)? = nil,
        resetEnabled: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footnote = footnote
        self.reset = reset
        self.resetEnabled = resetEnabled
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let footnote { HelpTooltip(text: footnote) }
                    Spacer()
                    if let reset {
                        Button(action: reset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(!resetEnabled)
                        .help("Reset \(title.lowercased()) to default")
                        .accessibilityLabel("Reset \(title.lowercased()) to default")
                    }
                }
                .padding(.horizontal, 4)
            }

            Group(subviews: content) { rows in
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        if index > 0 {
                            Divider()
                                .padding(.leading, CardMetrics.dividerInset)
                        }
                        rows[index]
                    }
                }
            }
            .background(Color.cardSurface, in: card)
            .overlay(card.strokeBorder(Color.cardBorder, lineWidth: 1))

        }
    }

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: CardMetrics.cornerRadius, style: .continuous)
    }
}
