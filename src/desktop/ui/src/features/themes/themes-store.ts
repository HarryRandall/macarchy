import { errorMessage } from "~/bridge/client";
import type { ThemeValues, ThemesState, ThemeColour } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

interface Snapshot {
  status: "loading" | "ready" | "failed";
  state: ThemesState | null;
  error: string | null;
  busy: boolean;
  applying: boolean;
}

/** Serial edits write individual fields, so delayed replies cannot overwrite newer input. */
export function createThemesStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot: Snapshot = {
    status: "loading",
    state: null,
    error: null,
    busy: false,
    applying: false,
  };
  let queue = Promise.resolve();
  let revision = 0;
  let waiting = 0;
  let readVersion = 0;
  let received: ThemesState | null = null;
  const pending = new Map<string, Partial<ThemeValues>>();
  const versions = new Map<string, number>();
  /** Colours being dragged: shown on the page, not yet saved. */
  const previews = new Map<string, Partial<ThemeValues>>();

  function set(patch: Partial<Snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  function receive(state: ThemesState) {
    received = state;
    set({
      status: "ready",
      state: {
        ...state,
        themes: state.themes.map((theme) => ({
          ...theme,
          values: {
            ...theme.values,
            ...pending.get(theme.summary.name),
            ...previews.get(theme.summary.name),
          },
        })),
      },
    });
  }

  function preview(theme: string, field: ThemeColour, value: string) {
    previews.set(theme, { ...previews.get(theme), [field]: value });
    if (received) receive(received);
  }

  /** Saves a colour once it settles, skipping a value that is already saved or queued. */
  async function commit(theme: string, field: ThemeColour, value: string) {
    const patch = previews.get(theme);
    if (patch) delete patch[field];
    const saved = received?.themes.find((item) => item.summary.name === theme)?.values;
    const current = { ...saved, ...pending.get(theme) }[field];
    if (current === value) {
      if (received) receive(received);
      return;
    }
    await edit(theme, field, value);
  }

  async function load() {
    const started = revision;
    const reading = ++readVersion;
    const first = !snapshot.state;
    try {
      const state = await host.request("themes.getState");
      if (started === revision && reading === readVersion) {
        receive(state);
        if (first) set({ error: null });
      }
    } catch (error) {
      if (started !== revision || reading !== readVersion) return;
      set({ status: snapshot.state ? "ready" : "failed", error: errorMessage(error) });
    }
  }

  function run(operation: () => Promise<ThemesState | null>, applying = false) {
    revision += 1;
    waiting += 1;
    set({ busy: true });
    queue = queue.then(async () => {
      set({ applying });
      try {
        const state = await operation();
        set({ error: null });
        if (state) receive(state);
      } catch (error) {
        set({ error: errorMessage(error) });
      } finally {
        waiting -= 1;
        revision += 1;
        set({ busy: waiting > 0, applying: false });
      }
    });
    return queue;
  }

  function edit<K extends keyof ThemeValues>(theme: string, field: K, value: ThemeValues[K]) {
    const key = `${theme}:${field}`;
    const version = (versions.get(key) ?? 0) + 1;
    versions.set(key, version);
    pending.set(theme, { ...pending.get(theme), [field]: value });
    if (received) receive(received);
    return run(async () => {
      try {
        if (field === "dark")
          return await host.request("themes.setDark", { theme, dark: value as boolean });
        if (field === "nvimColorscheme")
          return await host.request("themes.setColourscheme", {
            theme,
            value: value as string | null,
          });
        return await host.request("themes.setColour", {
          theme,
          colour: field as ThemeColour,
          value: value as string,
        });
      } finally {
        if (versions.get(key) === version) {
          const patch = pending.get(theme);
          if (patch) delete patch[field];
        }
      }
    }).then(async () => {
      // Reconcile a failed field with disk, preserving any later queued input.
      if (waiting === 0) await load();
    });
  }

  host.subscribe("themes.changed", () => void load());
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    edit,
    preview,
    commit,
    apply: (theme: string) => run(() => host.request("themes.apply", { theme }), true),
    choose: (theme: string, path: string) =>
      run(() => host.request("themes.chooseWallpaper", { theme, path }), true),
    /** Rejects with the failure, so a confirmation can stay open and show it. */
    async reset(theme: string) {
      await run(() => host.request("themes.reset", { theme }));
      if (snapshot.error) throw new Error(snapshot.error);
    },
    importFolder: () => run(() => host.request("themes.importFolder")),
    exportFolder: (theme: string) => run(() => host.request("themes.exportFolder", { theme })),
    reveal: (theme: string) => run(() => host.request("themes.reveal", { theme })),
  };
}
export type ThemesStore = ReturnType<typeof createThemesStore>;
