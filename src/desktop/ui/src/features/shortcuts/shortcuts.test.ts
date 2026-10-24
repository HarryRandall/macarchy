import { describe, expect, it, vi } from "vitest";

import { createBridge, type BridgeHost } from "~/bridge/client";
import type { ShortcutBinding, ShortcutsState } from "~/bridge/protocol";

import {
  emptyFilters,
  filterBindings,
  recordedChord,
  shortcutLabel,
} from "./shortcut-presentation";
import { createShortcutsStore } from "./shortcuts-store";

function binding(patch: Partial<ShortcutBinding> = {}): ShortcutBinding {
  return {
    id: 1,
    modifiers: ["ctrl"],
    key: "h",
    caps: ["⌃", "H"],
    section: null,
    command: "echo custom",
    passthrough: false,
    appOverrides: [],
    modes: [],
    activatesMode: null,
    disabled: false,
    ...patch,
  };
}
function fixture() {
  const initial: ShortcutsState = { revision: "one", bindings: [binding()] };
  const send = vi.fn<(method: string, params: unknown) => Promise<unknown>>(async (method) => {
    if (method === "shortcuts.getState") return initial;
    if (method === "shortcuts.validate")
      return { caps: ["⌘", "K"], spec: "cmd - k", conflicts: [] };
    return { state: { ...initial, revision: "two" }, warning: "" };
  });
  const host: BridgeHost = {
    webkit: {
      messageHandlers: {
        macarchy: {
          postMessage: async (message) => {
            const { method, params } = message as { method: string; params: unknown };
            return JSON.stringify({ ok: true, value: await send(method, params) });
          },
        },
      },
    },
  };
  const bridge = createBridge(host);
  bridge.start();
  const store = createShortcutsStore(bridge);
  return {
    store,
    send,
    initial,
    emit(state: ShortcutsState) {
      host.macarchyBridge!.receive(JSON.stringify({ type: "shortcuts.changed", state }));
    },
    unavailable(message: string) {
      host.macarchyBridge!.receive(
        JSON.stringify({ type: "shortcuts.unavailable", state: message }),
      );
    },
  };
}
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

describe("shortcut presentation", () => {
  it("ports all four Swift presentation tests", () => {
    const single = binding({ section: "Launch terminal", command: "open -a Ghostty" });
    expect(shortcutLabel(single, [single])).toBe("Launch terminal");
    const left = binding({ section: "Focus windows", command: "yabai -m window --focus west" });
    const right = binding({
      id: 2,
      section: "Focus windows",
      command: "yabai -m window --focus east",
    });
    expect(shortcutLabel(left, [left, right])).toBe("Focus left");
    expect(shortcutLabel(right, [left, right])).toBe("Focus right");
    for (const command of [
      "echo 'Spotify' && do_something_else",
      "yabai -m window --focus west; echo done",
    ]) {
      const custom = binding({ command });
      expect(shortcutLabel(custom, [custom])).toBe(command);
    }
  });
  it("preserves workspace, swap, media and per-app labels", () => {
    for (const [command, expected] of [
      ["yabai -m window --swap north; yabai -m window --focus north", "Swap up and follow"],
      ["yabai -m space --focus 20", "Switch to workspace 20"],
      ["yabai -m window --space 2", "Move to workspace 2"],
      ["yabai -m window --space 3; yabai -m space --focus 3", "Move to workspace 3 and follow"],
      [
        "/usr/bin/pgrep -x Spotify >/dev/null && /usr/bin/osascript -e 'tell application \"Spotify\" to playpause'",
        "Play or pause Spotify",
      ],
    ]) {
      const item = binding({ command });
      expect(shortcutLabel(item, [item])).toBe(expected);
    }
    const item = binding({
      command: "",
      appOverrides: [{ app: "Finder", command: "echo finder" }],
    });
    expect(shortcutLabel(item, [item])).toBe("Per-app action");
  });

  it("says which skhd mode a binding works in or switches to", () => {
    const enter = binding({ command: "", activatesMode: "resize" });
    const inMode = binding({ id: 2, command: "yabai -m window --focus west", modes: ["resize"] });
    expect(shortcutLabel(enter, [enter, inMode])).toBe("Switch to resize mode");
    expect(shortcutLabel(inMode, [enter, inMode])).toBe("Focus left (resize mode)");
  });
  it("filters source groups, scopes, modifier suffixes, keys and commands", () => {
    const all = [
      binding(),
      binding({
        id: 2,
        section: "Finder actions",
        modifiers: ["lcmd", "shift"],
        command: "echo finder",
        appOverrides: [{ app: "Finder", command: "echo finder" }],
      }),
    ];
    expect(
      filterBindings(all, {
        ...emptyFilters,
        modifiers: ["cmd"],
        scope: "perApp",
        search: "finder",
      }),
    ).toEqual([all[1]]);
    expect(filterBindings(all, { ...emptyFilters, scope: "global" })).toEqual([all[0]]);
    expect(filterBindings(all, { ...emptyFilters, section: "missing" })).toEqual([]);
    const off = binding({ id: 3, disabled: true });
    expect(filterBindings([...all, off], { ...emptyFilters, scope: "disabled" })).toEqual([off]);
    expect(filterBindings([...all, off], { ...emptyFilters, scope: "global" })).toEqual([all[0]]);
    expect(filterBindings([...all, off], emptyFilters)).toHaveLength(3);
  });
});

