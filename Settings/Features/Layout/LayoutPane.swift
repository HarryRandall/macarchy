import SwiftUI

struct LayoutPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var layout = model.layout

        Form {
            Section {
                TilingPreview(gap: layout.windowGap, padding: layout.padding)
                    .frame(height: 150)
                    .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            } header: {
                Text("Preview")
            } footer: {
                Text(
                    "Gaps and padding are spatial, so the miniature shows the change before it reaches the desktop."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Tiling") {
                Picker("Layout mode", selection: $layout.layout) {
                    Text("Binary space partitioning").tag("bsp")
                    Text("Stack").tag("stack")
                    Text("Float").tag("float")
                }
                .onChange(of: layout.layout) { _, new in layout.apply("layout", new) }

                Picker("Split type", selection: $layout.splitType) {
                    Text("Auto").tag("auto")
                    Text("Vertical").tag("vertical")
                    Text("Horizontal").tag("horizontal")
                }
                .onChange(of: layout.splitType) { _, new in layout.apply("split_type", new) }

                Picker("New window placement", selection: $layout.windowPlacement) {
                    Text("Second child").tag("second_child")
                    Text("First child").tag("first_child")
                }
                .onChange(of: layout.windowPlacement) { _, new in
                    layout.apply("window_placement", new)
                }

                Toggle("Auto balance", isOn: $layout.autoBalance)
                    .onChange(of: layout.autoBalance) { _, new in
                        layout.apply("auto_balance", new ? "on" : "off")
                    }
            }

            Section("Gaps and padding") {
                LabeledContent("Window gap") {
                    HStack {
                        Slider(value: $layout.windowGap, in: 0...32, step: 1)
                            .frame(width: 160)
                            .onChange(of: layout.windowGap) { _, new in
                                layout.apply("window_gap", String(Int(new)))
                            }
                        Text("\(Int(layout.windowGap))")
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                    }
                }

                Toggle("Link all edges", isOn: $layout.linkPadding)

                LabeledContent("Padding") {
                    HStack {
                        Slider(value: $layout.padding, in: 0...40, step: 1)
                            .frame(width: 160)
                            .onChange(of: layout.padding) { _, new in layout.applyPadding(new) }
                        Text("\(Int(layout.padding))")
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }

            Section("Mouse") {
                Picker("Modifier", selection: $layout.mouseModifier) {
                    Text("Control").tag("ctrl")
                    Text("Option").tag("alt")
                    Text("Command").tag("cmd")
                    Text("Shift").tag("shift")
                }
                .onChange(of: layout.mouseModifier) { _, new in layout.apply("mouse_modifier", new)
                }

                Toggle("Focus follows mouse", isOn: $layout.mouseFollowsFocus)
                    .onChange(of: layout.mouseFollowsFocus) { _, new in
                        layout.apply("mouse_follows_focus", new ? "autofocus" : "off")
                    }

                Picker("Drop action", selection: $layout.mouseDropAction) {
                    Text("Stack").tag("stack")
                    Text("Swap").tag("swap")
                }
                .onChange(of: layout.mouseDropAction) { _, new in
                    layout.apply("mouse_drop_action", new)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// A miniature of the current BSP split, driven by the same values as the sliders.
private struct TilingPreview: View {
    let gap: Double
    let padding: Double

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 1440
            let g = max(1, gap * scale * 2.4)
            let inset = max(1, padding * scale * 2.4)

            HStack(spacing: g) {
                tile(emphasised: true)
                VStack(spacing: g) {
                    tile()
                    tile()
                }
                .frame(width: proxy.size.width * 0.38)
            }
            .padding(inset)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func tile(emphasised: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.accentColor.opacity(emphasised ? 0.30 : 0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.accentColor.opacity(emphasised ? 0.9 : 0.45), lineWidth: 1)
            )
    }
}
