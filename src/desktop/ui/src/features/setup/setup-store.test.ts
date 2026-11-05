import { describe, expect, it, vi } from "vitest";
import type { BridgeEvent, SetupProgress, SetupState, SetupTool } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createSetupStore } from "./setup-store";

function tool(id: SetupTool["id"], patch: Partial<SetupTool> = {}): SetupTool {
  return {
    id,
    name: id,
    description: "",
    installed: true,
    chosen: true,
    ownConfig: null,
    ...patch,
  };
}
const plan: SetupState = {
  tools: [
    tool("yabai", { ownConfig: "~/.config/yabai/yabairc" }),
    tool("skhd"),
    tool("sketchybar", { installed: false }),
    tool("borders"),
  ],
  extras: [
    {
      id: "example-app",
      name: "Example",
      description: "",
      installed: false,
    },
  ],
  homebrew: true,
  changes: [{ path: "~/yabairc", action: "adopt", detail: "Kept" }],
  canClose: false,
  notices: [],
};
const every = { tools: ["yabai", "skhd", "sketchybar", "borders"], existing: {} };
function harness(state: SetupState = plan) {
  const handlers = new Map<string, (event: BridgeEvent) => void>();
  const request = vi.fn<(...args: unknown[]) => Promise<unknown>>().mockResolvedValue(state);
  const host = {
    request,
    subscribe: (type: string, handler: (event: BridgeEvent) => void) => {
      handlers.set(type, handler);
      return () => handlers.delete(type);
    },
  } as PageHost;
  function progress(step: SetupProgress) {
    handlers.get("setup.progress")?.({ type: "setup.progress", state: step });
  }
  return { request, progress, handlers, store: createSetupStore(host) };
}
describe("Setup store", () => {
  it("reads a plan for every tool, keeping their own configs, before enabling setup", async () => {
    const { store, request } = harness();
    await store.run();
    expect(request).not.toHaveBeenCalled();
    await store.load();
    expect(request.mock.calls).toEqual([["setup.getPlan", every]]);
  });
  it("starts from the tools chosen in an earlier setup", async () => {
    const earlier = {
      ...plan,
      tools: plan.tools.map((t) => (t.id === "borders" ? { ...t, chosen: false } : t)),
    };
    const { store, request } = harness(earlier);
    await store.load();
    expect(request.mock.calls.at(-1)).toEqual([
      "setup.getPlan",
      { tools: ["yabai", "skhd", "sketchybar"], existing: {} },
    ]);
    expect(store.getSnapshot().tools).toEqual(["yabai", "skhd", "sketchybar"]);
  });
  it("unticking a tool and choosing defaults for another reads a matching plan first", async () => {
    const { store, request } = harness();
    await store.load();
    let resolve!: (state: SetupState) => void;
    request.mockImplementationOnce(
      () =>
        new Promise<SetupState>((done) => {
          resolve = done;
        }),
    );
    store.toggle("borders", false);
    await store.run();
    expect(request.mock.calls).toHaveLength(2);
    resolve(plan);
    await vi.waitFor(() => expect(store.getSnapshot().planning).toBe(false));
    store.choose("yabai", "replace");
    await vi.waitFor(() => expect(store.getSnapshot().planning).toBe(false));
    request.mockResolvedValueOnce({ lines: ["Installed"], failures: [], failure: null });
    await store.run();
    expect(request.mock.calls.at(-1)).toEqual([
      "setup.run",
      { tools: ["yabai", "skhd", "sketchybar"], existing: { yabai: "replace" } },
    ]);
  });
  it("refuses to run with no tool chosen", async () => {
    const { store, request } = harness();
    await store.load();
    for (const id of ["yabai", "skhd", "sketchybar", "borders"] as const) store.toggle(id, false);
    await vi.waitFor(() => expect(store.getSnapshot().planning).toBe(false));
    const calls = request.mock.calls.length;
    await store.run();
    expect(request.mock.calls).toHaveLength(calls);
  });
  it("follows each tool Homebrew installs, with its output, then the files", async () => {
    const { store, request, progress } = harness();
    await store.load();
    let finish!: (report: unknown) => void;
    request.mockImplementationOnce(
      () =>
        new Promise((done) => {
          finish = done;
        }),
    );
    const running = store.run();
    expect(store.getSnapshot()).toMatchObject({
      busy: true,
      phase: "installing",
      installs: { sketchybar: { status: "waiting" } },
    });
    progress({ tool: "sketchybar", status: "installing", line: null });
    progress({ tool: "sketchybar", status: "output", line: "==> Pouring sketchybar" });
    progress({ tool: "sketchybar", status: "failed", line: "Error: No available formula" });
    progress({ tool: null, status: "configuring", line: null });
    expect(store.getSnapshot()).toMatchObject({
      phase: "configuring",
      installs: { sketchybar: { status: "failed", reason: "Error: No available formula" } },
      log: ["==> Pouring sketchybar", "Error: No available formula"],
    });
    finish({
      lines: ["Wrote settings"],
      failures: ["sketchybar was not installed"],
      failure: null,
    });
    await running;
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      phase: null,
      report: { failures: ["sketchybar was not installed"] },
      log: ["==> Pouring sketchybar", "Error: No available formula"],
    });
  });
  it("a ticked extra is installed with the tools and changes no plan", async () => {
    const { store, request } = harness();
    await store.load();
    const planned = request.mock.calls.length;
    store.toggleExtra("example-app", true);
    expect(request.mock.calls.length).toBe(planned);
    request.mockResolvedValueOnce({ lines: [], failures: [], failure: null });
    const running = store.run();
    expect(store.getSnapshot().installs).toMatchObject({
      sketchybar: { status: "waiting" },
      "example-app": { status: "waiting" },
    });
    await running;
    expect(request.mock.calls.at(-1)).toEqual(["setup.run", { ...every, extras: ["example-app"] }]);
  });
  it("ignores progress when no run is going", async () => {
    const { store, progress } = harness();
    await store.load();
    progress({ tool: "skhd", status: "output", line: "stray" });
    expect(store.getSnapshot().log).toEqual([]);
  });
  it("without Homebrew nothing waits to install, and Terminal opens its installer", async () => {
    const { store, request } = harness({ ...plan, homebrew: false });
    await store.load();
    request.mockResolvedValueOnce(null);
    await store.installHomebrew();
    expect(request.mock.calls.at(-1)).toEqual(["setup.installHomebrew"]);
    expect(store.getSnapshot().homebrewOpened).toBe(true);
    let finish!: (report: unknown) => void;
    request.mockImplementationOnce(
      () =>
        new Promise((done) => {
          finish = done;
        }),
    );
    const running = store.run();
    expect(store.getSnapshot()).toMatchObject({ phase: "configuring", installs: {} });
    finish({ lines: [], failures: [], failure: null });
    await running;
  });
  it("failed planning shows an error instead of stale defaults", async () => {
    const { store, request } = harness();
    request.mockRejectedValueOnce(new Error("Cannot read"));
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "Cannot read",
    });
    await store.run();
    expect(request.mock.calls).toHaveLength(1);
  });
  it("setup failures remain visible and allow retry with the same choice", async () => {
    const { store, request } = harness();
    await store.load();
    request.mockRejectedValueOnce(new Error("Some files changed"));
    await store.run();
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: "Some files changed",
      report: null,
    });
    request.mockResolvedValueOnce({ lines: ["Done"], failures: [], failure: null });
    await store.run();
    expect(request.mock.calls.at(-1)).toEqual(["setup.run", every]);
    expect(store.getSnapshot().report?.lines).toEqual(["Done"]);
  });
  it("a failed run rereads whether the window can close, keeping the report and reason", async () => {
    const { store, request } = harness();
    await store.load();
    const failure = "Setup did not finish; some files may already have changed. Bar not written";
    request.mockResolvedValueOnce({ lines: ["Wrote settings"], failures: [], failure });
    request.mockResolvedValueOnce({ ...plan, canClose: true });
    await store.run();
    expect(request.mock.calls.at(-1)).toEqual(["setup.getPlan", every]);
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: failure,
      state: { canClose: true },
      report: { lines: ["Wrote settings"], failure },
    });
    store.reset();
    await vi.waitFor(() => expect(store.getSnapshot().planning).toBe(false));
    expect(store.getSnapshot()).toMatchObject({ error: null, report: null });
  });
  it("stops listening once disposed", () => {
    const { store, handlers } = harness();
    expect(handlers.has("setup.progress")).toBe(true);
    store.dispose();
    expect(handlers.has("setup.progress")).toBe(false);
  });
});
