import SwiftUI

/// A stack of covers with the current one out front and its neighbours
/// receding either side, cycling round without end.
///
/// Built for browsing a set you want to compare — the point is that the next
/// and previous options stay on screen instead of hiding behind a page change.
/// Where a cover sits in the stack, so its caption can be laid out on the
/// side that is actually showing.
enum CoverPlacement {
    case front
    /// Stacked to the left of the front cover: its left edge is what shows.
    case leading
    /// Stacked to the right: its right edge is what shows.
    case trailing

    var isFront: Bool { self == .front }
}

struct Coverflow<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @Binding var index: Int
    var height: CGFloat = 280
    /// How wide the front cover is, as a fraction of the available width.
    var coverFraction: CGFloat = 0.50
    /// The cover never shrinks below this. A narrow window otherwise left the
    /// artwork and its caption squeezed into a sliver; the row is clipped at
    /// its edges instead, which costs a little of the neighbours and nothing
    /// of the cover being looked at.
    var minimumCoverWidth: CGFloat = 320
    /// Nor does it grow past this when the row is given room to bleed past
    /// the page's column.
    var maximumCoverWidth: CGFloat = 600
    /// Covers either side of the front one that stay on screen.
    var depth: Int = 3
    @ViewBuilder let content: (Item, CoverPlacement) -> Content

    /// How long each cover holds the front before the stack moves on.
    /// `nil` leaves it still.
    var dwell: Duration?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var paused = false

    var body: some View {
        GeometryReader { geometry in
            let coverWidth = min(
                maximumCoverWidth,
                max(geometry.size.width * coverFraction, minimumCoverWidth))
            // The row is as wide as the stack actually reaches, not just as
            // wide as the column it was given. A cover drawn outside its
            // container takes no clicks, which left the outermost pair
            // showing but dead to the pointer.
            let rowWidth = max(geometry.size.width, span(coverWidth: coverWidth))
            ZStack {
                // Keyed by the item, not by its slot. Iterating slots meant
                // every cover kept the same identity while its contents were
                // swapped underneath, so changing the index re-rendered in
                // place instead of moving anything.
                ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                    let offset = offset(for: position)
                    if abs(offset) <= depth {
                        cover(item, offset: offset, width: coverWidth)
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: rowWidth, height: height)
            .offset(x: -(rowWidth - geometry.size.width) / 2)
            .contentShape(Rectangle())
        }
        .frame(height: height)
        // A cover turned away from the reader is drawn in perspective, and
        // its near edge projects well outside the row — far enough that the
        // neighbouring covers were landing on top of the page's own title and
        // controls. Height is held to the row; width is deliberately let go,
        // so the stack can run past the column it sits in and show more of
        // itself. What is beyond the pane is clipped by the pane.
        .clipShape(Band(top: 10, bottom: 44))
        .animation(reduceMotion ? nil : Motion.smooth, value: index)
        // Advancing on its own shows there is more behind the front cover.
        // It stops under the pointer so it never moves out from under a click,
        // and never runs at all when the reader has asked for less motion.
        .onHover { paused = $0 }
        .task(id: pauseKey) {
            guard let dwell, !paused, !reduceMotion, items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: dwell)
                guard !Task.isCancelled else { return }
                step(1)
            }
        }
        .onMoveCommand { direction in
            switch direction {
            case .left: step(-1)
            case .right: step(1)
            default: break
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Featured designs")
        .accessibilityValue("\(index + 1) of \(items.count)")
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1)
        }
    }

    /// Restarts the timer when the stack moves for any reason, so a cover
    /// nudged by hand still gets its full turn out front.
    private var pauseKey: String { "\(paused)-\(index)" }

    /// How far an item sits from the front, by the shorter way round.
    ///
    /// Signed and wrapped, so the item just before the first one reads as -1
    /// rather than as the far end of the list.
    private func offset(for position: Int) -> Int {
        let count = items.count
        guard count > 0 else { return .max }
        var delta = (position - index) % count
        if delta > count / 2 { delta -= count }
        if delta < -count / 2 { delta += count }
        return delta
    }

    private func cover(_ item: Item, offset: Int, width: CGFloat) -> some View {
        let distance = CGFloat(abs(offset))
        let isFront = offset == 0
        let placement: CoverPlacement = isFront ? .front : (offset < 0 ? .leading : .trailing)
        let card = content(item, placement)
            // A little shorter than the row, so the shadow below has somewhere
            // to fade out instead of being cut off at the row's edge.
            .frame(width: width, height: height - 12 - distance * 14)
            // An opaque ground under every cover: the artwork's own background
            // is not guaranteed to be, and a translucent front cover shows the
            // whole stack through itself.
            .background(Color.paneBackground)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))
            .overlay {
                if !isFront {
                    // Light enough to read the name on: the covers behind are
                    // there to be chosen from, not just hinted at.
                    RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                        .fill(.black.opacity(0.26 + distance * 0.10))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(isFront ? 0.45 : 0.3),
                radius: isFront ? 20 : 12, y: isFront ? 8 : 5)

        // Every cover is built the same way, front or not. Branching on which
        // one is out front gave the front cover a different identity, so
        // arriving there it was a new view: it appeared in place instead of
        // turning into position with the rest of the stack.
        //
        // Only the sliver of a cover that is actually showing takes clicks.
        // They are all the same full-width rectangle underneath, so without
        // that the nearest one sat invisibly over all the others and answered
        // for them — a click three covers out stepped along by one.
        return
            card
            .contentShape(
                isFront
                    ? AnyShape(Rectangle())
                    : AnyShape(
                        EdgeStrip(
                            width: stripWidth(for: offset, width: width),
                            trailing: offset > 0))
            )
            .onTapGesture {
                guard !isFront else { return }
                step(offset)
            }
            .scaleEffect(isFront ? 1 : 1 - distance * 0.08)
            // A slight turn away from the reader, so the row reads as a stack
            // standing in space rather than flat cards sliding sideways.
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(offset) * -13),
                axis: (x: 0, y: 1, z: 0),
                anchor: offset < 0 ? .trailing : .leading,
                perspective: 0.42
            )
            .offset(x: shift(for: offset, width: width))
            .zIndex(10 - Double(distance))
    }

    /// How much of a cover is left showing past the one in front of it.
    private func stripWidth(for offset: Int, width: CGFloat) -> CGFloat {
        let distance = abs(offset)
        let outer = shift(for: distance, width: width)
        let inner = shift(for: distance - 1, width: width)
        return max(outer - inner, 44)
    }

    /// How far the stack reaches from edge to edge, so the row can be made
    /// wide enough to hold — and to hit-test — every cover it draws.
    private func span(coverWidth: CGFloat) -> CGFloat {
        let reach = shift(for: depth, width: coverWidth)
        return 2 * (reach + coverWidth / 2)
    }

    /// Covers step out by a full stride first, then by less and less, so a
    /// deep stack stays inside the row instead of marching off the edge.
    private func shift(for offset: Int, width: CGFloat) -> CGFloat {
        guard offset != 0 else { return 0 }
        let distance = CGFloat(abs(offset))
        let stride = width * 0.38
        let steps = (1...Int(distance)).reduce(CGFloat.zero) { total, step in
            total + (step == 1 ? 1 : 0.62) * stride
        }
        return offset < 0 ? -steps : steps
    }

    private func step(_ delta: Int) {
        guard !items.isEmpty else { return }
        withAnimation(reduceMotion ? nil : Motion.smooth) {
            index = ((index + delta) % items.count + items.count) % items.count
        }
    }
}

