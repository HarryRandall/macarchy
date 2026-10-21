import { errorMessage } from "~/bridge/client";
import type { ReportState } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";

export function createReportStore(host: PageHost) {
  const listeners = createListeners();
  let snapshot: {
    status: "loading" | "ready" | "failed";
    title: string;
    description: string;
    preview: ReportState | null;
    preparing: boolean;
    busy: boolean;
    error: string | null;
    /**
     * The last preparation failed, so the preview may not match the draft.
     * Copy and Open wait for a good one; a failed copy or open does not set
     * this, so both can be tried again at once.
     */
    stale: boolean;
    notice: string | null;
  } = {
    status: "loading",
    title: "",
    description: "",
    preview: null,
    preparing: false,
    busy: false,
    error: null,
    stale: false,
    notice: null,
  };
  let revision = 0;
  let active: Promise<void> | null = null;
  let shown = false;
  // Whether the next request, and the one in flight, collect diagnostics again.
  // Draft edits reuse the last collection so typing does not rerun the checks.
  let refresh = false;
  let collecting = false;
  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  async function prepare() {
    let sent: number;
    do {
      sent = revision;
      collecting = refresh;
      refresh = false;
      try {
        const preview = await host.request("report.prepare", {
          description: snapshot.description,
          refresh: collecting,
        });
        if (sent === revision) set({ preview, status: "ready", error: null, stale: false });
      } catch (error) {
        if (sent === revision)
          set({
            status: snapshot.preview ? "ready" : "failed",
            error: errorMessage(error),
            stale: true,
          });
      } finally {
        collecting = false;
      }
    } while (sent !== revision);
    set({ preparing: false });
  }
  function start() {
    if (active) return active;
    set({ preparing: true, notice: null });
    active = prepare().finally(() => {
      active = null;
    });
    return active;
  }
  /** Collects diagnostics again, sharing a collection that is already running. */
  function load() {
    if (active && collecting) return active;
    refresh = true;
    revision += 1;
    return start();
  }
  function setDescription(description: string) {
    revision += 1;
    set({ description });
    void start();
  }
  /** Runs a native action, resolving to whether it went through. */
  async function action(perform: () => Promise<string | null>): Promise<boolean> {
    if (snapshot.busy || snapshot.preparing) return false;
    set({ busy: true, error: null, notice: null });
    try {
      set({ notice: await perform() });
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
    /**
     * The shell loads a page only the first time it is shown, so coming back
     * to the page collects again: the person may have fixed something since.
     */
    opened() {
      if (shown) void load();
      shown = true;
    },
    setTitle(title: string) {
      set({ title });
    },
    setDescription,
    /** Clears the draft for another report, keeping the diagnostics already collected. */
    clear() {
      set({ title: "", notice: null });
      if (snapshot.description) setDescription("");
    },
    copy() {
      const preview = snapshot.preview;
      if (!preview || snapshot.stale) return Promise.resolve(false);
      return action(async () => {
        await host.request("report.copy", { token: preview.token });
        return "Copied";
      });
    },
    open() {
      const preview = snapshot.preview;
      if (!preview || !snapshot.title.trim() || snapshot.stale) return Promise.resolve(false);
      const title = snapshot.title;
      return action(async () => {
        const result = await host.request("report.openIssue", { token: preview.token, title });
        return result.copied
          ? "The report was too long for a link, so it is on your clipboard to paste."
          : null;
      });
    },
    openIssues: () =>
      action(async () => {
        await host.request("report.openIssues");
        return null;
      }),
  };
}
export type ReportStore = ReturnType<typeof createReportStore>;
