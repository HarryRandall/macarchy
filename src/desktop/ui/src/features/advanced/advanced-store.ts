import { errorMessage } from "~/bridge/client";
import type {
  AdvancedState,
  CleanupPlan,
  CleanupReport,
  GeneratedFileId,
  ServiceId,
  SetupReport,
} from "~/bridge/protocol";
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
    /** The cleanup plan being reviewed, until it is carried out or closed. */
    cleanupPlan: null as CleanupPlan | null,
    reviewingCleanup: false,
    cleanupReport: null as CleanupReport | null,
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
    /** Rebuilds each file in turn; one failing does not stop the rest, and all failures are reported. */
    rebuildAll: (files: readonly GeneratedFileId[]) =>
      perform(async () => {
        const failed: string[] = [];
        for (const file of files) {
          try {
            const result = await host.request("advanced.rebuild", { file });
            set({ outcomes: { ...snapshot.outcomes, [file]: result.outcome } });
          } catch (error) {
            failed.push(`${file}: ${errorMessage(error)}`);
          }
        }
        if (failed.length) {
          const rebuilt = files.length - failed.length;
          throw new Error(`Rebuilt ${rebuilt} of ${files.length} files. ${failed.join(". ")}`);
        }
      }),
    restoreSnapshot: (id: string) =>
      perform(() => host.request("advanced.restoreSnapshot", { id })),
    repair: () => perform(() => host.request("advanced.repairAddition")),
    setLoginItem: (enabled: boolean) =>
      perform(() => host.request("advanced.setLoginItem", { enabled })),
    setTrackpadSwipes: (enabled: boolean) =>
      perform(() => host.request("advanced.setTrackpadSwipes", { enabled })),
    /** Opens Login Items in System Settings. Changes nothing, so the state is not read again. */
    async openLoginItems() {
      set({ error: null });
      try {
        await host.request("advanced.openLoginItems");
      } catch (error) {
        set({ error: errorMessage(error) });
      }
    },
    /** Puts the original files back, also removing `removeTools`, which Macarchy installed. */
    restoreOriginals: (removeTools: string[] = []) =>
      perform(async () => {
        set({ report: await host.request("advanced.restoreOriginals", { removeTools }) });
      }),
    dismissReport() {
      set({ report: null });
    },
    /** Reads what cleaning up would do. Changes nothing. */
    async reviewCleanup() {
      if (snapshot.busy || snapshot.reviewingCleanup) return;
      set({ reviewingCleanup: true, error: null, cleanupReport: null });
      try {
        set({ cleanupPlan: await host.request("advanced.getCleanupPlan") });
      } catch (error) {
        set({ error: errorMessage(error) });
      } finally {
        set({ reviewingCleanup: false });
      }
    },
    closeCleanup() {
      set({ cleanupPlan: null });
    },
    cleanUp: () =>
      perform(async () => {
        set({ cleanupReport: await host.request("advanced.cleanUp"), cleanupPlan: null });
      }),
    dismissCleanupReport() {
      set({ cleanupReport: null });
    },
    /** Shows the settings folder in Finder. Changes nothing, so the state is not read again. */
    async reveal() {
      set({ error: null });
      try {
        await host.request("shell.revealSettings");
      } catch (error) {
        set({ error: errorMessage(error) });
      }
    },
  };
}
export type AdvancedStore = ReturnType<typeof createAdvancedStore>;
