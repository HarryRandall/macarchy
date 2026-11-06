import SwiftUI

/// The status item icon.
struct StatusLabel: View {
    var body: some View {
        Group {
            if let logo = BrandMark.menuBar {
                Image(nsImage: logo).resizable().scaledToFit().frame(height: 15)
            } else {
                Image(systemName: "circle.lefthalf.filled")
            }
        }
    }
}
