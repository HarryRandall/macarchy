import Foundation

extension BarConfiguration {
    /// The bar a fresh install starts with: Spaces on the left, and the
    /// network, memory, GPU, CPU, battery and clock widgets on the right, in
    /// that order, on a 35 point bar at the top of every Space.
    public static var widgetDefault: BarConfiguration {
        var bar = BarConfiguration()
        bar.geometry = Dictionary(
            uniqueKeysWithValues: StartupConfiguration.sketchybarKeys.map {
                ($0.key, $0.fallback)
            })
        bar.componentPadding = 0
        bar.componentSpacing = 4
        let widgets = [
            ("spaces", "Spaces", "left"), ("network", "Network", "right"),
            ("memory", "Memory", "right"), ("gpu", "GPU", "right"), ("cpu", "CPU", "right"),
            ("battery", "Battery", "right"), ("clock", "Clock", "right")
        ]
        bar.components = widgets.map { widget, title, side in
            let id = "macarchy.\(widget)"
            var component = BarComponent(id: id, title: title, side: side, members: [id])
            component.widget = widget
            return component
        }
        return bar
    }
}
