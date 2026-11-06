import { expect, it, vi } from "vitest";
import type { PageHost } from "~/shell/page";
import { createHomeStore } from "./home-store";

it("reads only its own core summary and reloads on native invalidation", async () => {
  const request = vi.fn<PageHost["request"]>().mockResolvedValue({ theme: "lumon" } as never);
  let changed: (() => void) | undefined;
  const subscribe = vi.fn<PageHost["subscribe"]>().mockImplementation((_type, handler) => {
    changed = () => handler({ type: "home.changed" } as never);
    return () => {};
  });
  const store = createHomeStore({ request, subscribe: subscribe as PageHost["subscribe"] });
  expect(subscribe).toHaveBeenCalledWith("home.changed", expect.any(Function));
  expect(request).not.toHaveBeenCalled();
  await store.load();
  expect(request).toHaveBeenLastCalledWith("home.getState");
  request.mockResolvedValueOnce({ theme: "tokyo-night" } as never);
  changed?.();
  await vi.waitFor(() => expect(store.getSnapshot().state?.theme).toBe("tokyo-night"));
  expect(request).toHaveBeenCalledTimes(2);
});
