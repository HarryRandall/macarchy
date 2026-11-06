import { errorMessage } from "~/bridge/client";
import type { LogEntry, ServiceId, ShellState } from "~/bridge/protocol";
import { createReadStore } from "~/features/overview/read-store";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

export type Service = ShellState["serviceList"][number];

/** The service list and the activity log, which Home reads beside its summary. */
export function createActivityStores(host: PageHost) {
  const shell = createReadStore(() => host.request("shell.getState"));
  const log = createReadStore<LogEntry[]>(() =>
    host.request("shell.getLog").then((result) => result.entries),
  );
  host.subscribe("shell.changed", () => shell.invalidate());
  host.subscribe("shell.logChanged", () => log.invalidate());
  return { shell, log };
}

/** Starts and stops services, tracking each request until the service list catches up. */
export function createServiceSwitches(host: PageHost, refresh: () => Promise<void>) {
  const listeners = createListeners();
  let snapshot: { pending: Partial<Record<ServiceId, boolean>>; error: string | null } = {
    pending: {},
    error: null,
  };

  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    async setRunning(service: Service, running: boolean) {
      if (snapshot.pending[service.id] !== undefined) return;
      set({ pending: { ...snapshot.pending, [service.id]: running }, error: null });
      try {
        const daemon = service.id;
        await (running
          ? host.request("advanced.restartService", { daemon })
          : host.request("advanced.stopService", { daemon }));
        await refresh();
      } catch (error) {
        set({
          error: `Could not ${running ? "start" : "stop"} ${service.name}. ${errorMessage(error)}`,
        });
      } finally {
        const pending = { ...snapshot.pending };
        delete pending[service.id];
        set({ pending });
      }
    },
    dismiss() {
      set({ error: null });
    },
  };
}

export type ActivityStores = ReturnType<typeof createActivityStores>;
export type ServiceSwitches = ReturnType<typeof createServiceSwitches>;
