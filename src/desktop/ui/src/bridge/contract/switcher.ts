/** The floating theme switcher part of the bridge contract; see `../protocol.ts`. */

export interface TerminalColours {
  background: string;
  foreground: string;
  red: string;
  green: string;
  blue: string;
  cyan: string;
}

export interface Background {
  /** Path inside the theme folder; what settings record. */
  path: string;
  /** "backgrounds/2-hand-of-adam.png" reads as "Hand Of Adam". */
  name: string;
  /** Image URL for a grid tile. */
  thumbnail: string;
}

export interface ThemeSummary {
  name: string;
  /** "city-783" reads as "City 783". */
  title: string;
  isDark: boolean;
  /** `#rrggbb`: the theme's ANSI blue, falling back to its border accent. */
  ring: string;
  colours: TerminalColours | null;
  /** The background in force for this theme, as a path inside its folder. */
  currentBackground: string | null;
  /** Image URL for the large preview, or null when the theme has no images. */
  preview: string | null;
  backgrounds: Background[];
}

export interface SwitcherState {
  /** Sorted by name; the interface applies its own preferred order. */
  themes: ThemeSummary[];
  /** The applied theme's name, if any. */
  current: string | null;
}

export interface SwitcherFailure {
  /** What failed, such as "Could not apply Lumon". */
  title: string;
  reason: string;
}

export interface SwitcherOpening extends SwitcherState {
  /** Set when the panel reopens because an action failed. */
  error: SwitcherFailure | null;
}

export interface SwitcherMethods {
  "switcher.getState": { params: Record<string, never>; result: SwitcherState };
  /** Reloads themes from disk. */
  "switcher.refresh": { params: Record<string, never>; result: SwitcherState };
  /**
   * Closes the panel, then applies, resolving once applied. New state arrives
   * as `themes.changed`. On failure it rejects and reopens the panel with the
   * reason in `switcher.willOpen`.
   */
  "switcher.applyTheme": { params: { theme: string }; result: null };
  /** Closes the panel, then sets the wallpaper, with failures as for applying. */
  "switcher.useBackground": { params: { theme: string; path: string }; result: null };
  "switcher.openSettings": { params: Record<string, never>; result: null };
  "switcher.close": { params: Record<string, never>; result: null };
}

export type SwitcherEvent =
  | { type: "themes.changed"; state: SwitcherState }
  /**
   * The panel is about to show. The page resets to this state and resolves
   * the returned promise once it has rendered, so the panel never shows a
   * stale or empty frame.
   */
  | { type: "switcher.willOpen"; state: SwitcherOpening }
  /** The panel is closing. The page resets and resolves after painting, as above. */
  | { type: "switcher.didClose" };
