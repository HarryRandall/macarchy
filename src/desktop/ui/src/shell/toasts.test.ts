import { afterEach, describe, expect, it, vi } from "vitest";

import { createToasts } from "./toasts";

const messages = (toasts: ReturnType<typeof createToasts>) =>
  toasts.getSnapshot().map((toast) => toast.message);

describe("toasts", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("dismisses each toast after its tone's duration", () => {
    vi.useFakeTimers();
    const toasts = createToasts();
    toasts.push("yabai restarted");
    toasts.push("borders could not restart", "danger");
    vi.advanceTimersByTime(2600);
    expect(messages(toasts)).toEqual(["borders could not restart"]);
    vi.advanceTimersByTime(3400);
    expect(messages(toasts)).toEqual([]);
  });

  it("keeps the three newest", () => {
    vi.useFakeTimers();
    const toasts = createToasts();
    for (const message of ["one", "two", "three", "four"]) toasts.push(message);
    expect(messages(toasts)).toEqual(["two", "three", "four"]);
  });

  it("removes a toast dismissed by hand and forgets its timer", () => {
    vi.useFakeTimers();
    const toasts = createToasts();
    toasts.push("Copied 4 lines");
    const [toast] = toasts.getSnapshot();
    if (toast) toasts.dismiss(toast.id);
    expect(messages(toasts)).toEqual([]);
    expect(vi.getTimerCount()).toBe(0);
  });
});
