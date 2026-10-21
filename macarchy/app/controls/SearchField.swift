import SwiftUI

/// A rounded search field with a magnifier and a clear button.
///
/// This is the only search field in the app. Two panes previously built their
/// own — different widths, radii, fills and paddings — while this one went
/// unused.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    /// `nil` fills the space it is given, for a field that heads a page.
    var width: CGFloat? = 240
    var help: String?

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Metrics.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.rowTitle)
                .focused($focused)

            if !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .hoverHelp("Clear the search")
            }
        }
        .padding(.horizontal, Metrics.medium)
        .padding(.vertical, 7)
        .frame(width: width)
        .background(Color.controlWell, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
        .hoverHelp(help ?? "", enabled: help != nil)
    }
}
