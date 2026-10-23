import AppKit
import Macarchy
import SwiftUI

/// What an open dropdown shows, and what picking a row does.
@MainActor
@Observable
final class WidgetMenuModel {
    var items: [WidgetMenuItem] = []
    @ObservationIgnored var pick: (Int, String?) -> Void = { _, _ in }
}

/// A widget's dropdown, drawn to look like a macOS menu.
struct WidgetMenuView: View {
    static let width: CGFloat = 288
    let model: WidgetMenuModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.items) { item in row(item) }
        }
        .padding(6)
        .frame(width: Self.width)
        .background(MenuMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .font(.system(size: 13))
    }

    @ViewBuilder
    private func row(_ item: WidgetMenuItem) -> some View {
        switch item.type {
        case "divider":
            Divider().padding(.vertical, 5).padding(.horizontal, 8)
        case "heading":
            HStack {
                Text(item.label).fontWeight(.semibold)
                Spacer(minLength: 12)
                Text(item.value).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 2)
        case "text":
            Text(item.label).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 1)
        case "action":
            MenuRowButton(enabled: item.enabled) {
                model.pick(item.id, nil)
            } label: {
                Text(item.label)
            }
        case "toggle":
            MenuRowButton(enabled: item.enabled) {
                model.pick(item.id, nil)
            } label: {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                    .opacity(item.checked ? 1 : 0).frame(width: 12)
                Text(item.label)
            }
        case "choice":
            if !item.label.isEmpty {
                Text(item.label).fontWeight(.semibold).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.top, 2)
            }
            ForEach(item.options, id: \.self) { option in
                MenuRowButton(enabled: item.enabled) {
                    model.pick(item.id, option)
                } label: {
                    Image(
                        systemName: option == item.selected ? "largecircle.fill.circle" : "circle"
                    )
                    .foregroundStyle(option == item.selected ? Color.accentColor : .secondary)
                    .frame(width: 14)
                    Text(option)
                }
            }
        case "graph":
            MenuGraph(caption: item.label, points: MenuValues.numbers(item.value))
        case "cores":
            MenuCores(groups: MenuValues.groups(item.value))
        case "apps":
            MenuApps(apps: MenuValues.apps(item.value))
        default:
            HStack {
                Text(item.label)
                Spacer(minLength: 12)
                Text(item.value).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(.horizontal, 8).frame(height: 24)
        }
    }
}

/// A row that highlights under the pointer, as a menu item does.
private struct MenuRowButton<Label: View>: View {
    let enabled: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { label() }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovering && enabled ? Color.accentColor : .clear)
                )
                .foregroundStyle(hovering && enabled ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
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
