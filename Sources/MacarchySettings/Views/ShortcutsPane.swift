import SwiftUI
import AppKit
import MacarchyKit

struct ShortcutsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var shortcuts = model.shortcuts

        Form {
            Section {
                TextField("Filter by key, command or section", text: $shortcuts.search)
                    .textFieldStyle(.roundedBorder)
            } footer: {
                Text(
                    "\(model.shortcuts.bindings.count) bindings parsed from skhdrc. Read-only for now — editing writes back through a macarchy:keep block."
                )
                .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(model.shortcuts.sections, id: \.self) { section in
                Section(section) {
                    ForEach(model.shortcuts.bindings(in: section)) { binding in
                        BindingRow(binding: binding)
                    }
                }
            }

            if !model.shortcuts.ungrouped.isEmpty {
                Section("Other") {
                    ForEach(model.shortcuts.ungrouped) { binding in
                        BindingRow(binding: binding)
                    }
                }
            }

            Section {
                Button("Open skhdrc") { NSWorkspace.shared.open(ShortcutsModel.configURL) }
            }
        }
        .formStyle(.grouped)
        .onAppear { if model.shortcuts.bindings.isEmpty { model.shortcuts.reload() } }
    }
}

private struct BindingRow: View {
    let binding: SkhdBinding

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                Text(binding.command.isEmpty ? "per-app" : binding.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(binding.command)

                if !binding.appOverrides.isEmpty {
                    Text(binding.appOverrides.map(\.app).joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        } label: {
            HStack(spacing: 3) {
                ForEach(Array(binding.keyCaps.enumerated()), id: \.offset) { _, cap in
                    KeyCap(cap)
                }
                if binding.passthrough {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .help("Also forwarded to the focused app")
                }
            }
            .frame(width: 150, alignment: .leading)
        }
    }
}

private struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .frame(minWidth: 18)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
    }
}
