import Macarchy
import SwiftUI

struct MenuBarPane: View {
    @Environment(AppModel.self) var model
    var bar: MenuBarModel { model.menuBar }

    var body: some View {
        SettingsPage("Menu Bar", subtitle: "Arrange your desktop, one component at a time.") {
            previewCard
            LazyVStack(spacing: Metrics.cardGap, pinnedViews: bar.live ? [] : [.sectionHeaders]) {
                Section {
                    inspector
                    geometryCard
                    HStack {
                        Button("Refresh") { Task { await bar.refreshReadings() } }
                            .disabled(bar.isApplying || bar.isHydrating)
                        Spacer()
                        Button("Open config") {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                Paths.home.appending(path: ".config/sketchybar")
                            ])
                        }
                    }
                } header: {
                    componentCard
                        .padding(.top, bar.live ? 0 : Metrics.large)
                        .background(Color.paneBackground)
                        .padding(.bottom, Metrics.cardGap)
                }
            }
        }
        .task { await bar.observeWhileVisible() }
    }

    private var previewCard: some View {
        SettingsCard("Overview") {
            VStack(spacing: Metrics.medium) {
                toolbar
                if bar.isHydrating {
                    ProgressView("Reading your menu bar...").frame(height: 82)
                } else {
                    MenuBarStage(bar: bar, wallpaper: model.currentThemeWallpaper)
                }
                if bar.isApplying || bar.hasChanges {
                    HStack {
                        Spacer()
                        if bar.isApplying {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Unsaved changes").font(.meta).foregroundStyle(.secondary)
                        }
                    }
                }
                if let error = bar.error {
                    Text(error).font(.meta).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(Metrics.medium)
        }
    }

    /// Live preview on the left, the draft's actions on the right.
    ///
    /// These were five buttons in a row all taking the interface accent, so a
    /// destructive Discard and a neutral Undo shouted as loudly as Apply. Only
    /// the action that writes to the desktop is tinted now.
    private var toolbar: some View {
        HStack(spacing: Metrics.medium) {
            Toggle("Live preview", isOn: Binding(get: { bar.live }, set: { bar.setLive($0) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.rowTitle)
                .disabled(!bar.live && (bar.hasChanges || bar.isApplying))
                .hoverHelp("Apply each change straight away, or collect them in a draft")

            Spacer(minLength: Metrics.medium)

            if bar.hasChanges || !bar.live {
                ActionCluster {
                    IconButton(symbol: "arrow.uturn.backward", help: "Undo the last change") {
                        bar.undoLast()
                    }
                    .disabled(!bar.canUndo)
                    if !bar.live {
                        IconButton(symbol: "arrow.counterclockwise", help: "Discard the draft") {
                            bar.discard()
                        }
                        .disabled(!bar.hasChanges || bar.isApplying)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if !bar.live {
                Button(bar.isApplying ? "Applying…" : "Apply") { Task { await bar.apply() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!bar.hasChanges || bar.isApplying)
            }
        }
        .motion(Motion.snappy, value: bar.hasChanges)
        .motion(Motion.snappy, value: bar.live)
    }

    private var componentCard: some View {
        @Bindable var bar = bar
        return SettingsCard("Components") {
            VStack(alignment: .leading, spacing: Metrics.medium) {
                HStack {
                    SegmentedPill(
                        selection: $bar.side,
                        options: [
                            .init("left", "Left"), .init("center", "Centre"),
                            .init("right", "Right")
                        ])
                    Spacer()
                    Button("New", systemImage: "plus") { presentTemplates() }
                        .hoverHelp("Add a text or spacer component")
                }
                MenuBarStage(bar: bar, wallpaper: model.currentThemeWallpaper, half: bar.side)
                ScrollView(.horizontal) {
                    HStack(spacing: Metrics.small) {
                        ForEach(bar.draft.components.filter { $0.side == bar.side }) { component in
                            componentChip(component)
                        }
                    }.padding(3)
                }
                .scrollIndicators(.hidden)
            }.padding(Metrics.medium)
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
            .font(.rowTitle)
            .padding(.horizontal, Metrics.small).padding(.vertical, Metrics.small - 2)
            .background(
                bar.selection.contains(component.id)
                    ? Color.accentColor.opacity(0.20) : Color.controlWell,
                in: RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                    .strokeBorder(
                        bar.selection.contains(component.id) ? Color.accentColor : .clear))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { presentEditor(component) })
        .hoverHelp(
            "Click to select, Shift-click to select several. Drag to reorder or double-click to edit."
        )
        .draggable(component.id)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, bar.draft.components.contains(where: { $0.id == id }) else {
                return false
            }
            bar.move(id, before: component.id)
            return true
        }
    }

    /// Opens the gallery of starting points rather than dropping a blank
    /// chip into the bar and leaving you to work out what it should be.
    func presentTemplates() {
        model.modal.present {
            TemplateGallery { template in
                bar.add(from: template)
                model.modal.dismiss()
            } close: {
                model.modal.dismiss()
            }
        }
    }

}
