import { describe, expect, it, vi } from "vitest";

import { BridgeError, type BridgeHost, createBridge, parseReply } from "./client";
import type { BridgeEvent, SwitcherState } from "./protocol";

function hostReplying(reply: unknown) {
  const postMessage = vi.fn<(message: unknown) => Promise<string>>(async () => reply as string);
  const host: BridgeHost = { webkit: { messageHandlers: { macarchy: { postMessage } } } };
  return { host, postMessage };
}

const switcherState: SwitcherState = { themes: [], current: null };

describe("parseReply", () => {
  it("returns the value of a successful reply", () => {
    expect(parseReply(JSON.stringify({ ok: true, value: { a: 1 } }))).toEqual({ a: 1 });
    expect(parseReply(JSON.stringify({ ok: true, value: null }))).toBeNull();
  });

  it("throws a BridgeError carrying the host's code and message", () => {
    const raw = JSON.stringify({
      ok: false,
      error: { code: "operation_failed", message: "yabai said no." },
    });
    expect(() => parseReply(raw)).toThrowError(BridgeError);
    expect(() => parseReply(raw)).toThrowError(
      expect.objectContaining({ code: "operation_failed", message: "yabai said no." }),
    );
  });

  it.each([
    ["text that is not JSON", "not json {"],
    ["JSON without an ok flag", JSON.stringify({ value: 1 })],
    ["a bare number", "42"],
  ])("maps %s to an internal error", (_label, raw) => {
    expect(() => parseReply(raw)).toThrowError(expect.objectContaining({ code: "internal" }));
  });

  it("maps an unknown error code to internal but keeps the message", () => {
    const raw = JSON.stringify({
      ok: false,
      error: { code: "teapot", message: "Short and stout." },
    });
    expect(() => parseReply(raw)).toThrowError(
      expect.objectContaining({ code: "internal", message: "Short and stout." }),
    );
  });
});

describe("request", () => {
  it("posts the method and params and resolves with the value", async () => {
    const { host, postMessage } = hostReplying(JSON.stringify({ ok: true, value: null }));
    const bridge = createBridge(host);
    await expect(
      bridge.request("shell.setPreferences", { sidebarVisible: false }),
    ).resolves.toBeNull();
    expect(postMessage).toHaveBeenCalledWith({
      method: "shell.setPreferences",
      params: { sidebarVisible: false },
    });
  });

  it("sends empty params when a method takes none", async () => {
    const { host, postMessage } = hostReplying(JSON.stringify({ ok: true, value: switcherState }));
    await createBridge(host).request("switcher.getState");
    expect(postMessage).toHaveBeenCalledWith({ method: "switcher.getState", params: {} });
  });

  it("rejects with the host's error", async () => {
    const { host } = hostReplying(
      JSON.stringify({
        ok: false,
        error: { code: "unavailable", message: "yabai is not running." },
      }),
    );
    await expect(createBridge(host).request("layout.getState")).rejects.toMatchObject({
      code: "unavailable",
      message: "yabai is not running.",
    });
  });

  it("maps a rejected postMessage to internal", async () => {
    const postMessage = vi.fn<(message: unknown) => Promise<string>>(async () => {
      throw new Error("reply handler failed");
    });
    const bridge = createBridge({ webkit: { messageHandlers: { macarchy: { postMessage } } } });
    await expect(bridge.request("layout.getState")).rejects.toMatchObject({
      code: "internal",
      message: "reply handler failed",
    });
  });

  it("rejects as unavailable without a message handler", async () => {
    await expect(createBridge({}).request("layout.getState")).rejects.toMatchObject({
      code: "unavailable",
    });
  });
});

describe("events", () => {
  const changed: BridgeEvent = {
    type: "themes.changed",
    state: { themes: [], current: "lumon" },
  };

  it("drains events queued before start, in order, then takes over receive", () => {
    const host: BridgeHost = {
      macarchyBridge: {
        queue: [JSON.stringify(changed), JSON.stringify({ type: "switcher.didClose" })],
        receive: () => undefined,
      },
    };
    const bridge = createBridge(host);
    const seen: string[] = [];
    bridge.subscribe("themes.changed", (event) => seen.push(`changed:${event.state.current}`));
    bridge.subscribe("switcher.didClose", () => seen.push("closed"));

    bridge.start();
    expect(seen).toEqual(["changed:lumon", "closed"]);
    expect(host.macarchyBridge?.queue).toEqual([]);

    host.macarchyBridge?.receive(JSON.stringify({ type: "switcher.didClose" }));
    expect(seen).toEqual(["changed:lumon", "closed", "closed"]);
  });

  it("creates the sink when the host has not", () => {
    const host: BridgeHost = {};
    createBridge(host).start();
    expect(host.macarchyBridge?.queue).toEqual([]);
  });

  it("ignores unreadable events without throwing", () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const bridge = createBridge({});
    expect(bridge.receive("{oops")).toBeUndefined();
    expect(bridge.receive(JSON.stringify({ nope: true }))).toBeUndefined();
    error.mockRestore();
  });

  it("stops delivering after unsubscribe", () => {
    const bridge = createBridge({});
    const handler = vi.fn<() => void>();
    const unsubscribe = bridge.subscribe("themes.changed", handler);
    unsubscribe();
    bridge.receive(JSON.stringify(changed));
    expect(handler).not.toHaveBeenCalled();
  });

  it("returns nothing for ordinary events", () => {
    const bridge = createBridge({});
    expect(bridge.receive(JSON.stringify(changed))).toBeUndefined();
  });
});

describe("switcher.willOpen", () => {
  it("commits handlers synchronously and resolves only after paint", async () => {
    const order: string[] = [];
    let painted!: () => void;
    const bridge = createBridge(
      {},
      {
        commit: (run) => {
          order.push("commit:start");
          run();
          order.push("commit:end");
        },
        afterPaint: () =>
          new Promise<void>((resolve) => {
            painted = () => {
              order.push("painted");
              resolve();
            };
          }),
      },
    );
    bridge.subscribe("switcher.willOpen", () => order.push("handler"));

    const result = bridge.receive(
      JSON.stringify({ type: "switcher.willOpen", state: switcherState }),
    );
    expect(result).toBeInstanceOf(Promise);
    expect(order).toEqual(["commit:start", "handler", "commit:end"]);

    let settled = false;
    void result?.then(() => (settled = true));
    await Promise.resolve();
    expect(settled).toBe(false);

    painted();
    await result;
    expect(settled).toBe(true);
    expect(order.at(-1)).toBe("painted");
  });

  it("waits for paint on didClose too, but not for other events", async () => {
    let paints = 0;
    const bridge = createBridge(
      {},
      {
        afterPaint: () => {
          paints += 1;
          return Promise.resolve();
        },
      },
    );
    await bridge.receive(JSON.stringify({ type: "switcher.didClose" }));
    expect(paints).toBe(1);
    expect(
      bridge.receive(JSON.stringify({ type: "themes.changed", state: switcherState })),
    ).toBeUndefined();
    expect(paints).toBe(1);
  });

  it("still resolves when a handler throws", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const bridge = createBridge({});
    bridge.subscribe("switcher.willOpen", () => {
      throw new Error("boom");
    });
    await expect(
      bridge.receive(JSON.stringify({ type: "switcher.willOpen", state: switcherState })),
    ).resolves.toBeUndefined();
    error.mockRestore();
  });
});
