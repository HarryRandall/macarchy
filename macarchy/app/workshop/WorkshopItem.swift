import SwiftUI

struct WorkshopItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let subtitle: String
    let colour: String

    var accent: Color { Color(macarchyHex: colour) ?? .gray }

    func previewTheme(in themes: [InstalledTheme]) -> InstalledTheme? {
        let names = [
            "dusk": "midnight", "moss": "lumon", "mono": "blackgold",
            "clay": "matte-black", "tide": "carbonfox", "orbit": "city-783",
            "linen": "turbonite", "ember": "awakening", "studio": "midnight"
        ]
        return themes.first { $0.name == names[id] } ?? themes.first
    }

    static let samples: [Self] = [
        .init(
            id: "dusk", name: "Dusk", category: "Desktop Packs",
            subtitle: "A softer end to the day.", colour: "#C4A3DA"),
        .init(
            id: "moss", name: "Moss", category: "Themes", subtitle: "A little closer to nature.",
            colour: "#9EB58B"),
        .init(
            id: "mono", name: "Mono", category: "Menu Bars", subtitle: "Only the essentials.",
            colour: "#B8BEC8"),
        .init(
            id: "clay", name: "Clay", category: "Themes", subtitle: "Warmth in the small things.",
            colour: "#D69C80"),
        .init(
            id: "tide", name: "Tide", category: "Desktop Packs",
            subtitle: "Room to find your flow.", colour: "#83BDBD"),
        .init(
            id: "orbit", name: "Orbit", category: "Menu Bars", subtitle: "Everything in its place.",
            colour: "#A5A9E0"),
        .init(
            id: "linen", name: "Linen", category: "Themes", subtitle: "An easy kind of quiet.",
            colour: "#D1C7AC"),
        .init(
            id: "ember", name: "Ember", category: "Themes", subtitle: "A bright idea after dark.",
            colour: "#D58A73"),
        .init(
            id: "studio", name: "Studio", category: "Menu Bars",
            subtitle: "Made for your working day.", colour: "#9BB0C7")
    ]
}
