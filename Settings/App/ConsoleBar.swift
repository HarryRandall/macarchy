import SwiftUI

/// The running record of what the app has actually asked the daemons to do.
struct ConsoleBar: View {
    @Environment(AppModel.self) private var model
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.log.entries.reversed()) { entry in
                            row(entry)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .frame(height: 140)
                Divider()
            }

            HStack(spacing: 8) {
                Text("CONSOLE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                if let latest = model.log.latest {
                    row(latest)
                } else {
                    Text("waiting for first command")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button(expanded ? "Hide" : "History") { withAnimation { expanded.toggle() } }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    private func row(_ entry: CommandLog.Entry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: entry.ok ? "checkmark" : "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(entry.ok ? .green : .red)
            Text(entry.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
            if !entry.detail.isEmpty {
                Text("→ \(entry.detail)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}
