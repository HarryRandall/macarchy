import Macarchy
import SwiftUI

/// Chooses the theme's Neovim colourscheme from those installed on this Mac.
struct NeovimColourschemeRow: View {
    @Binding var draft: Theme?
    let save: (Theme) -> Void

    /// Read once per editor; listing plugin folders is cheap but not free.
    @State private var installed = NeovimColourschemes.discover()

    var body: some View {
        SettingRow(
            "Neovim colourscheme",
            help: "Found in your Neovim config and installed plugins. "
                + "Neovim needs a small hook to follow it; see the README."
        ) {
            Picker("Neovim colourscheme", selection: selection) {
                Text("Theme default (\(defaultName))").tag(String?.none)
                Divider()
                ForEach(options, id: \.self) { name in
                    Text(installed.contains(name) ? name : "\(name) (not found)")
                        .tag(String?.some(name))
                }
            }
            .labelsHidden()
            .frame(width: 200)
        }
    }

    /// Installed schemes, plus the saved one if it is not installed here.
    private var options: [String] {
        var names = installed
        if let chosen = draft?.apps.nvimColorscheme, !names.contains(chosen) {
            names.insert(chosen, at: 0)
        }
        return names
    }

    private var defaultName: String {
        var manifest = draft ?? Theme(name: "default")
        manifest.apps.nvimColorscheme = nil
        return ThemeOutputs(theme: manifest, ghostty: "").nvim
    }

    private var selection: Binding<String?> {
        Binding(
            get: { draft?.apps.nvimColorscheme },
            set: { value in
                guard var edited = draft else { return }
                edited.apps.nvimColorscheme = value
                draft = edited
                save(edited)
            })
    }
}
