import { describe, expect, it, vi } from "vitest";
import type { AdvancedState, BridgeEvent } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createAdvancedStore } from "./advanced-store";

const state: AdvancedState = {
  services: [{ id: "yabai", state: "running" }],
  snapshots: [],
  theme: "lumon",
  installedThemes: 8,
  addition: "missing",
  additionExplanation: "Optional",
  wakeHelpers: true,
  backupsDirectory: "~/.config/macarchy/backups",
};
function harness() {
  const handlers = new Map<string, (event: BridgeEvent) => void>();
  const request = vi.fn<(...args: unknown[]) => Promise<unknown>>().mockResolvedValue(state);
  const host = {
    request,
    subscribe: (type: string, handler: (event: BridgeEvent) => void) => {
      handlers.set(type, handler);
      return () => {};
    },
  } as PageHost;
  return { store: createAdvancedStore(host), request, handlers };
}
describe("Advanced store", () => {
  it("loads read-only and accepts outside state", async () => {
    const { store, request, handlers } = harness();
    await store.load();
    expect(request.mock.calls).toEqual([["advanced.getState"]]);
    handlers.get("advanced.changed")?.({
      type: "advanced.changed",
      state: { ...state, theme: "midnight" },
    });
    expect(store.getSnapshot().state?.theme).toBe("midnight");
  });
  it("reports a failed first read without defaults, then retries", async () => {
    const { store, request } = harness();
    request.mockRejectedValueOnce(new Error("invalid settings"));
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "invalid settings",
    });
    await store.load();
    expect(store.getSnapshot().status).toBe("ready");
  });
  it("keeps status visible during actions and exposes failures to confirmation dialogs", async () => {
    const { store, request } = harness();
    await store.load();
    request.mockRejectedValueOnce(new Error("Restore refused"));
    await expect(store.restoreSnapshot("backup")).rejects.toThrow("Restore refused");
    expect(store.getSnapshot()).toMatchObject({ state, busy: false, error: "Restore refused" });
  });
  it("uses named actions and shows the state read after each one", async () => {
    const { store, request } = harness();
    let desktop: AdvancedState = {
      ...state,
      services: [
        { id: "yabai", state: "stopped" },
        { id: "skhd", state: "running" },
      ],
      addition: "repair",
    };
    request.mockImplementation(async (method, params) => {
      const daemon = (params as { daemon?: string } | undefined)?.daemon;
      if (method === "advanced.restartService" && daemon === "yabai") {
        desktop = {
          ...desktop,
          services: [
            { id: "yabai", state: "running" },
            { id: "skhd", state: "running" },
          ],
        };
      } else if (method === "advanced.stopService" && daemon === "skhd") {
        desktop = {
          ...desktop,
          services: [
            { id: "yabai", state: "running" },
            { id: "skhd", state: "stopped" },
          ],
        };
      } else if (method === "advanced.repairAddition") {
        desktop = { ...desktop, addition: "active" };
      } else if (method !== "advanced.getState") {
        throw new Error(`Unexpected ${String(method)}`);
      }
      return method === "advanced.getState" ? desktop : null;
    });
    await store.load();
    expect(store.getSnapshot().state?.services).toEqual([
      { id: "yabai", state: "stopped" },
      { id: "skhd", state: "running" },
    ]);

    await store.restart("yabai");
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: null,
      state: {
        services: [
          { id: "yabai", state: "running" },
          { id: "skhd", state: "running" },
        ],
        addition: "repair",
      },
    });

    await store.stop("skhd");
    expect(store.getSnapshot().state?.services).toEqual([
      { id: "yabai", state: "running" },
      { id: "skhd", state: "stopped" },
    ]);

    await store.repair();
    expect(store.getSnapshot().state?.addition).toBe("active");
    expect(request.mock.calls.map(([method]) => method)).toEqual([
      "advanced.getState",
      "advanced.restartService",
      "advanced.getState",
      "advanced.stopService",
      "advanced.getState",
      "advanced.repairAddition",
      "advanced.getState",
    ]);
  });
  it("does not let stale reads replace an external event", async () => {
    const { store, request, handlers } = harness();
    let resolve!: (value: AdvancedState) => void;
    request.mockImplementationOnce(
      () =>
        new Promise<AdvancedState>((done) => {
          resolve = done;
        }),
    );
    const reading = store.load();
    handlers.get("advanced.changed")?.({
      type: "advanced.changed",
      state: { ...state, theme: "midnight" },
    });
    resolve(state);
    await reading;
    expect(store.getSnapshot().state?.theme).toBe("midnight");
  });
});
