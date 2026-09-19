import SwiftUI

/// The frame every pane sits in: a large title with an optional subtitle and
/// trailing actions, then a scrolling column of cards.
///
/// Panes supply cards and nothing else — the page owns the title, the spacing
/// between cards and the scroll behaviour, so no two panes can disagree about
/// their margins.
struct SettingsPage<Actions: View, Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let actions: Actions
    private let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                content
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color.paneBackground)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) { actions }
        }
        .padding(.bottom, 2)
    }
}

extension SettingsPage where Actions == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, subtitle: subtitle, actions: { EmptyView() }, content: content)
    }
}
