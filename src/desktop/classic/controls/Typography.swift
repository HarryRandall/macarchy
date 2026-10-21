import SwiftUI

/// The type scale, named by the job each size does.
///
/// Every size here is a step on Apple's macOS scale — Large Title 26, Title 1
/// 22, Title 3 15, Headline and Body 13, Callout 12, Subheadline 11, Caption
/// 10 — and nothing sits below the platform's 10 pt minimum. The app
/// previously mixed 16 hardcoded sizes with 13 semantic styles, including six
/// uses of 9 pt; naming the roles keeps a heading in Themes the same size as a
/// heading in Layout.
extension Font {
    /// The title at the top of a pane. Large Title.
    static let pageTitle = Font.system(size: 26, weight: .semibold)

    /// The headline inside a hero card, and any large standalone figure.
    /// Title 1 — one size for what used to be 23, 25 and 28.
    static let heroTitle = Font.system(size: 22, weight: .semibold)

    /// A heading introducing a group of cards. Title 3.
    static let sectionTitle = Font.system(size: 15, weight: .semibold)

    /// The label above a card, and the name inside a grid tile. Headline.
    static let cardTitle = Font.system(size: 13, weight: .semibold)

    /// The title of a settings row. Body — the platform default.
    static let rowTitle = Font.system(size: 13)

    /// The explanatory line under a row title. Subheadline.
    static let rowDetail = Font.system(size: 11)

    /// Counts, categories, timestamps and status. Subheadline.
    static let meta = Font.system(size: 11)

    /// A small all-caps label introducing a block. Caption, at the 10 pt
    /// floor; the tracking below is what makes it read as an eyebrow.
    static let eyebrow = Font.system(size: 10, weight: .semibold)

    /// A count or state inside a pill. Caption 2.
    static let badge = Font.system(size: 10, weight: .medium)

    /// Commands, paths and anything quoted from a configuration file.
    static let monoDetail = Font.system(size: 11, design: .monospaced)
}

extension View {
    /// An all-caps label with the letterspacing that style needs.
    ///
    /// The system already widens tracking below 12 pt, so this adds only the
    /// extra the style calls for — the app previously stacked 1.2, 1.3, 1.8
    /// and 2.0 on top of it in different panes.
    func eyebrowStyle() -> some View {
        font(.eyebrow)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}
