import Macarchy
import SwiftUI

/// A connection as a card: its symbol in a round tile, a name and a line
/// under it, signal bars when there is a signal, and small tags such as the
/// band and link speed. Tags that come out empty are left off.
struct MenuStatus: View {
    let item: WidgetMenuItem

    private var signal: Int? { Int(item.current).map { min(max($0, 0), 4) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.accentColor)
                    Image(systemName: item.icons.first.flatMap { $0.isEmpty ? nil : $0 } ?? "wifi")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    if !item.value.isEmpty {
                        Text(item.value).font(.system(size: 11)).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let signal {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<4, id: \.self) { bar in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.primary.opacity(bar < signal ? 1 : 0.2))
                                .frame(width: 3, height: CGFloat(5 + bar * 3))
                        }
                    }
                }
            }
            let tags = item.options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        Text(tag).font(.system(size: 10.5)).foregroundStyle(.secondary)
                            .monospacedDigit().lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(.primary.opacity(0.07)))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 10).padding(.vertical, 2)
    }
}
