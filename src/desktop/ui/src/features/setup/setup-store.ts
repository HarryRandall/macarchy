import { errorMessage } from "~/bridge/client";
import type { ExistingSetup, SetupReport, SetupState } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

export function createSetupStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot = {
    status: "loading" as "loading" | "ready" | "failed",
    state: null as SetupState | null,
    existing: "keep" as ExistingSetup,
    busy: false,
    planning: false,
    error: null as string | null,
    report: null as SetupReport | null,
  };
  let generation = 0;
  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  async function load() {
    const reading = ++generation;
    set({ planning: true, error: null });
    try {
      const state = await host.request("setup.getPlan", { existing: snapshot.existing });
      if (reading === generation) set({ state, status: "ready" });
    } catch (error) {
      if (reading === generation)
        set({ state: null, status: "failed", error: errorMessage(error) });
    } finally {
      if (reading === generation) set({ planning: false });
    }
  }
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    choose(existing: ExistingSetup) {
      if (snapshot.busy) return;
      set({ existing });
      void load();
    },
    async run() {
      if (snapshot.busy || snapshot.planning || !snapshot.state) return;
      set({ busy: true, error: null });
      try {
        const report = await host.request("setup.run", { existing: snapshot.existing });
        set({ report, error: report.failure });
      } catch (error) {
        set({ error: errorMessage(error) });
      } finally {
        set({ busy: false });
      }
    },
    async openAccessibility() {
      try {
        await host.request("setup.openAccessibility");
      } catch (error) {
        set({ error: errorMessage(error) });
      }
    },
    reset() {
      set({ report: null, error: null });
      void load();
    },
  };
}
export type SetupStore = ReturnType<typeof createSetupStore>;
