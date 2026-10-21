import { describe, expect, it, vi } from "vitest";

import { createBridge } from "~/bridge/client";
import type { CustomWindowRule, RulesState } from "~/bridge/contract/rules";

import { createRulesStore } from "./rules-store";

const state: RulesState = {
  floatingApps: ["Messages"],
  customRules: [],
  externalRules: [],
  icons: {},
  unavailableReason: null,
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

  it("shows saved rules without yabai and refuses edits until it recovers", async () => {
    const test = setup();
    const rule = { id: "copy", app: "Finder", title: "^Copy$" };
    const unavailable: RulesState = {
      ...state,
      customRules: [rule],
      unavailableReason: "yabai isn't responding, so these are your saved rules.",
    };
    test.getState.mockResolvedValueOnce(unavailable);
    await test.store.load();
    expect(test.store.getSnapshot()).toMatchObject({
      status: "ready",
      error: null,
      state: { floatingApps: ["Messages"], customRules: [rule], externalRules: [] },
    });
    expect(test.store.getSnapshot().state?.unavailableReason).toContain("saved rules");

    expect(await test.store.addApplication()).toBe(false);
    expect(await test.store.removeFloating("Messages")).toBe(false);
    expect(await test.store.saveCustom(rule)).toBe(false);
    expect(await test.store.removeCustom("copy")).toBe(false);
    expect(test.addApplication).not.toHaveBeenCalled();
    expect(test.removeFloating).not.toHaveBeenCalled();
    expect(test.saveCustom).not.toHaveBeenCalled();
    expect(test.removeCustom).not.toHaveBeenCalled();
    expect(test.store.getSnapshot()).toMatchObject({ busy: false, error: null });

    test.event(state);
    expect(await test.store.removeCustom("copy")).toBe(true);
    expect(test.removeCustom).toHaveBeenCalledWith("copy");
  });

  it("routes each edit to its named operation and shows the saved result", async () => {
    const test = setup();
    let saved: RulesState = state;
    test.getState.mockImplementation(async () => saved);
    test.addApplication.mockImplementation(async () => {
      saved = { ...saved, floatingApps: [...saved.floatingApps, "Calculator"] };
      return null;
    });
    test.removeFloating.mockImplementation(async (app) => {
      saved = { ...saved, floatingApps: saved.floatingApps.filter((name) => name !== app) };
      return null;
    });
    test.saveCustom.mockImplementation(async (rule) => {
      saved = { ...saved, customRules: [...saved.customRules, rule] };
      return null;
    });
    test.removeCustom.mockImplementation(async (id) => {
      saved = { ...saved, customRules: saved.customRules.filter((rule) => rule.id !== id) };
      return null;
    });
    await test.store.load();

    expect(await test.store.addApplication()).toBe(true);
    expect(test.store.getSnapshot().state?.floatingApps).toEqual(["Messages", "Calculator"]);

    expect(await test.store.removeFloating("Messages")).toBe(true);
    expect(test.store.getSnapshot().state?.floatingApps).toEqual(["Calculator"]);

    expect(await test.store.saveCustom({ id: "copy", app: "Finder", title: "^Copy$" })).toBe(true);
    expect(test.store.getSnapshot().state?.customRules).toEqual([
      { id: "copy", app: "Finder", title: "^Copy$" },
    ]);

    expect(await test.store.removeCustom("copy")).toBe(true);
    expect(test.store.getSnapshot()).toMatchObject({
      status: "ready",
      busy: false,
      error: null,
      state: { floatingApps: ["Calculator"], customRules: [] },
    });
    expect(test.addApplication).toHaveBeenCalledOnce();
    expect(test.removeFloating).toHaveBeenCalledWith("Messages");
    expect(test.removeCustom).toHaveBeenCalledWith("copy");
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
