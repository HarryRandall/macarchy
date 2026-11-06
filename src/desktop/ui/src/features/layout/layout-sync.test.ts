import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { BridgeError } from "~/bridge/client";
import type { BridgeEvent, LayoutApplyParams, LayoutState, LayoutValues } from "~/bridge/protocol";

import { createLayoutStore } from "./layout-store";
import { createEditQueue, type LayoutField, mergeLayoutValues } from "./layout-sync";

const values: LayoutValues = {
  layout: "bsp",
  splitType: "auto",
  windowPlacement: "second_child",
  autoBalance: false,
  windowGap: 8,
  padding: 8,
  mouseModifier: "ctrl",
  mouseFollowsFocus: false,
  mouseDropAction: "stack",
};

function daemonState(patch: Partial<LayoutValues> = {}): LayoutState {
  return {
    values: { ...values, ...patch },
    source: "daemon",
    unavailableReason: null,
    wallpaper: null,
  };
}

const timers = {
  setTimeout: (run: () => void, ms: number) => setTimeout(run, ms),
  clearTimeout: (handle: unknown) => clearTimeout(handle as ReturnType<typeof setTimeout>),
};

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe("mergeLayoutValues", () => {
  it("takes incoming values except protected fields", () => {
    const local = { ...values, windowGap: 20, padding: 4 };
    const incoming = { ...values, windowGap: 8, padding: 12, layout: "float" as const };
    expect(mergeLayoutValues(local, incoming, new Set<LayoutField>(["windowGap"]))).toEqual({
      ...values,
      windowGap: 20,
      padding: 12,
      layout: "float",
    });
  });

  it("returns incoming unchanged when nothing is protected", () => {
    const incoming = { ...values, windowGap: 3 };
    expect(mergeLayoutValues(values, incoming, new Set())).toEqual(incoming);
  });
});

describe("createEditQueue", () => {
  it("coalesces rapid edits to one field into one send with the last value", async () => {
    const send = vi.fn<(params: LayoutApplyParams) => Promise<null>>(async () => null);
    const queue = createEditQueue({ delay: 80, timers, send });
    for (const gap of [9, 10, 11, 12]) {
      queue.edit("windowGap", gap, true);
      await vi.advanceTimersByTimeAsync(30);
    }
    expect(send).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(80);
    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenCalledWith({ changes: { windowGap: 12 }, linkPadding: true });
  });

  it("debounces each field independently", async () => {
    const send = vi.fn<(params: LayoutApplyParams) => Promise<null>>(async () => null);
    const queue = createEditQueue({ delay: 80, timers, send });
    queue.edit("windowGap", 10, true);
    await vi.advanceTimersByTimeAsync(50);
    queue.edit("layout", "stack", true);
    await vi.advanceTimersByTimeAsync(30);
    expect(send.mock.calls).toEqual([[{ changes: { windowGap: 10 }, linkPadding: true }]]);
    await vi.advanceTimersByTimeAsync(50);
    expect(send.mock.calls).toEqual([
      [{ changes: { windowGap: 10 }, linkPadding: true }],
      [{ changes: { layout: "stack" }, linkPadding: true }],
    ]);
  });

  it("captures linkPadding at the moment of the edit", async () => {
    const send = vi.fn<(params: LayoutApplyParams) => Promise<null>>(async () => null);
    const queue = createEditQueue({ delay: 80, timers, send });
    queue.edit("padding", 14, false);
    await vi.advanceTimersByTimeAsync(100);
    queue.edit("padding", 16, true);
    await vi.advanceTimersByTimeAsync(100);
    expect(send.mock.calls).toEqual([
      [{ changes: { padding: 14 }, linkPadding: false }],
      [{ changes: { padding: 16 }, linkPadding: true }],
    ]);
  });

  it("protects a field while pending, in flight, and against reads that started earlier", async () => {
    let finish!: () => void;
    const send = vi.fn<(params: LayoutApplyParams) => Promise<void>>(
      () => new Promise<void>((resolve) => (finish = resolve)),
    );
    const queue = createEditQueue({ delay: 80, timers, send });

    const before = queue.now();
    queue.edit("windowGap", 20, true);
    expect(queue.protectedFields(queue.now())).toEqual(new Set(["windowGap"]));

    await vi.advanceTimersByTimeAsync(80);
    expect(send).toHaveBeenCalledTimes(1);
    expect(queue.isBusy("windowGap")).toBe(true);

    finish();
    await vi.advanceTimersByTimeAsync(0);
    expect(queue.isBusy("windowGap")).toBe(false);
    // A read issued before the send settled may hold the old value.
    expect(queue.protectedFields(before)).toEqual(new Set(["windowGap"]));
    // A read issued afterwards is authoritative.
    expect(queue.protectedFields(queue.now())).toEqual(new Set());
  });
});

