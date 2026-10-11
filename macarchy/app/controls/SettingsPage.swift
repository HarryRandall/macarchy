import SwiftUI

/// The frame every pane sits in: a large title with an optional subtitle and
/// trailing actions, then a scrolling column of cards.
///
/// Panes supply cards and nothing else — the page owns the title, the spacing
/// between cards and the scroll behaviour, so no two panes can disagree about
/// their margins.
struct SettingsPage<Actions: View, Banner: View, Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let actions: Actions
    private let banner: Banner
    private let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder banner: () -> Banner,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
        self.banner = banner()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.cardGap) {
                column { header }
                // The banner is given the pane rather than the column: a row
                // that runs wider than the text does — a carousel, a strip of
                // covers — is drawn and clicked out here, where the column's
                // edge cannot cut it off.
                banner
                column { content }
            }
            .padding(.top, Metrics.xxl + Metrics.small)
            .padding(.bottom, Metrics.xxl + Metrics.large)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        // Content passes under the title rather than stopping at a hard rule,
        // which is how the system separates chrome from content now.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Color.paneBackground)
    }

    /// The measure the page's text is set to, centred in the pane.
    private func column<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        inner()
            .frame(maxWidth: DesignSettings.shared.values.pageWidth, alignment: .leading)
            .padding(.horizontal, Metrics.pageMargin)
            .frame(maxWidth: .infinity)
    }

    /// One row while the title and the actions both fit; two once they do
    /// not. Squeezed into one row on a narrow window, the actions were
    /// clipped at the edge — a pane's mode switch simply disappeared.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                titleBlock
                Spacer(minLength: Metrics.large)
                actionRow
            }

            VStack(alignment: .leading, spacing: Metrics.medium) {
                titleBlock
                actionRow
            }
        }
        .padding(.bottom, Metrics.small)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Metrics.small - 2) {
            Text(title).font(.pageTitle)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actionRow: some View {
        HStack(spacing: Metrics.small) { actions }
    }
}

extension SettingsPage where Banner == EmptyView {
    /// A page with no full-width banner, which is most of them.
    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title, subtitle: subtitle, actions: actions, banner: { EmptyView() },
            content: content)
    }
}

extension SettingsPage where Actions == EmptyView, Banner == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title, subtitle: subtitle, actions: { EmptyView() }, banner: { EmptyView() },
            content: content)
    }
}

/// A heading that introduces a run of cards or a grid, with optional trailing
/// metadata.
///
/// Five panes built this same title-plus-count line by hand, at three
/// different sizes.
struct SectionHeading<Trailing: View>: View {
    private let title: String
    private let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.sectionTitle)
            Spacer(minLength: Metrics.medium)
            trailing
        }
        .padding(.top, Metrics.xs)
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title, trailing: { EmptyView() })
    }
}

extension SectionHeading where Trailing == Text {
    /// The common case: a heading with a count or a note on the right.
    init(_ title: String, note: String) {
        self.init(title) { Text(note).font(.meta).foregroundStyle(Color.metaText) }
    }
}
