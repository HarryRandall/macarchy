import type { BridgeEvent, ThemesState } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

/** The colours and wallpaper the bar preview is painted in. */
export interface BarLook {
  background: string;
  foreground: string;
  accent: string;
  wallpaper: string | null;
  themeTitle: string;
}

/** Matte Black, Macarchy's default theme, for when the themes cannot be read. */
export const fallbackLook: BarLook = {
  background: "#121212",
  foreground: "#bebebe",
  accent: "#e68e0d",
  wallpaper: null,
  themeTitle: "Matte Black",
};

/** The applied theme's bar colours, as SketchyBar takes them from the theme. */
export function barLook(state: ThemesState): BarLook | null {
  const theme = state.themes.find((entry) => entry.summary.name === state.current);
  if (!theme) return null;
  const { summary, values } = theme;
  return {
    background: summary.colours?.background ?? fallbackLook.background,
    foreground: summary.colours?.foreground ?? fallbackLook.foreground,
    accent: values.borderActive ?? summary.ring,
    wallpaper: summary.preview,
    themeTitle: summary.title,
  };
}

export interface MenuBarSnapshot {
  status: "loading" | "ready" | "failed";
  /** Null until read, and when the themes could not be read. */
  look: BarLook | null;
}

export interface MenuBarStoreDeps {
  getThemes(): Promise<ThemesState>;
  subscribe(
    type: "themes.changed",
    handler: (event: Extract<BridgeEvent, { type: "themes.changed" }>) => void,
  ): () => void;
}

/**
 * The Menu Bar page reads only the applied theme, to paint its preview. The
 * bar's items and settings are placeholders until the bar has a bridge, so a
 * failed read still leaves the page usable in the default colours.
 */
export function createMenuBarStore(deps: MenuBarStoreDeps) {
  const listeners = createListeners();
  let snapshot: MenuBarSnapshot = { status: "loading", look: null };
  let reads = 0;

  async function load() {
    const read = ++reads;
    let look: BarLook | null = null;
    try {
      look = barLook(await deps.getThemes());
    } catch {
      look = snapshot.look;
    }
    if (read !== reads) return;
    snapshot = { status: "ready", look };
    listeners.notify();
  }

  deps.subscribe("themes.changed", () => {
    if (snapshot.status !== "loading") void load();
  });

  return { subscribe: listeners.subscribe, getSnapshot: () => snapshot, load };
}

export type MenuBarStore = ReturnType<typeof createMenuBarStore>;
