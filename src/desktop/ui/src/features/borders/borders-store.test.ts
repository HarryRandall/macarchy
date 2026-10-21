import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { BorderAppearance, BordersState } from "~/bridge/contract/borders";
import type { PageHost } from "~/shell/page";
import type { BridgeEvent } from "~/bridge/protocol";
import { createBordersStore } from "./borders-store";

function state(): BordersState {
  return {
    appearance: {
      width: 7,
      visible: true,
      radius: null,
      excludedApps: ["Example"],
      activeColour: "0xff123456",
      inactiveColour: null,
    },
    applicationIcons: {},
    theme: "lumon",
    defaults: null,
    unavailableReason: null,
    wallpaper: null,
  };
}
function setup() {
  const getState = vi.fn<() => Promise<BordersState>>().mockResolvedValue(state());
  const apply = vi
    .fn<(params: { appearance: BordersState["appearance"]; theme: string }) => Promise<unknown>>()
    .mockResolvedValue(null);
  const pick = vi
    .fn<() => Promise<{ name: string; icon: string | null } | null>>()
    .mockResolvedValue({ name: "Other", icon: null });
  const handlers = new Map<string, (event: BridgeEvent) => void>();
  const host = {
    request: (method: string, params: { appearance: BordersState["appearance"]; theme: string }) =>
      method === "borders.getState"
        ? getState()
        : method === "borders.apply"
          ? apply(params)
          : pick(),
    subscribe: (type: string, handler: (event: BridgeEvent) => void) => {
      handlers.set(type, handler);
      return () => {};
    },
  } as PageHost;
  return {
    store: createBordersStore(host),
    getState,
    apply,
    pick,
    receive: (incoming: BordersState) =>
      handlers.get("borders.changed")?.({ type: "borders.changed", state: incoming }),
    themes: () =>
      handlers.get("themes.changed")?.({
        type: "themes.changed",
        state: { current: "lumon", themes: [] },
      }),
  };
}
describe("Borders draft editor", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());
  it("reads without applying; manual edits and resets wait for Apply", async () => {
    const { store, apply } = setup();
    await store.load();
    store.edit({ width: 6, radius: 0.3, activeColour: "0xffabcdef", excludedApps: [] });
    await vi.advanceTimersByTimeAsync(500);
    expect(apply).not.toHaveBeenCalled();
    store.setLive(true);
    expect(store.getSnapshot().live).toBe(false);
    await store.apply();
    const edited: BorderAppearance = {
      width: 6,
      visible: true,
      radius: 0.3,
      excludedApps: [],
      activeColour: "0xffabcdef",
      inactiveColour: null,
    };
    expect(apply).toHaveBeenCalledExactlyOnceWith({ theme: "lumon", appearance: edited });
    expect(store.getSnapshot()).toMatchObject({
      draft: edited,
      applied: edited,
      state: { appearance: edited },
      applying: false,
      error: null,
    });
  });
  it("coalesces a live drag into the latest complete appearance", async () => {
    const { store, apply } = setup();
    await store.load();
    store.setLive(true);
    store.edit({ width: 9 });
    store.edit({ width: 10 });
    store.edit({ visible: false });
    await vi.advanceTimersByTimeAsync(179);
    expect(apply).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(apply).toHaveBeenCalledTimes(1);
    expect(apply.mock.calls[0]?.[0].appearance).toMatchObject({ width: 10, visible: false });
  });
  it("turning off live cancels queued work and Discard restores all fields", async () => {
    const { store, apply } = setup();
    await store.load();
    store.setLive(true);
    store.edit({ width: 9 });
    store.setLive(false);
    await vi.advanceTimersByTimeAsync(500);
    expect(apply).not.toHaveBeenCalled();
    store.discard();
    expect(store.getSnapshot().draft).toEqual(state().appearance);
  });
  it("preserves failed drafts and disables live until an explicit retry", async () => {
    const { store, apply } = setup();
    await store.load();
    store.setLive(true);
    apply.mockRejectedValueOnce(new Error("Rejected"));
    store.edit({ width: 10 });
    await vi.advanceTimersByTimeAsync(180);
    expect(store.getSnapshot()).toMatchObject({
      live: false,
      draft: { width: 10 },
      applied: { width: 7 },
    });
    expect(store.getSnapshot().error).toContain("Some changes may already have applied");
    await store.apply();
    expect(store.getSnapshot().error).toBeNull();
  });
  it("allows live to turn off during Apply without cancelling the write", async () => {
    const { store, apply } = setup();
    await store.load();
    store.setLive(true);
    let finish!: () => void;
    apply.mockImplementationOnce(
      () =>
        new Promise<void>((resolve) => {
          finish = resolve;
        }),
    );
    store.edit({ width: 10 });
    await vi.advanceTimersByTimeAsync(180);
    expect(store.getSnapshot().applying).toBe(true);
    store.setLive(false);
    finish();
    await vi.advanceTimersByTimeAsync(0);
    expect(store.getSnapshot()).toMatchObject({
      live: false,
      applying: false,
      applied: { width: 10 },
    });
  });
  it("updates idle pages, keeps drafts on external changes and refuses a stale theme", async () => {
    const { store, receive, apply } = setup();
    await store.load();
    receive({ ...state(), appearance: { ...state().appearance, width: 8 } });
    expect(store.getSnapshot().draft?.width).toBe(8);
    store.edit({ width: 10 });
    receive({ ...state(), theme: "other" });
    expect(store.getSnapshot().draft?.width).toBe(10);
    expect(store.getSnapshot().externalChange).toBe(true);
    await store.apply();
    expect(apply).not.toHaveBeenCalled();
    expect(store.getSnapshot().error).toContain("active theme changed");
    store.discard();
    expect(store.getSnapshot().draftTheme).toBe("other");
  });
  it("refreshes theme-derived colours when themes change", async () => {
    const { store, getState, themes } = setup();
    await store.load();
    getState.mockResolvedValue({
      ...state(),
      appearance: { ...state().appearance, activeColour: "0xffabcdef" },
    });
    themes();
    await vi.advanceTimersByTimeAsync(0);
    expect(store.getSnapshot().draft?.activeColour).toBe("0xffabcdef");
  });
  it("does not invent values on a failed first read, and retries", async () => {
    const { store, getState } = setup();
    getState.mockRejectedValueOnce(new Error("Unreadable"));
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      draft: null,
      loadError: "Unreadable",
    });
    await store.load();
    expect(store.getSnapshot().status).toBe("ready");
  });
  it("shows saved settings while unavailable and never sends edits", async () => {
    const { store, getState, apply } = setup();
    getState.mockResolvedValue({ ...state(), unavailableReason: "borders isn't installed." });
    await store.load();
    store.edit({ width: 12 });
    await store.apply();
    expect(store.getSnapshot().draft?.width).toBe(7);
    expect(apply).not.toHaveBeenCalled();
  });
  it("ignores a read started before an edit and deduplicates selected apps", async () => {
    const { store, getState } = setup();
    await store.load();
    let resolve!: (state: BordersState) => void;
    getState.mockImplementationOnce(
      () =>
        new Promise<BordersState>((done) => {
          resolve = done;
        }),
    );
    const loading = store.load();
    store.edit({ width: 10 });
    resolve(state());
    await loading;
    expect(store.getSnapshot().draft?.width).toBe(10);
    await store.pickApplication();
    await store.pickApplication();
    expect(store.getSnapshot().draft?.excludedApps).toEqual(["Example", "Other"]);
  });
});
