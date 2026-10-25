import { describe, expect, it, vi } from "vitest";
import type { SetupState } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createSetupStore } from "./setup-store";

const plan: SetupState = {
  tools: [],
  changes: [{ path: "~/yabairc", action: "adopt", detail: "Kept" }],
  hasExisting: true,
  canClose: false,
  notices: [],
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
    request.mockResolvedValueOnce({
      lines: ["Installed"],
      failures: ["Service unavailable"],
      failure: null,
    });
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
    request.mockResolvedValueOnce({ lines: ["Done"], failures: [], failure: null });
    await store.run();
    expect(store.getSnapshot().report?.lines).toEqual(["Done"]);
  });
  it("a partial setup keeps the completed lines visible with the reason it stopped", async () => {
    const { store, request } = harness();
    await store.load();
    request.mockResolvedValueOnce({
      lines: ["Moved 1 yabai settings into Macarchy", "Installed default shortcuts"],
      failures: [],
      failure: "Setup did not finish; some files may already have changed. Bar not written",
    });
    await store.run();
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: "Setup did not finish; some files may already have changed. Bar not written",
      report: {
        lines: ["Moved 1 yabai settings into Macarchy", "Installed default shortcuts"],
        failure: "Setup did not finish; some files may already have changed. Bar not written",
      },
    });
  });
  it("a failed run rereads whether the window can close, keeping the report and reason", async () => {
    const { store, request } = harness();
    await store.load();
    const failure = "Setup did not finish; some files may already have changed. Bar not written";
    request.mockResolvedValueOnce({ lines: ["Wrote settings"], failures: [], failure });
    request.mockResolvedValueOnce({ ...plan, canClose: true });
    await store.run();
    expect(request.mock.calls.at(-1)).toEqual(["setup.getPlan", { existing: "keep" }]);
    expect(store.getSnapshot()).toMatchObject({
      busy: false,
      error: failure,
      state: { canClose: true },
      report: { lines: ["Wrote settings"], failure },
    });
    store.reset();
    await vi.waitFor(() => expect(store.getSnapshot().planning).toBe(false));
    expect(store.getSnapshot()).toMatchObject({ error: null, report: null });
  });
});
