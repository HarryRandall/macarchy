import SwiftUI

struct LayoutPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        SettingsPage("Layout", subtitle: "Give every window a place.") {
            SettingsCard(
                "Your workspace",
                help: "Illustrative preview. Changes apply to the desktop as you edit."
            ) {
                VStack(alignment: .leading, spacing: Metrics.medium) {
                    LayoutPreview(
                        mode: model.layout.layout, gap: model.layout.windowGap,
                        padding: model.layout.padding, wallpaper: model.currentThemeWallpaper
                    )
                    .frame(height: 230)
                }.padding(Metrics.medium)
            }
            layoutChoices
            arrangement
            spacing
            mouse
        }
    }

    private var layoutChoices: some View {
        VStack(alignment: .leading, spacing: Metrics.medium) {
            SectionHeading("Choose your layout")
            HStack(spacing: Metrics.gridGap) {
                layoutChoice("bsp", "Tile", "Fit windows neatly beside each other")
                layoutChoice("stack", "Stack", "Keep windows together and switch between them")
                layoutChoice("float", "Freeform", "Move and resize windows yourself")
            }
        }
    }

    private func layoutChoice(_ mode: String, _ title: String, _ help: String) -> some View {
        ChoiceCard(label: title, isSelected: model.layout.layout == mode, height: 95) {
            model.layout.layout = mode
            model.layout.apply("layout", mode)
        } preview: {
            LayoutPreview(mode: mode, gap: 12, padding: 18, wallpaper: nil)
        }
        .hoverHelp(help)
    }

    private var arrangement: some View {
        @Bindable var layout = model.layout
        return SettingsCard(
            "Window arrangement",
            help: "Choose where new windows appear and how they share the available space."
        ) {
            SettingRow(
                "Split direction",
                help:
                    "Place tiled windows side by side or one above the other. Automatic chooses for the available space."
            ) {
                layoutPicker(
                    "Split direction", selection: $layout.splitType,
                    options: [
                        ("auto", "Automatic"), ("vertical", "Side by side"),
                        ("horizontal", "Above and below")
                    ]
                )
                .onChange(of: layout.splitType) { _, value in layout.apply("split_type", value)
                }
            }
            SettingRow(
                "New windows",
                help: "Choose which side of the current window gets a newly opened window."
            ) {
                layoutPicker(
                    "New windows", selection: $layout.windowPlacement,
                    options: [("second_child", "After current"), ("first_child", "Before current")]
                )
                .onChange(of: layout.windowPlacement) { _, value in
                    layout.apply("window_placement", value)
                }
            }
            SettingRow(
                "Balance window sizes",
                help: "Automatically share space more evenly when windows are added or removed."
            ) {
                Toggle("Balance window sizes", isOn: $layout.autoBalance).labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: layout.autoBalance) { _, value in
                        layout.apply("auto_balance", value ? "on" : "off")
                    }
            }
        }.disabled(layout.layout != "bsp")
    }

    private var spacing: some View {
        @Bindable var layout = model.layout
        return SettingsCard("Room to breathe") {
            SettingRow(
                "Between windows", help: "The empty space separating neighbouring windows."
            ) {
                ValueSlider(value: $layout.windowGap, range: 0...32, unit: "pt") {
                    layout.apply("window_gap", String(Int($0)))
                }
            }
            SettingRow(
                "Match all screen edges",
                help:
                    "Keep the same margin around every edge. When off, the margin control changes only the top edge."
            ) {
                Toggle("Match all screen edges", isOn: $layout.linkPadding).labelsHidden()
                    .toggleStyle(.switch)
            }
            SettingRow(
                layout.linkPadding ? "Screen margins" : "Top margin",
                help: "Leave space between your windows and the edge of the display."
            ) {
                ValueSlider(value: $layout.padding, range: 0...40, unit: "pt") {
                    layout.applyPadding($0)
                }
            }
        }
    }

    private var mouse: some View {
        @Bindable var layout = model.layout
        return SettingsCard("Mouse and movement") {
            SettingRow(
                "Hold to move or resize",
                help: "Hold this key while dragging a window to move or resize it."
            ) {
                layoutPicker(
                    "Modifier key", selection: $layout.mouseModifier,
                    options: [
                        ("ctrl", "Control"), ("alt", "Option"), ("cmd", "Command"),
                        ("shift", "Shift")
                    ]
                )
                .onChange(of: layout.mouseModifier) { _, value in
                    layout.apply("mouse_modifier", value)
                }
            }
            SettingRow(
                "Move pointer to focused window",
                help: "Bring the pointer to the window you switch to using your keyboard."
            ) {
                Toggle("Move pointer to focused window", isOn: $layout.mouseFollowsFocus)
                    .labelsHidden().toggleStyle(.switch)
                    .onChange(of: layout.mouseFollowsFocus) { _, value in
                        layout.apply("mouse_follows_focus", value ? "autofocus" : "off")
                    }
            }
            SettingRow(
                "Drop onto another window",
                help: "Group the two windows into a stack, or exchange their positions."
            ) {
                layoutPicker(
                    "Drop action", selection: $layout.mouseDropAction,
                    options: [("stack", "Stack together"), ("swap", "Swap places")]
                )
                .onChange(of: layout.mouseDropAction) { _, value in
                    layout.apply("mouse_drop_action", value)
                }
            }
        }
    }

    /// Native pickers keep their intrinsic width inside a frame. Size the menu
    /// label itself so every dropdown shares the same edges and text inset.
    private func layoutPicker(
        _ title: String, selection: Binding<String>, options: [(value: String, label: String)]
    ) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack {
                Text(
                    options.first { $0.value == selection.wrappedValue }?.label
                        ?? selection.wrappedValue
                )
                .lineLimit(1)
                Spacer(minLength: Metrics.small)
                Image(systemName: "chevron.up.chevron.down").font(
                    .system(size: 10, weight: .medium)
                )
                .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, Metrics.small)
            .padding(.vertical, 6)
            .frame(width: 176)
            .glassEffect(
                .regular.interactive(),
                in: RoundedRectangle(cornerRadius: Metrics.radiusControl)
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(
                options.first { $0.value == selection.wrappedValue }?.label
                    ?? selection.wrappedValue)
        }
        .menuStyle(.button)
        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusControl))
        .menuIndicator(.hidden)
        .accessibilityLabel(title)
        .accessibilityValue(
            options.first { $0.value == selection.wrappedValue }?.label ?? selection.wrappedValue)
    }
}
