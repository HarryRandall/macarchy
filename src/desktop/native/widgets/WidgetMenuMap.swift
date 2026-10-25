import Macarchy
import SwiftUI

/// A whole, such as memory, as rows of 16 blocks coloured by what holds
/// each share, with the rest left empty. Pointing at a block names its part
/// and how much it holds, and dims the others.
struct MenuMap: View {
    let item: WidgetMenuItem
    let pointer: CGPoint?
    @State private var frame: CGRect = .zero
    static let columns = 16
    private let spacing: CGFloat = 3

    /// Activity Monitor's order of colours, then a few more.
    private static let palette = ["accent", "#bf5af2", "#ff9f0a", "#8e8e93", "#30d158", "#ff375f"]

    struct Part {
        var name: String
        var amount: Double
        var colour: Color
    }

    private var parts: [Part] {
        let given = MenuMirror.parts(item.colour == "accent" ? "" : item.colour)
        return MenuValues.apps(item.value).enumerated().map { index, part in
            let chosen = given.indices.contains(index) ? given[index] : ""
            let colour = chosen.isEmpty ? Self.palette[index % Self.palette.count] : chosen
            return Part(
                name: part.name, amount: MenuValues.numbers(part.value).first ?? 0,
                colour: colour.hasPrefix("#") ? Color(hex: colour) : .accentColor)
        }
    }

    /// Which part each block belongs to, in order, or nil for an empty one.
    /// Each part gets its share of the blocks, rounded, and never more than
    /// are left.
    static func owners(_ amounts: [Double], total: Double, cells: Int) -> [Int?] {
        let whole = total > 0 ? total : amounts.reduce(0, +)
        guard whole > 0 else { return Array(repeating: nil, count: cells) }
        var owners: [Int?] = []
        for (index, amount) in amounts.enumerated() {
            let share = Int((max(amount, 0) / whole * Double(cells)).rounded())
            owners += Array(repeating: index, count: min(share, cells - owners.count))
        }
        return owners + Array(repeating: nil, count: cells - owners.count)
    }

    private var hovered: Int? {
        guard let pointer, frame.contains(pointer) else { return nil }
        let pitch = (frame.width + spacing) / CGFloat(Self.columns)
        let column = Int((pointer.x - frame.minX) / pitch)
        let row = Int((pointer.y - frame.minY) / pitch)
        return row * Self.columns + min(column, Self.columns - 1)
    }

    var body: some View {
        let parts = self.parts
        let owners = Self.owners(parts.map(\.amount), total: item.max ?? 0, cells: item.cells)
        let lit = hovered.flatMap { owners.indices.contains($0) ? owners[$0] : nil }
        VStack(alignment: .leading, spacing: 7) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: spacing), count: Self.columns),
                spacing: spacing
            ) {
                ForEach(Array(owners.enumerated()), id: \.offset) { _, owner in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(owner.map { parts[$0].colour } ?? Color.primary.opacity(0.08))
                        .opacity(lit == nil || owner == lit ? 1 : 0.35)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .named(WidgetMenuView.space))
            } action: {
                frame = $0
            }
            if lit != nil || parts.count > 1 || !item.label.isEmpty {
                footer(parts, lit: lit)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 2)
    }

    @ViewBuilder
    private func footer(
        _ parts: [Part], lit: Int?
    )
        -> some View
    {
        HStack(spacing: 12) {
            if let lit {
                key(parts[lit].name, colour: parts[lit].colour)
                Spacer(minLength: 4)
                Text(MenuValues.format(parts[lit].amount, unit: item.unit))
                    .monospacedDigit()
            } else {
                if parts.count > 1 {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        key(part.name, colour: part.colour)
                    }
                }
                if !item.label.isEmpty {
                    Spacer(minLength: 4)
                    Text(item.label).lineLimit(1)
                }
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .frame(height: 14)
    }

    private func key(_ name: String, colour: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(colour).frame(width: 7, height: 7)
            Text(name).lineLimit(1)
        }
    }
}
