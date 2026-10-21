import AppKit
import Macarchy
import SwiftUI

extension ComponentEditor {
    @ViewBuilder
    func layoutTab(_ component: BarComponent) -> some View {
        if component.kind == "spacer" {
            SettingsCard(
                "Empty space", help: "Place this spacer between components to add space there."
            ) {
                SettingRow("Width", help: "Drag either edge in the preview") {
                    ValueSlider(
                        value: Binding(
                            get: { measuredWidth }, set: { resizeBox(component, width: $0) }),
                        range: 1...200, unit: "pt"
                    ) { _ in }
                    Button("Reset") { resizeBox(component, width: 20) }
                }
            }
        } else {
            partInspector(component)
        }
        positionInspector(component)
    }

    private func partInspector(_ component: BarComponent) -> some View {
        SettingsCard("Edit a part") {
            HStack {
                Button("Box") { selectedParts = [] }
                    .tint(selectedParts.isEmpty ? .accentColor : .secondary)
                ForEach(ComponentGeometry(items: nativeItems, component: component).parts) { part in
                    Button(partTitle(part)) { selectedParts = [part.id] }
                        .tint(selectedParts.contains(part.id) ? .accentColor : .secondary)
                }
            }.padding(Metrics.medium)
            movementControls(component)
            if let part = ComponentGeometry(items: nativeItems, component: component).parts.first(
                where: { $0.id == selectedPart }),
                let item = nativeItems.first(where: { $0.id == part.member })
            {
                SettingRow(
                    partTitle(part) + (part.layer == "image" ? " height" : " text size"),
                    help: "Drag the selected part to move it. Drag either edge to resize it."
                ) {
                    ValueSlider(
                        value: Binding(
                            get: {
                                let current = item.presenting(live(component))
                                if part.layer == "image" { return part.frame.height }
                                return SketchybarFont(
                                    part.layer == "icon" ? current.icon.font : current.label.font
                                ).native.pointSize
                            },
                            set: { sizePart(component, id: part.id, height: $0, textPoints: true) }),
                        range: 6...40, unit: "pt"
                    ) { _ in }
                }
            } else if selectedParts.isEmpty {
                SettingRow("Box width", help: "Drag either edge in the preview") {
                    NumberField(
                        value: Binding(
                            get: { measuredWidth }, set: { resizeBox(component, width: $0) }),
                        range: 24...1000)
                    Text("pt").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func positionInspector(_ component: BarComponent) -> some View {
        SettingsCard("Position and order") {
            SettingRow("Screen area") {
                SegmentedPill(
                    selection: Binding(
                        get: { live(component).side },
                        set: { bar.moveToSide(component.id, side: $0) }),
                    options: [
                        .init("left", "Left"), .init("center", "Centre"), .init("right", "Right")
                    ])
            }
            SettingRow("Order", detail: orderDescription(component)) {
                Button("← One left") { moveNeighbour(component, direction: -1) }.disabled(
                    !canMove(component, direction: -1))
                Button("One right →") { moveNeighbour(component, direction: 1) }.disabled(
                    !canMove(component, direction: 1))
            }
            if component.kind != "spacer" {
                SettingRow("Space to next component") {
                    ValueSlider(value: gapBinding(component), range: 0...40, unit: "pt") { _ in }
                    Button("Reset") { bar.update(component.id) { $0.spacingOverride = nil } }
                        .disabled(
                            component.spacingOverride == nil)
                }
            }
        }
    }

    func partTitle(_ part: ComponentGeometry.Part) -> String {
        guard let item = nativeItems.first(where: { $0.id == part.member }) else { return "Part" }
        return part.layer == "image" ? "Icon" : layerTitle(item, icon: part.layer == "icon")
    }

    private func movementControls(_ component: BarComponent) -> some View {
        HStack {
            Button("Select all parts") {
                selectedParts = Set(
                    ComponentGeometry(items: nativeItems, component: component).parts.map(\.id))
            }
            Text("\(selectedParts.count) selected").font(.meta).foregroundStyle(.secondary)
            Spacer()
            ForEach(["Left", "Right", "Up", "Down"], id: \.self) { direction in
                let delta = CGSize(
                    width: direction == "Left" ? -1 : direction == "Right" ? 1 : 0,
                    height: direction == "Up" ? -1 : direction == "Down" ? 1 : 0)
                Button(direction) { moveParts(component, ids: selectedParts, delta: delta) }
                    .disabled(selectedParts.isEmpty)
                    .help("Move selected parts one point " + direction.lowercased())
            }
        }.padding(Metrics.medium)
    }

    func moveParts(_ component: BarComponent, ids: Set<String>, delta: CGSize) {
        let moved = ComponentMovement.moving(
            items: nativeItems, component: live(component), ids: ids, delta: delta)
        bar.update(component.id) { $0 = moved }
    }

    func sizePart(
        _ component: BarComponent, id: String, height: Double, textPoints: Bool = false,
        leading: Bool = false
    ) {
        let component = live(component)
        guard
            let part = ComponentGeometry(items: nativeItems, component: component).parts.first(
                where: { $0.id == id }),
            let item = nativeItems.first(where: { $0.id == part.member })
        else { return }
        let current = item.presenting(component)
        var values = ComponentGeometry.positionedText(current)
        if part.layer == "image" {
            let nativeHeight =
                current.background.imageURL.flatMap { NSImage(contentsOf: $0) }?.size.height ?? 1
            values = [
                "background.image.scale": String(max(6, min(height, 60)) / max(nativeHeight, 1))
            ]
        } else {
            let raw =
                (part.layer == "icon" ? current.icon.font : current.label.font)
                ?? "SF Pro:Regular:12"
            let font = SketchybarFont(raw).native
            let size = textPoints ? height : font.pointSize * height / max(part.frame.height, 1)
            values[part.layer + ".font"] =
                raw.split(separator: ":").prefix(2).joined(separator: ":") + ":"
                + String(max(6, min(size, 40)))
        }
        if leading {
            values = ComponentMovement.anchoringRightEdge(
                values, item: item,
                component: component, layer: part.layer)
        }
        if part.layer != "image" {
            var candidate = component
            candidate.presentation[item.id, default: [:]].merge(values) { _, new in new }
            values.merge(
                ComponentGeometry.reservedReadings(item.presenting(candidate), component: component)
            ) { _, new in new }
        }
        let width = measuredWidth
        bar.update(component.id) { target in
            capture(values, item: item, target: &target)
            if target.boxWidth == nil { target.boxWidth = width }
        }
    }

    func resetLayout(_ component: BarComponent) {
        let keys: Set<String> = [
            "align", "width", "icon.width", "label.width", "icon.align", "label.align", "icon.font",
            "label.font", "icon.padding_left", "label.padding_left", "icon.padding_right",
            "label.padding_right", "icon.y_offset", "label.y_offset", "background.image.scale",
            "background.image.padding_left", "background.image.y_offset"
        ]
        bar.update(component.id) { target in
            for id in target.members {
                for key in keys {
                    target.presentation[id]?[key] = target.presentationDefaults[id]?[key]
                }
            }
            target.boxWidth = nil
            target.paddingOverride = nil
        }
    }

    private func orderDescription(_ component: BarComponent) -> String {
        let peers = bar.draft.components.filter { $0.side == component.side }
        return "Position \((peers.firstIndex { $0.id == component.id } ?? 0) + 1) of \(peers.count)"
    }

    private func canMove(_ component: BarComponent, direction: Int) -> Bool {
        let peers = bar.draft.components.filter { $0.side == component.side }
        guard let index = peers.firstIndex(where: { $0.id == component.id }) else { return false }
        return peers.indices.contains(index + direction)
    }

    private func moveNeighbour(_ component: BarComponent, direction: Int) {
        bar.edit { $0.moveOne(component.id, direction: direction) }
    }
}
