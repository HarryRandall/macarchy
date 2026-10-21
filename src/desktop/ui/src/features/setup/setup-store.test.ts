import { describe, expect, it, vi } from "vitest";
import type { SetupState } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createSetupStore } from "./setup-store";

const plan: SetupState = {
  tools: [],
  changes: [{ path: "~/yabairc", action: "adopt", detail: "Kept" }],
  hasExisting: true,
  canClose: false,
};
function harness() {
  const request = vi.fn<(...args: unknown[]) => Promise<unknown>>().mockResolvedValue(plan);
  return { request, store: createSetupStore({ request } as unknown as PageHost) };
}
describe("Setup store", () => {
  it("reads a plan before enabling setup and starts with keep mine", async () => {
    const { store, request } = harness();
    await store.run();
    expect(request).not.toHaveBeenCalled();
    await store.load();
    expect(request.mock.calls).toEqual([["setup.getPlan", { existing: "keep" }]]);
  });
  it("blocks setup until the changed choice has a matching plan", async () => {
    const { store, request } = harness();
    await store.load();
    let resolve!: (state: SetupState) => void;
    request.mockImplementationOnce(
      () =>
        new Promise<SetupState>((done) => {
          resolve = done;
        }),
    );
    store.choose("replace");
    await store.run();
    expect(request.mock.calls).toHaveLength(2);
    resolve(plan);
    await Promise.resolve();
    request.mockResolvedValueOnce({ lines: ["Installed"], failures: ["Service unavailable"] });
    await store.run();
    expect(request.mock.calls.at(-1)).toEqual(["setup.run", { existing: "replace" }]);
    expect(store.getSnapshot().report?.failures).toEqual(["Service unavailable"]);
  });
  it("failed planning shows an error instead of stale defaults", async () => {
    const { store, request } = harness();
    request.mockRejectedValueOnce(new Error("Cannot read"));
    await store.load();
    expect(store.getSnapshot()).toMatchObject({
      status: "failed",
      state: null,
      error: "Cannot read",
    });
    await store.run();
    expect(request.mock.calls).toHaveLength(1);
  });
  it("setup failures remain visible and allow retry with the same choice", async () => {
    const { store, request } = harness();
    await store.load();
    request.mockRejectedValueOnce(new Error("Some files changed"));
    await store.run();
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: "Some files changed",
      report: null,
      existing: "keep",
    });
    request.mockResolvedValueOnce({ lines: ["Done"], failures: [] });
    await store.run();
    expect(store.getSnapshot().report?.lines).toEqual(["Done"]);
  });
});
