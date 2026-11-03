import Foundation

extension BarConfiguration {
    /// The bar a fresh install starts with: Spaces on the left, and the
    /// network, memory, GPU, CPU, battery and clock widgets on the right, in
    /// that order, on a 35 point bar at the top of every Space.
    ///
    /// The right-hand widgets drop their outline, and the clock shows 24-hour
    /// time without its icon. These are changes on the bar's copies rather than in
    /// the manifests, so a widget added later starts from its own look and
    /// the Menu Bar page can reset each copy to it.
    public static var widgetDefault: BarConfiguration {
        var bar = BarConfiguration()
        bar.geometry = Dictionary(
            uniqueKeysWithValues: StartupConfiguration.sketchybarKeys.map {
                ($0.key, $0.fallback)
            })
        bar.componentPadding = 0
        bar.componentSpacing = 4
        bar.widgetGap = 2
        bar.widgetInset = 4
        bar.widgetHeight = 24
        let widgets = [
            ("spaces", "Spaces", "left"), ("network", "Network", "right"),
            ("memory", "Memory", "right"), ("gpu", "GPU", "right"), ("cpu", "CPU", "right"),
            ("battery", "Battery", "right"), ("clock", "Clock", "right")
        ]
        bar.components = widgets.map { widget, title, side in
            let id = "macarchy.\(widget)"
            var component = BarComponent(id: id, title: title, side: side, members: [id])
            component.widget = widget
            if side == "right" {
                var style = WidgetStyle()
                style.box = "none"
                if widget == "clock" {
                    style.showIcon = false
                    style.iconColour = "text"
                    component.settings = ["twentyFourHour": .bool(true)]
                }
                component.style = style
            }
            return component
        }
        return bar
    }
}
