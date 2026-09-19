import SwiftUI

/// One row of a `SettingsCard`: an optional leading icon, a title with an
/// optional explanatory line under it, and a trailing control.
///
/// The title column is what the reader scans, so it stays flush left and the
/// control stays flush right however wide the window gets.
struct SettingRow<Leading: View, Accessory: View>: View {
    private let title: String
    private let detail: String?
    private let leading: Leading
    private let accessory: Accessory

    init(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.detail = detail
        self.leading = leading()
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

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
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.init(title, detail: detail, leading: { EmptyView() }, accessory: accessory)
    }
}

extension SettingRow where Leading == EmptyView, Accessory == EmptyView {
    init(_ title: String, detail: String? = nil) {
        self.init(title, detail: detail, leading: { EmptyView() }, accessory: { EmptyView() })
    }
}
