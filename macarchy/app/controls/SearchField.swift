import SwiftUI

/// A rounded search field with a magnifier and a clear button.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var width: CGFloat = 240

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: width)
        .background(Color.controlWell, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
    }
}
