import SwiftUI

/// A full-bleed preview with a caption bar under it.
///
/// Home, Themes and Workshop each built this by hand at three different
/// radii, with and without a border, so a banner changed shape as you moved
/// between panes.
struct HeroBanner<Artwork: View, Trailing: View>: View {
    private let eyebrow: String?
    private let title: String
    private let subtitle: String?
    private let artwork: Artwork
    private let trailing: Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artwork
            HStack(alignment: .center, spacing: Metrics.large) {
                VStack(alignment: .leading, spacing: Metrics.xs) {
                    if let eyebrow { Text(eyebrow).eyebrowStyle() }
                    Text(title).font(.heroTitle)
                    if let subtitle {
                        Text(subtitle).font(.meta).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: Metrics.medium)
                trailing
            }
            .padding(Metrics.xl)
        }
        .background(Color.cardSurface, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}

extension HeroBanner where Trailing == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.init(
            eyebrow: eyebrow, title: title, subtitle: subtitle, artwork: artwork,
            trailing: { EmptyView() })
    }
}

/// An icon, a short explanation and an optional action.
///
/// Used where a pane needs to say what it is for before showing any controls.
struct CalloutCard<Trailing: View>: View {
    private let symbol: String
    private let title: String
    private let message: String
    private let trailing: Trailing

    init(
        symbol: String,
        title: String,
        message: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.large) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(title).font(.sectionTitle)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Metrics.medium)
            trailing
        }
        .padding(Metrics.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardSurface, in: shape)
        .overlay(shape.strokeBorder(Color.cardBorder, lineWidth: 1))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous)
    }
}

extension CalloutCard where Trailing == EmptyView {
    init(symbol: String, title: String, message: String) {
        self.init(
            symbol: symbol, title: title, message: message,
            trailing: { EmptyView() })
    }
}
