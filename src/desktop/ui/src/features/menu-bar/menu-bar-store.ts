import { errorMessage } from "~/bridge/client";
import type {
  MenuBarItemEdit,
  MenuBarSettings,
  MenuBarState,
  ThemesState,
} from "~/bridge/protocol";
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
  /** Null until read, and when reading failed. */
  state: MenuBarState | null;
  /** Why the last read or apply failed. */
  error: string | null;
  applying: boolean;
}

export interface MenuBarStoreDeps {
  getThemes(): Promise<ThemesState>;
  getState(): Promise<MenuBarState>;
  apply(items: MenuBarItemEdit[], bar: MenuBarSettings): Promise<MenuBarState>;
  reveal(widget: string | null): Promise<null>;
  openFile(widget: string, file: string): Promise<null>;
  duplicate(widget: string): Promise<{ state: MenuBarState; widget: string }>;
  subscribe(type: "themes.changed" | "menuBar.changed", handler: () => void): () => void;
}

/**
 * The bar as SketchyBar and the saved configuration have it, and the applied
 * theme to paint its preview in. The page keeps its own draft; this only
 * holds what is on the bar. A failed theme read still leaves the page usable
 * in the default colours.
 */
export function createMenuBarStore(deps: MenuBarStoreDeps) {
  const listeners = createListeners();
  let snapshot: MenuBarSnapshot = {
    status: "loading",
    look: null,
    state: null,
    error: null,
    applying: false,
  };
  let reads = 0;

  function set(patch: Partial<MenuBarSnapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  async function readLook(): Promise<BarLook | null> {
    try {
      return barLook(await deps.getThemes());
    } catch {
      return snapshot.look;
    }
  }

  async function load() {
    const read = ++reads;
    const [look, bar] = await Promise.all([
      readLook(),
      deps.getState().then(
        (state) => ({ state, error: null }),
        (error: unknown) => ({ state: null, error: errorMessage(error) }),
      ),
    ]);
    if (read !== reads) return;
    set({
      status: bar.state ? "ready" : "failed",
      look,
      state: bar.state ?? snapshot.state,
      error: bar.error,
    });
  }

  /** Resolves true once the bar matches; on failure the error says why. */
  async function apply(items: MenuBarItemEdit[], bar: MenuBarSettings): Promise<boolean> {
    if (snapshot.applying) return false;
    reads++;
    set({ applying: true, error: null });
    try {
      const state = await deps.apply(items, bar);
      set({ applying: false, state, status: "ready" });
      return true;
    } catch (error) {
      set({ applying: false, error: errorMessage(error) });
      return false;
    }
  }

  /** Runs a request about a widget's files; a failure shows as the page's error. */
  async function files(run: () => Promise<unknown>): Promise<void> {
    try {
      await run();
    } catch (error) {
      set({ error: errorMessage(error) });
    }
  }

  /** Copies a widget into the person's own; resolves the copy's id, or null on failure. */
  async function duplicate(widget: string): Promise<string | null> {
    try {
      const result = await deps.duplicate(widget);
      set({ state: result.state, error: null });
      return result.widget;
    } catch (error) {
      set({ error: errorMessage(error) });
      return null;
    }
  }

  deps.subscribe("themes.changed", () => {
    if (snapshot.status === "loading") return;
    void readLook().then((look) => set({ look }));
  });

  deps.subscribe("menuBar.changed", () => {
    if (snapshot.status === "ready" && !snapshot.applying) void load();
  });

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    apply,
    duplicate,
    reveal: (widget: string | null) => files(() => deps.reveal(widget)),
    openFile: (widget: string, file: string) => files(() => deps.openFile(widget, file)),
    dismissError: () => set({ error: null }),
  };
}

export type MenuBarStore = ReturnType<typeof createMenuBarStore>;
