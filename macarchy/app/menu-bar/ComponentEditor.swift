import Macarchy
import SwiftUI

/// Fixed context and measured preview above a compact presentation inspector.
struct ComponentEditor: View {
    @Environment(AppModel.self) var model
    let componentID: String
    let close: () -> Void
    @State var tab: Tab = .layout
    @State var sample = "Now"
    @State var guides = true
    @State var selectedParts: Set<String> = []
    var selectedPart: String? { selectedParts.count == 1 ? selectedParts.first : nil }

    enum Tab: String, CaseIterable {
        case layout = "Layout"
        case look = "Style"
        case source = "Source"
    }

    var bar: MenuBarModel { model.menuBar }
    var component: BarComponent? { bar.draft.components.first { $0.id == componentID } }
    var nativeItems: [SketchybarItem] {
        bar.items.filter { component?.members.contains($0.id) == true && !$0.id.hasPrefix("gap.") }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let component {
                header(component)
                Divider()
                MenuBarStage(
                    bar: bar, wallpaper: model.currentThemeWallpaper, half: component.side,
                    compact: true
                )
                .frame(height: 48, alignment: .top).clipped()
                .padding(.horizontal, Metrics.large).padding(.top, Metrics.small)
                .allowsHitTesting(false)
                ComponentCanvas(
                    bar: bar, component: component, sample: sample, guides: guides,
                    wallpaper: model.currentThemeWallpaper, selectedParts: $selectedParts,
                    onResize: { resizeBox(component, width: $0, leading: $1) },
                    onMove: { moveParts(component, ids: $0, delta: $1) },
                    onSize: { sizePart(component, id: $0, height: $1, leading: $2) }
                )
                .padding(.horizontal, Metrics.large).padding(.top, Metrics.medium)
                if component.kind != "spacer" { previewControls(component) }
                Divider()
                if component.kind != "spacer" {
                    SegmentedPill(
                        selection: $tab, options: Tab.allCases.map { .init($0, $0.rawValue) },
                        isProminent: true
                    )
                    .padding(.vertical, Metrics.small)
                }
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: Metrics.cardGap) {
                        if component.kind == "spacer" {
                            layoutTab(component)
                        } else {
                            switch tab {
                            case .look: lookTab(component)
                            case .layout: layoutTab(component)
                            case .source: sourceTab(component)
                            }
                        }
                    }.padding(Metrics.large)
                }
                Divider()
                HStack {
                    HelpTooltip(
                        text: bar.live
                            ? "Changes apply as you edit." : "Apply changes from the Menu Bar page."
                    )
                    Spacer()
                    Button("Undo") { bar.undoLast() }.disabled(!bar.canUndo)
                    Button("Revert to applied") { revert(component) }
                        .disabled(
                            component == bar.applied.components.first { $0.id == component.id })
                }.font(.meta).foregroundStyle(.secondary).padding(Metrics.medium)
            } else {
                ContentUnavailableView(
                    "Component removed", systemImage: "questionmark.square.dashed")
            }
        }
        .frame(width: 640, height: 680)
        .background(Color.paneBackground)
        .onDisappear { bar.endInteraction() }
    }

    private func header(_ component: BarComponent) -> some View {
        HStack(spacing: Metrics.medium) {
            VStack(alignment: .leading, spacing: Metrics.xs) {
                HStack {
                    Text(component.title).font(.sectionTitle)
                    HelpTooltip(text: ComponentSource.describe(component).title)
                }
            }
            Spacer()
            Toggle("Visible", isOn: binding(component, \.visible))
                .toggleStyle(.switch).controlSize(.small).labelsHidden()
            if component.isCustom {
                IconMenu(symbol: "ellipsis", help: "Component actions") {
                    Button("Remove component", role: .destructive) {
                        bar.removeCustom(component.id); close()
                    }
                }
            }
            CloseButton(action: close)
        }.padding(Metrics.large)
    }

    private func previewControls(_ component: BarComponent) -> some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            HStack {
                SegmentedPill(
                    selection: $sample,
                    options: [.init("Now", "Live reading"), .init("Widest", "Longest reading")])
                Spacer()
                Button("Make it fit") { makeItFit(component) }
                    .hoverHelp("Fit the icon and all reading samples inside the component box")
                Button("Reset layout") { resetLayout(component) }
                HelpTooltip(
                    text:
                        "Drag parts to move them. Shift-click to select several. Drag either box edge to resize."
                )
            }
        }.padding(Metrics.medium)
    }

    func freshness(_ component: BarComponent) -> String {
        if component.isCustom { return "Static element · no sensor attached" }
        if let error = bar.observationError { return "Unavailable · \(error)" }
        guard let time = bar.lastObservedAt else { return "Waiting for a reading" }
        let age = Int(Date().timeIntervalSince(time))
        return age < 30 ? "Observed \(age)s ago" : "Stale · \(age)s ago"
    }

    func revert(_ component: BarComponent) {
        guard let original = bar.applied.components.first(where: { $0.id == component.id }) else {
            return
        }
        bar.update(component.id) { $0 = original }
    }
}
