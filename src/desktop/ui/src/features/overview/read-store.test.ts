import { describe, expect, it, vi } from "vitest";
import { createReadStore } from "./read-store";

const deferred = <T>() => {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
};

describe("overview reads", () => {
  it("does not read until shown and coalesces invalidations without concurrent checks", async () => {
    const first = deferred<number>();
    const read = vi
      .fn<() => Promise<number>>()
      .mockReturnValueOnce(first.promise)
      .mockResolvedValue(2);
    const store = createReadStore<number>(read);
    store.invalidate();
    expect(read).not.toHaveBeenCalled();
    const loading = store.load();
    store.invalidate();
    store.invalidate();
    expect(read).toHaveBeenCalledTimes(1);
    first.resolve(1);
    await loading;
    expect(read).toHaveBeenCalledTimes(2);
    expect(store.getSnapshot()).toMatchObject({ status: "ready", state: 2, refreshing: false });
  });
  it("shows first read errors and retains real state during later failures", async () => {
    const read = vi
      .fn<() => Promise<number>>()
      .mockRejectedValueOnce(new Error("Cannot read settings"))
      .mockResolvedValueOnce(7)
      .mockRejectedValue(new Error("Disconnected"));
    const store = createReadStore<number>(read);
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "Cannot read settings",
    });
    await store.load();
    expect(store.getSnapshot()).toMatchObject({ status: "ready", state: 7, error: null });
    await store.load();
    expect(store.getSnapshot()).toMatchObject({ status: "ready", state: 7, error: "Disconnected" });
    expect(await store.action(() => Promise.reject(new Error("Clipboard unavailable")))).toBe(
      false,
    );
    expect(store.getSnapshot().error).toBe("Clipboard unavailable");
  });
});
