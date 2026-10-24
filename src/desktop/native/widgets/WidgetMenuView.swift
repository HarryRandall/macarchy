import AppKit
import Macarchy
import SwiftUI

/// What an open dropdown shows, where the pointer is over it, and what
/// picking a row does.
@MainActor
@Observable
final class WidgetMenuModel {
    var items: [WidgetMenuItem] = []
    /// The pointer in the dropdown's own coordinates, top-left origin, or nil
    /// when it is outside. The panel tracks it itself, because a window that
    /// never becomes key gets no hover from SwiftUI.
    var pointer: CGPoint?
    @ObservationIgnored var pick: (Int, String?) -> Void = { _, _ in }
}

/// A widget's dropdown, drawn to look like a macOS menu.
struct WidgetMenuView: View {
    static let width: CGFloat = 304
    nonisolated static let space = "menu"
    let model: WidgetMenuModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Self.blocks(model.items), id: \.first?.id) { block in
                if block.count > 1 || block.first.map(Self.isCard) == true {
                    MenuCards(items: block, pointer: model.pointer)
                } else if let item = block.first {
                    row(item)
                }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
        .frame(width: Self.width)
        .background(MenuMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .font(.system(size: 13))
        .coordinateSpace(name: Self.space)
    }

    /// A graph with a reading in its corner is a card.
    static func isCard(_ item: WidgetMenuItem) -> Bool {
        item.type == "graph" && !item.current.isEmpty
    }

    /// The rows in order, with up to two cards in a row grouped to sit side
    /// by side.
    static func blocks(_ items: [WidgetMenuItem]) -> [[WidgetMenuItem]] {
        var blocks: [[WidgetMenuItem]] = []
        for item in items {
            if isCard(item), let last = blocks.last, last.count == 1, let first = last.first,
                isCard(first)
            {
                blocks[blocks.count - 1].append(item)
            } else {
                blocks.append([item])
            }
        }
        return blocks
    }

    @ViewBuilder
    private func row(_ item: WidgetMenuItem) -> some View {
        switch item.type {
        case "divider":
            Divider().padding(.vertical, 6).padding(.horizontal, 10)
        case "heading":
            HStack {
                Text(item.label).font(.system(size: 13.5, weight: .bold))
                Spacer(minLength: 12)
                Text(item.value).foregroundStyle(.secondary).fontWeight(.medium)
            }
            .padding(.horizontal, 10).padding(.top, 2).padding(.bottom, 4)
        case "text":
            Text(item.label).foregroundStyle(.secondary).lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 1)
        case "action":
            MenuRowButton(enabled: item.enabled, pointer: model.pointer) {
                model.pick(item.id, nil)
            } label: { _ in
                Text(item.label)
            }
        case "toggle":
            MenuRowButton(enabled: item.enabled, pointer: model.pointer) {
                model.pick(item.id, nil)
            } label: { _ in
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                    .opacity(item.checked ? 1 : 0).frame(width: 12)
                Text(item.label)
            }
        case "choice":
            choice(item)
        case "graph":
            MenuGraph(
                caption: item.label, points: MenuValues.numbers(item.value), pointer: model.pointer)
        case "cores":
            MenuCores(
                caption: item.label, groups: MenuValues.groups(item.value), pointer: model.pointer)
        case "apps":
            MenuApps(apps: MenuValues.apps(item.value), pointer: model.pointer)
        default:
            HStack {
                Text(item.label)
                Spacer(minLength: 12)
                Text(item.value).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 10).frame(height: 24)
        }
    }

    /// Options as macOS draws Energy Mode: a round tile per option, filled
    /// for the one picked. Without icons, plain radio rows.
    @ViewBuilder
    private func choice(_ item: WidgetMenuItem) -> some View {
        if !item.label.isEmpty {
            Text(item.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.bottom, 4)
        }
        ForEach(Array(item.options.enumerated()), id: \.offset) { index, option in
            let picked = option == item.selected
            if item.icons.indices.contains(index) {
                MenuRowButton(
                    enabled: item.enabled, pointer: model.pointer, height: 36, subtle: true
                ) {
                    model.pick(item.id, option)
                } label: { _ in
                    ZStack {
                        Circle().fill(picked ? Color.blue : Color.primary.opacity(0.1))
                        Image(systemName: item.icons[index]).font(
                            .system(size: 12, weight: .medium)
                        )
                        .foregroundStyle(picked ? Color.white : Color.secondary)
                    }
                    .frame(width: 28, height: 28)
                    Text(option)
                }
            } else {
                MenuRowButton(enabled: item.enabled, pointer: model.pointer) {
                    model.pick(item.id, option)
                } label: { hovering in
                    Image(systemName: picked ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(picked && !hovering ? Color.accentColor : .primary)
                        .frame(width: 14)
                    Text(option)
                }
            }
        }
    }
}

/// A row that highlights under the pointer, as a menu item does. A subtle
/// row tints instead of filling with the accent, as Control Centre's do.
private struct MenuRowButton<Label: View>: View {
    let enabled: Bool
    let pointer: CGPoint?
    var height: CGFloat = 24
    var subtle = false
    let action: () -> Void
    @ViewBuilder let label: (Bool) -> Label
    @State private var frame: CGRect = .zero

    var body: some View {
        let hovering = enabled && pointer.map { frame.contains($0) } == true
        Button(action: action) {
            HStack(spacing: 10) { label(hovering && !subtle) }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: subtle ? 8 : 6, style: .continuous)
                        .fill(
                            hovering
                                ? (subtle ? Color.primary.opacity(0.08) : Color.accentColor)
                                : .clear)
                )
                .foregroundStyle(hovering && !subtle ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(WidgetMenuView.space))
        } action: {
            frame = $0
        }
    }
}

/// The material macOS draws menus with, kept active although the panel
/// never becomes the key window.
private struct MenuMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
