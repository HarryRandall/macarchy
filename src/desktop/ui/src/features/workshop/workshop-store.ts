import { errorMessage } from "~/bridge/client";
import type { BridgeEvent, ThemeDetail, ThemesState } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

export interface WorkshopSnapshot {
  status: "loading" | "ready" | "failed";
  /** The themes on this Mac, to mark what is already installed. */
  installed: ThemeDetail[];
  /** The applied theme's name. */
  current: string | null;
  /** Why the installed themes could not be read; the catalogue still shows. */
  error: string | null;
}

export interface WorkshopStoreDeps {
  getThemes(): Promise<ThemesState>;
  subscribe(
    type: "themes.changed",
    handler: (event: Extract<BridgeEvent, { type: "themes.changed" }>) => void,
  ): () => void;
}

/**
 * Workshop reads only the installed themes. Everything else on the page is
 * a placeholder catalogue, so a failed read leaves the page usable with
 * nothing marked installed.
 */
export function createWorkshopStore(deps: WorkshopStoreDeps) {
  const listeners = createListeners();
  let snapshot: WorkshopSnapshot = { status: "loading", installed: [], current: null, error: null };
  let reads = 0;

  async function load() {
    const read = ++reads;
    let next: WorkshopSnapshot;
    try {
      const state = await deps.getThemes();
      next = { status: "ready", installed: state.themes, current: state.current, error: null };
    } catch (error) {
      next = { ...snapshot, status: "ready", error: errorMessage(error) };
    }
    if (read !== reads) return;
    snapshot = next;
    listeners.notify();
  }

  deps.subscribe("themes.changed", () => {
    if (snapshot.status !== "loading") void load();
  });

  return { subscribe: listeners.subscribe, getSnapshot: () => snapshot, load };
}

export type WorkshopStore = ReturnType<typeof createWorkshopStore>;
