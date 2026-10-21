import { errorMessage } from "~/bridge/client";
import type { BridgeEvent, BridgeMethods, PaneId, ShellState } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

import { reactPanes } from "./panes";

export interface ShellSnapshot {
  status: "loading" | "ready" | "failed";
  state: ShellState | null;
  error: string | null;
}

type Request = <M extends "shell.getState" | "shell.setPreferences" | "shell.openClassic">(
  method: M,
  params: BridgeMethods[M]["params"],
) => Promise<BridgeMethods[M]["result"]>;

export function createShellStore(deps: {
  request: Request;
  subscribe(
    type: "shell.changed",
    handler: (event: Extract<BridgeEvent, { type: "shell.changed" }>) => void,
  ): () => void;
}) {
  const listeners = createListeners();
  let snapshot: ShellSnapshot = { status: "loading", state: null, error: null };

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

  // A selection is saved by a request; an event the host sent before that
  // request arrived still carries the old pane and must not undo the click.
  let pendingPane: PaneId | null = null;

  deps.subscribe("shell.changed", (event) => {
    const state = pendingPane ? { ...event.state, selectedPane: pendingPane } : event.state;
    set({ status: "ready", state, error: null });
  });

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,

    async load() {
      try {
        set({
          status: "ready",
          state: await deps.request("shell.getState", {}),
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

    dismissError() {
      set({ error: null });
    },

    openClassic(params: BridgeMethods["shell.openClassic"]["params"]) {
      deps.request("shell.openClassic", params).catch(report);
    },
  };
}

export type ShellStore = ReturnType<typeof createShellStore>;
