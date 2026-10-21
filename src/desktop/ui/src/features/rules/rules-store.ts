import type { CustomWindowRule, RulesState } from "~/bridge/protocol";
import type { Bridge } from "~/bridge/client";
import { createListeners } from "~/lib/store";

interface RulesHost {
  getState(): Promise<RulesState>;
  addApplication(): Promise<unknown>;
  removeFloating(app: string): Promise<unknown>;
  saveCustom(rule: CustomWindowRule): Promise<unknown>;
  removeCustom(id: string): Promise<unknown>;
  subscribe: Bridge["subscribe"];
}

interface Snapshot {
  status: "loading" | "ready" | "failed";
  state: RulesState | null;
  busy: boolean;
  refreshing: boolean;
  error: string | null;
}

const message = (error: unknown) => (error instanceof Error ? error.message : String(error));

export function createRulesStore(host: RulesHost) {
  const listeners = createListeners();
  let snapshot: Snapshot = {
    status: "loading",
    state: null,
    busy: false,
    refreshing: false,
    error: null,
  };
  let version = 0;
  let loaded = false;
  let mutationError = false;
  const update = (patch: Partial<Snapshot>) => {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  };

  async function refresh() {
    const started = ++version;
    update({ refreshing: true });
    try {
      const state = await host.getState();
      if (started === version) {
        mutationError = false;
        update({ state, status: "ready", error: null });
      }
    } catch (error) {
      if (started === version) {
        mutationError = false;
        update({ status: snapshot.state ? "ready" : "failed", error: message(error) });
      }
    } finally {
      if (started === version) update({ refreshing: false });
    }
  }

  async function mutate(operation: () => Promise<unknown>) {
    if (snapshot.busy) return false;
    ++version;
    mutationError = false;
    update({ busy: true, error: null, refreshing: false });
    try {
      await operation();
    } catch (error) {
      mutationError = true;
      update({ busy: false, error: message(error) });
      return false;
    }
    // A saved edit stays successful even if the subsequent read fails.
    await refresh();
    update({ busy: false });
    return true;
  }

  host.subscribe("rules.unavailable", (event) => {
    ++version;
    update({
      error: mutationError ? snapshot.error : event.state.message,
      status: snapshot.state ? "ready" : "failed",
      refreshing: false,
    });
  });

  host.subscribe("rules.changed", (event) => {
    ++version;
    update({
      state: event.state,
      status: "ready",
      refreshing: false,
      error: mutationError ? snapshot.error : null,
    });
  });

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    async load() {
      if (loaded) return;
      loaded = true;
      await refresh();
    },
    refresh,
    addApplication: () => mutate(() => host.addApplication()),
    removeFloating: (app: string) => mutate(() => host.removeFloating(app)),
    saveCustom: (rule: CustomWindowRule) => mutate(() => host.saveCustom(rule)),
    removeCustom: (id: string) => mutate(() => host.removeCustom(id)),
  };
}

export type RulesStore = ReturnType<typeof createRulesStore>;
