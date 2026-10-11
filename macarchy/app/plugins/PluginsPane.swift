import SwiftUI

/// Optional integrations are presented separately from the core desktop controls.
struct PluginsPane: View {
    @Environment(AppModel.self) private var model
    @State private var category = "All"
    @State private var search = ""
    @Namespace private var chips

    private func count(_ value: String) -> Int {
        value == "All"
            ? AddOn.catalogue.count : AddOn.catalogue.filter { $0.category == value }.count
    }

    private var filtered: [AddOn] {
        AddOn.catalogue.filter {
            (category == "All" || $0.category == category)
                && (search.isEmpty
                    || "\($0.name) \($0.description) \($0.category)"
                        .localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        SettingsPage("Plugins", subtitle: "Your desktop. Only the extras you want.") {
            SearchField(prompt: "Search add-ons", text: $search, width: 190)
        } content: {
            filters

            HStack {
                SectionHeading("Optional add-ons", note: "\(filtered.count) shown")
                HelpTooltip(text: "Catalogue preview. Installation is not available yet.")
            }

            if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 248), spacing: Metrics.gridGap)],
                spacing: Metrics.gridGap
            ) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, plugin in
                    Button {
                        open(plugin)
                    } label: {
                        AddOnCard(plugin: plugin)
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .appearStagger(index)
                }
            }
        }
        .motion(Motion.snappy, value: category)
    }

    /// Presented inside the window, so the catalogue behind it goes inert.
    private func open(_ plugin: AddOn) {
        model.modal.present {
            AddOnDetail(plugin: plugin) { model.modal.dismiss() }
        }
    }

    private var summary: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: Metrics.medium)],
            spacing: Metrics.medium
        ) {
            ForEach(Array(AddOn.Stage.allCases.enumerated()), id: \.element) { index, stage in
                let matching = AddOn.catalogue.filter { $0.stage == stage }
                StatTile(
                    symbol: symbol(for: stage),
                    value: "\(matching.count)",
                    caption: stage.rawValue,
                    tint: stage.tone.colour,
                    emphasis: true
                ) {
                    Text(matching.map(\.name).joined(separator: " · "))
                        .font(.badge).foregroundStyle(Color.metaText).lineLimit(1)
                }
                .appearStagger(index)
            }
        }
    }

    private func symbol(for stage: AddOn.Stage) -> String {
        switch stage {
        case .planned: "checkmark.seal"
        case .exploring: "compass.drawing"
        case .considering: "lightbulb"
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Metrics.small) {
                ForEach(AddOn.categories, id: \.self) { value in
                    FilterChip(
                        label: value, count: count(value),
                        isSelected: category == value, namespace: chips
                    ) {
                        withAnimation(Motion.snappy) { category = value }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.never)
    }
}

private struct AddOnCard: View {
    let plugin: AddOn
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.medium) {
            HStack(alignment: .top) {
                Image(systemName: plugin.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(plugin.tint)
                    .frame(width: 38, height: 38)
                    .background(
                        plugin.tint.opacity(0.14),
                        in: RoundedRectangle(
                            cornerRadius: Metrics.radiusControl,
                            style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.radiusControl, style: .continuous)
                            .strokeBorder(plugin.tint.opacity(0.28), lineWidth: 1))
                Spacer()
                StatusChip(tone: plugin.stage.tone, label: plugin.stage.rawValue)
            }

            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(plugin.name).font(.sectionTitle)
                Text(plugin.description)
                    .font(.rowDetail).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            }

            // The three phrases do more than a category label alone: they say
            // what adopting the tool would change.
            VStack(alignment: .leading, spacing: 3) {
                ForEach(plugin.brings.prefix(3), id: \.self) { line in
                    HStack(spacing: Metrics.xs + 1) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(plugin.tint)
                        Text(line).font(.badge).foregroundStyle(Color.metaText).lineLimit(1)
                    }
                }
            }

            Divider()

            HStack {
                Text(plugin.category).font(.badge).foregroundStyle(Color.metaText)
                Spacer()
                HStack(spacing: Metrics.xs) {
                    Text("Details")
                    Image(systemName: "arrow.up.right")
                        .offset(
                            x: hovering && !reduceMotion ? 2 : 0,
                            y: hovering && !reduceMotion ? -2 : 0)
                }
                .font(.badge)
                .foregroundStyle(hovering ? plugin.tint : Color.metaText)
            }
        }
        .padding(Metrics.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface, in: shape)
        .overlay(
            shape.strokeBorder(
                hovering ? plugin.tint.opacity(0.45) : Color.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plugin.name). \(plugin.description). \(plugin.stage.rawValue)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}

private struct AddOnDetail: View {
    let plugin: AddOn
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add-on preview").font(.cardTitle).foregroundStyle(.secondary)
                HelpTooltip(
                    text:
                        "Installation is not available yet. This preview does not check installed apps."
                )
                Spacer()
                CloseButton(action: close)
            }
            .padding(Metrics.xl)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.large) {
                    HStack(spacing: Metrics.large) {
                        Image(systemName: plugin.icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(plugin.tint)
                            .frame(width: 58, height: 58)
                            .background(
                                plugin.tint.opacity(0.14),
                                in: RoundedRectangle(
                                    cornerRadius: Metrics.radiusCard,
                                    style: .continuous))
                        VStack(alignment: .leading, spacing: Metrics.xs) {
                            Text(plugin.name).font(.heroTitle)
                            HStack(spacing: Metrics.small) {
                                StatusChip(tone: .idle, label: plugin.category)
                                StatusChip(tone: plugin.stage.tone, label: plugin.stage.rawValue)
                            }
                        }
                        Spacer()
                    }

                    Text(plugin.description).font(.system(size: 13)).foregroundStyle(.secondary)
                    Divider()
                    Text("What it would bring").font(.cardTitle)
                    VStack(alignment: .leading, spacing: Metrics.small) {
                        ForEach(plugin.brings, id: \.self) { line in
                            HStack(spacing: Metrics.small) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(plugin.tint)
                                Text(line).font(.system(size: 13))
                            }
                        }
                    }
                    Divider()
                    Text(plugin.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(Metrics.xl)
            }
        }
        .frame(width: 480, height: 560)
        .background(Color.paneBackground)
    }
}
