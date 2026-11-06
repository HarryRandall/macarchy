import { describe, expect, it } from "vitest";

import type { BridgeEvent, ShellShortcut, ShellState } from "~/bridge/protocol";

import { createShellStore } from "./shell-store";

const state: ShellState = {
  selectedPane: "layout",
  sidebarVisible: true,
  setupRequired: false,
  appearance: { accent: "#0a84ff", mode: "system" },
  services: { running: 4, total: 4 },
  version: "0.9.2",
  serviceList: [
    { id: "yabai", name: "yabai", state: "running" },
    { id: "borders", name: "borders", state: "running" },
    { id: "sketchybar", name: "SketchyBar", state: "running" },
    { id: "skhd", name: "skhd", state: "stopped" },
  ],
};

interface Call {
  method: string;
  params: unknown;
  settle(value?: unknown): void;
  fail(error: Error): void;
}

function harness() {
  const handlers = new Map<string, (event: BridgeEvent) => void>();
  const calls: Call[] = [];
  const store = createShellStore({
    request: ((method: string, params: unknown) => {
      if (method === "shell.getState") return Promise.resolve(state);
      return new Promise((resolve, reject) => {
        calls.push({
          method,
          params,
          settle: (value = null) => resolve(value),
          fail: reject,
        });
      });
    }) as never,
    subscribe: (type, next) => {
      handlers.set(type, next as (event: BridgeEvent) => void);
      return () => {};
    },
  });
  return {
    store,
    calls,
    send: (patch: Partial<ShellState>) =>
      handlers.get("shell.changed")?.({ type: "shell.changed", state: { ...state, ...patch } }),
    menu: (shortcut: ShellShortcut) =>
      handlers.get("shell.shortcut")?.({ type: "shell.shortcut", state: { shortcut } }),
  };
}

/** Lets the store's promise chains run to their end. */
async function flush() {
  for (let turn = 0; turn < 3; turn++) await Promise.resolve();
}

describe("shell store", () => {
  it("passes the app menu's shortcuts to whoever is listening", () => {
    const { store, menu } = harness();
    const heard: ShellShortcut[] = [];
    const stop = store.onShortcut((shortcut) => heard.push(shortcut));
    menu("palette");
    stop();
    menu("logs");
    expect(heard).toEqual(["palette"]);
  });

  it("keeps a click while its selection is being saved", async () => {
    const { store, send, calls } = harness();
    await store.load();
    store.selectPane("rules");
    // Sent by the host before it saw the request.
    send({ selectedPane: "layout" });
    expect(store.getSnapshot().state?.selectedPane).toBe("rules");

    calls[0]?.settle();
    await flush();
    send({ selectedPane: "layout" });
    expect(store.getSnapshot().state?.selectedPane).toBe("layout");
  });

  it("applies an appearance at once and keeps it while it is being saved", async () => {
    const { store, send, calls } = harness();
    await store.load();
    store.setAppearance("dark");
    expect(store.getSnapshot().state?.appearance.mode).toBe("dark");
    expect(calls[0]).toMatchObject({
      method: "shell.setPreferences",
      params: { appearance: "dark" },
    });

    send({ appearance: { accent: "#ff9f0a", mode: "system" } });
    expect(store.getSnapshot().state?.appearance).toEqual({ accent: "#ff9f0a", mode: "dark" });

    calls[0]?.settle();
    await flush();
    send({ appearance: { accent: "#ff9f0a", mode: "light" } });
    expect(store.getSnapshot().state?.appearance.mode).toBe("light");
  });

  it("marks a service busy until its restart settles", async () => {
    const { store, calls } = harness();
    await store.load();
    const restart = store.restartService("skhd", "start");
    expect(store.getSnapshot().pending).toEqual({ skhd: "start" });
    expect(calls[0]).toMatchObject({
      method: "advanced.restartService",
      params: { daemon: "skhd" },
    });
    calls[0]?.settle();
    await restart;
    expect(store.getSnapshot().pending).toEqual({});
  });

  it("clears the busy mark and passes the reason on when a stop fails", async () => {
    const { store, calls } = harness();
    await store.load();
    const stop = store.stopService("yabai");
    expect(store.getSnapshot().pending).toEqual({ yabai: "stop" });
    calls[0]?.fail(new Error("launchctl refused"));
    await expect(stop).rejects.toThrow("launchctl refused");
    expect(store.getSnapshot().pending).toEqual({});
  });

  it("reports the outcome of restarting everything", async () => {
    const { store, calls } = harness();
    await store.load();
    const restart = store.restartAll();
    expect(store.getSnapshot().restartingAll).toBe(true);
    calls[0]?.settle({ outcome: "Restarted 3 of 4 services" });
    await expect(restart).resolves.toBe("Restarted 3 of 4 services");
    expect(store.getSnapshot().restartingAll).toBe(false);
  });

  it("asks the host to reveal settings and to quit", async () => {
    const { store, calls } = harness();
    await store.load();
    void store.revealSettings();
    void store.quit();
    expect(calls.map((call) => call.method)).toEqual(["shell.revealSettings", "shell.quit"]);
  });
});
