import { errorMessage } from "~/bridge/client";
import type { BridgeEvent, LayoutApplyParams, LayoutState, LayoutValues } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

import { createEditQueue, type LayoutField, mergeLayoutValues, type Timers } from "./layout-sync";

export interface LayoutSnapshot {
  status: "loading" | "ready" | "failed";
  /** What the host last reported, with in-progress edits laid over its values. */
  state: LayoutState | null;
  /** Why the first read failed; the page shows this instead of any values. */
  loadError: string | null;
  /**
   * The last apply or refresh failure, until dismissed, replaced by a newer
   * failure, or cleared by an apply sent after it that succeeds.
   */
  error: string | null;
  refreshing: boolean;
  /** "Match all screen edges". Local and unsaved, as in the SwiftUI page. */
  linkPadding: boolean;
}

export interface LayoutStoreDeps {
  getState(): Promise<LayoutState>;
  apply(params: LayoutApplyParams): Promise<unknown>;
  subscribe(
    type: "layout.changed",
    handler: (event: Extract<BridgeEvent, { type: "layout.changed" }>) => void,
  ): () => void;
  timers?: Timers;
  /** Long enough to swallow a slider drag, short enough to feel immediate. */
  debounce?: number;
}

/**
 * The Layout page's state. Reading never applies: only `edit`, called from a
 * person's input, sends anything to the desktop.
 */
export function createLayoutStore(deps: LayoutStoreDeps) {
  const listeners = createListeners();
  let snapshot: LayoutSnapshot = {
    status: "loading",
    state: null,
    loadError: null,
    error: null,
    refreshing: false,
    linkPadding: true,
  };

  function set(patch: Partial<LayoutSnapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  /** Clock reading when the shown error was raised. */
  let errorAt = 0;

  function fail(error: unknown) {
    errorAt = queue.now();
    set({ error: errorMessage(error) });
  }

  const queue = createEditQueue({
    delay: deps.debounce ?? 80,
    timers: deps.timers ?? {
      setTimeout: (run, ms) => globalThis.setTimeout(run, ms),
      clearTimeout: (handle) => globalThis.clearTimeout(handle as ReturnType<typeof setTimeout>),
    },
    send: deps.apply,
    onSettled(_field, error, sentAt) {
      if (!error) {
        // An apply that left before the failure says nothing about it, so
        // only a later one clears the notice.
        if (snapshot.error !== null && sentAt > errorAt) set({ error: null });
        return;
      }
      // As LayoutModel does: a failed apply re-reads the daemon, which puts
      // the failed field back to what is really in effect.
      fail(error);
      void refresh();
    },
  });

  function receive(remote: LayoutState, since: number) {
    const local = snapshot.state?.values ?? remote.values;
    const values = mergeLayoutValues(local, remote.values, queue.protectedFields(since));
    set({ status: "ready", state: { ...remote, values }, loadError: null });
  }

  async function refresh() {
    const since = queue.now();
    set({ refreshing: true });
    try {
      receive(await deps.getState(), since);
      set({ refreshing: false });
    } catch (error) {
      if (snapshot.state) {
        set({ refreshing: false });
        fail(error);
      } else set({ refreshing: false, status: "failed", loadError: errorMessage(error) });
    }
  }

  deps.subscribe("layout.changed", (event) => receive(event.state, queue.now()));

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load: refresh,
    refresh,

    edit<F extends LayoutField>(field: F, value: LayoutValues[F]) {
      const state = snapshot.state;
      if (!state || state.source !== "daemon") return;
      if (state.values[field] === value) return;
      set({ state: { ...state, values: { ...state.values, [field]: value } } });
      queue.edit(field, value, snapshot.linkPadding);
    },

    setLinkPadding(linkPadding: boolean) {
      set({ linkPadding });
    },

    dismissError() {
      set({ error: null });
    },
  };
}

export type LayoutStore = ReturnType<typeof createLayoutStore>;
