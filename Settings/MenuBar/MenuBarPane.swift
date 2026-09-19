import Desktop
import SwiftUI

struct MenuBarPane: View {
    @Environment(AppModel.self) var model
    var bar: MenuBarModel { model.menuBar }

    var body: some View {
        SettingsPage("Menu Bar", subtitle: "Arrange your desktop, one component at a time") {
            previewCard
            componentCard
            inspector
            geometryCard
            HStack {
                Button("Refresh") { Task { await bar.hydrate() } }
                    .disabled(bar.hasChanges || bar.isApplying || bar.isHydrating)
                Spacer()
                Button("Open config") {
                    NSWorkspace.shared.activateFileViewerSelecting([
                        Paths.home.appending(path: ".config/sketchybar")
                    ])
                }
            }
        }
        .task { await bar.hydrate() }
    }

    private var previewCard: some View {
        SettingsCard(
            "Overview",
            footnote: "The full display is scaled uniformly, including its real notch. "
                + "Select a component here, then use the enlarged half below to arrange it."
        ) {
            VStack(spacing: 14) {
                ScrollView(.horizontal) { toolbar.fixedSize(horizontal: true, vertical: false) }
                    .scrollIndicators(.hidden)
                if bar.isHydrating {
                    ProgressView("Reading your menu bar...").frame(height: 82)
                } else {
                    MenuBarStage(bar: bar, wallpaper: model.currentThemeWallpaper)
                }
                HStack {
                    Text(
                        bar.live
                            ? "Changes apply as you edit."
                            : "Arrange your draft, then Apply to update the desktop."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if bar.isApplying {
                        ProgressView().controlSize(.small)
                    } else if bar.hasChanges {
                        Text("Unsaved changes").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = bar.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(12)
        }
    }

    private var toolbar: some View {
        HStack {
            Toggle("Live preview", isOn: Binding(get: { bar.live }, set: { bar.setLive($0) }))
                .toggleStyle(.switch).controlSize(.small)
                .disabled(!bar.live && (bar.hasChanges || bar.isApplying))
            HelpTooltip(
                text:
                    "Live applies each change after a short pause. With Live off, moves, additions "
                    + "and settings stay in your draft. Apply or discard a draft before enabling Live."
            )
            Spacer()
            Button("Undo") { bar.undoLast() }.disabled(!bar.canUndo)
            if !bar.live {
                Button("Discard") { bar.discard() }.disabled(!bar.hasChanges || bar.isApplying)
                Button(bar.isApplying ? "Applying..." : "Apply") { Task { await bar.apply() } }
                    .buttonStyle(.borderedProminent).disabled(!bar.hasChanges || bar.isApplying)
            }
        }
    }

    private var componentCard: some View {
        @Bindable var bar = bar
        return SettingsCard(
            "Components",
            footnote: "Drag an outlined group or its chip before another component. "
                + "Shift-click to select several groups, then drag or edit them together."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal) {
                    HStack {
                        SegmentedPill(
                            selection: $bar.side,
                            options: [.init("left", "Left"), .init("right", "Right")])
                        Spacer()
                        Button("Select all") { bar.selectAll() }
                        Button("Clear") { bar.selection.removeAll() }
                            .disabled(bar.selection.isEmpty)
                        addMenu
                    }.fixedSize(horizontal: true, vertical: false)
                }.scrollIndicators(.hidden)
                MenuBarStage(bar: bar, wallpaper: model.currentThemeWallpaper, half: bar.side)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(bar.draft.components.filter { $0.side == bar.side }) { component in
                            componentChip(component)
                        }
                        Text("Drop here to move to \(bar.side)")
                            .font(.caption).foregroundStyle(.secondary).padding(10)
                            .background(Color.controlWell, in: RoundedRectangle(cornerRadius: 7))
                            .dropDestination(for: String.self) { ids, _ in
                                guard let id = ids.first,
                                    bar.draft.components.contains(where: { $0.id == id })
                                else { return false }
                                bar.moveToSide(id, side: bar.side)
                                return true
                            }
                    }.padding(3)
                }
                .scrollIndicators(.hidden)
            }.padding(12)
                .disabled(bar.isApplying || bar.isHydrating)
        }
    }

    private func componentChip(_ component: BarComponent) -> some View {
        Button {
            bar.select(component.id, extending: NSEvent.modifierFlags.contains(.shift))
        } label: {
            Label(
                component.title, systemImage: component.visible ? "line.3.horizontal" : "eye.slash"
            )
            .font(.callout).padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                bar.selection.contains(component.id)
                    ? Color.accentColor.opacity(0.18) : Color.controlWell,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7).strokeBorder(
                    bar.selection.contains(component.id) ? Color.accentColor : .clear))
        }
        .buttonStyle(.plain)
        .draggable(component.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, bar.draft.components.contains(where: { $0.id == id }) else {
                return false
            }
            bar.move(id, before: component.id)
            return true
        }
    }

    private var addMenu: some View {
        Menu {
            Section("New component") {
                Button("Text") { bar.add(kind: "text") }
                Button("Icon") { bar.add(kind: "icon") }
                Button("Spacer") { bar.add(kind: "spacer") }
            }
            Section("Your widgets") {
                ForEach(bar.draft.components.filter { !$0.isCustom }) { component in
                    Button(
                        component.visible ? "\(component.title) (in bar)" : "Add \(component.title)"
                    ) {
                        bar.update(component.id) { $0.visible = true }
                        bar.select(component.id, extending: NSEvent.modifierFlags.contains(.shift))
                        bar.side = component.side
                    }.disabled(component.visible)
                }
            }
        } label: {
            Label("Add component", systemImage: "plus")
        }
        .menuStyle(.borderlessButton).fixedSize()
    }
}
