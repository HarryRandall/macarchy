import { describe, expect, it, vi } from "vitest";

import { createSignal } from "./signal";

describe("signal", () => {
  it("calls the latest listener and forgets it once unsubscribed", () => {
    const signal = createSignal();
    const first = vi.fn<() => void>();
    const second = vi.fn<() => void>();
    signal.emit();
    const stopFirst = signal.listen(first);
    const stopSecond = signal.listen(second);
    signal.emit();
    expect(first).not.toHaveBeenCalled();
    expect(second).toHaveBeenCalledOnce();
    stopFirst();
    signal.emit();
    expect(second).toHaveBeenCalledTimes(2);
    stopSecond();
    signal.emit();
    expect(second).toHaveBeenCalledTimes(2);
  });
});
