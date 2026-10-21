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
    notice: string | null;
  } = {
    status: "loading",
    title: "",
    description: "",
    preview: null,
    preparing: false,
    busy: false,
    error: null,
    notice: null,
  };
  let revision = 0;
  let active: Promise<void> | null = null;
  function set(patch: Partial<typeof snapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }
  async function prepare() {
    let sent: number;
    do {
      sent = revision;
      try {
        const preview = await host.request("report.prepare", { description: snapshot.description });
        if (sent === revision) set({ preview, status: "ready", error: null });
      } catch (error) {
        if (sent === revision)
          set({ status: snapshot.preview ? "ready" : "failed", error: errorMessage(error) });
      }
    } while (sent !== revision);
    set({ preparing: false });
  }
  function load() {
    if (active) return active;
    set({ preparing: true, notice: null });
    active = prepare().finally(() => {
      active = null;
    });
    return active;
  }
  async function action(perform: () => Promise<string | null>) {
    if (snapshot.busy || snapshot.preparing) return;
    set({ busy: true, error: null, notice: null });
    try {
      set({ notice: await perform() });
    } catch (error) {
      set({ error: errorMessage(error) });
    } finally {
      set({ busy: false });
    }
  }
  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,
    setTitle(title: string) {
      set({ title });
    },
    setDescription(description: string) {
      revision += 1;
      set({ description });
      void load();
    },
    copy() {
      const preview = snapshot.preview;
      if (!preview || snapshot.error) return Promise.resolve();
      return action(async () => {
        await host.request("report.copy", { token: preview.token });
        return "Copied";
      });
    },
    open() {
      const preview = snapshot.preview;
      if (!preview || !snapshot.title.trim() || snapshot.error) return Promise.resolve();
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
