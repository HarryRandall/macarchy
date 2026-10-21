import { describe, expect, it, vi } from "vitest";
import type { BridgeEvent, ThemesState } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createThemesStore } from "./themes-store";

const state: ThemesState = {
  current: "lumon",
  colourschemes: [],
  warnings: [],
  themes: [
    {
      summary: {
        name: "lumon",
        title: "Lumon",
        isDark: true,
        ring: "#ffffff",
        colours: null,
        currentBackground: null,
        preview: null,
        backgrounds: [],
      },
      values: {
        dark: true,
        borderActive: "#ffffff",
        borderInactive: null,
        sketchybarBar: null,
        sketchybarText: null,
        firefoxAccent: null,
        nvimColorscheme: null,
      },
      modified: false,
      hasDefault: true,
      defaultColourscheme: "habamax",
      terminal: null,
    },
  ],
};
function setup(
  request = vi
    .fn<(...args: unknown[]) => Promise<ThemesState>>()
    .mockResolvedValue(structuredClone(state)),
) {
  let receive: (event: BridgeEvent) => void = vi.fn<(event: BridgeEvent) => void>();
  const host = {
    request,
    subscribe: (_type: string, handler: typeof receive) => {
      receive = handler;
      return () => {};
    },
  } as unknown as PageHost;
  return {
    store: createThemesStore(host),
    request,
    event: () => receive({ type: "themes.changed", state: { themes: [], current: "lumon" } }),
  };
}
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

describe("Themes store", () => {
  it("opening only reads and a failed first load shows failure rather than defaults", async () => {
    const { store, request } = setup(
      vi
        .fn<(...args: unknown[]) => Promise<ThemesState>>()
        .mockRejectedValue(new Error("broken settings")),
    );
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "broken settings",
    });
    request.mockResolvedValue(state);
    await store.load();
    expect(store.getSnapshot().status).toBe("ready");
    expect(request.mock.calls.map((call) => call[0])).toEqual([
      "themes.getState",
      "themes.getState",
    ]);
  });
  it("ignores a stale first read after an external refresh has completed", async () => {
    const old = deferred<ThemesState>();
    const request = vi
      .fn<(...args: unknown[]) => Promise<ThemesState>>()
      .mockReturnValueOnce(old.promise)
      .mockResolvedValue({ ...state, current: "newer" });
    const { store, event } = setup(request);
    const loading = store.load();
    event();
    await vi.waitFor(() => expect(store.getSnapshot().state?.current).toBe("newer"));
    old.resolve(state);
    await loading;
    expect(store.getSnapshot().state?.current).toBe("newer");
  });

  it("serialises fields and protects newer input from external reads and earlier replies", async () => {
    const { store, request, event } = setup();
    await store.load();
    const first = deferred<ThemesState>();
    request.mockImplementation((method: unknown) =>
      method === "themes.setColour" ? first.promise : Promise.resolve(state),
    );
    const a = store.edit("lumon", "borderActive", "#123456");
    const b = store.edit("lumon", "borderActive", "#abcdef");
    event();
    await Promise.resolve();
    expect(store.getSnapshot().state?.themes[0]?.values.borderActive).toBe("#abcdef");
    expect(request.mock.calls.filter((call) => call[0] === "themes.setColour")).toHaveLength(1);
    request.mockResolvedValue(state);
    first.resolve(state);
    await Promise.all([a, b]);
    expect(
      request.mock.calls.filter((call) => call[0] === "themes.setColour").map((call) => call[1]),
    ).toEqual([
      { theme: "lumon", colour: "borderActive", value: "#123456" },
      { theme: "lumon", colour: "borderActive", value: "#abcdef" },
    ]);
  });
  it("previews a dragged colour locally and saves it once when the drag settles", async () => {
    const { store, request, event } = setup();
    await store.load();
    const writes = () => request.mock.calls.filter((call) => call[0] === "themes.setColour");
    for (const value of ["#111111", "#222222", "#333333"]) {
      store.preview("lumon", "borderActive", value);
    }
    expect(writes()).toHaveLength(0);
    expect(store.getSnapshot().state?.themes[0]?.values.borderActive).toBe("#333333");
    request.mockResolvedValueOnce({ ...state, current: "another" });
    event();
    await vi.waitFor(() => expect(store.getSnapshot().state?.current).toBe("another"));
    expect(store.getSnapshot().state?.themes[0]?.values.borderActive).toBe("#333333");

    await store.commit("lumon", "borderActive", "#333333");
    expect(writes().map((call) => call[1])).toEqual([
      { theme: "lumon", colour: "borderActive", value: "#333333" },
    ]);
  });
  it("commits nothing when a drag ends on the saved colour", async () => {
    const { store, request } = setup();
    await store.load();
    store.preview("lumon", "borderActive", "#123456");
    await store.commit("lumon", "borderActive", "#ffffff");
    expect(request.mock.calls.map((call) => call[0])).toEqual(["themes.getState"]);
    expect(store.getSnapshot().state?.themes[0]?.values.borderActive).toBe("#ffffff");
  });
  it("rejects a failed reset so its confirmation can show why", async () => {
    const { store, request } = setup();
    await store.load();
    request.mockRejectedValueOnce(new Error("No shipped default for lumon"));
    await expect(store.reset("lumon")).rejects.toThrow("No shipped default for lumon");
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: "No shipped default for lumon",
    });
  });
  it("keeps failures visible, reconciles rejected edits and accepts external changes", async () => {
    const { store, request, event } = setup();
    await store.load();
    request.mockImplementation((method: unknown) =>
      method === "themes.setDark" ? Promise.reject(new Error("read only")) : Promise.resolve(state),
    );
    await store.edit("lumon", "dark", false);
    expect(store.getSnapshot().error).toBe("read only");
    expect(store.getSnapshot().state?.themes[0]?.values.dark).toBe(true);
    request.mockResolvedValue({ ...state, current: "another" });
    event();
    await vi.waitFor(() => expect(store.getSnapshot().state?.current).toBe("another"));
  });
  it("uses named actions and sends null for the default colourscheme", async () => {
    const { store, request } = setup();
    await store.load();
    await store.edit("lumon", "nvimColorscheme", null);
    await store.apply("lumon");
    await store.choose("lumon", "backgrounds/a.png");
    await store.reset("lumon");
    await store.importFolder();
    await store.exportFolder("lumon");
    await store.reveal("lumon");
    expect(request).toHaveBeenCalledWith("themes.setColourscheme", { theme: "lumon", value: null });
    expect(request.mock.calls.map((call) => call[0])).toEqual([
      "themes.getState",
      "themes.setColourscheme",
      "themes.getState",
      "themes.apply",
      "themes.chooseWallpaper",
      "themes.reset",
      "themes.importFolder",
      "themes.exportFolder",
      "themes.reveal",
    ]);
  });
});
