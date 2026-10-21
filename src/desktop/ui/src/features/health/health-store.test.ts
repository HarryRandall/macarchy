import { expect, it, vi } from "vitest";
import type { PageHost } from "~/shell/page";
import { createHealthStore } from "./health-store";

it("refreshes health after native changes and names native fix and reveal operations", async () => {
  const request = vi.fn<PageHost["request"]>().mockResolvedValue({ checks: [] } as never);
  let changed: (() => void) | undefined;
  const subscribe = vi.fn<PageHost["subscribe"]>().mockImplementation((_type, handler) => {
    changed = () => handler({ type: "health.changed" } as never);
    return () => {};
  });
  const store = createHealthStore({ request, subscribe: subscribe as PageHost["subscribe"] });
  await store.load();
  expect(request).toHaveBeenLastCalledWith("health.getState");
  changed?.();
  await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(2));
  await store.copyFix("Dependencies/skhd");
  expect(request).toHaveBeenLastCalledWith("health.copyFix", { id: "Dependencies/skhd" });
  await store.reveal();
  expect(request).toHaveBeenLastCalledWith("health.revealSettings");
  request.mockRejectedValueOnce(new Error("Clipboard unavailable"));
  await store.copyFix("Dependencies/skhd");
  expect(store.getSnapshot().error).toBe("Clipboard unavailable");
});
