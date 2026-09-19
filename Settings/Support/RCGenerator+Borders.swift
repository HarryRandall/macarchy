import Foundation
import Desktop

extension RCGenerator {

    // The body is a single shell document. Breaking it up to satisfy the length
    // rule would scatter one file's contents across several string fragments.
    // swiftlint:disable:next function_body_length
    func generateBordersRC() {
        let file = Self.bordersrc
        let kept = file.preservedRegions()
        let extra =
            kept["extra"].map {
                "\n\(GeneratedFile.beginKeep) extra\n\($0)\n\(GeneratedFile.endKeep)\n"
            } ?? """

                \(GeneratedFile.beginKeep) extra
                \(GeneratedFile.endKeep)

                """

        let content =
            Self.header + """
                set -euo pipefail

                BORDERS_BIN="/opt/homebrew/opt/borders/bin/borders"
                # Local renderer keeps square borders rectangular on translucent windows.
                if [ -x "$HOME/.local/bin/macarchy-borders" ]; then
                  BORDERS_BIN="$HOME/.local/bin/macarchy-borders"
                fi

                THEMES_DIR="$HOME/.config/macarchy-settings/themes"
                CURRENT_THEME="$(cat "$THEMES_DIR/.current" 2>/dev/null || true)"
                if [ -n "$CURRENT_THEME" ] && [ -f "$THEMES_DIR/$CURRENT_THEME/theme.env" ]; then
                  # shellcheck source=/dev/null
                  source "$THEMES_DIR/$CURRENT_THEME/theme.env"
                fi

                SETTINGS_ENV="$HOME/.config/macarchy-settings/settings.env"
                if [ -f "$SETTINGS_ENV" ]; then
                  # shellcheck source=/dev/null
                  source "$SETTINGS_ENV"
                fi

                # Theme owns colour; settings owns geometry. Defaults only apply if neither set it.
                BORDER_STYLE="${BORDER_STYLE:-square}"
                BORDER_ACTIVE="${BORDER_ACTIVE:-0xff45e8ff}"
                BORDER_INACTIVE="${BORDER_INACTIVE:-0x00000000}"
                BORDER_WIDTH="${BORDER_WIDTH:-6.0}"
                BORDERS_VISIBLE="${BORDERS_VISIBLE:-true}"
                BORDERS_BLACKLIST="${BORDERS_BLACKLIST:-}"

                case ",$BORDERS_BLACKLIST," in
                  *",iPhone Mirroring,"*) ;;
                  ",,") BORDERS_BLACKLIST="iPhone Mirroring" ;;
                  *) BORDERS_BLACKLIST="$BORDERS_BLACKLIST,iPhone Mirroring" ;;
                esac

                if [ "$BORDERS_VISIBLE" != "true" ]; then
                  BORDER_ACTIVE="0x00000000"
                  BORDER_INACTIVE="0x00000000"
                  BORDER_WIDTH="0.0"
                  BORDER_ANIMATION_COLORS=""
                fi

                if [ -n "${BORDER_ANIMATION_COLORS:-}" ]; then
                  read -r -a BORDER_COLORS <<< "$BORDER_ANIMATION_COLORS"
                  FIRST="${BORDER_COLORS[0]}"
                  SECOND="${BORDER_COLORS[3]:-${BORDER_COLORS[1]:-$FIRST}}"
                  if [ "${BORDER_ANIMATION_EFFECT:-glow}" = "glow" ]; then
                    ACTIVE_ARG="active_color=glow($FIRST)"
                  else
                    ACTIVE_ARG="active_color=gradient(top_left=$FIRST,bottom_right=$SECOND)"
                  fi
                else
                  ACTIVE_ARG="active_color=$BORDER_ACTIVE"
                fi
                \(extra)
                exec "$BORDERS_BIN" \\
                  style="$BORDER_STYLE" \\
                  width="$BORDER_WIDTH" \\
                  hidpi=on \\
                  background_color=0x00000000 \\
                  "$ACTIVE_ARG" \\
                  inactive_color="$BORDER_INACTIVE" \\
                  blacklist="$BORDERS_BLACKLIST"

                """

        record("bordersrc", file.write(content, reason: "borders settings changed"))
    }
}
