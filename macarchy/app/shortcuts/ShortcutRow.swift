import Macarchy
import SwiftUI

struct ShortcutRow: View {
    let binding: SkhdBinding
    let title: String
    let edit: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(title == binding.command ? .monoDetail : .rowTitle)
                        .lineLimit(2).truncationMode(.middle)
                    if !binding.appOverrides.isEmpty {
                        Text("Per app").font(.meta).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: edit) { KeyCaps(caps: binding.keyCaps, size: 11) }
                    .buttonStyle(.plain)
                    .hoverHelp("Change this key combination")
                    .accessibilityLabel("Edit shortcut: " + binding.keyCaps.joined(separator: " "))
                IconButton(
                    symbol: expanded ? "chevron.up" : "chevron.down",
                    help: expanded ? "Hide command details" : "Show command details"
                ) { expanded.toggle() }
            }
            .padding(.horizontal, Metrics.medium).padding(.vertical, Metrics.small)
            if expanded { details }
            Divider()
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            if !binding.command.isEmpty {
                Text(binding.command).font(.monoDetail).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(binding.appOverrides.enumerated()), id: \.offset) { _, override in
                VStack(alignment: .leading, spacing: 2) {
                    Text(override.app == "*" ? "Other apps" : override.app).font(.badge)
                    Text(override.command).font(.monoDetail).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if binding.passthrough {
                Label("Also sent to the focused app", systemImage: "arrow.turn.down.right")
                    .font(.meta).foregroundStyle(.secondary)
            }
        }
        .padding(Metrics.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.controlWell)
    }
}
