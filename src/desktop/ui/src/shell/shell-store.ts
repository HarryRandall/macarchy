import { errorMessage } from "~/bridge/client";
import type {
  AppearanceMode,
  BridgeEvent,
  BridgeMethods,
  PaneId,
  ServiceId,
  ShellShortcut,
  ShellState,
} from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

import { reactPanes } from "./panes";

export type ServiceAction = "restart" | "start" | "stop";

export interface ShellSnapshot {
  status: "loading" | "ready" | "failed";
  state: ShellState | null;
  error: string | null;
  /** Services with a request in flight, shown as busy until it settles. */
  pending: Partial<Record<ServiceId, ServiceAction>>;
  restartingAll: boolean;
}

type ShellMethod =
  | "shell.getState"
  | "shell.setPreferences"
  | "shell.openClassic"
  | "shell.restartAll"
  | "shell.revealSettings"
  | "shell.quit"
  | "advanced.restartService"
  | "advanced.stopService";

type Request = <M extends ShellMethod>(
  method: M,
  params: BridgeMethods[M]["params"],
) => Promise<BridgeMethods[M]["result"]>;

type ShellEventType = "shell.changed" | "shell.shortcut";

export function createShellStore(deps: {
  request: Request;
  subscribe<T extends ShellEventType>(
    type: T,
    handler: (event: Extract<BridgeEvent, { type: T }>) => void,
  ): () => void;
}) {
  const listeners = createListeners();
  const shortcutListeners = new Set<(shortcut: ShellShortcut) => void>();
  let snapshot: ShellSnapshot = {
    status: "loading",
    state: null,
    error: null,
    pending: {},
    restartingAll: false,
  };

  function set(patch: Partial<ShellSnapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  function patchState(patch: Partial<ShellState>) {
    if (snapshot.state) set({ state: { ...snapshot.state, ...patch } });
  }

  function report(error: unknown) {
    console.error(error);
    set({ error: errorMessage(error) });
  }

  // A preference is saved by a request; an event the host sent before that
  // request arrived still carries the old value and must not undo the click.
  let pendingPane: PaneId | null = null;
  let pendingMode: AppearanceMode | null = null;

  function withPending(state: ShellState): ShellState {
    let next = state;
    if (pendingPane) next = { ...next, selectedPane: pendingPane };
    if (pendingMode) next = { ...next, appearance: { ...next.appearance, mode: pendingMode } };
    return next;
  }

  deps.subscribe("shell.changed", (event) => {
    set({ status: "ready", state: withPending(event.state), error: null });
  });

  deps.subscribe("shell.shortcut", (event) => {
    for (const listener of shortcutListeners) listener(event.state.shortcut);
  });

  /** Marks a service busy for the length of a request; failures reach the caller. */
  async function serviceRequest(id: ServiceId, action: ServiceAction, run: () => Promise<null>) {
    set({ pending: { ...snapshot.pending, [id]: action } });
    try {
      await run();
    } finally {
      const pending = { ...snapshot.pending };
      delete pending[id];
      set({ pending });
    }
  }

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,

    async load() {
      try {
        set({
          status: "ready",
          state: withPending(await deps.request("shell.getState", {})),
          error: null,
        });
      } catch (error) {
        set({ status: snapshot.state ? "ready" : "failed", error: errorMessage(error) });
      }
    },

    setSidebarVisible(sidebarVisible: boolean) {
      patchState({ sidebarVisible });
      deps.request("shell.setPreferences", { sidebarVisible }).catch(report);
    },

    /** React panes are selected here; the rest open the classic window. */
    selectPane(pane: PaneId) {
      if (reactPanes.has(pane)) {
        patchState({ selectedPane: pane });
        pendingPane = pane;
        deps
          .request("shell.setPreferences", { selectedPane: pane })
          .catch(report)
          .finally(() => {
            if (pendingPane === pane) pendingPane = null;
          });
      } else {
        deps.request("shell.openClassic", { pane }).catch(report);
      }
    },

    setAppearance(mode: AppearanceMode) {
      if (snapshot.state) patchState({ appearance: { ...snapshot.state.appearance, mode } });
      pendingMode = mode;
      deps
        .request("shell.setPreferences", { appearance: mode })
        .catch(report)
        .finally(() => {
          if (pendingMode === mode) pendingMode = null;
        });
    },

    dismissError() {
      set({ error: null });
    },

    /** Hears the shortcuts the app menu passes on. */
    onShortcut(listener: (shortcut: ShellShortcut) => void): () => void {
      shortcutListeners.add(listener);
      return () => shortcutListeners.delete(listener);
    },

    /** Restarts a running service, or starts a stopped one. Rejects with the host's reason. */
    restartService(id: ServiceId, action: "restart" | "start" = "restart") {
      return serviceRequest(id, action, () =>
        deps.request("advanced.restartService", { daemon: id }),
      );
    },

    stopService(id: ServiceId) {
      return serviceRequest(id, "stop", () => deps.request("advanced.stopService", { daemon: id }));
    },

    /** Resolves with the host's summary, such as which services came back. */
    async restartAll(): Promise<string> {
      set({ restartingAll: true });
      try {
        return (await deps.request("shell.restartAll", {})).outcome;
      } finally {
        set({ restartingAll: false });
      }
    },

    revealSettings(): Promise<null> {
      return deps.request("shell.revealSettings", {});
    },

    quit(): Promise<null> {
      return deps.request("shell.quit", {});
    },
  };
}

export type ShellStore = ReturnType<typeof createShellStore>;
