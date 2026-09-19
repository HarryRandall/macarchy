import Foundation

extension ThemeOutputs {
    public var btop: String {
        let bg = colour("background", fallback: "#000000")
        let fg = colour("foreground", fallback: "#ffffff")
        let selection = colour("selection-background", fallback: bg)
        let accent = palette(4, fallback: fg)
        let muted = palette(8, fallback: fg)
        let green = palette(2, fallback: accent)
        let yellow = palette(3, fallback: accent)
        let red = palette(1, fallback: accent)
        let cyan = palette(6, fallback: accent)
        let purple = palette(5, fallback: accent)
        let orange = palette(11, fallback: yellow)
        return """
            # Auto-generated from theme-switch for \(theme.name)
            theme[main_bg]=""
            theme[main_fg]="\(fg)"
            theme[title]="\(fg)"
            theme[hi_fg]="\(accent)"
            theme[selected_bg]="\(selection)"
            theme[selected_fg]="\(fg)"
            theme[inactive_fg]="\(muted)"
            theme[proc_misc]="\(cyan)"
            theme[cpu_box]="\(muted)"
            theme[mem_box]="\(muted)"
            theme[net_box]="\(muted)"
            theme[proc_box]="\(muted)"
            theme[div_line]="\(muted)"
            theme[temp_start]="\(green)"
            theme[temp_mid]="\(yellow)"
            theme[temp_end]="\(red)"
            theme[cpu_start]="\(green)"
            theme[cpu_mid]="\(yellow)"
            theme[cpu_end]="\(red)"
            theme[free_start]="\(green)"
            theme[free_mid]="\(cyan)"
            theme[free_end]="\(accent)"
            theme[cached_start]="\(cyan)"
            theme[cached_mid]="\(accent)"
            theme[cached_end]="\(purple)"
            theme[available_start]="\(green)"
            theme[available_mid]="\(yellow)"
            theme[available_end]="\(orange)"
            theme[used_start]="\(yellow)"
            theme[used_mid]="\(orange)"
            theme[used_end]="\(red)"
            theme[download_start]="\(accent)"
            theme[download_mid]="\(cyan)"
            theme[download_end]="\(green)"
            theme[upload_start]="\(yellow)"
            theme[upload_mid]="\(orange)"
            theme[upload_end]="\(red)"
            theme[process_start]="\(green)"
            theme[process_mid]="\(yellow)"
            theme[process_end]="\(red)"

            """
    }
}
