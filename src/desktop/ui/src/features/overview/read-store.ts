import { errorMessage } from "~/bridge/client";
import { createListeners } from "~/lib/store";

/** Serialises slow read-only summaries and coalesces invalidations. */
export function createReadStore<T>(read: () => Promise<T>) {
  const listeners = createListeners();
  let snapshot: {
    status: "loading" | "ready" | "failed";
    state: T | null;
    error: string | null;
    refreshing: boolean;
  } = { status: "loading", state: null, error: null, refreshing: false };
  let active: Promise<void> | null = null;
  let pending = false;
  let loaded = false;

  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  async function run() {
    do {
      pending = false;
      set({ refreshing: true });
      try {
        const state = await read();
        set({ state, status: "ready", error: null });
      } catch (error) {
        set({ status: snapshot.state ? "ready" : "failed", error: errorMessage(error) });
      }
    } while (pending);
    set({ refreshing: false });
  }

  function load(): Promise<void> {
    loaded = true;
    if (active) {
      pending = true;
      return active;
    }
    active = run().finally(() => {
      active = null;
    });
    return active;
  }

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    invalidate() {
      if (loaded) void load();
    },
    async action(perform: () => Promise<unknown>) {
      try {
        await perform();
        return true;
      } catch (error) {
        set({ error: errorMessage(error) });
        return false;
      }
    },
  };
}
