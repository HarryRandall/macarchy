import SwiftUI

/// Popover for a single live item. Writes go through MenuBarModel → Integrations.
struct MenuBarItemEditor: View {
    let item: SketchybarItem
    var bar: MenuBarModel

    @State private var label: String = ""

    var body: some View {
        Form {
            LabeledContent("Item", value: item.id)

            Toggle(
                "Visible",
                isOn: Binding(
                    get: { item.drawing },
                    set: { bar.setDrawing(item.id, $0) }
                ))

            if !item.id.hasPrefix("space."), item.label.drawing {
                TextField("Label", text: $label)
                    .onSubmit { bar.setLabel(item.id, label) }
                Button("Set label") { bar.setLabel(item.id, label) }
                    .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .frame(width: 260)
        .onAppear { label = item.label.value }
    }
}
