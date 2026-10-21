import AppKit
import Macarchy
import SwiftUI

/// The dark, slightly translucent ground Raycast-style windows sit on.
struct SwitcherBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct SwitcherSearchBar: View {
    @Binding var text: String
    let placeholder: String
    var focused: FocusState<Bool>.Binding
    let back: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 19))
                .focused(focused)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}

/// One list row: icon, title, and right-aligned accessories.
struct SwitcherRow<Icon: View, Title: View, Accessories: View>: View {
    let selected: Bool
    @ViewBuilder let icon: Icon
    @ViewBuilder let title: Title
    @ViewBuilder let accessories: Accessories

    var body: some View {
        HStack(spacing: 10) {
            icon
            HStack(spacing: 8) { title }
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            HStack(spacing: 12) { accessories }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(
            selected ? Color.white.opacity(0.1) : .clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}

struct SwitcherFooter: View {
    let title: String
    let status: ThemeSwitcherView.Status?
    let primary: String
    let showActions: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            switch status {
            case .working(let message):
                ProgressView().controlSize(.small)
                Text(message).foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).foregroundStyle(.orange).lineLimit(1)
            case nil:
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 20, height: 20)
                Text(title).foregroundStyle(.secondary)
            }
            Spacer()
            Text(primary).fontWeight(.semibold)
            SwitcherKeys(keys: ["↵"])
            Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 14)
            Button(action: showActions) {
                HStack(spacing: 8) {
                    Text("Actions").foregroundStyle(.secondary)
                    SwitcherKeys(keys: ["⌘", "K"])
                }
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 40)
    }
}

struct SwitcherKeys: View {
    let keys: [String]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .medium))
                    .frame(minWidth: 22, minHeight: 20)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

/// The ⌘K menu: every action with its shortcut.
struct SwitcherActions: View {
    struct Item: Identifiable {
        let title: String
        let symbol: String
        let keys: [String]
        let run: () -> Void
        var id: String { title }
    }

    let actions: [Item]
    let dismiss: () -> Void
    @State private var hovered: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(actions) { item in
                Button {
                    dismiss()
                    item.run()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol).frame(width: 18)
                        Text(item.title)
                        Spacer(minLength: 16)
                        SwitcherKeys(keys: item.keys)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 8).frame(height: 30)
                    .background(
                        hovered == item.id ? Color.white.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? item.id : nil }
            }
        }
        .padding(6)
        .frame(width: 280)
        .background(SwitcherBackdrop())
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }
}
