import Macarchy
import SwiftUI

/// One component drawn the way the bar would draw it, at a given reading.
///
/// The studio puts several of these side by side, because a component that
/// looks right at 47% can still break at "0.00" or at a track title long
/// enough to shove everything else off the bar.
struct ComponentChip: View {
    let component: BarComponent
    let value: String
    var barColour: Color = .black
    var scale: CGFloat = 1

    private var label: String { component.rendered(value) }

    var body: some View {
        HStack(spacing: 8 * scale) {
            if !component.icon.isEmpty {
                Text(component.icon)
                    .font(.system(size: 15 * scale))
                    .foregroundStyle(
                        Color(macarchyHex: component.iconColour)
                            ?? Color(macarchyHex: component.colour) ?? .white)
            }
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(Color(macarchyHex: component.colour) ?? .white)
                    .lineLimit(1)
            }
            if component.kind == "spacer" {
                Color.clear.frame(width: component.customWidth * scale)
            }
        }
        .padding(.horizontal, (component.paddingOverride ?? 0) * scale)
        .padding(.vertical, 4 * scale)
        .background {
            if let fill = Color(macarchyHex: component.backgroundColour) {
                RoundedRectangle(cornerRadius: component.cornerRadius * scale, style: .continuous)
                    .fill(fill)
            }
        }
        .fixedSize()
    }
}

/// The states strip: the component at each of its sample readings.
struct ComponentStates: View {
    let component: BarComponent
    let barColour: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            ScrollView(.horizontal) {
                HStack(spacing: Metrics.medium) {
                    ForEach(Array(component.samples.enumerated()), id: \.offset) { _, value in
                        VStack(spacing: Metrics.xs) {
                            ComponentChip(component: component, value: value)
                                .padding(.horizontal, Metrics.small)
                                .padding(.vertical, Metrics.small)
                                .frame(minWidth: 70)
                                .background(barColour, in: shape)
                                .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
                            Text(value.isEmpty ? "empty" : value)
                                .font(.badge)
                                .foregroundStyle(Color.metaText)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, CardMetrics.horizontalPadding)
                .padding(.vertical, Metrics.medium)
            }
            .scrollIndicators(.never)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
    }
}

/// A grid of glyphs that render in the real bar.
struct GlyphPicker: View {
    @Binding var glyph: String
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Choose an icon").font(.sectionTitle)
                Spacer()
                CloseButton(action: close)
            }
            .padding(Metrics.xl)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.large) {
                    ForEach(GlyphCatalogue.groups) { group in
                        VStack(alignment: .leading, spacing: Metrics.small) {
                            Text(group.id.uppercased()).eyebrowStyle()
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 44), spacing: Metrics.small)],
                                spacing: Metrics.small
                            ) {
                                ForEach(group.glyphs, id: \.self) { candidate in
                                    button(candidate)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: Metrics.small) {
                        Text("OR TYPE ONE").eyebrowStyle()
                        TextField("Any character", text: $glyph)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 15))
                    }
                }
                .padding(Metrics.xl)
            }
        }
        .frame(width: 420, height: 480)
        .background(Color.paneBackground)
    }

    private func button(_ candidate: String) -> some View {
        let isChosen = candidate == glyph
        return Button {
            withAnimation(Motion.snappy) { glyph = candidate }
        } label: {
            Text(candidate)
                .font(.system(size: 17))
                .frame(width: 42, height: 38)
                .background(
                    isChosen ? Color.accentColor.opacity(0.2) : Color.controlWell,
                    in: RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.radiusSmall, style: .continuous)
                        .strokeBorder(
                            isChosen ? Color.accentColor : Color.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Icon \(candidate)")
        .accessibilityAddTraits(isChosen ? [.isButton, .isSelected] : .isButton)
    }
}

/// The gallery of starting points, shown when adding a component.
struct TemplateGallery: View {
    let choose: (ComponentTemplate) -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Add a component").font(.sectionTitle)
                HelpTooltip(text: "Choose a starting point, then customise it in the editor.")
                Spacer()
                CloseButton(action: close)
            }
            .padding(Metrics.xl)
            Divider()
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: Metrics.medium)],
                    spacing: Metrics.medium
                ) {
                    ForEach(ComponentTemplate.all) { template in
                        Button {
                            choose(template)
                        } label: {
                            card(template)
                        }
                        .buttonStyle(.plain)
                        .hoverLift(scale: 1.02, lift: 1)
                    }
                }
                .padding(Metrics.xl)
            }
        }
        .frame(width: 520, height: 500)
        .background(Color.paneBackground)
    }

    private func card(_ template: ComponentTemplate) -> some View {
        VStack(alignment: .leading, spacing: Metrics.small) {
            HStack(spacing: Metrics.small) {
                Image(systemName: template.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(template.tint)
                    .frame(width: 28, height: 28)
                    .background(
                        template.tint.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: Metrics.radiusSmall))
                Text(template.title).font(.cardTitle)
                Spacer(minLength: 0)
            }
            Text(template.blurb)
                .font(.rowDetail).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(template.samples.prefix(2).joined(separator: "  ·  "))
                .font(.monoDetail).foregroundStyle(Color.metaText).lineLimit(1)
        }
        .padding(Metrics.medium)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(Color.cardSurface, in: shape)
        .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}
