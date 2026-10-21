import { errorMessage } from "~/bridge/client";
import type { AdvancedState, GeneratedFileId, ServiceId, SetupReport } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

export function createAdvancedStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot = {
    status: "loading" as "loading" | "ready" | "failed",
    state: null as AdvancedState | null,
    error: null as string | null,
    busy: false,
    refreshing: false,
    outcomes: {} as Partial<Record<GeneratedFileId, string>>,
    report: null as SetupReport | null,
  };
  let version = 0;
  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  async function load() {
    const reading = ++version;
    set({ refreshing: true });
    try {
      const state = await host.request("advanced.getState");
      if (reading === version) set({ state, status: "ready", error: null });
    } catch (error) {
      if (reading === version)
        set({ status: snapshot.state ? "ready" : "failed", error: errorMessage(error) });
    } finally {
      if (reading === version) set({ refreshing: false });
    }
  }
  async function perform(action: () => Promise<unknown>) {
    if (snapshot.busy) return;
    ++version;
    set({ busy: true, error: null });
    try {
      await action();
      await load();
    } catch (error) {
      await load();
      set({ error: errorMessage(error) });
      throw error;
    } finally {
      set({ busy: false });
    }
  }
  // Reads never replace a pending operation's progress or its local result.
  host.subscribe("advanced.changed", (event) => {
    if (!snapshot.busy) {
      ++version;
      set({ state: event.state, status: "ready", refreshing: false });
    }
  });
  host.subscribe("advanced.invalidated", () => {
    if (!snapshot.busy) void load();
  });
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    restart: (daemon: ServiceId) =>
      perform(() => host.request("advanced.restartService", { daemon })),
    stop: (daemon: ServiceId) => perform(() => host.request("advanced.stopService", { daemon })),
    rebuild: (file: GeneratedFileId) =>
      perform(async () => {
        const result = await host.request("advanced.rebuild", { file });
        set({ outcomes: { ...snapshot.outcomes, [file]: result.outcome } });
      }),
    restoreSnapshot: (id: string) =>
      perform(() => host.request("advanced.restoreSnapshot", { id })),
    repair: () => perform(() => host.request("advanced.repairAddition")),
    restoreOriginals: () =>
      perform(async () => {
        set({ report: await host.request("advanced.restoreOriginals") });
      }),
  };
}
export type AdvancedStore = ReturnType<typeof createAdvancedStore>;
