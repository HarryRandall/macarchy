import { createListeners } from "~/lib/store";

/** Where a page keeps a small value between launches. */
export interface PluginsStorage {
  read(): string | null;
  write(value: string): void;
}

const notifyKey = "macarchy.pluginNotify";

/** localStorage, which private browsing or a full store can refuse. */
const localStore: PluginsStorage = {
  read() {
    try {
      return localStorage.getItem(notifyKey);
    } catch {
      return null;
    }
  },
  write(value) {
    try {
      localStorage.setItem(notifyKey, value);
    } catch {
      // The choice still holds for this session.
    }
  },
};

/** The saved plugin ids, ignoring anything that is not a list of strings. */
export function parseNotify(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const value: unknown = JSON.parse(raw);
    return Array.isArray(value)
      ? value.filter((item): item is string => typeof item === "string")
      : [];
  } catch {
    return [];
  }
}

/**
 * The Plugins page's state. There is no catalogue to read, so loading only
 * recalls which plugins the person asked to hear about.
 */
export function createPluginsStore(storage: PluginsStorage = localStore) {
  const listeners = createListeners();
  let snapshot: { status: "loading" | "ready"; notify: ReadonlySet<string> } = {
    status: "loading",
    notify: new Set(),
  };
  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load() {
      set({ status: "ready", notify: new Set(parseNotify(storage.read())) });
      return Promise.resolve();
    },
    // Mock: nothing sends a notification yet; the choice is only remembered here.
    toggleNotify(id: string) {
      const notify = new Set(snapshot.notify);
      if (notify.has(id)) notify.delete(id);
      else notify.add(id);
      set({ notify });
      storage.write(JSON.stringify([...notify]));
    },
  };
}
export type PluginsStore = ReturnType<typeof createPluginsStore>;
