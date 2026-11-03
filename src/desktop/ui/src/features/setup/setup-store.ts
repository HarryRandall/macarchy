import { errorMessage } from "~/bridge/client";
import type {
  ExistingSetup,
  ServiceId,
  SetupChoices,
  SetupExtraId,
  SetupProgress,
  SetupReport,
  SetupState,
} from "~/bridge/protocol";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

const allTools: ServiceId[] = ["yabai", "skhd", "sketchybar", "borders"];

/** How installing one tool is going during a run. */
export interface ToolInstall {
  status: "waiting" | "installing" | "installed" | "failed";
  /** Why it failed. */
  reason: string | null;
}

export function createSetupStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot = {
    status: "loading" as "loading" | "ready" | "failed",
    state: null as SetupState | null,
    /** The ticked tools. Every tool until the first plan says what was chosen before. */
    tools: allTools,
    existing: {} as Partial<Record<ServiceId, ExistingSetup>>,
    /** The ticked extras to install. None until the person ticks one. */
    extras: [] as SetupExtraId[],
    busy: false,
    planning: false,
    error: null as string | null,
    report: null as SetupReport | null,
    /** What a run is doing: installing tools, then writing files. */
    phase: null as "installing" | "configuring" | null,
    installs: {} as Partial<Record<ServiceId | SetupExtraId, ToolInstall>>,
    /** Homebrew's output during the last run, in order. */
    log: [] as string[],
    /** Terminal was opened to install Homebrew, so checking again is next. */
    homebrewOpened: false,
  };
  let generation = 0;
  /** The first plan carries the earlier choice of tools, which replaces the default. */
  let adopted = false;
  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  function choices(): SetupChoices {
    const { tools, existing, extras } = snapshot;
    return extras.length ? { tools, existing, extras } : { tools, existing };
  }
  async function load() {
    const reading = ++generation;
    set({ planning: true, error: null });
    try {
      const state = await host.request("setup.getPlan", choices());
      if (reading !== generation) return;
      if (!adopted) {
        adopted = true;
        const chosen = allTools.filter((id) => state.tools.some((t) => t.id === id && t.chosen));
        if (chosen.join() !== snapshot.tools.join()) {
          set({ tools: chosen });
          return await load();
        }
      }
      set({ state, status: "ready" });
    } catch (error) {
      if (reading === generation)
        set({ state: null, status: "failed", error: errorMessage(error) });
    } finally {
      if (reading === generation) set({ planning: false });
    }
  }
  /** Rereads the plan after a failed run, keeping its report and reason, since
   * whether the window can close depends on how far the run got. */
  async function refresh() {
    const reading = ++generation;
    try {
      const state = await host.request("setup.getPlan", choices());
      if (reading === generation) set({ state });
    } catch {
      // The run's failure is already shown; the earlier plan keeps the window open.
    }
  }
  function progress(step: SetupProgress) {
    if (!snapshot.busy) return;
    if (step.status === "configuring" || step.tool === null) {
      set({ phase: "configuring" });
      return;
    }
    const tool = step.tool;
    switch (step.status) {
      case "output":
        if (step.line !== null) set({ log: [...snapshot.log, step.line] });
        return;
      case "failed":
        set({
          installs: { ...snapshot.installs, [tool]: { status: "failed", reason: step.line } },
          log: step.line === null ? snapshot.log : [...snapshot.log, step.line],
        });
        return;
      default:
        set({ installs: { ...snapshot.installs, [tool]: { status: step.status, reason: null } } });
    }
  }
  const unsubscribe = host.subscribe("setup.progress", (event) => progress(event.state));
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    /** Ticks or unticks a tool, and reads the plan for the new choice. */
    toggle(tool: ServiceId, chosen: boolean) {
      if (snapshot.busy) return;
      const tools = allTools.filter((id) => (id === tool ? chosen : snapshot.tools.includes(id)));
      set({ tools });
      void load();
    },
    /** Ticks or unticks an extra. It changes no files, so the plan stays as it is. */
    toggleExtra(extra: SetupExtraId, chosen: boolean) {
      if (snapshot.busy) return;
      const others = snapshot.extras.filter((id) => id !== extra);
      set({ extras: chosen ? [...others, extra] : others });
    },
    /** Keeps a tool's own config or starts it from Macarchy's defaults. */
    choose(tool: ServiceId, existing: ExistingSetup) {
      if (snapshot.busy) return;
      set({ existing: { ...snapshot.existing, [tool]: existing } });
      void load();
    },
    async run() {
      const state = snapshot.state;
      if (snapshot.busy || snapshot.planning || !state || !snapshot.tools.length) return;
      const missing = state.homebrew
        ? [
            ...state.tools.filter((tool) => !tool.installed && snapshot.tools.includes(tool.id)),
            ...state.extras.filter(
              (extra) => !extra.installed && snapshot.extras.includes(extra.id),
            ),
          ]
        : [];
      set({
        busy: true,
        error: null,
        phase: missing.length ? "installing" : "configuring",
        installs: Object.fromEntries(
          missing.map((tool) => [tool.id, { status: "waiting", reason: null }]),
        ),
        log: [],
      });
      try {
        const report = await host.request("setup.run", choices());
        set({ report, error: report.failure });
        if (report.failure) await refresh();
      } catch (error) {
        set({ error: errorMessage(error) });
      } finally {
        set({ busy: false, phase: null });
      }
    },
    /** Opens Homebrew's installer in Terminal; checking again reads the plan afresh. */
    async installHomebrew() {
      set({ error: null });
      try {
        await host.request("setup.installHomebrew");
        set({ homebrewOpened: true });
      } catch (error) {
        set({ error: errorMessage(error) });
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
      set({ report: null, error: null, installs: {}, log: [] });
      void load();
    },
    dispose: unsubscribe,
  };
}
export type SetupStore = ReturnType<typeof createSetupStore>;