describe("recording", () => {
  it("uses physical keys with Option and Shift and ignores modifiers, repeats and IME", () => {
    const event = {
      code: "KeyK",
      metaKey: true,
      ctrlKey: false,
      altKey: false,
      shiftKey: false,
      repeat: false,
      isComposing: false,
    };
    expect(recordedChord(event)).toEqual({ modifiers: ["cmd"], key: "k" });
    expect(recordedChord({ ...event, code: "Equal", altKey: true, shiftKey: true })).toEqual({
      modifiers: ["alt", "shift", "cmd"],
      key: "0x18",
    });
    expect(recordedChord({ ...event, code: "AltLeft" })).toBeNull();
    expect(recordedChord({ ...event, repeat: true })).toBeNull();
    expect(recordedChord({ ...event, isComposing: true })).toBeNull();
    expect(recordedChord({ ...event, code: "ArrowLeft" })?.key).toBe("left");
    expect(recordedChord({ ...event, code: "Backspace" })?.key).toBe("backspace");
    expect(recordedChord({ ...event, code: "Numpad1" })?.key).toBe("0x53");
  });
});

describe("shortcuts store", () => {
  it("opening is read-only and a failed load never displays defaults", async () => {
    const { store, send } = fixture();
    send.mockRejectedValueOnce(new Error("Unreadable skhdrc"));
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "Unreadable skhdrc",
    });
    await store.load();
    expect(store.getSnapshot().status).toBe("ready");
    expect(send.mock.calls.map(([method]) => method)).toEqual([
      "shortcuts.getState",
      "shortcuts.getState",
    ]);
  });
  it("validates before saving and sends the loaded revision", async () => {
    const { store, send, initial } = fixture();
    await store.load();
    store.edit(initial.bindings[0]!);
    const chord = { modifiers: ["cmd"], key: "k" };
    expect(await store.save()).toBe(false);
    await store.record(chord);
    expect(await store.save()).toBe(true);
    expect(send).toHaveBeenLastCalledWith("shortcuts.rebind", { id: 1, revision: "one", chord });
    expect(store.getSnapshot().draft).toBeNull();
  });
  it("keeps recordings across external events and blocks stale edits", async () => {
    const { store, initial, emit, send } = fixture();
    await store.load();
    store.edit(initial.bindings[0]!);
    await store.record({ modifiers: ["cmd"], key: "k" });
    emit({ ...initial, revision: "external" });
    expect(store.getSnapshot()).toMatchObject({
      external: true,
      draft: { revision: "one", chord: { key: "k" } },
      state: { revision: "external" },
    });
    expect(await store.save()).toBe(false);
    expect(await store.disable()).toBe(false);
    expect(send.mock.calls.map(([method]) => method)).toEqual([
      "shortcuts.getState",
      "shortcuts.validate",
    ]);
  });
  it("ignores stale validation replies and stops conflicts reaching rebind", async () => {
    const { store, initial, send } = fixture();
    await store.load();
    store.edit(initial.bindings[0]!);
    const pending = deferred<unknown>();
    send.mockReturnValueOnce(pending.promise);
    const first = store.record({ modifiers: ["cmd"], key: "j" });
    send.mockResolvedValueOnce({ caps: ["⌘", "K"], spec: "cmd - k", conflicts: [2] });
    await store.record({ modifiers: ["cmd"], key: "k" });
    pending.resolve({ caps: ["⌘", "J"], spec: "cmd - j", conflicts: [] });
    await first;
    expect(store.getSnapshot().draft?.validation?.conflicts).toEqual([2]);
    expect(await store.save()).toBe(false);
  });
  it("preserves failed edits and reports partial application", async () => {
    const { store, initial, send } = fixture();
    await store.load();
    store.edit(initial.bindings[0]!);
    await store.record({ modifiers: ["cmd"], key: "k" });
    send.mockRejectedValueOnce(new Error("Disk full"));
    expect(await store.save()).toBe(false);
    expect(store.getSnapshot()).toMatchObject({
      error: "Disk full",
      draft: { chord: { key: "k" } },
      state: { revision: "one" },
    });
    send.mockResolvedValueOnce({
      state: { ...initial, revision: "saved" },
      warning: "Saved, but skhd could not restart.",
    });
    expect(await store.save()).toBe(true);
    expect(store.getSnapshot()).toMatchObject({
      draft: null,
      warning: "Saved, but skhd could not restart.",
    });
  });
  it("uses named disable and reset operations and surfaces reset failures", async () => {
    const { store, initial, send } = fixture();
    await store.load();
    store.edit(initial.bindings[0]!);
    expect(await store.disable()).toBe(true);
    expect(send).toHaveBeenLastCalledWith("shortcuts.disable", { id: 1, revision: "one" });
    send.mockRejectedValueOnce(new Error("Snapshot failed"));
    await expect(store.reset("two")).rejects.toThrow("Snapshot failed");
    expect(send).toHaveBeenLastCalledWith("shortcuts.reset", { revision: "two" });
  });

  it("enables only a disabled binding, against the revision on screen, and never edits it", async () => {
    const { store, initial, send } = fixture();
    await store.load();
    const off = binding({ id: 2, disabled: true });
    store.edit(off);
    expect(store.getSnapshot().draft).toBeNull();
    expect(await store.enable(initial.bindings[0]!)).toBe(false);
    expect(await store.enable(off)).toBe(true);
    expect(send).toHaveBeenLastCalledWith("shortcuts.enable", { id: 2, revision: "one" });
    const clash = 'ctrl + alt - h is now used by "Open notes".';
    send.mockRejectedValueOnce(new Error(clash));
    expect(await store.enable(off)).toBe(false);
    expect(store.getSnapshot()).toMatchObject({ error: clash, busy: false });
  });
  it("clears a transient read error on fresh state but keeps a failed edit", async () => {
    const { store, initial, send, emit, unavailable } = fixture();
    await store.load();
    unavailable("Your shortcuts could not be read: permission denied");
    expect(store.getSnapshot()).toMatchObject({
      status: "ready",
      error: "Your shortcuts could not be read: permission denied",
    });
    emit({ ...initial, revision: "recovered" });
    expect(store.getSnapshot()).toMatchObject({ error: null, state: { revision: "recovered" } });

    store.edit(initial.bindings[0]!);
    await store.record({ modifiers: ["cmd"], key: "k" });
    send.mockRejectedValueOnce(new Error("Disk full"));
    expect(await store.save()).toBe(false);
    emit({ ...initial, revision: "recovered" });
    expect(store.getSnapshot().error).toBe("Disk full");
  });
  it("does not let an old refresh overwrite an external event", async () => {
    const { store, initial, send, emit } = fixture();
    const pending = deferred<unknown>();
    send.mockReturnValueOnce(pending.promise);
    const loading = store.load();
    emit({ ...initial, revision: "external" });
    pending.resolve(initial);
    await loading;
    expect(store.getSnapshot().state?.revision).toBe("external");
  });
});
