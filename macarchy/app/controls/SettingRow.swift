import SwiftUI

/// One row of a `SettingsCard`: an optional leading icon, a title with an
/// optional value or status under it, and a trailing control.
///
/// The title column is what the reader scans, so it stays flush left and the
/// control stays flush right however wide the window gets.
///
/// `detail` shows values or essential status inline. Secondary explanations
/// belong in `help`, which appears only on hover or focus.
struct SettingRow<Leading: View, Accessory: View>: View {
    private let title: String
    private let detail: String?
    private let help: String?
    private let leading: Leading
    private let accessory: Accessory

    init(
        _ title: String,
        detail: String? = nil,
        help: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.detail = detail
        self.help = help
        self.leading = leading()
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.medium) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(title).font(.rowTitle).foregroundStyle(.primary)
                    if let help { HelpTooltip(text: help) }
                }
                if let detail {
                    Text(detail)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Metrics.medium)

            accessory
        }
        .padding(.horizontal, CardMetrics.horizontalPadding)
        .padding(.vertical, CardMetrics.rowVerticalPadding)
    }
}

extension SettingRow where Leading == EmptyView {
    init(
        _ title: String,
        detail: String? = nil,
        help: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.init(title, detail: detail, help: help, leading: { EmptyView() }, accessory: accessory)
    }
}

extension SettingRow where Leading == EmptyView, Accessory == EmptyView {
    init(_ title: String, detail: String? = nil, help: String? = nil) {
        self.init(
            title, detail: detail, help: help, leading: { EmptyView() }, accessory: { EmptyView() })
    }
}
