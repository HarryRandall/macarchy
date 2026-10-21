import Foundation
import Macarchy

extension MenuBarModel {
    /// Adds a component pre-filled from a template.
    func add(from template: ComponentTemplate) {
        let id = "macarchy." + UUID().uuidString.lowercased()
        var component = BarComponent(
            id: id, title: template.title, side: side, members: [id])
        template.apply(to: &component)
        let neighbour = selected
        edit { configuration in
            if template.id == "spacer",
                let index = configuration.components.firstIndex(where: { $0.id == neighbour })
            {
                component.side = configuration.components[index].side
                configuration.components.insert(component, at: index + 1)
            } else {
                configuration.components.append(component)
            }
        }
        selected = id
    }

}
