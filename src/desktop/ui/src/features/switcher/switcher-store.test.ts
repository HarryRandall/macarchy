import { describe, expect, it } from "vitest";

import { type BridgeHost, createBridge } from "~/bridge/client";
import type { SwitcherState, ThemeSummary } from "~/bridge/protocol";

import { createSwitcherStore } from "./switcher-store";

function theme(name: string, patch: Partial<ThemeSummary> = {}): ThemeSummary {
  return {
    name,
    title: name,
    isDark: true,
    ring: "#000000",
    colours: null,
    currentBackground: null,
    preview: null,
    backgrounds: [],
    ...patch,
  };
}

const data: SwitcherState = {
  current: "carbonfox",
  themes: [theme("awakening"), theme("carbonfox"), theme("lumon")],
};

/** The store's requests are not under test here. */
async function request(): Promise<never> {
  throw new Error("not connected");
}

/** The real bridge with a paint the test settles by hand, wired to a store. */
function setup() {
  const host: BridgeHost = {};
  const order: string[] = [];
  let painted!: () => void;
  const bridge = createBridge(host, {
    commit: (run) => {
      run();
      order.push("committed");
    },
    afterPaint: () =>
      new Promise<void>((resolve) => {
        painted = () => {
          order.push("painted");
          resolve();
        };
      }),
  });
  const store = createSwitcherStore({ request, subscribe: bridge.subscribe });
  bridge.start();
  const send = (event: unknown) => host.macarchyBridge?.receive(JSON.stringify(event));
  return { store, order, send, paint: () => painted() };
}

describe("switcher.didClose", () => {
  it("resets inside the handler, before the host's awaited paint", async () => {
    const { store, order, send, paint } = setup();
    const opened = send({ type: "switcher.willOpen", state: data });
    paint();
    await opened;

    store.dispatch({ type: "search", search: "lu" });
    store.dispatch({ type: "toggleActions" });
    const before = store.getSnapshot().generation;

    let seenAtCommit: unknown;
    store.subscribe(() => {
      if (!order.includes("committed")) seenAtCommit = store.getSnapshot().model?.ui;
    });
    order.length = 0;
    const closed = send({ type: "switcher.didClose" });

    // The reset is already in the snapshot when the commit returns, with
    // the paint still outstanding, so the frame the host waits for shows it.
    expect(closed).toBeInstanceOf(Promise);
    expect(order).toEqual(["committed"]);
    expect(seenAtCommit).toMatchObject({ search: "", actionsOpen: false });
    expect(store.getSnapshot().generation).toBe(before + 1);
    expect(store.getSnapshot().model?.ui).toMatchObject({
      search: "",
      actionsOpen: false,
      selection: "theme:carbonfox",
    });

    paint();
    await expect(closed).resolves.toBeUndefined();
    expect(order).toEqual(["committed", "painted"]);
  });

  it("is harmless before any state has arrived", async () => {
    const { store, send, paint } = setup();
    const closed = send({ type: "switcher.didClose" });
    expect(store.getSnapshot().model).toBeNull();
    paint();
    await closed;
  });
});

describe("switcher.willOpen after a failed action", () => {
  const failure = { title: "Could not apply Lumon", reason: "yabai is not running." };

  async function open(
    { send, paint }: ReturnType<typeof setup>,
    error: typeof failure | null,
  ): Promise<void> {
    const opened = send({ type: "switcher.willOpen", state: { ...data, error } });
    paint();
    await opened;
  }

  it("shows the failure apart from the themes and keeps it as themes change", async () => {
    const page = setup();
    await open(page, failure);
    expect(page.store.getSnapshot().model?.ui.failure).toEqual(failure);
    expect(page.store.getSnapshot().model?.data).toEqual(data);

    page.send({ type: "themes.changed", state: { ...data, current: "lumon" } });
    expect(page.store.getSnapshot().model?.ui.failure).toEqual(failure);
    expect(page.store.getSnapshot().model?.data.current).toBe("lumon");

    page.store.dispatch({ type: "dismissFailure" });
    expect(page.store.getSnapshot().model?.ui.failure).toBeNull();
  });

  it("is gone after closing and on the next open", async () => {
    const page = setup();
    await open(page, failure);
    const closed = page.send({ type: "switcher.didClose" });
    expect(page.store.getSnapshot().model?.ui.failure).toBeNull();
    page.paint();
    await closed;

    await open(page, failure);
    await open(page, null);
    expect(page.store.getSnapshot().model?.ui.failure).toBeNull();
  });
});

describe("null fields from the host", () => {
  it("opens with nothing applied and themes without colours or a preview", async () => {
    const { store, send, paint } = setup();
    const state: SwitcherState = {
      current: null,
      themes: [theme("lumon"), theme("awakening", { currentBackground: null })],
    };
    const opened = send({ type: "switcher.willOpen", state });
    paint();
    await opened;
    expect(store.getSnapshot().model?.ui.selection).toBe("theme:awakening");

    send({ type: "themes.changed", state: { ...state, current: null } });
    expect(store.getSnapshot().model?.ui.selection).toBe("theme:awakening");
  });
});
