import SwiftUI

/// The status item icon. It also lends the window-opening action to AppDelegate.
struct StatusLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "circle.lefthalf.filled")
            .onAppear { AppDelegate.openMainWindow = { openWindow(id: "main") } }
    }
}