/// Dots under a coverflow.
///
/// No arrows — the neighbouring covers are the arrows — and no caption: the
/// front cover already carries its own name in letters far bigger than these.
struct CoverflowControls: View {
    let count: Int
    @Binding var index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Metrics.xs + 2) {
            ForEach(0..<count, id: \.self) { position in
                Button {
                    withAnimation(reduceMotion ? nil : Motion.smooth) { index = position }
                } label: {
                    Capsule()
                        .fill(
                            position == index
                                ? AnyShapeStyle(Color.accentColor)
                                : AnyShapeStyle(Color.controlWell)
                        )
                        .frame(width: position == index ? 18 : 6, height: 6)
                        .contentShape(Rectangle().inset(by: -6))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(reduceMotion ? nil : Motion.snappy, value: index)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

/// A clip that holds a row's height but lets it run as wide as it likes.
///
/// The two edges are given different room on purpose: little above, where a
/// cover in perspective would otherwise reach the page's title, and enough
/// below for the front cover's shadow to fade out. Cut short, that shadow
/// ended in a straight line drawn across the whole row.
private struct Band: Shape {
    /// Room allowed above the row.
    let top: CGFloat
    /// Room allowed below it.
    let bottom: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            CGRect(
                x: rect.minX - 4000, y: rect.minY - top,
                width: rect.width + 8000, height: rect.height + top + bottom))
    }
}

/// The outer edge of a cover: the part of it the reader can actually see, and
/// so the only part that should answer a click.
private struct EdgeStrip: Shape {
    let width: CGFloat
    let trailing: Bool

    func path(in rect: CGRect) -> Path {
        let strip = min(width, rect.width)
        return Path(
            CGRect(
                x: trailing ? rect.maxX - strip : rect.minX, y: rect.minY,
                width: strip, height: rect.height))
    }
}
