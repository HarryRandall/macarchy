import AppKit
import Macarchy
import SwiftUI

extension ComponentEditor {
    var measuredWidth: Double {
        guard let component else { return 24 }
        if let width = MenuBarLayout(bar: bar).frames[component.id]?.width { return Double(width) }
        return component.boxWidth ?? Double(MenuBarLayout.customWidth(component))
    }

    var canvasOffsets: [String: Double] {
        guard let component else { return [:] }
        let layout = MenuBarLayout(bar: bar)
        let origin =
            layout.frames[component.id]?.minX ?? nativeItems.filter(\.isOnScreen).map(\.frame.minX)
            .min() ?? 0
        return Dictionary(
            uniqueKeysWithValues: nativeItems.filter(\.isOnScreen).map {
                ($0.id, Double((layout.memberFrames[$0.id]?.minX ?? $0.frame.minX) - origin))
            })
    }

    func makeItFit(_ component: BarComponent) {
        let items = nativeItems.filter(\.isOnScreen)
        let offsets = canvasOffsets
        let padding = bar.draft.padding(for: component)
        let fitted = ComponentSizing.fitting(
            items: items, component: component, offsets: offsets,
            padding: padding, height: bar.height)
        bar.update(component.id) { $0 = fitted }
    }

    func capture(_ values: [String: String], item: SketchybarItem, target: inout BarComponent) {
        for (key, value) in values {
            if target.presentationDefaults[item.id]?[key] == nil {
                target.presentationDefaults[item.id, default: [:]][key] = item.editableSettings[key]
            }
            target.presentation[item.id, default: [:]][key] = value
        }
    }

    func resizeBox(_ component: BarComponent, width: Double, leading: Bool = false) {
        let resized = ComponentSizing.resizing(
            items: nativeItems, component: live(component),
            currentWidth: measuredWidth, width: width, leading: leading)
        bar.update(component.id) { $0 = resized }
    }

    func restoreBox(_ component: BarComponent) {
        bar.update(component.id) { target in
            target.boxWidth = nil
            for id in target.members {
                target.presentation[id]?["width"] = target.presentationDefaults[id]?["width"]
            }
        }
    }

}
