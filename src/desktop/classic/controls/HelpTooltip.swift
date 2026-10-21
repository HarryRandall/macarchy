import SwiftUI

/// The small question mark that reveals a line of help.
///
/// It is a button rather than a bare image so it can be reached by Tab and
/// read by VoiceOver. Hover help supplies the description as an accessibility
/// hint, so the label here names the control instead of repeating the text —
/// setting both made VoiceOver read the same sentence twice.
struct HelpTooltip: View {
    let text: String

    var body: some View {
        Button {
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHelp(text)
        .accessibilityLabel("Help")
    }
}
