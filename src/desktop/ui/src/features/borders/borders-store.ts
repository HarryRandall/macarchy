import { errorMessage } from "~/bridge/client";
import type { BorderAppearance, BordersState } from "~/bridge/contract/borders";
import type { PageHost } from "~/shell/page";
import { createListeners } from "~/lib/store";

interface Snapshot {
  status: "loading" | "ready" | "failed";
  state: BordersState | null;
  draft: BorderAppearance | null;
  applied: BorderAppearance | null;
  draftTheme: string | null;
  live: boolean;
  applying: boolean;
  error: string | null;
  loadError: string | null;
  externalChange: boolean;
}
const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);
export function createBordersStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot: Snapshot = {
    status: "loading",
    state: null,
    draft: null,
    applied: null,
    draftTheme: null,
    live: false,
    applying: false,
    error: null,
    loadError: null,
    externalChange: false,
  };
  let pending: ReturnType<typeof setTimeout> | undefined;
  let revision = 0;
  function set(patch: Partial<Snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  function dirty() {
    return !same(snapshot.draft, snapshot.applied);
  }
  function cancel() {
    clearTimeout(pending);
    pending = undefined;
  }
  function receive(state: BordersState) {
    if (snapshot.applying || dirty()) {
      set({
        state,
        externalChange:
          !same(state.appearance, snapshot.applied) || state.theme !== snapshot.draftTheme,
      });
    } else {
      cancel();
      set({
        state,
        draft: state.appearance,
        applied: state.appearance,
        draftTheme: state.theme,
        status: "ready",
        loadError: null,
        externalChange: false,
      });
    }
  }
  async function load() {
    const started = revision;
    try {
      const state = await host.request("borders.getState");
      if (started === revision) receive(state);
    } catch (error) {
      if (snapshot.state) set({ error: errorMessage(error) });
      else set({ status: "failed", loadError: errorMessage(error) });
    }
  }
  function changed() {
    cancel();
    if (snapshot.live && dirty() && !snapshot.applying)
      pending = setTimeout(() => void apply(), 180);
  }
  async function apply() {
    cancel();
    const { draft, draftTheme, state } = snapshot;
    if (!draft || !draftTheme || !dirty() || snapshot.applying || state?.unavailableReason) return;
    if (state?.theme !== draftTheme) {
      set({
        live: false,
        error: "The active theme changed. Discard this draft and edit the current theme.",
      });
      return;
    }
    ++revision;
    set({ applying: true, error: null });
    try {
      await host.request("borders.apply", { appearance: draft, theme: draftTheme });
      set({
        applied: draft,
        state:
          snapshot.state?.theme === draftTheme
            ? { ...snapshot.state, appearance: draft }
            : snapshot.state,
        externalChange: snapshot.state?.theme !== draftTheme,
      });
    } catch (error) {
      set({
        live: false,
        error:
          "Some changes may already have applied. " +
          errorMessage(error) +
          " Retry Apply to finish.",
      });
    } finally {
      set({ applying: false });
      changed();
    }
  }
  host.subscribe("borders.changed", (event) => {
    ++revision;
    receive(event.state);
  });
  host.subscribe("themes.changed", () => {
    void load();
  });
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    apply,
    edit(patch: Partial<BorderAppearance>) {
      if (!snapshot.draft || snapshot.applying || snapshot.state?.unavailableReason) return;
      ++revision;
      set({ draft: { ...snapshot.draft, ...patch } });
      changed();
    },
    setLive(live: boolean) {
      if (live && (snapshot.applying || dirty())) return;
      cancel();
      set({ live });
    },
    discard() {
      if (snapshot.applying) return;
      cancel();
      ++revision;
      const state = snapshot.state;
      set({
        draft: state?.appearance ?? snapshot.applied,
        applied: state?.appearance ?? snapshot.applied,
        draftTheme: state?.theme ?? null,
        externalChange: false,
        error: null,
      });
    },
    async pickApplication() {
      try {
        const selected = await host.request("borders.pickApplication");
        const name = selected?.name;
        if (name && snapshot.draft && !snapshot.draft.excludedApps.includes(name)) {
          if (snapshot.state && selected?.icon) {
            set({
              state: {
                ...snapshot.state,
                applicationIcons: { ...snapshot.state.applicationIcons, [name]: selected.icon },
              },
            });
          }
          this.edit({ excludedApps: [...snapshot.draft.excludedApps, name] });
        }
      } catch (error) {
        set({ error: errorMessage(error) });
      }
    },
  };
}
export type BordersStore = ReturnType<typeof createBordersStore>;
