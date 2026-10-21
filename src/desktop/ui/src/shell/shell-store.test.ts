import { describe, expect, it } from "vitest";

import type { BridgeEvent, ShellState } from "~/bridge/protocol";

import { createShellStore } from "./shell-store";

const state: ShellState = {
  selectedPane: "layout",
  sidebarVisible: true,
  setupRequired: false,
  appearance: { accent: "#0a84ff" },
  services: { running: 4, total: 4 },
};

function harness() {
  let handler: ((event: Extract<BridgeEvent, { type: "shell.changed" }>) => void) | null = null;
  let settle: (() => void) | null = null;
  const store = createShellStore({
    request: ((method: string) => {
      if (method === "shell.getState") return Promise.resolve(state);
      return new Promise<null>((resolve) => {
        settle = () => resolve(null);
      });
    }) as never,
    subscribe: (_type, next) => {
      handler = next;
      return () => {};
    },
  });
  return {
    store,
    send: (selectedPane: ShellState["selectedPane"]) =>
      handler?.({ type: "shell.changed", state: { ...state, selectedPane } }),
    settle: () => settle?.(),
  };
}

describe("shell store", () => {
  it("keeps a click while its selection is being saved", async () => {
    const { store, send, settle } = harness();
    await store.load();
    store.selectPane("rules");
    // Sent by the host before it saw the request.
    send("layout");
    expect(store.getSnapshot().state?.selectedPane).toBe("rules");

    settle();
    await Promise.resolve();
    await Promise.resolve();
    // Once saved, the host's word is final again.
    send("layout");
    expect(store.getSnapshot().state?.selectedPane).toBe("layout");
  });
});
