import { describe, expect, it, vi } from "vitest";
import type { PageHost } from "~/shell/page";
import { createActivityStores, createServiceSwitches, type Service } from "./services-store";

const yabai: Service = { id: "yabai", name: "yabai", state: "running" };

function host(request: PageHost["request"]) {
  const handlers = new Map<string, () => void>();
  const subscribe = vi.fn<(type: string, handler: (event: never) => void) => () => void>(
    (type, handler) => {
      handlers.set(type, () => handler({ type } as never));
      return () => {};
    },
  );
  return {
    host: { request, subscribe: subscribe as unknown as PageHost["subscribe"] },
    emit: (type: string) => handlers.get(type)?.(),
  };
}

describe("createActivityStores", () => {
  it("reads the log and rereads it when the log changes", async () => {
    const request = vi.fn<PageHost["request"]>().mockResolvedValue({ entries: [] } as never);
    const { host: page, emit } = host(request);
    const { log } = createActivityStores(page);
    await log.load();
    expect(request).toHaveBeenLastCalledWith("shell.getLog");
    request.mockResolvedValueOnce({ entries: [{ id: "1" }] } as never);
    emit("shell.logChanged");
    await vi.waitFor(() => expect(log.getSnapshot().state).toHaveLength(1));
  });

  it("does not read before the page loads", () => {
    const request = vi.fn<PageHost["request"]>();
    const { emit, host: page } = host(request);
    createActivityStores(page);
    emit("shell.changed");
    emit("shell.logChanged");
    expect(request).not.toHaveBeenCalled();
  });
});

describe("createServiceSwitches", () => {
  it("stops a running service, then refreshes", async () => {
    const request = vi.fn<PageHost["request"]>().mockResolvedValue(null as never);
    const refresh = vi.fn<() => Promise<void>>(() => Promise.resolve());
    const switches = createServiceSwitches(host(request).host, refresh);
    const done = switches.setRunning(yabai, false);
    expect(switches.getSnapshot().pending).toEqual({ yabai: false });
    await done;
    expect(request).toHaveBeenCalledWith("advanced.stopService", { daemon: "yabai" });
    expect(refresh).toHaveBeenCalledOnce();
    expect(switches.getSnapshot()).toEqual({ pending: {}, error: null });
  });

  it("starts a service with a restart", async () => {
    const request = vi.fn<PageHost["request"]>().mockResolvedValue(null as never);
    const switches = createServiceSwitches(host(request).host, () => Promise.resolve());
    await switches.setRunning({ ...yabai, state: "stopped" }, true);
    expect(request).toHaveBeenCalledWith("advanced.restartService", { daemon: "yabai" });
  });

  it("ignores a second request while one is in flight", async () => {
    const request = vi.fn<PageHost["request"]>().mockResolvedValue(null as never);
    const switches = createServiceSwitches(host(request).host, () => Promise.resolve());
    const first = switches.setRunning(yabai, false);
    await switches.setRunning(yabai, true);
    await first;
    expect(request).toHaveBeenCalledOnce();
  });

  it("reports a failure and clears it on dismiss", async () => {
    const request = vi.fn<PageHost["request"]>().mockRejectedValue(new Error("No launch agent"));
    const switches = createServiceSwitches(host(request).host, () => Promise.resolve());
    await switches.setRunning(yabai, false);
    expect(switches.getSnapshot().error).toBe("Could not stop yabai. No launch agent");
    expect(switches.getSnapshot().pending).toEqual({});
    switches.dismiss();
    expect(switches.getSnapshot().error).toBeNull();
  });
});
