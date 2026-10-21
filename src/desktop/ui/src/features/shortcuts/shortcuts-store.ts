import { errorMessage } from "~/bridge/client";
import type {
  ShortcutBinding,
  ShortcutChord,
  ShortcutValidation,
  ShortcutMutation,
  ShortcutsState,
} from "~/bridge/protocol";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

export interface ShortcutDraft {
  binding: ShortcutBinding;
  revision: string;
  chord: ShortcutChord;
  validation: ShortcutValidation | null;
  validating: boolean;
  validationError: string | null;
}
export interface ShortcutsSnapshot {
  status: "loading" | "ready" | "failed";
  state: ShortcutsState | null;
  error: string | null;
  warning: string | null;
  busy: boolean;
  refreshing: boolean;
  external: boolean;
  draft: ShortcutDraft | null;
}

export function createShortcutsStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot: ShortcutsSnapshot = {
    status: "loading",
    state: null,
    error: null,
    warning: null,
    busy: false,
    refreshing: false,
    external: false,
    draft: null,
  };
  let validationVersion = 0;
  let stateVersion = 0;
  const set = (patch: Partial<ShortcutsSnapshot>) => {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  };
  function receive(state: ShortcutsState) {
    stateVersion++;
    const external = !!snapshot.draft && snapshot.draft.revision !== state.revision;
    set({
      state,
      status: "ready",
      external,
      ...(snapshot.status === "failed" ? { error: null } : {}),
    });
  }
  host.subscribe("shortcuts.changed", (event) => receive(event.state));
  host.subscribe("shortcuts.unavailable", (event) =>
    set({ error: event.state, external: !!snapshot.draft }),
  );
  async function load() {
    if (snapshot.busy || snapshot.refreshing) return;
    const version = stateVersion;
    set({ refreshing: true });
    try {
      const state = await host.request("shortcuts.getState");
      if (version === stateVersion) {
        receive(state);
        set({ error: null });
      }
    } catch (error) {
      if (version === stateVersion)
        set({ error: errorMessage(error), status: snapshot.state ? "ready" : "failed" });
    } finally {
      set({ refreshing: false });
    }
  }
  async function mutate(operation: () => Promise<ShortcutMutation>) {
    if (snapshot.busy) return false;
    set({ busy: true, error: null, warning: null });
    try {
      const result = await operation();
      receive(result.state);
      set({ draft: null, external: false, warning: result.warning || null });
      return true;
    } catch (error) {
      set({ error: errorMessage(error) });
      return false;
    } finally {
      set({ busy: false });
    }
  }
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    refresh: load,
    edit(binding: ShortcutBinding) {
      if (!snapshot.state || snapshot.busy) return;
      validationVersion++;
      set({
        error: null,
        external: false,
        draft: {
          binding,
          revision: snapshot.state.revision,
          chord: { modifiers: binding.modifiers, key: binding.key },
          validation: null,
          validating: false,
          validationError: null,
        },
      });
    },
    close() {
      if (!snapshot.busy) {
        validationVersion++;
        set({ draft: null, external: false });
      }
    },
    async record(chord: ShortcutChord) {
      const draft = snapshot.draft;
      if (!draft || snapshot.busy) return;
      const version = ++validationVersion;
      set({
        draft: { ...draft, chord, validation: null, validating: true, validationError: null },
      });
      try {
        const validation = await host.request("shortcuts.validate", {
          id: draft.binding.id,
          chord,
        });
        if (version === validationVersion && snapshot.draft)
          set({ draft: { ...snapshot.draft, validation, validating: false } });
      } catch (error) {
        if (version === validationVersion && snapshot.draft)
          set({
            draft: { ...snapshot.draft, validating: false, validationError: errorMessage(error) },
          });
      }
    },
    save() {
      const draft = snapshot.draft;
      if (
        !draft?.validation ||
        draft.validating ||
        draft.validation.conflicts.length ||
        snapshot.external
      )
        return Promise.resolve(false);
      return mutate(() =>
        host.request("shortcuts.rebind", {
          id: draft.binding.id,
          revision: draft.revision,
          chord: draft.chord,
        }),
      );
    },
    disable() {
      const draft = snapshot.draft;
      if (!draft || snapshot.external) return Promise.resolve(false);
      return mutate(() =>
        host.request("shortcuts.disable", { id: draft.binding.id, revision: draft.revision }),
      );
    },
    async reset(revision: string) {
      if (!(await mutate(() => host.request("shortcuts.reset", { revision }))))
        throw new Error(snapshot.error ?? "Could not reset shortcuts.");
    },
    async openConfiguration() {
      try {
        await host.request("shortcuts.openConfiguration");
      } catch (error) {
        set({ error: errorMessage(error) });
      }
    },
  };
}
export type ShortcutsStore = ReturnType<typeof createShortcutsStore>;
