import AppKit
import SwiftUI

/// Session activity beside the current pane, or as a page in narrow windows.
struct ConsolePanel: View {
    @Environment(AppModel.self) private var model

    var asPage = false

    static let width: CGFloat = 360
    static let minimumWidthForPanel: CGFloat = 1080

    private var entries: [CommandLog.Entry] {
        Array(model.log.entries.reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            ConsoleEntryRow(entry: entry) { model.log.remove(entry.id) }
                            Divider()
                        }
                    }
                    .padding(.horizontal, Metrics.medium)
                }
            }
        }
        .frame(width: asPage ? nil : Self.width)
        .frame(maxWidth: asPage ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paneBackground)
        .overlay(alignment: .leading) {
            if !asPage {
                Rectangle().fill(Color.cardBorder).frame(width: 1)
            }
        }
    }

    private var header: some View {
        HStack(spacing: Metrics.small) {
            Text("Console").font(.cardTitle)
            Text(String(entries.count)).font(.meta).foregroundStyle(.secondary)
            Spacer(minLength: Metrics.small)
            BarButton(symbol: "xmark", help: "Close the console") {
                model.consoleOpen = false
            }
        }
        .padding(.horizontal, Metrics.medium)
        .frame(height: ContentBar.height)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var emptyState: some View {
        VStack(spacing: Metrics.small) {
            Image(systemName: "terminal")
                .font(.sectionTitle)
                .foregroundStyle(.secondary)
            Text("No activity yet")
                .font(.cardTitle)
            Text("Commands and configuration reads appear here as you use the app.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Metrics.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct ConsoleEntryRow: View {
    let entry: CommandLog.Entry
    let dismiss: () -> Void
    @State private var expanded = false
    @State private var detailsHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            HStack(alignment: .top, spacing: Metrics.small) {
                VStack(alignment: .leading, spacing: Metrics.xs) {
                    HStack(spacing: Metrics.small) {
                        Label(entry.category.rawValue, systemImage: entry.category.symbol)
                            .foregroundStyle(.secondary)
                        if !entry.ok {
                            Label("Failed", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    Text(entry.at, format: .dateTime.hour().minute().second())
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    entryButton("doc.on.doc", help: "Copy entry") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.copyText, forType: .string)
                    }
                    entryButton("xmark", help: "Clear entry", action: dismiss)
                }
            }
            .font(.meta)

            Text(entry.command)
                .font(.monoDetail)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            // Controls stay above a bounded details area, so long output
            // cannot push the collapse button out of the entry.
            if !expanded && !entry.detail.isEmpty {
                Text(previewDetail)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            disclosure
            if expanded {
                ScrollView {
                    Text("Command:\n\(entry.command)\n\n\(entry.detail)")
                        .font(.monoDetail)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Metrics.small)
                        .onGeometryChange(for: CGFloat.self) {
                            $0.size.height
                        } action: { height in
                            detailsHeight = min(height, 180)
                        }
                }
                .frame(height: detailsHeight)
                .background(
                    Color.controlWell, in: RoundedRectangle(cornerRadius: Metrics.radiusSmall))
                if let status = entry.status {
                    Text("Exit \(status)").font(.meta).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Metrics.medium)
    }

    private var previewDetail: String {
        for prefix in ["Standard output:\n", "Standard error:\n"]
        where entry.detail.hasPrefix(prefix) {
            return String(entry.detail.dropFirst(prefix.count))
        }
        return entry.detail
    }

    private var disclosure: some View {
        Button {
            expanded.toggle()
        } label: {
            Label(
                expanded ? "Hide details" : "Show details",
                systemImage: expanded ? "chevron.up" : "chevron.down"
            )
            .font(.meta)
            .padding(.vertical, Metrics.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(expanded ? "Hide details" : "Show details")
    }

    private func entryButton(
        _ symbol: String, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusSmall))
        .foregroundStyle(.secondary)
        .hoverHelp(help)
        .accessibilityLabel(help)
    }
}
