import { describe, expect, it, vi } from "vitest";

import type { BridgeEvent, ThemesState } from "~/bridge/protocol";

import { createWorkshopStore } from "./workshop-store";

const ignore: Changed = () => {};

type Changed = (event: Extract<BridgeEvent, { type: "themes.changed" }>) => void;

function state(current: string | null): ThemesState {
  return { themes: [], current, colourschemes: [], warnings: [] };
}

describe("createWorkshopStore", () => {
  it("is ready with nothing installed when the themes cannot be read", async () => {
    const store = createWorkshopStore({
      getThemes: vi.fn<() => Promise<ThemesState>>().mockRejectedValue(new Error("offline")),
      subscribe: () => () => {},
    });
    await store.load();
    expect(store.getSnapshot()).toEqual({
      status: "ready",
      installed: [],
      current: null,
      error: "offline",
    });
  });

  it("reads again when the themes change, keeping what it had on failure", async () => {
    let changed: Changed = ignore;
    const getThemes = vi
      .fn<() => Promise<ThemesState>>()
      .mockResolvedValueOnce(state("lumon"))
      .mockResolvedValueOnce(state("nord"))
      .mockRejectedValueOnce(new Error("busy"));
    const store = createWorkshopStore({
      getThemes,
      subscribe: (_type, handler) => {
        changed = handler;
        return () => {};
      },
    });

    changed({ type: "themes.changed", state: { themes: [], current: "nord" } });
    expect(getThemes).not.toHaveBeenCalled();

    await store.load();
    expect(store.getSnapshot()).toMatchObject({ current: "lumon", error: null });

    changed({ type: "themes.changed", state: { themes: [], current: "nord" } });
    await vi.waitFor(() => expect(store.getSnapshot().current).toBe("nord"));

    changed({ type: "themes.changed", state: { themes: [], current: "nord" } });
    await vi.waitFor(() => expect(store.getSnapshot().error).toBe("busy"));
    expect(store.getSnapshot().current).toBe("nord");
  });
});
