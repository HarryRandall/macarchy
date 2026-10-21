import { describe, expect, it } from "vitest";

import { shortcutFor } from "./shortcuts";

type Modifier = "meta" | "ctrl" | "alt" | "shift";

const press = (key: string, modifiers: Partial<Record<Modifier, boolean>> = {}) =>
  shortcutFor({
    key,
    metaKey: modifiers.meta ?? true,
    ctrlKey: modifiers.ctrl ?? false,
    altKey: modifiers.alt ?? false,
    shiftKey: modifiers.shift ?? false,
  });

describe("shortcutFor", () => {
  it.each([
    ["k", "palette"],
    ["\\", "sidebar"],
    ["[", "back"],
    ["]", "forward"],
    ["/", "shortcuts"],
  ] as const)("reads ⌘%s as %s", (key, shortcut) => {
    expect(press(key)).toBe(shortcut);
  });

  it.each([
    ["L", "logs"],
    ["R", "reload"],
    ["O", "folder"],
  ] as const)("reads ⇧⌘%s as %s", (key, shortcut) => {
    expect(press(key, { shift: true })).toBe(shortcut);
  });

  it("keeps ⌃⌘S for the sidebar", () => {
    expect(press("s", { ctrl: true })).toBe("sidebar");
    expect(press("k", { ctrl: true })).toBeNull();
  });

  it("ignores presses without ⌘, with ⌥, or with the wrong shift", () => {
    expect(press("k", { meta: false, ctrl: true })).toBeNull();
    expect(press("k", { alt: true })).toBeNull();
    expect(press("l")).toBeNull();
    expect(press("k", { shift: true })).toBeNull();
  });
});
