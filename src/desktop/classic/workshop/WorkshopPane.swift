import SwiftUI

struct WorkshopPane: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var category = "All"
    @State private var dense = false
    /// Starts in the middle so there is something on both sides straight
    /// away, rather than an empty left edge.
    @State private var featured = DesignSettings.shared.values.listings.count / 2
    @Namespace private var featuredNamespace

    private var design: DesignSettings.Values { DesignSettings.shared.values }
    private let categories = ["All", "Themes", "Menu Bars", "Desktop Packs"]

    private func count(_ value: String) -> Int {
        value == "All"
            ? design.listings.count : design.listings.filter { $0.category == value }.count
    }

    private var filtered: [WorkshopItem] {
        design.listings.filter {
            (category == "All" || $0.category == category)
                && (search.isEmpty
                    || "\($0.name) \($0.subtitle) \($0.category)"
                        .localizedCaseInsensitiveContains(search))
        }
    }

    private var showsFeature: Bool { category == "All" && search.isEmpty }

    var body: some View {
        SettingsPage("Workshop", subtitle: "Find a new perspective for your desktop.") {
            SearchField(prompt: "Search designs", text: $search, width: 200)
            // A pill bound straight to the state. As two icon buttons inside
            // a decorated capsule, the capsule's stroke overlay sat above them
            // and swallowed clicks along its edge.
            SegmentedPill(
                selection: $dense.animation(Motion.snappy),
                options: [.init(false, "Grid"), .init(true, "List")])
        } banner: {
            if showsFeature, !design.listings.isEmpty {
                featureCarousel
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        } content: {
            filters

            SectionHeading(
                showsFeature ? "Explore the collection" : category,
                note: "\(filtered.count) designs · Sample catalogue")

            if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
                    .transition(.opacity)
            }

            if dense {
                VStack(spacing: Metrics.small) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                        Button {
                            open(item)
                        } label: {
                            WorkshopRow(item: item)
                        }
                        .buttonStyle(InteractiveButtonStyle(cornerRadius: Metrics.radiusCard))
                        .appearStagger(index)
                    }
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260), spacing: Metrics.gridGap)],
                    spacing: Metrics.gridGap
                ) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                        Button {
                            open(item)
                        } label: {
                            WorkshopCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .hoverLift()
                        .appearStagger(index)
                    }
                }
            }
        }
        .motion(Motion.snappy, value: category)
        .motion(Motion.snappy, value: dense)
    }

    /// Presented inside the window, so the grid behind it stops responding.
    private func open(_ item: WorkshopItem) {
        model.modal.present {
            WorkshopDetail(item: item) { model.modal.dismiss() }
        }
    }

    /// The lead listings, stacked so the next and previous ones stay on
    /// screen rather than being hidden behind a page change.
    private var featureCarousel: some View {
        let listings = design.listings
        return VStack(alignment: .leading, spacing: Metrics.medium) {
            Coverflow(items: listings, index: $featured, height: 290) { item, placement in
                FeatureCover(item: item, placement: placement) { open(item) }
            }
            CoverflowControls(count: listings.count, index: $featured)
                .frame(maxWidth: .infinity)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Metrics.small) {
                ForEach(categories, id: \.self) { value in
                    FilterChip(
                        label: value,
                        count: count(value),
                        isSelected: category == value,
                        namespace: featuredNamespace
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

/// A pill that says how much is behind it, and slides its highlight between
/// neighbours rather than blinking from one to the next.
struct FilterChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metrics.xs + 2) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                CountBadge(count: count, tint: isSelected ? .accentColor : nil)
            }
            .padding(.horizontal, Metrics.medium)
            .padding(.vertical, Metrics.small - 1)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.45)))
                        .matchedGeometryEffect(id: "filter", in: namespace)
                } else {
                    Capsule().fill(Color.controlWell)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(count) designs")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// One cover in the featured stack: the theme's desktop, with its terminal
/// laid over it and the title along the bottom.
private struct FeatureCover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: WorkshopItem
    let placement: CoverPlacement
    let action: () -> Void

    private var isFront: Bool { placement.isFront }

    /// A cover behind the front one is only half on show, and which half
    /// depends on the side it is stacked to. The caption goes on the edge
    /// that is actually visible, so every name in the row can be read.
    private var edge: HorizontalAlignment { placement == .trailing ? .trailing : .leading }
    private var corner: Alignment { placement == .trailing ? .bottomTrailing : .bottomLeading }

    @State private var hovering = false

    private var theme: InstalledTheme? { item.previewTheme(in: model.themes.themes) }

    var body: some View {
        ZStack(alignment: corner) {
            DesktopArtwork(
                accent: item.accent,
                wallpaper: theme?.wallpaperURL,
                palette: theme?.palette,
                variant: item.category == "Menu Bars" ? .menuBar : .desktop,
                height: 290)

            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black.opacity(0.92)],
                startPoint: .center, endPoint: .bottom)

            HStack(alignment: .bottom, spacing: Metrics.large) {
                if placement == .trailing { Spacer(minLength: Metrics.small) }
                VStack(alignment: edge, spacing: Metrics.xs) {
                    Text(item.category.uppercased())
                        .font(.system(size: isFront ? 10 : 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(item.name)
                        .font(.system(size: isFront ? 26 : 19, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(item.subtitle)
                        .font(.system(size: isFront ? 13 : 11))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .multilineTextAlignment(placement == .trailing ? .trailing : .leading)
                if placement != .trailing { Spacer(minLength: Metrics.small) }
                if isFront {
                    HStack(spacing: Metrics.xs) {
                        Text("Explore")
                        Image(systemName: "arrow.right")
                            .offset(x: hovering && !reduceMotion ? 3 : 0)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Metrics.large)
                    .padding(.vertical, Metrics.small + 1)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(Metrics.large)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        // Behind the front cover, the card is transparent to the pointer so
        // the stack underneath can take the click and bring it forward.
        .allowsHitTesting(isFront)
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name). \(item.subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}
