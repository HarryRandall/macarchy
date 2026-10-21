import Macarchy
import SwiftUI

extension ComponentEditor {
    @ViewBuilder
    func sourceTab(_ component: BarComponent) -> some View {
        SettingsCard(
            "Data source",
            help: component.isCustom
                ? "Static text with no live data source."
                : "Widget scripts refresh readings, symbols and colours. Preview samples are illustrative."
        ) {
            SettingRow(ComponentSource.describe(component).title, detail: freshness(component)) {
                Text(component.isCustom ? "Static" : "Existing widget").font(.meta).foregroundStyle(
                    .secondary)
            }
        }
        ForEach(nativeItems) { item in
            SettingsCard(item.id) {
                if item.icon.drawing {
                    SettingRow(layerTitle(item, icon: true)) {
                        Text(item.icon.value).font(.monoDetail)
                    }
                }
                if item.label.drawing {
                    SettingRow(layerTitle(item, icon: false)) {
                        Text(item.label.value).font(.monoDetail)
                    }
                }
                SettingRow("Measured frame") {
                    Text("\(Int(item.frame.width)) × \(Int(item.frame.height)) pt").font(
                        .monoDetail)
                }
                SettingRow("Visibility") { Text(item.drawing ? "Drawing" : "Hidden").font(.meta) }
            }
        }
    }

    func layerTitle(_ item: SketchybarItem, icon: Bool) -> String {
        guard let component else { return icon ? "Icon" : "Label" }
        let readings = ComponentSource.describe(component).readings
        if item.id.hasSuffix(".text"), readings.count > 1 { return readings[icon ? 0 : 1] }
        return icon ? "Icon" : (readings.first ?? "Label")
    }
}