function setup(initial: LayoutState = daemonState()) {
  const handlers: ((event: Extract<BridgeEvent, { type: "layout.changed" }>) => void)[] = [];
  const getState = vi.fn<() => Promise<LayoutState>>(async () => initial);
  const apply = vi.fn<(params: LayoutApplyParams) => Promise<unknown>>(async () => null);
  const store = createLayoutStore({
    getState,
    apply,
    subscribe: (_type, handler) => {
      handlers.push(handler);
      return () => {};
    },
    timers,
  });
  const emit = (state: LayoutState) =>
    handlers.forEach((handler) => handler({ type: "layout.changed", state }));
  return { store, getState, apply, emit };
}

describe("createLayoutStore", () => {
  it("never applies on load, refresh or external change", async () => {
    const { store, apply, emit } = setup();
    await store.load();
    await store.refresh();
    emit(daemonState({ windowGap: 30, layout: "float" }));
    await vi.advanceTimersByTimeAsync(1000);
    expect(apply).not.toHaveBeenCalled();
    expect(store.getSnapshot().state?.values.windowGap).toBe(30);
  });

  it("shows edits at once and sends them debounced", async () => {
    const { store, apply } = setup();
    await store.load();
    store.edit("windowGap", 12);
    store.edit("windowGap", 14);
    expect(store.getSnapshot().state?.values.windowGap).toBe(14);
    expect(apply).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(80);
    expect(apply).toHaveBeenCalledExactlyOnceWith({
      changes: { windowGap: 14 },
      linkPadding: true,
    });
  });

  it("keeps a field being edited when an external change arrives, and updates the others", async () => {
    const { store, emit } = setup();
    await store.load();
    store.edit("windowGap", 20);
    emit(daemonState({ windowGap: 8, padding: 30 }));
    expect(store.getSnapshot().state?.values).toMatchObject({ windowGap: 20, padding: 30 });
  });

  it("does not let a refetch that started before an apply settled overwrite it", async () => {
    const { store, getState, apply } = setup();
    await store.load();

    let finishApply!: () => void;
    apply.mockImplementationOnce(() => new Promise<void>((resolve) => (finishApply = resolve)));
    let finishRead!: (state: LayoutState) => void;
    getState.mockImplementationOnce(
      () => new Promise<LayoutState>((resolve) => (finishRead = resolve)),
    );

    store.edit("windowGap", 24);
    await vi.advanceTimersByTimeAsync(80);
    const refresh = store.refresh();
    finishApply();
    await vi.advanceTimersByTimeAsync(0);
    finishRead(daemonState({ windowGap: 8, mouseModifier: "alt" }));
    await refresh;

    expect(store.getSnapshot().state?.values).toMatchObject({
      windowGap: 24,
      mouseModifier: "alt",
    });
  });

  it("uses the Match all screen edges setting at the time of the edit", async () => {
    const { store, apply } = setup();
    await store.load();
    store.setLinkPadding(false);
    store.edit("padding", 20);
    store.setLinkPadding(true);
    await vi.advanceTimersByTimeAsync(80);
    expect(apply).toHaveBeenCalledWith({ changes: { padding: 20 }, linkPadding: false });
  });

  it("on a failed apply shows the error and restores the failed field from the daemon", async () => {
    const { store, apply, getState } = setup();
    await store.load();
    apply.mockRejectedValueOnce(new BridgeError("operation_failed", "yabai rejected it."));
    getState.mockResolvedValueOnce(daemonState({ windowGap: 8 }));

    store.edit("windowGap", 30);
    expect(store.getSnapshot().state?.values.windowGap).toBe(30);
    await vi.advanceTimersByTimeAsync(80);
    await vi.advanceTimersByTimeAsync(0);

    expect(store.getSnapshot().error).toBe("yabai rejected it.");
    expect(getState).toHaveBeenCalledTimes(2);
    expect(store.getSnapshot().state?.values.windowGap).toBe(8);

    store.dismissError();
    expect(store.getSnapshot().error).toBeNull();
  });

  it("clears the failure notice when a later apply succeeds", async () => {
    const { store, apply } = setup();
    await store.load();
    apply.mockRejectedValueOnce(new BridgeError("operation_failed", "yabai rejected it."));
    store.edit("windowGap", 30);
    await vi.advanceTimersByTimeAsync(80);
    expect(store.getSnapshot().error).toBe("yabai rejected it.");

    store.edit("padding", 12);
    expect(store.getSnapshot().error).toBe("yabai rejected it.");
    await vi.advanceTimersByTimeAsync(80);
    expect(store.getSnapshot().error).toBeNull();
  });

  it("keeps the notice when an apply sent before the failure succeeds after it", async () => {
    const { store, apply } = setup();
    await store.load();
    let finishEarly!: () => void;
    apply.mockImplementationOnce(() => new Promise<void>((resolve) => (finishEarly = resolve)));
    apply.mockRejectedValueOnce(new BridgeError("operation_failed", "yabai rejected it."));

    store.edit("padding", 12);
    await vi.advanceTimersByTimeAsync(80);
    store.edit("windowGap", 30);
    await vi.advanceTimersByTimeAsync(80);
    expect(store.getSnapshot().error).toBe("yabai rejected it.");

    finishEarly();
    await vi.advanceTimersByTimeAsync(0);
    expect(store.getSnapshot().error).toBe("yabai rejected it.");
  });

  it("replaces the notice with a newer failure", async () => {
    const { store, apply } = setup();
    await store.load();
    apply.mockRejectedValueOnce(new BridgeError("operation_failed", "First."));
    apply.mockRejectedValueOnce(new BridgeError("operation_failed", "Second."));
    store.edit("windowGap", 30);
    await vi.advanceTimersByTimeAsync(80);
    expect(store.getSnapshot().error).toBe("First.");
    store.edit("padding", 12);
    await vi.advanceTimersByTimeAsync(80);
    expect(store.getSnapshot().error).toBe("Second.");
  });

  it("passes a null unavailable reason and wallpaper through as null", async () => {
    const { store } = setup({ ...daemonState(), source: "saved" });
    await store.load();
    expect(store.getSnapshot().state).toMatchObject({
      source: "saved",
      unavailableReason: null,
      wallpaper: null,
    });
  });

  it("does not edit saved values while yabai is unavailable", async () => {
    const { store, apply } = setup({
      ...daemonState(),
      source: "saved",
      unavailableReason: "yabai is not running.",
    });
    await store.load();
    store.edit("windowGap", 30);
    await vi.advanceTimersByTimeAsync(200);
    expect(apply).not.toHaveBeenCalled();
    expect(store.getSnapshot().state?.values.windowGap).toBe(8);
  });

  it("reports a failed first read without inventing values", async () => {
    const { store, getState } = setup();
    getState.mockRejectedValueOnce(new BridgeError("unavailable", "Could not read the layout."));
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      loadError: "Could not read the layout.",
    });
    await store.refresh();
    expect(store.getSnapshot().status).toBe("ready");
  });
});
