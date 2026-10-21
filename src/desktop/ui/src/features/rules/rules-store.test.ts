import { describe, expect, it, vi } from "vitest";

import { createBridge } from "~/bridge/client";
import type { CustomWindowRule, RulesState } from "~/bridge/contract/rules";

import { createRulesStore } from "./rules-store";

const state: RulesState = {
  floatingApps: ["Messages"],
  customRules: [],
  externalRules: [],
  icons: {},
};
function setup() {
  const bridge = createBridge({});
  const getState = vi.fn<() => Promise<RulesState>>(async () => state);
  const addApplication = vi.fn<() => Promise<null>>(async () => null);
  const removeFloating = vi.fn<(app: string) => Promise<null>>(async () => null);
  const saveCustom = vi.fn<(rule: CustomWindowRule) => Promise<null>>(async () => null);
  const removeCustom = vi.fn<(id: string) => Promise<null>>(async () => null);
  const store = createRulesStore({
    getState,
    addApplication,
    removeFloating,
    saveCustom,
    removeCustom,
    subscribe: bridge.subscribe,
  });
  return {
    store,
    getState,
    addApplication,
    removeFloating,
    saveCustom,
    removeCustom,
    unavailable: (message: string) =>
      bridge.receive(JSON.stringify({ type: "rules.unavailable", state: { message } })),
    event: (next: RulesState) =>
      bridge.receive(JSON.stringify({ type: "rules.changed", state: next })),
  };
}

describe("Rules store", () => {
  it("loads and refreshes without editing", async () => {
    const test = setup();
    await test.store.load();
    await test.store.load();
    expect(test.getState).toHaveBeenCalledTimes(1);
    await test.store.refresh();
    expect(test.store.getSnapshot()).toMatchObject({ status: "ready", state });
    expect(test.addApplication).not.toHaveBeenCalled();
    expect(test.saveCustom).not.toHaveBeenCalled();
  });

  it("shows a failed first read without defaults and supports retry", async () => {
    const test = setup();
    test.getState.mockRejectedValueOnce(new Error("Unreadable settings"));
    await test.store.load();
    expect(test.store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "Unreadable settings",
    });
    await test.store.refresh();
    expect(test.store.getSnapshot()).toMatchObject({ status: "ready", error: null });
  });

  it("routes each edit to its named operation and refreshes", async () => {
    const test = setup();
    await test.store.load();
    const rule = { id: "id", app: "Finder", title: "^Copy$" };
    await test.store.addApplication();
    await test.store.removeFloating("Messages");
    await test.store.saveCustom(rule);
    await test.store.removeCustom("id");
    expect(test.addApplication).toHaveBeenCalledOnce();
    expect(test.removeFloating).toHaveBeenCalledWith("Messages");
    expect(test.saveCustom).toHaveBeenCalledWith(rule);
    expect(test.removeCustom).toHaveBeenCalledWith("id");
    expect(test.getState).toHaveBeenCalledTimes(5);
  });

  it("keeps saved state and exposes failed apply", async () => {
    const test = setup();
    await test.store.load();
    test.saveCustom.mockRejectedValueOnce(new Error("Rejected"));
    expect(await test.store.saveCustom({ id: "id", app: "Finder", title: "[" })).toBe(false);
    expect(test.store.getSnapshot()).toMatchObject({ state, error: "Rejected", busy: false });
  });

  it("does not mistake a failed refresh for a failed save", async () => {
    const test = setup();
    await test.store.load();
    test.getState.mockRejectedValueOnce(new Error("Disconnected"));
    expect(await test.store.removeCustom("id")).toBe(true);
    expect(test.store.getSnapshot().error).toBe("Disconnected");
  });

  it("serialises edits and exposes progress", async () => {
    const test = setup();
    let finish!: (value: null) => void;
    test.addApplication.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    const mutation = test.store.addApplication();
    expect(test.store.getSnapshot().busy).toBe(true);
    expect(await test.store.removeCustom("id")).toBe(false);
    expect(test.removeCustom).not.toHaveBeenCalled();
    finish(null);
    await mutation;
    expect(test.store.getSnapshot().busy).toBe(false);
  });

  it("reports unreadable external settings and clears the notice when they recover", async () => {
    const test = setup();
    await test.store.load();
    test.unavailable("Unreadable external change");
    expect(test.store.getSnapshot()).toMatchObject({ state, error: "Unreadable external change" });
    test.event(state);
    expect(test.store.getSnapshot().error).toBeNull();
  });

  it("does not hide an apply failure when another entry point publishes state", async () => {
    const test = setup();
    await test.store.load();
    test.saveCustom.mockRejectedValueOnce(new Error("Rejected"));
    await test.store.saveCustom({ id: "id", app: "Finder", title: "[" });
    test.event(state);
    expect(test.store.getSnapshot().error).toBe("Rejected");
  });

  it("external events supersede stale reads", async () => {
    const test = setup();
    let finish!: (value: RulesState) => void;
    test.getState.mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    const loading = test.store.load();
    const next = { ...state, floatingApps: ["Calculator"] };
    test.event(next);
    finish(state);
    await loading;
    expect(test.store.getSnapshot()).toMatchObject({ state: next, refreshing: false });
  });
});
