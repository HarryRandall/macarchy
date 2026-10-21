import SwiftUI

/// The status item icon. It also lends the window-opening action to AppDelegate.
struct StatusLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if let logo = BrandMark.menuBar {
                Image(nsImage: logo).resizable().scaledToFit().frame(height: 15)
            } else {
                Image(systemName: "circle.lefthalf.filled")
            }
        }
        .onAppear { AppDelegate.openMainWindow = { openWindow(id: "main") } }
    }
}
